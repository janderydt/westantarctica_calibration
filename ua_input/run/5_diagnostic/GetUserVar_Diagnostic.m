function UserVar = GetUserVar_Diagnostic(RunTable,ind,UserVar)
% GetUserVar_Diagnostic  Translate one row of the diagnostic run table into UserVar for Ua.
%
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% This function reads the results of the inverse experiments (restart files
% ../4_inverse/cases/<Domain>/<Domain>_Inverse_<ExpID>/<...>-RestartFile_InverseCycle<k>.mat),
% which can be obtained upon request from the author.
%
% PURPOSE
%   Called by UaWrapper for run type "Diagnostic". A diagnostic experiment is a
%   velocity solve (no time evolution) with the C and AGlen fields of an inverse
%   experiment, and with the geometry of the inverse experiment (before or after the
%   spinup) possibly perturbed: a different calving front (mesh), ice shelf thickness
%   and/or grounded ice thickness. Run table columns used:
%     BaseMesh                 : base mesh (see DefineBaseMesh)
%     Calv                     : calving front year (UserVar.Calv, see ApplyMeshModifications)
%     ISthick, GIthick         : geometry of the ice shelf / grounded ice (year for AMUND,
%                                "Weertmanyr30" etc. for SYNTH_PIG)
%     InverseCycleIS/GI        : 1 = geometry from interpolants (no spinup), 2 = geometry
%                                from the restart file of the inverse experiment (after spinup);
%                                if the geometry differs from the one of the inverse
%                                experiment, the thickness change between the two geometries
%                                is added (UserVar.Adapt<IS/GI>BaseGeometry=1)
%     InverseA / InverseCycleA : experiment and cycle of the inversion that provides AGlen, n
%     InverseC / InverseCycleC : same for C, m and the sliding law
%   The velocity interpolants are those of the first inverse cycle (assumed not to change
%   in the perturbation experiments); there are no level set / calving evolution
%   (UserVar.LevelSetMethod = 0).
%
% INPUTS / OUTPUT
%   RunTable, ind, UserVar as in UaWrapper; returns UserVar with the file names and
%   flags used by the Define* files in ua_input/run/5_diagnostic. The C and AGlen estimates are
%   saved to files in the experiment folder.
%
% REQUIRES
%   DefineBaseMesh, ApplyMeshModifications (ua_input/2_meshing)

%% target geometry interpolants
UserVar.ThickMin = 1;

%% CALVING
UserVar.Calv = RunTable{ind,"Calv"};
UserVar = DefineBaseMesh(UserVar,RunTable{ind,"BaseMesh"}{:});

if ismember(UserVar.Domain,["AMUND_nsmbl","SYNTH_PIG_nsmbl"])
    UserVar.LevelSetMethod = 0;
    UserVar.CalvingFrontFilename = [];
end
UserVar = ApplyMeshModifications(UserVar);

