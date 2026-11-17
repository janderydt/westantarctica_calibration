function UserVar=DefineOutputs(UserVar,CtrlVar,MUA,BCs,F,l,GF,InvStartValues,InvFinalValues,Priors,Meas,BCsAdjoint,RunInfo)
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Part of the diagnostic stage, which needs the inversion results (restart files) of the
% ensemble members. These data can be obtained upon request from the author.
%
% DefineOutputs  Ua user input file (diagnostic stage): save the results.
%
% PURPOSE
%   Saves UserVar, CtrlVar, MUA and F to <UserVar.UaOutputDirectory>/ResultsFile-<ExpID>.mat and,
%   at the last call, sets UserVar.Finished=1 and deletes the temporary files of the run folder
%   (copies of the inversion results, restart files, extruded-field caches, mesh files).
%
% REQUIRES
%   Ua source code (v2struct)
v2struct(F); % creates variables from the fields of F (the input GF is overwritten by F.GF)
time=CtrlVar.time;
plots='-save-';

if contains(plots,'-save-')
    
    % save data in files with running names
    % check if folder 'ResultsFiles' exists, if not create
    
    if exist(fullfile(cd,UserVar.UaOutputDirectory),'dir')~=7
        mkdir(UserVar.UaOutputDirectory) ;
    end
       
    FileName=sprintf("%s/ResultsFile-%s.mat",...
            UserVar.UaOutputDirectory,string(UserVar.ExpID));
    fprintf(' Saving data in %s \n',FileName)
    save(FileName,'UserVar','CtrlVar','MUA','F');
    
end

if strcmp(CtrlVar.DefineOutputsInfostring,'Last call')
    UserVar.Finished = 1;
    % clean up some files from the run folder
    delete(UserVar.Domain+"*_Inverse*.mat") 
    delete *-RestartFile.mat Fields_to_extrude*.mat 
    delete NewMeshFile.mat 
    delete(UserVar.Domain+"_*_InitialMesh.mat")
    delete(UserVar.Domain+"_*_MeshBoundaryCoordinates.mat")
    delete *C-Estimate*.mat *AGlen-Estimate*.mat
end

end
