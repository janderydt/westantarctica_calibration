function UserVar = GetUserVar_Inverse(RunTable,ind,UserVar)
% GetUserVar_Inverse  Translate one run table row into the UserVar structure for Ua.
%
% PURPOSE
%   Called at the start of each Ua run of the inverse/spinup experiment (see
%   UaWrapper). Reads the row ind of the run table and feeds all the
%   information to Ua via UserVar. The content of this function is entirely
%   flexible and has to be adapted to the parameters you need to provide to Ua
%   at runtime.
%
%   Which part of the experiment is run follows from InverseIterations /
%   InverseIterationsDone and SpinupYears / SpinupYearsDone: cycles alternate as
%       inverse cycle 1 -> spinup cycle 1 -> inverse cycle 2 -> spinup cycle 2 ...
%   Example: InverseIterations "10000+5000" and SpinupYears "3" = inverse run of
%   10000 iterations (velocities only), spinup of 3 years, inverse run of 5000
%   iterations (velocities and dhdt). The first inverse cycle never uses dhdt.
%
% INPUTS
%   RunTable : run table (see ReadWritetable; columns as in EmptyTable.csv)
%   ind      : row of the experiment in the run table
%   UserVar  : struct; the fields Restart, fid_experimentlog, Experiment, ExpID,
%              Domain, datafolder, casefolder and hostname are set by the wrapper
%
% OUTPUT
%   UserVar with, among others: InverseCycle/SpinupCycle (which type of run),
%   Inverse.* and Spinup.* (iterations, years, regularisation, measurements),
%   file names for geometry, density, velocity and dhdt interpolants (in
%   <datafolder>/1_interpolants), mesh (DefineBaseMesh,
%   ApplyMeshModifications), sliding law, rheology, thickness constraints.
%
% START VALUES (run table columns startC, startAglen)
%   > 0     : ExpID of an earlier experiment whose C (or AGlen) estimate is used as
%             start value (needs the results of that experiment)
%   -9999   : (C only) initial guess from the measured velocities
%   0       : constant prior value (priorC, priorAGlen); the run tables of the ensemble use 0
%
% INTERPOLANT FILES in <datafolder>/1_interpolants (can be obtained upon request from the author, see README)
%   AMUND_nsmbl    : GriddedInterpolants_Geometry_01-Jun-<year>_EXTRUDED.mat,
%                    GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities.mat,
%                    GriddedInterpolants_dhdt_01-Jun-<year>.mat
%   SYNTH_PIG_nsmbl: ScatteredInterpolants_Geometry_SYNTH_PIG_<startGeometry>.mat,
%                    ScatteredInterpolants_Velocities_SYNTH_PIG_<Velocity>.mat,
%                    ScatteredInterpolants_dhdt_SYNTH_PIG_<startGeometry>.mat
%
% REQUIRES
%   DefineBaseMesh, ApplyMeshModifications (ua_input/2_meshing)

% initialize variables: either start a new simulation with
% an inverse cycle, or continue an existing simulation with
% a spinup or inverse cycle

iter_tmp = RunTable{ind,"InverseIterations"}{:};
UserVar.Inverse.Iterations = str2double(split(iter_tmp,"+"));
UserVar.Inverse.IterationsDone = RunTable{ind,"InverseIterationsDone"};
UserVar.Inverse.Cycle = find([0; cumsum(UserVar.Inverse.Iterations)]==UserVar.Inverse.IterationsDone);
if isempty(UserVar.Inverse.Cycle) & UserVar.Restart == 0
    fprintf(UserVar.fid_experimentlog,"> GetUserVar_Inverse: Expecting InverseIterationsDone to be equal to [%s] but got %s instead.\n",...
            string(iter_tmp),string(UserVar.Inverse.IterationsDone));
    error("Unexpected number of InverseIterationsDone.");
elseif isempty(UserVar.Inverse.Cycle) & UserVar.Restart
    %% restarting inverse cycle 
    UserVar.InverseCycle = 1;
    UserVar.SpinupCycle = 0;
    Itmp = find(cumsum(UserVar.Inverse.Iterations)-UserVar.Inverse.IterationsDone>0);
    UserVar.Inverse.Cycle = Itmp(1);