%% ICE SHELF and GROUNDED ICE
for geom=["IS","GI"]

    UserVar.(geom+"Geometry") = RunTable{ind,geom+"thick"};
    UserVar.("InverseCycle"+geom) = RunTable{ind,"InverseCycle"+geom};

    if UserVar.("InverseCycle"+geom) == 1

        if ismember(UserVar.Domain,"AMUND_nsmbl")
            switch UserVar.(geom+"Geometry")
                case {'2000','2009','2014','2018','2020'}
                    UserVar.(geom+"BaseGeometry") = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_Geometry_01-Jun-"+...
                        UserVar.(geom+"Geometry")+"_EXTRUDED.mat";
                    UserVar.("Adapt"+geom+"BaseGeometry") = 0;
                otherwise
                    error("ExpID "+RunTable{ind,"ExpID"}+": Do not recognise "+geom+"thick flag in RunTable.");
            end
            
        elseif ismember(UserVar.Domain,"SYNTH_PIG_nsmbl")
            switch UserVar.(geom+"Geometry")
                case cellstr(vertcat(["Weertmanyr"+string([30:5:50 75]), "Umbiyr"+string([30:5:50 75])]))
                    UserVar.(geom+"BaseGeometry") = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/ScatteredInterpolants_Geometry_SYNTH_PIG_"+...
                        UserVar.(geom+"Geometry")+".mat";
                    UserVar.("Adapt"+geom+"BaseGeometry") = 0;
                otherwise
                    error("ExpID "+RunTable{ind,"ExpID"}+": Do not recognise "+geom+"thick flag "+UserVar.(geom+"Geometry")+" in RunTable.");
            end

        end
 
    elseif UserVar.InverseCycleIS > 1 
        UserVar.(geom+"BaseGeometry") = UserVar.casefolder+"../../../4_inverse/cases/"+UserVar.Domain+"/"+UserVar.Domain+"_Inverse_"+string(RunTable{ind,"InverseA"})+"/"+UserVar.Domain+...
            "_Inverse_"+string(RunTable{ind,"InverseA"})+"-RestartFile_InverseCycle"+string(UserVar.("InverseCycle"+geom))+".mat";

        if ismember(UserVar.Domain,"AMUND_nsmbl")
            switch UserVar.(geom+"Geometry")
                case '2000'
                    UserVar.("Adapt"+geom+"BaseGeometry") = 0;
                case {'2009','2014','2018','2020'}
                    UserVar.("Adapt"+geom+"BaseGeometry") = 1;
                    UserVar.("InterpolantsToCalculateNew"+geom+"Geometry") = ...
                        [UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_Geometry_01-Jun-2000_EXTRUDED.mat",... % this is the base geometry
                        UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_Geometry_01-Jun-"+UserVar.(geom+"Geometry")+"_EXTRUDED.mat"]; % this is the perturbed geometry
                otherwise
                    error("ExpID "+RunTable{ind,"ExpID"}+": Do not recognise "+geom+"thick flag in RunTable.");
            end

        elseif ismember(UserVar.Domain,"SYNTH_PIG_nsmbl")
            switch UserVar.(geom+"Geometry")
                case {'Weertmanyr30', 'Umbiyr30'}
                    UserVar.("Adapt"+geom+"BaseGeometry") = 0;
                case cellstr(vertcat(["Weertmanyr"+string([35:5:50 75]), "Umbiyr"+string([35:5:50 75])]))
                    UserVar.("Adapt"+geom+"BaseGeometry") = 1;
                    basegeom = replace(UserVar.(geom+"Geometry"),string([35:5:50 75]),"30");
                    UserVar.("InterpolantsToCalculateNew"+geom+"Geometry") = ...
                        [UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/ScatteredInterpolants_Geometry_SYNTH_PIG_"+basegeom+".mat",... % this is the base geometry
                        UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/ScatteredInterpolants_Geometry_SYNTH_PIG_"+UserVar.(geom+"Geometry")+".mat"]; % this is the perturbed geometry
                otherwise
                    error("ExpID "+RunTable{ind,"ExpID"}+": Do not recognise "+geom+"thick flag in RunTable.");
            end

        end
    
    else
        error("ExpID "+RunTable{ind,"ExpID"}+": Do not recognise UserVar.InverseCycle"+geom+".");
    
    end
end
    
%% density interpolant: same as inverse run
if ismember(UserVar.Domain,"AMUND_nsmbl")
    UserVar.DensityInterpolant = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_Geometry_01-Jun-2000_EXTRUDED.mat";   

elseif ismember(UserVar.Domain,"SYNTH_PIG_nsmbl")
    UserVar.DensityInterpolant = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/ScatteredInterpolants_Geometry_SYNTH_PIG_Weertmanyr30.mat";

end

%% sliding law
UserVar.InverseC = RunTable{ind,"InverseC"};

% copy relevant files   
NameOfFiletoRead="../4_inverse/cases/"+UserVar.Domain+"/"+UserVar.Domain+"_Inverse_"+string(UserVar.InverseC)+"/"+UserVar.Domain+"_Inverse_"+string(UserVar.InverseC)+...
    "-RestartFile_InverseCycle"+string(RunTable{ind,"InverseCycleC"})+".mat";
if exist(NameOfFiletoRead,"file")
    load(NameOfFiletoRead,"F","MUA","CtrlVarInRestartFile");
    C = F.C; m = F.m;
    UserVar.NameOfFileForReadingSlipperinessEstimate = UserVar.Domain+"_Inverse_"+string(UserVar.InverseC)+"_C-Estimate.mat";
    save(UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.NameOfFileForReadingSlipperinessEstimate,"MUA","C","m");
    UserVar.SlidingLaw = CtrlVarInRestartFile.SlidingLaw;
else
    error("ExpID "+RunTable{ind,"ExpID"}+": Could not find file to copy C field: "+NameOfFiletoRead);
end

%% Glen's exponent
UserVar.InverseA = RunTable{ind,"InverseA"};

% copy relevant files   
NameOfFiletoRead="../4_inverse/cases/"+UserVar.Domain+"/"+UserVar.Domain+"_Inverse_"+string(UserVar.InverseA)+"/"+UserVar.Domain+"_Inverse_"+string(UserVar.InverseA)+...
    "-RestartFile_InverseCycle"+string(RunTable{ind,"InverseCycleA"})+".mat";
if exist(NameOfFiletoRead,"file")
    load(NameOfFiletoRead,"F","MUA","CtrlVarInRestartFile");
    AGlen = F.AGlen; n = F.n;
    UserVar.NameOfFileForReadingAGlenEstimate = UserVar.Domain+"_Inverse_"+string(UserVar.InverseA)+"_AGlen-Estimate.mat";
    save(UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.NameOfFileForReadingAGlenEstimate,"MUA","AGlen","n");
else
    error("ExpID "+RunTable{ind,"ExpID"}+": Could not find file to copy AGlen field: "+NameOfFiletoRead);
end   

%% velocity interpolants for fixed boundaries // we assume these do not change in the perturbation experiments
if ismember(UserVar.Domain,"AMUND_nsmbl")
    UserVar.Velocity = "2000";
    UserVar.VelocityInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities.mat";

elseif ismember(UserVar.Domain,"SYNTH_PIG_nsmbl")
    UserVar.Velocity = "Weertmanyr30";
    UserVar.VelocityInterpolants = UserVar.datafolder+"/1_interpolants/"+lower(erase(string(UserVar.Domain),"_nsmbl"))+"/ScatteredInterpolants_Velocities_SYNTH_PIG_Weertmanyr30.mat";

end

    
%% outputs
UserVar.UaOutputDirectory = './ResultsFiles';

%% write log file
fprintf(UserVar.fid_experimentlog,"> GetUserVar_Diagnostic: ExpID %s: Starting diagnostic experiment on %s.\n",string(UserVar.ExpID),UserVar.hostname);
