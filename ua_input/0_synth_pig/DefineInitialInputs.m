function [UserVar,CtrlVar,MeshBoundaryCoordinates]=DefineInitialInputs(UserVar,CtrlVar)
% DefineInitialInputs  Ua user input file of the synthetic SYNTH_PIG experiments (spinup, transient runs, inversion test).
%
% PURPOSE
%   Sets the type of run, the mesh, the physics, the inversion and the output options of the experiments with the
%   synthetic glacier. An experiment is selected by CtrlVar.Experiment and the flags TimeDependentRun, InverseRun and
%   Restart, which are edited for each run; UserVar.m, UserVar.n and UserVar.SlidingLaw set the sliding law exponent, the
%   Glen exponent and the sliding law. As supplied, the file is set up for the inversion test (Experiment "SYNTH_inv",
%   InverseRun=1). The experiments of the paper are run in this order: a spinup without melt ("spinup_nomelt"), then a
%   spinup with the cold ocean temperature profile ("cold_<SlidingLaw>", low basal melt), then the warm ocean temperature
%   profile is activated ("warm_<SlidingLaw>", high basal melt); the times of the result files of the warm experiment
%   (30, 35, 40, 45, 50 and 75 years) are the epochs Weertmanyr30, ..., Weertmanyr75 / Umbiyr30, ... used in the
%   calibration. Parts of the experiment name that are recognised in the files of this folder:
%     "spinup"  : spinup run (the initial geometry is a linear surface on the bed, DefineGeometryAndDensities; output every
%                 10 years); the experiment "spinup_nomelt" is read by the "cold" experiments
%     "cold", "warm" : transient run with low or high basal melt (DefineMassBalance); runs that are not inversions read
%                 the estimates of C and AGlen from C-Estimate_<SlidingLaw>_m<m>.mat and
%                 AGlen-Estimate_<SlidingLaw>_m<m>.mat; output every 10 years ("cold") or every year ("warm")
%     "calving" : calving experiment with the level set method (DefineCalving; restart file cold-RestartFile.mat, output
%                 every day)
%     "nochange": geometry from the result file of the experiment "warm" after 15 years (DefineGeometryAndDensities)
%     "test"    : the estimates of C and AGlen are read from C-Estimate.mat and AGlen-Estimate.mat
%   Output (results files): DefineOutputs.
%
% FILES READ
%   MeshFile_Nele22114_Nnodes11338.mat, MeshBoundaryCoordinates.mat (mesh of the synthetic glacier, 22114 elements)
%
% REQUIRES
%   Ua source code, fminuncOutfun (modified copy in ua_input/run/ua_core_overrides); MATLAB Optimization Toolbox
%   (fmincon), Parallel Computing Toolbox ('UseParallel' is true)

CtrlVar.Experiment = 'SYNTH_inv';
UserVar.m = 4;
UserVar.n = 3;
UserVar.SlidingLaw = "Weertman";

%% Type of run
%
CtrlVar.TimeDependentRun=0;
CtrlVar.InverseRun=1;
CtrlVar.Restart=0;
%
if CtrlVar.Restart
    CtrlVar.ResetTime=1;
    CtrlVar.RestartTime=0;
    CtrlVar.ResetRunStepNumber=1;
    CtrlVar.ResetTimeStep=1;
end
if CtrlVar.TimeDependentRun
    CtrlVar.StartTime=0 ; % start time (decimal year, e.g. 2000.5)
    CtrlVar.EndTime=100; % end time (decimal year, e.g. 2001.5)
    CtrlVar.dt=1e-2; % time step
    CtrlVar.dtmin=1e-6;
    CtrlVar.ATSdtMin=1e-6;
    CtrlVar.AdaptMesh=1;
end
if ~CtrlVar.TimeDependentRun && ~CtrlVar.InverseRun
    CtrlVar.TotalNumberOfForwardRunSteps=1;
else
    CtrlVar.TotalNumberOfForwardRunSteps=1e10;
end
if contains(CtrlVar.Experiment,"calving")
    CtrlVar.LevelSetMethod=1;
    CtrlVar.LevelSetEvolution="-By solving the level set equation-" ;
    UserVar.RunType="-c0isGL0-"; %initial calving front is grounding line
    CtrlVar.LevelSetMethodMassBalanceFeedbackCoeffLin=-100;
    CtrlVar.LevelSetInfoLevel=1;
    CtrlVar.LevelSetInitialisationInterval=1;
end

%% Grid options
CtrlVar.TriNodes=3;
CtrlVar.kH=100;
CtrlVar.nip=6;
CtrlVar.niph=6;
CtrlVar.ReadInitialMesh=1;
CtrlVar.ReadInitialMeshFileName="MeshFile_Nele22114_Nnodes11338.mat";
CtrlVar.RefineMeshOnStart=0;

CtrlVar.MeshSize=1.25e3;
CtrlVar.MeshSizeMax=1.25e3;
CtrlVar.MeshSizeMin=0.1e3;