end

spinup_tmp = RunTable{ind,"SpinupYears"}{:};
UserVar.Spinup.Years = str2double(split(spinup_tmp,"+"));
UserVar.Spinup.YearsDone = RunTable{ind,"SpinupYearsDone"};
UserVar.Spinup.Cycle = find([0; cumsum(UserVar.Spinup.Years)]==UserVar.Spinup.YearsDone);
UserVar.Spinup.Restart = 0;
if isempty(UserVar.Spinup.Cycle) & UserVar.Restart == 0
    fprintf(UserVar.fid_experimentlog,"> GetUserVar_Inverse: Expecting SpinupYearsDone to be equal to [%s] but got %s instead.\n",...
            string(spinup_tmp),string(UserVar.Spinup.YearsDone));
    error("Unexpected number of SpinupYearsDone.");
elseif isempty(UserVar.Spinup.Cycle) & UserVar.Restart == 1
    %% restarting spinup cycle 
    UserVar.Spinup.Restart = 1;
    Itmp = find(cumsum(UserVar.Spinup.Years)-UserVar.Spinup.YearsDone>0);
    UserVar.Spinup.Cycle = Itmp(1);
end

% Restart files
UserVar.NameOfRestartFiletoRead = UserVar.Experiment + "-RestartFile.mat";

% Read Density from RunTable
Geometry = RunTable{ind,"startGeometry"};

fprintf(UserVar.fid_experimentlog,"Density from geometry file: %s\n",string(Geometry));
fprintf(UserVar.fid_experimentlog,class(Geometry));

if ismember(string(UserVar.Domain),"AMUND_nsmbl")
    switch Geometry
        case {'2000','2009','2014','2018','2020'}
            UserVar.DensityInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_Geometry_01-Jun-"+string(Geometry)+"_EXTRUDED.mat";
        otherwise
            error("ExpID "+string(RunTable{ind,"ExpID"})+": Do not recognise Geometry flag in RunTable");
    end
elseif ismember(string(UserVar.Domain),"SYNTH_PIG_nsmbl")
    UserVar.DensityInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/ScatteredInterpolants_Geometry_SYNTH_PIG_"+string(Geometry)+".mat";
    
    fprintf(UserVar.fid_experimentlog,"%s",UserVar.DensityInterpolants);
    if ~exist(UserVar.DensityInterpolants,"file")
        error("ExpID "+RunTable{ind,"ExpID"}+": Do not recognise file for density interpolants: "+UserVar.DensityInterpolants);
    end
else
    error("Do not recognize case "+string(UserVar.Domain));
end


% Always read dhdt interpolants even if they don't get used
UserVar.Geometry = RunTable{ind,"startGeometry"};
UserVar.Inverse.Measurements = RunTable{ind,"Measurements"}{:};
if contains(UserVar.Inverse.Measurements,"dhdt")
    if ismember(string(UserVar.Domain),"AMUND_nsmbl")
        UserVar.dhdtInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_dhdt_01-Jun-"+string(UserVar.Geometry)+".mat";   
    elseif ismember(string(UserVar.Domain),"SYNTH_PIG_nsmbl")
        UserVar.dhdtInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/ScatteredInterpolants_dhdt_SYNTH_PIG_"+string(UserVar.Geometry)+".mat";
    else
        error("Do not recognize case "+string(UserVar.Domain));
    end
    UserVar.Inverse.dhdt_err = RunTable{ind,"dhdt_err"};
end

% Read Geometry from RunTable and set up calving front if needed
if ismember(string(UserVar.Domain),"AMUND_nsmbl")
    UserVar.LevelSetMethod=0;
elseif ismember(string(UserVar.Domain),"SYNTH_PIG_nsmbl")
    UserVar.Geometry = []; % set empty to skip mesh modifications in ApplyMeshModifications
    UserVar.LevelSetMethod=0;
else
    error("Do not recognize case "+string(UserVar.Domain));
