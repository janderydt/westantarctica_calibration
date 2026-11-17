function [UserVar,CtrlVar,MeshBoundaryCoordinates]=DefineInitialInputs(UserVar,CtrlVar)
% DefineInitialInputs  Ua user input file: settings of a Ua run (inverse and spinup cycles).
%
% PURPOSE
%   Sets CtrlVar for the current run, depending on UserVar.InverseCycle (inverse
%   run with fmincon and the Hessian-based method) or UserVar.SpinupCycle
%   (time-dependent spinup run). The mesh is read from UserVar.InitialMeshFileName and
%   never adapted. Debug options are at the end.
%
%   Walltime: UserVar.walltime_remaining (seconds, set by the job wrapper) is
%   reduced by a buffer of 60 min (minimum 600 s) and starts a timer that sets the
%   application flag 'UAstopFlag'. This flag is read by fminuncOutfun (inverse
%   runs) and DefineRunStopCriterion (spinup runs) to stop the run cleanly.
%
% INPUTS (fields of UserVar, set by GLUE_UaWrapper and GLUE_GetUserVar_Inverse)
%   walltime_remaining, fid_experimentlog, Experiment, Restart, InverseCycle,
%   SpinupCycle, Spinup.Years/Cycle/Restart, NameOfRestartFiletoRead,
%   InitialMeshFileName, MeshBoundaryCoordinatesFile, SlidingLaw, LevelSetMethod,
%   ThickMin, ThicknessConstraints, ResetThicknessToMinThickness, TargetIterations,
%   Inverse.GradientCalculation/Measurements/InvertFor/logC/logAGlen,
%   NameOfFileForSavingSlipperinessEstimate, NameOfFileForSavingAGlenEstimate, debug
%
% REQUIRES
%   Ua source code, fminuncOutfun (modified copy in ua_core_overrides);
%   MATLAB Optimization Toolbox (fmincon), Parallel Computing Toolbox
%   ('UseParallel' is true)

%% Keep track of walltime
% These lines define a UI to keep track of the remaining walltime.
% If the walltime expires, the UI is set to false, which is picked
% up by the fmincon minimization algorithm or DefineRunStopCriterion.m and 
% used as a stopping % criteria to break out of the inversion or spinup.
% We apply a generous 60min buffer to allow fmincon and the runstep to 
% cleanly finish the current iteration. The remaining walltime should never 
% be negative, so we set it to a minimum value of 600s.
UserVar.walltime_remaining = max(UserVar.walltime_remaining-3600,600);
setappdata(0,'UAstopFlag',false); %stopping flag is false
T = timer('startdelay',UserVar.walltime_remaining,'timerfcn',@(src,evt)setappdata(0,'UAstopFlag',true)); %initialize timer to change value of uastopflag after wallclocktime
t0 = tic(); 
start(T); %start the timer
remainingTime = round(UserVar.walltime_remaining-toc(t0));
fprintf(UserVar.fid_experimentlog,"> At %s: remaining time on wallclock timer is %ss. Ua will be stopped when this time has been exceeded.\n",string(datetime("now")),num2str(remainingTime));

%% 
CtrlVar.Experiment = UserVar.Experiment;
CtrlVar.Restart=UserVar.Restart;

%% Type of run
if UserVar.InverseCycle

    CtrlVar.TimeDependentRun=0; 
    CtrlVar.doInverseStep=1;
    CtrlVar.NRitmax=50;

elseif UserVar.SpinupCycle

    CtrlVar.TimeDependentRun=1; 
    CtrlVar.doInverseStep=0;
    CtrlVar.TotalNumberOfForwardRunSteps=inf; % an arbitrary large number
    CtrlVar.StartTime=0; % in a restart CtrlVar.time will be set to the restart time
    CtrlVar.EndTime=UserVar.Spinup.Years(UserVar.Spinup.Cycle);
    if ~UserVar.Spinup.Restart        
        CtrlVar.ResetTime=1;
        CtrlVar.dt = 1e-3;
        CtrlVar.ResetTimeStep=1; 
        CtrlVar.RestartTime=0;  
    end   

    CtrlVar.InitialDiagnosticStep=1; 
    CtrlVar.NameOfRestartFiletoRead = UserVar.NameOfRestartFiletoRead;   

    UserVar.Spinup.stoppedduetowalltime = 0;
    CtrlVar.UseUserDefinedRunStopCriterion=1;
    
else
    error("Unknown run case");
end

%% Grid options
CtrlVar.TriNodes=3;
CtrlVar.kH=100;
CtrlVar.nip=6;
CtrlVar.niph=6;    
CtrlVar.RefineMeshOnStart=0;

% read intial mesh - this is always the same for inverse and spinup cycles
CtrlVar.ReadInitialMesh=1;
CtrlVar.ReadInitialMeshFileName=UserVar.InitialMeshFileName;

% never adapt mesh as this complicates the diagnostic perturbation
% experiments
CtrlVar.AdaptMesh=0;

%% Boundary
load(UserVar.MeshBoundaryCoordinatesFile,"MeshBoundaryCoordinates");
CtrlVar.UpdateBoundaryConditionsAtEachTimeStep=0;

%% Physics
CtrlVar.SlidingLaw = UserVar.SlidingLaw;

%% Level set
CtrlVar.LevelSetMethod = UserVar.LevelSetMethod; % 0: no calving front evolution

%% Adapt Mesh options
% Adaptive meshing is not used (CtrlVar.AdaptMesh=0 above).