if CtrlVar.AdaptMesh == 1
    CtrlVar.InfoLevelAdaptiveMeshing=1;

    CtrlVar.MeshAdapt.GLrange=[5000 CtrlVar.MeshSizeMin*5; 2500 CtrlVar.MeshSizeMin*2; 1000 CtrlVar.MeshSizeMin];
    CtrlVar.AdaptMeshAndThenStop=0;    % if true, then mesh will be adapted but no further calculations performed
    CtrlVar.AdaptMeshMaxIterations=5;

    CtrlVar.AdaptMeshUntilChangeInNumberOfElementsLessThan=10;
    CtrlVar.MeshRefinementMethod='explicit:local:newest vertex bisection';

    CtrlVar.SaveAdaptMeshFileName='MeshFileAdapt';    %  file name for saving adapt mesh. If left empty, no file is written
    CtrlVar.AdaptMeshRunStepInterval=10 ; % remesh whenever mod(Itime,CtrlVar.AdaptMeshInterval)==0
end

%% Define domain boundary
load("MeshBoundaryCoordinates.mat");

%% Physics
CtrlVar.SlidingLaw = UserVar.SlidingLaw;

%% Inverse options
if CtrlVar.InverseRun
    CtrlVar.Inverse.Iterations=10000; % Number of inverse iterations
    CtrlVar.Inverse.DataMisfit.GradientCalculation='Adjoint';
    CtrlVar.Inverse.InvertFor='-logC-logA-'; % {'-C-','-logC-','-A-','-logA-'}
    CtrlVar.Inverse.Regularize.Field=CtrlVar.Inverse.InvertFor;

    CtrlVar.Inverse.WriteRestartFile=1;  % always a good idea to write a restart file.

    CtrlVar.Inverse.NameOfRestartOutputFile=CtrlVar.Experiment+"_RestartFile.mat";
    CtrlVar.Inverse.NameOfRestartInputFile=CtrlVar.Inverse.NameOfRestartOutputFile;
    CtrlVar.Inverse.Measurements='-uv-';

    CtrlVar.Inverse.DataMisfit.Multiplier=1;
    CtrlVar.Inverse.Regularize.Multiplier=1;

    % regularisation parameters
    CtrlVar.Inverse.Regularize.logAGlen.ga=1;
    CtrlVar.Inverse.Regularize.logAGlen.gs=2.5e4;
    CtrlVar.Inverse.Regularize.logC.ga=1;
    CtrlVar.Inverse.Regularize.logC.gs=2.5e4;
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

%% Output options
CtrlVar.InfoLevelNonLinIt=1;
CtrlVar.InfoLevel=1;

CtrlVar.NameOfRestartFiletoWrite = CtrlVar.Experiment+"-RestartFile.mat";

if contains(CtrlVar.Experiment,"calving")
    CtrlVar.NameOfRestartFiletoRead = "cold-RestartFile.mat";
else
    CtrlVar.NameOfRestartFiletoRead = CtrlVar.NameOfRestartFiletoWrite;
end
CtrlVar.CreateOutputsBeginningOfRun=1;
CtrlVar.CreateOutputsEndOfRun=1; % always call DefineOutputs at the end of a run

if contains(CtrlVar.Experiment,["spinup","cold"])
    CtrlVar.DefineOutputsDt=10; % write output files at given interval (yrs)
elseif contains(CtrlVar.Experiment,"calving")
    CtrlVar.DefineOutputsDt=1/365.25;
else
    CtrlVar.DefineOutputsDt=1;
end

if CtrlVar.InverseRun
    CtrlVar.NameOfFileForSavingSlipperinessEstimate=CtrlVar.Experiment+"_C-Estimate.mat";
    CtrlVar.NameOfFileForSavingAGlenEstimate=CtrlVar.Experiment+"_AGlen-Estimate.mat";
else
    if contains(CtrlVar.Experiment,"test")
        CtrlVar.NameOfFileForReadingSlipperinessEstimate="C-Estimate.mat";
        CtrlVar.NameOfFileForReadingAGlenEstimate="AGlen-Estimate.mat";
    elseif contains(CtrlVar.Experiment,["cold","warm"])
        CtrlVar.NameOfFileForReadingSlipperinessEstimate="C-Estimate_"+string(CtrlVar.SlidingLaw)+"_m"+string(UserVar.m)+".mat";
        CtrlVar.NameOfFileForReadingAGlenEstimate="AGlen-Estimate_"+string(CtrlVar.SlidingLaw)+"_m"+string(UserVar.m)+".mat";
    else
        CtrlVar.NameOfFileForReadingSlipperinessEstimate="inverse_m"+string(UserVar.m)+"_C-Estimate.mat";
        CtrlVar.NameOfFileForReadingAGlenEstimate="inverse_m"+string(UserVar.m)+"_AGlen-Estimate.mat";
    end
end

%% Plotting
CtrlVar.doplots=0;
CtrlVar.PlotWaitBar=0;
CtrlVar.PlotOceanLakeNodes=0;
CtrlVar.PlotMesh=0;  CtrlVar.PlotBCs=1;
CtrlVar.PlotXYscale=1;

%% Other
CtrlVar.ThicknessConstraints=1;
CtrlVar.ThickMin=1;