end

% How is minimum thickness enforced?
UserVar.ThickMin = 1;
if ismember(string(UserVar.Domain),["AMUND_nsmbl","SYNTH_PIG_nsmbl"])
    UserVar.ThicknessConstraints=0;
    UserVar.ResetThicknessToMinThickness=1;
else
    error("Do not recognize case "+string(UserVar.Domain));
end

% Sliding law
UserVar.SlidingLaw = RunTable{ind,"SlidingLaw"}{:};
UserVar.SlidingCoefficient = RunTable{ind,"m"};
UserVar.muk = RunTable{ind,"muk"};
UserVar.NameOfFileForSavingSlipperinessEstimate=string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"ExpID"})+"_C-Estimate.mat";

% Rheology
UserVar.n = RunTable{ind,"n"};
UserVar.NameOfFileForSavingAGlenEstimate=string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"ExpID"})+"_AGlen-Estimate.mat";

% Mesh variables
%% !!!!!! This script assumes that the mesh is not adapted during the spinup cycles. !!!!!!!
%% Adapting in the mesh is not advised anyway, because it complicates the diagnostic perturbation experiments
UserVar = DefineBaseMesh(UserVar,RunTable{ind,"startMesh"}{:});
UserVar = ApplyMeshModifications(UserVar);

% Outputs
UserVar.UaOutputDirectory = './ResultsFiles';

% Initialize other variables
if UserVar.Inverse.Cycle == 1
    %% (re)start first inverse cycle
    UserVar.InverseCycle = 1;
    UserVar.SpinupCycle = 0;

    fprintf(UserVar.fid_experimentlog,"> GetUserVar_Inverse: ExpID %s: Start inverse cycle %s on %s.\n",string(UserVar.ExpID),string(UserVar.Inverse.Cycle),UserVar.hostname);

    UserVar = GetUserVar_FirstInverseRun(RunTable,ind,UserVar);

else
    if UserVar.Inverse.Cycle == UserVar.Spinup.Cycle
        %% start new inverse cycle
        UserVar.InverseCycle = 1;
        UserVar.SpinupCycle = 0;
      
        fprintf(UserVar.fid_experimentlog,"> GetUserVar_Inverse: ExpID %s: Start inverse cycle %s on %s.\n",string(UserVar.ExpID),string(UserVar.Inverse.Cycle),UserVar.hostname);

        UserVar = GetUserVar_InverseAfterSpinup(RunTable,ind,UserVar);

    elseif UserVar.Inverse.Cycle > UserVar.Spinup.Cycle
        %% start spinup cycle
        UserVar.SpinupCycle = 1;
        UserVar.InverseCycle = 0;
       
        fprintf(UserVar.fid_experimentlog,"> GetUserVar_Inverse: ExpID %s: Start spinup cycle %s on %s.\n",string(UserVar.ExpID),string(UserVar.Spinup.Cycle),UserVar.hostname);

        UserVar = GetUserVar_Spinup(RunTable,ind,UserVar);

    else
        error("Something odd happened: number of inverse cycles (%s) should be >= number of spinup cycles (%s).",...
            string(UserVar.Inverse.Cycle),string(UserVar.Spinup.Cycle));
    end
end

end

%% ======================== %%
%% === helper functions === %%
%% ======================== %%

function UserVar = GetUserVar_InverseAfterSpinup(RunTable,ind,UserVar)

UserVar.Restart = 0;

%% Read inversion parameters from Runtable
UserVar.Inverse.GradientCalculation = RunTable{ind,"GradientCalc"}{:};
UserVar.Inverse.InvertFor = RunTable{ind,"InvertFor"}{:};
UserVar.Inverse.logC.gs = RunTable{ind,"gsC"};
UserVar.Inverse.logAGlen.gs = RunTable{ind,"gsA"};
UserVar.Inverse.logC.ga = RunTable{ind,"gaC"};
UserVar.Inverse.logAGlen.ga = RunTable{ind,"gaA"};