%% Output options
if UserVar.InverseCycle
    CtrlVar.InfoLevelInverse=1; % Overall level of information (inverse runs). 
                                % Note: generally good to combine with CtrlVar.InfoLevelNonLinIt=0;
                                % CtrlVar.InfoLevel=0; to suppress information related to the forward step.   
    CtrlVar.Inverse.InfoLevelBackTrack=1;  % info on backtracking within inverse step
    CtrlVar.InfoLevel=0;
    CtrlVar.InfoLevelBackTrack=0;
    CtrlVar.InfoLevelNonLinIt=0;  
    CtrlVar.Inverse.WriteRestartFile=1;  % always a good idea to write a restart file. 
    CtrlVar.Inverse.NameOfRestartInputFile = UserVar.NameOfRestartFiletoRead;
    CtrlVar.Inverse.NameOfRestartOutputFile = UserVar.NameOfRestartFiletoRead;
    CtrlVar.Inverse.SaveSlipperinessEstimateInSeperateFile=true;
    CtrlVar.Inverse.SaveAGlenEstimateInSeperateFile=true;
    CtrlVar.NameOfFileForSavingSlipperinessEstimate=UserVar.NameOfFileForSavingSlipperinessEstimate;
    CtrlVar.NameOfFileForSavingAGlenEstimate=UserVar.NameOfFileForSavingAGlenEstimate;
else    
    CtrlVar.InfoLevel=1;
    CtrlVar.InfoLevelBackTrack=1;
    CtrlVar.InfoLevelNonLinIt=1;  
    CtrlVar.DefineOutputsDt=1;
    CtrlVar.WriteRestartFile = 1;
    CtrlVar.WriteRestartFileInterval = 100;
    CtrlVar.NameOfRestartFiletoWrite = UserVar.NameOfRestartFiletoRead;

end
CtrlVar.CreateOutputsEndOfRun=1;

%% Plotting
CtrlVar.doplots=0;   
CtrlVar.PlotGLs=0;
CtrlVar.LineUpGLs=0;
CtrlVar.PlotWaitBar=0;
CtrlVar.PlotOceanLakeNodes=0;
CtrlVar.PlotMesh=0;  CtrlVar.PlotBCs=1;
CtrlVar.PlotXYscale=1;

%% Inverse options
if UserVar.InverseCycle
    CtrlVar.Inverse.Iterations=UserVar.TargetIterations; % Number of inverse iterations
    
    CtrlVar.Inverse.DataMisfit.GradientCalculation=UserVar.Inverse.GradientCalculation; % {'Adjoint','FixPoint'}
    
    CtrlVar.Inverse.Measurements=UserVar.Inverse.Measurements;
    
    CtrlVar.Inverse.InvertFor=UserVar.Inverse.InvertFor; % {'-C-','-logC-','-A-','-logA-'}
    CtrlVar.Inverse.Regularize.Field=CtrlVar.Inverse.InvertFor; 
    
    CtrlVar.Inverse.DataMisfit.Multiplier=1;
    CtrlVar.Inverse.Regularize.Multiplier=1;
    
    % regularisation parameters
    CtrlVar.Inverse.Regularize.logAGlen.ga=UserVar.Inverse.logAGlen.ga;
    CtrlVar.Inverse.Regularize.logAGlen.gs=UserVar.Inverse.logAGlen.gs ;
    CtrlVar.Inverse.Regularize.logC.ga=UserVar.Inverse.logC.ga;
    CtrlVar.Inverse.Regularize.logC.gs=UserVar.Inverse.logC.gs; 

    CtrlVar.Inverse.MinimisationMethod="MatlabOptimization-HessianBased"; 
    CtrlVar.Inverse.Hessian="RHA=E RHC=E IHC=FP IHA=FP";
end

%% Settings for optimization algorithm
Hfunc=@(p,lambda) p+lambda ;  % just needs to defined here, this is then later replaced with a function that returns the Hessian estmation.
CtrlVar.Inverse.MatlabOptimisationHessianParameters = optimoptions('fmincon',...
        'Algorithm','interior-point',...
        'CheckGradients',false,...
        'ConstraintTolerance',1e-10,...
        'HonorBounds',true,...
        'Diagnostics','on',...
        'DiffMaxChange',Inf,...
        'DiffMinChange',0,...
        'Display','iter-detailed',...
        'FunValCheck','off',...
        'MaxFunctionEvaluations',1e6,...
        'MaxIterations',CtrlVar.Inverse.Iterations,...,...
        'OptimalityTolerance',1e-20,...
        'OutputFcn',@fminuncOutfun,...
        'PlotFcn',{@optimplotlogfval,@optimplotstepsize},...
        'StepTolerance',1e-30,...
        'FunctionTolerance',1,...
        'UseParallel',true,...
        'HessianFcn',Hfunc,...
        'HessianMultiplyFcn',[],...
        'InitBarrierParam',1e-7,...           % On a restart this might have to be reduced if objective function starts to increase
        'ScaleProblem','none',...
        'InitTrustRegionRadius',1,...         % set to smaller value if the forward problem is not converging
        'SpecifyConstraintGradient',false,...
        'SpecifyObjectiveGradient',true,...
        'SubproblemAlgorithm','cg');  % here the options are 'gc' and 'factorization', unclear whic

CtrlVar.Cmin=1e-150;  CtrlVar.Cmax=1e150;                                                  

%% Minimum ice thickness
CtrlVar.ThicknessConstraints=UserVar.ThicknessConstraints;
CtrlVar.ResetThicknessToMinThickness=UserVar.ResetThicknessToMinThickness;
CtrlVar.ThickMin=UserVar.ThickMin;
CtrlVar.ThicknessConstraintsItMax = 0;

%% Debugging options
if UserVar.debug == 1
    CtrlVar.InfoLevel=100;
    CtrlVar.InfoLevelBackTrack=10;
    CtrlVar.InfoLevelNonLinIt=100;
    CtrlVar.doplots=1;   
    CtrlVar.PlotGLs=1;
end

end
