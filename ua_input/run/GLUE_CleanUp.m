function GLUE_CleanUp(UserVar)
% GLUE_CleanUp  Update the experiment run table at the end of a run.
%
% PURPOSE
%   Called by GLUE_UaWrapper when all jobs of an experiment have ended. Reads the
%   run table of the experiment (UserVar.runtable_exp; this function only writes
%   to experiment run tables), and sets the status columns Submitted, Running,
%   Finished, Restart, Error and the time stamps FinishedTime / ErrorTime according to
%   UserVar.Finished, UserVar.Restart and UserVar.Error:
%     Finished=1, Error=0          : successfully finished
%     Finished=0, Restart=1        : restart required (e.g. walltime reached)
%     Finished=0, Restart=0, Error=0 : an inverse or spinup cycle has finished
%     Error=1                      : aborted
%   The column pgid is reset to 0. Messages are written to the experiment log
%   (UserVar.fid_experimentlog).
%
% NOTE: the typo UsserVar in the final error message was corrected.
%
% REQUIRES
%   GLUE_ReadWritetable (ua_input/runtable)

% read table
RunTable=GLUE_ReadWritetable(UserVar,UserVar.runtable_exp,[],'read'); 
ind = find(RunTable{:,'ExpID'}==UserVar.ExpID); % all going well, this index should always be 1

% add flags and timestamps to table
if UserVar.Finished==1 && UserVar.Error==0

    RunTable{ind,"Submitted"} = 0;
    RunTable{ind,"Running"} = 0;
    RunTable{ind,"Finished"} = 1;
    RunTable{ind,"Restart"} = 0;
    RunTable{ind,"FinishedTime"} = string(datetime("now","format","yyyy-MM-dd HH:mm:ss"));
 
    fprintf(UserVar.fid_experimentlog,'> GLUE_CleanUp: ExpID %s SUCCESSFULLY FINISHED.\n',string(UserVar.ExpID));    
    fprintf(UserVar.fid_experimentlog,'============================\n');

elseif UserVar.Finished==0 && UserVar.Restart==1

    RunTable{ind,"Submitted"} = 0;
    RunTable{ind,"Running"} = 0;
    RunTable{ind,"Finished"} = 0;
    RunTable{ind,"Restart"} = 1;
    RunTable{ind,"FinishedTime"} = string(datetime("now","format","yyyy-MM-dd HH:mm:ss"));
   
    fprintf(UserVar.fid_experimentlog,'> GLUE_CleanUp: ExpID %s RESTART REQUIRED.\n',string(UserVar.ExpID));
    fprintf(UserVar.fid_experimentlog,'============================\n');

elseif UserVar.Finished==0 && UserVar.Restart==0 && UserVar.Error==0
	
    RunTable{ind,"Submitted"} = 0;
    RunTable{ind,"Running"} = 0;
    RunTable{ind,"Finished"} = 0;
    RunTable{ind,"Restart"} = 0;
    RunTable{ind,"FinishedTime"} = string(datetime("now","format","yyyy-MM-dd HH:mm:ss"));

    if isfield(UserVar,'InverseCycle')
        if UserVar.InverseCycle==1
	        fprintf(UserVar.fid_experimentlog,'> GLUE_CleanUp: ExpID %s FINISHED INVERSE CYCLE.\n',string(UserVar.ExpID));
        else
            fprintf(UserVar.fid_experimentlog,'> GLUE_CleanUp: ExpID %s FINISHED SPINUP CYCLE.\n',string(UserVar.ExpID));
        end
    end
    fprintf(UserVar.fid_experimentlog,'============================\n');

elseif UserVar.Error==1

    RunTable{ind,"Running"} = 0;
    RunTable{ind,"Error"} = 1;
    RunTable{ind,"ErrorTime"} = string(datetime("now","format","yyyy-MM-dd HH:mm:ss"));
   
    fprintf(UserVar.fid_experimentlog,'> GLUE_CleanUp: ExpID %s ABORTED AND DID NOT FINISH.\n',string(UserVar.ExpID));    
    fprintf(UserVar.fid_experimentlog,'============================\n');

else

    error("GLUE_Cleanup ExpID "+string(UserVar.ExpID)+": unknown case");
    
end

RunTable{ind,"pgid"} = 0;

[~]=GLUE_ReadWritetable(UserVar,UserVar.runtable_exp,RunTable,'write');