%% geometry interpolants from spinup
NameOfRestartFiletoRead = ...
    strrep(UserVar.NameOfRestartFiletoRead,".mat","_SpinupCycle"+string(UserVar.Inverse.Cycle-1)+".mat");
load(UserVar.casefolder+"/"+UserVar.Experiment+"/"+NameOfRestartFiletoRead,"F","MUA");

UserVar.GeometryInterpolants = "ScatteredInterpolants_GeometryfromSpinupCycle"+string(UserVar.Inverse.Cycle-1)+".mat";

% (No interpolants of the spinup geometry are created: the mesh is not changed
% during the spinup.)
% We create a new file with the Ua geometry fields at the end of the spinup,
% so we can use these fields directly in the next inversion. This wastes a bit of 
% storage space, but for spinup simulation we do not adapt the mesh, so
% it is more memory efficient to read the Ua fields directly, rather than
% load interpolants
B=F.B; b=F.b; s=F.s; S=F.S; rho=F.rho;
save(UserVar.casefolder+"/"+UserVar.Experiment+"/GeometryfromSpinupCycle"+string(UserVar.Inverse.Cycle-1)+"_mesh_Nnodes"+string(MUA.Nnodes)+"_Nele"+string(MUA.Nele)+".mat","B","S","s","b","rho");

%% velocity interpolants
UserVar = DefineVelocityInterpolant(UserVar,RunTable,ind);

%% sliding law
UserVar.NameOfFileForReadingSlipperinessEstimate=UserVar.NameOfFileForSavingSlipperinessEstimate;
% make sure NameOfFileForReadingSlipperinessEstimate contains the correct
% fields in case they were accidentally overwritten
load(UserVar.casefolder+"/"+UserVar.Experiment+"/"+NameOfRestartFiletoRead,"F","MUA","CtrlVarInRestartFile");
C = F.C; xC = MUA.coordinates(:,1); yC = MUA.coordinates(:,2); m = F.m;
muk = F.muk; q = F.q;
save(UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.NameOfFileForReadingSlipperinessEstimate,...
    "MUA","CtrlVarInRestartFile","xC","yC","C","m","muk","q");
UserVar.Inverse.priorC = RunTable{ind,"priorC"};

%% Glen's exponent
UserVar.NameOfFileForReadingAGlenEstimate=UserVar.NameOfFileForSavingAGlenEstimate;
% make sure NameOfFileForReadingAGlenEstimate contains the correct
% fields in case they were accidentally overwritten
load(UserVar.casefolder+"/"+UserVar.Experiment+"/"+NameOfRestartFiletoRead,"F","MUA","CtrlVarInRestartFile");
AGlen = F.AGlen; xA = MUA.coordinates(:,1); yA = MUA.coordinates(:,2); n = F.n;
save(UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.NameOfFileForReadingAGlenEstimate,...
    "MUA","CtrlVarInRestartFile","xA","yA","AGlen","n");
UserVar.Inverse.priorAGlen = RunTable{ind,"priorAGlen"};

end

function UserVar = GetUserVar_Spinup(RunTable,ind,UserVar)

UserVar.Restart = 1;

% make sure to start from the correct restart file
if UserVar.Spinup.Restart == 0 
    % this means we start a new spinup, using the restart file from the previous inversion
    NameOfRestartInputFile = strrep(UserVar.NameOfRestartFiletoRead,".mat","_InverseCycle"+string(UserVar.Spinup.Cycle)+".mat");
    copyfile(UserVar.casefolder+"/"+string(UserVar.Experiment)+"/"+NameOfRestartInputFile,...
        UserVar.casefolder+"/"+string(UserVar.Experiment)+"/"+UserVar.NameOfRestartFiletoRead);
else
    % we restart the spinup in the current spinup cycle
    NameOfRestartInputFile = strrep(UserVar.NameOfRestartFiletoRead,".mat","_SpinupCycle"+string(UserVar.Spinup.Cycle)+".mat");
    copyfile(UserVar.casefolder+"/"+string(UserVar.Experiment)+"/"+NameOfRestartInputFile,...
        UserVar.casefolder+"/"+string(UserVar.Experiment)+"/"+UserVar.NameOfRestartFiletoRead);
end

%% Read geometry interpolants from Runtable
UserVar = DefineGeometryInterpolant(UserVar,RunTable,ind);

%% mesh boundary
UserVar.MeshBoundaryCoordinatesFile = UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.Experiment+"_MeshBoundaryCoordinates.mat";

%% velocity interpolants for fixed boundaries
UserVar = DefineVelocityInterpolant(UserVar,RunTable,ind);

%% sliding law
UserVar.NameOfFileForReadingSlipperinessEstimate=UserVar.NameOfFileForSavingSlipperinessEstimate;
% C is not updated for floating ice, except for some
% regularization-dependent smoothing. A more representative value for C
% beneath the ice shelves could be obtained by extruding C from the
% grounded ice along streamlines. We use streamlines based on the
% velocity fields obtained through the inversion. Note that is very ad-hoc
% and users might want to change this part of the code.
load(UserVar.casefolder+"/"+string(UserVar.Experiment)+"/"+UserVar.NameOfRestartFiletoRead,"CtrlVarInRestartFile","MUA","F");
C = F.C;
xC = MUA.coordinates(:,1); yC = MUA.coordinates(:,2); m = F.m;
muk = F.muk; q = F.q;
save(UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.NameOfFileForReadingSlipperinessEstimate,...
    "MUA","CtrlVarInRestartFile","xC","yC","C","m","muk","q");

%% Glen's exponent
UserVar.NameOfFileForReadingAGlenEstimate=UserVar.NameOfFileForSavingAGlenEstimate;
% make sure NameOfFileForReadingAGlenEstimate contains the correct
% fields in case they were accidentally overwritten
load(UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.NameOfRestartFiletoRead,"F","MUA","CtrlVarInRestartFile");
AGlen = F.AGlen; xA = MUA.coordinates(:,1); yA = MUA.coordinates(:,2); n = F.n;
save(UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.NameOfFileForReadingAGlenEstimate,...
    "MUA","CtrlVarInRestartFile","xA","yA","AGlen","n");
    
end

function UserVar = GetUserVar_FirstInverseRun(RunTable,ind,UserVar)

%% Read inversion parameters from Runtable
UserVar.Inverse.Measurements = "-uv-"; % don't use dhdt in first inverse cycle
UserVar.Inverse.GradientCalculation = RunTable{ind,"GradientCalc"}{:};
UserVar.Inverse.InvertFor = RunTable{ind,"InvertFor"}{:};
UserVar.Inverse.logC.gs = RunTable{ind,"gsC"};
UserVar.Inverse.logAGlen.gs = RunTable{ind,"gsA"};
UserVar.Inverse.logC.ga = RunTable{ind,"gaC"};
UserVar.Inverse.logAGlen.ga = RunTable{ind,"gaA"};

%% Read geometry interpolants from Runtable
UserVar = DefineGeometryInterpolant(UserVar,RunTable,ind);

%% density interpolant
UserVar.DensityInterpolant = UserVar.GeometryInterpolants;

%% velocity interpolants
UserVar = DefineVelocityInterpolant(UserVar,RunTable,ind);

%% sliding law
UserVar.Inverse.startC = 0;
if RunTable{ind,"startC"} > 0
    % copy relevant files   
    RestartFile = UserVar.casefolder+"/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"startC"})+...
        "/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"startC"})+"-RestartFile_InverseCycle1.mat";
    UserVar.NameOfFileForReadingSlipperinessEstimate=string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"startC"})+"_C-Estimate.mat";
    
    if exist(RestartFile,"file")
        load(RestartFile,"F","MUA","CtrlVarInRestartFile");
        C = F.C; xC = MUA.coordinates(:,1); yC = MUA.coordinates(:,2); m = F.m;
        muk = F.muk; q = F.q;
        save(UserVar.casefolder+"/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"ExpID"})+...
            "/"+UserVar.NameOfFileForReadingSlipperinessEstimate,"MUA","CtrlVarInRestartFile","xC","yC","C","m","muk","q");
    else    
        copyfile(UserVar.casefolder+"/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"startC"})+...
                "/"+UserVar.NameOfFileForReadingSlipperinessEstimate,...
                UserVar.casefolder+"/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"ExpID"})+...
                "/"+UserVar.NameOfFileForReadingSlipperinessEstimate);
    end
elseif RunTable{ind,"startC"} == -9999
    UserVar.Inverse.startC = -9999;
    UserVar.NameOfFileForReadingSlipperinessEstimate="";
else
    UserVar.NameOfFileForReadingSlipperinessEstimate="";
end
UserVar.Inverse.priorC = RunTable{ind,"priorC"};

%% Glen's exponent
if RunTable{ind,"startAglen"} > 0
    % copy relevant files   
    RestartFile = UserVar.casefolder+"/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"startAglen"})+...
        "/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"startAglen"})+"-RestartFile_InverseCycle1.mat";
    UserVar.NameOfFileForReadingAGlenEstimate=string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"startAglen"})+"_AGlen-Estimate.mat";
    if exist(RestartFile,"file")
        load(RestartFile,"F","MUA","CtrlVarInRestartFile");
        AGlen = F.AGlen; xA = MUA.coordinates(:,1); yA = MUA.coordinates(:,2); n = F.n;
        save(UserVar.casefolder+"/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"ExpID"})+...
            "/"+UserVar.NameOfFileForReadingAGlenEstimate,"MUA","CtrlVarInRestartFile","xA","yA","AGlen","n");
    else    
        copyfile(UserVar.casefolder+"/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"startAglen"})+...
            "/"+UserVar.NameOfFileForReadingAGlenEstimate,...
            UserVar.casefolder+"/"+string(UserVar.Domain)+"_Inverse_"+string(RunTable{ind,"ExpID"})+...
            "/"+UserVar.NameOfFileForReadingAGlenEstimate);
    end 
elseif RunTable{ind,"startAglen"} == -9999
    UserVar.Inverse.startAGlen = -9999;
    UserVar.NameOfFileForReadingAGlenEstimate="";  
else
    UserVar.NameOfFileForReadingAGlenEstimate="";
end
UserVar.Inverse.priorAGlen = RunTable{ind,"priorAGlen"};

end

function UserVar = DefineGeometryInterpolant(UserVar,RunTable,ind)

% Just adding this line in case the geometry has been modified above
UserVar.Geometry = RunTable{ind,"startGeometry"};

if ismember(string(UserVar.Domain),"AMUND_nsmbl")
    switch UserVar.Geometry
        case {'2000','2009','2014','2018','2020'}
            UserVar.GeometryInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_Geometry_01-Jun-"+num2str(UserVar.Geometry)+"_EXTRUDED.mat";
        otherwise
            error(['ExpID ',RunTable{ind,"ExpID"},': Do not recognise Geometry flag in RunTable.']);
    end
elseif ismember(string(UserVar.Domain),"SYNTH_PIG_nsmbl")
    UserVar.GeometryInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/ScatteredInterpolants_Geometry_SYNTH_PIG_"+string(UserVar.Geometry)+".mat";
end

end

function UserVar = DefineVelocityInterpolant(UserVar,RunTable,ind)

UserVar.Velocity = RunTable{ind,"Velocity"};

if ismember(string(UserVar.Domain),"AMUND_nsmbl")
    switch UserVar.Velocity
        case '2000'
            UserVar.VelocityInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities.mat";
        case {'2009','2014','2018','2020'}
            UserVar.VelocityInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_"+string(UserVar.Velocity)+"-"+string(UserVar.Velocity+1)+"_MeaSUREs_ITSLIVE_Velocities.mat";
        otherwise
            error(['ExpID ',RunTable{ind,"ExpID"},': Do not recognise Velocity flag in RunTable.']);
    end
elseif ismember(string(UserVar.Domain),"SYNTH_PIG_nsmbl")
    UserVar.VelocityInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/ScatteredInterpolants_Velocities_SYNTH_PIG_"+string(UserVar.Velocity)+".mat";
end

end
