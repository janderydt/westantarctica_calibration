function UserVar = UaJob(RunTable,ind,UserVar,pgid)
% UaJob  Run Ua once for an experiment.
%
% PURPOSE
%   Called by UaWrapper for each inverse cycle, spinup cycle or diagnostic run.
%   Copies the latest Ua user files from the master folder ./GLUE_<type>_9999 to the
%   experiment folder, makes sure the experiment run table exists (copy of
%   RunTable_GLUE_<type>_9999.csv), logs the start of the run in the global and
%   experiment run tables (SubmissionTime, Submitted=1, Running=1, pgid), changes into
%   the experiment folder and runs Ua (Ua2D). Errors in Ua are caught and logged
%   to UserVar.fid_experror (UserVar.Error=1, UserVar.Breakout=1).
%
% INPUTS
%   RunTable : global run table;  ind : row of the experiment;  pgid : job id
%   UserVar  : struct set up by UaWrapper (type, casefolder, Experiment,
%              runtable_exp, runtable_global, hostname, fid_experimentlog, fid_experror)
%
% OUTPUT
%   UserVar as returned by Ua2D (status fields Finished, Restart, Error, Breakout
%   are set in DefineOutputs)
%
% NOTE: the global run table is not updated on ARCHER2 (see comment below).
%
% REQUIRES
%   Ua source code (Ua2D); ReadWritetable (ua_input/run)

%% copy latest Ua run files from master folder to experiment folder
copyfile("./GLUE_"+UserVar.type+"_9999/*.m",UserVar.casefolder+"/"+UserVar.Experiment);

%% check if experiment runtable exists, otherwise, create a new one
if ~isfile(UserVar.runtable_exp)
    copyfile("./GLUE_"+UserVar.type+"_9999/RunTable_GLUE_"+UserVar.type+"_9999.csv",UserVar.runtable_exp);
end

%% log changes in tables
RunTable{ind,"SubmissionTime"} = string(datetime("now","format","yyyy-MM-dd HH:mm:ss")); 
RunTable{ind,"Submitted"} = 1;
RunTable{ind,"Running"} = 1;
RunTable{ind,'pgid'} = pgid;

% Here we log changes in global table. This is ok if experiments are 
% launched one after the other. However, on ARCHER2, all experiments are 
% launched simultaneously, so changing the global table can cause problems 
% because multiple jobs will try to access and modify the same file. That's 
% why we exclude ARCHER2 here, and only update the global table once all
% simulations are finished.
if UserVar.hostname ~= "ARCHER2"
    [~]=ReadWritetable(UserVar,UserVar.runtable_global,RunTable,'write');
end

% extract relevant row from global table
RunTable_exp = RunTable(ind,:);

% write to experiment runtable
[~]=ReadWritetable(UserVar,UserVar.runtable_exp,RunTable_exp,'write');

% launch job
cd(UserVar.casefolder+"/"+UserVar.Experiment);

% start diary
diary(UserVar.Experiment+".out")
diary on

UserVar.Error=0;

try
    
    UserVar = Ua2D(UserVar);   
    
catch ME

    fprintf(UserVar.fid_experimentlog,string(datetime("now"))+" || ERROR in the execution of ExpID %s.\n",string(UserVar.ExpID));

    UserVar.Breakout = 1;
    UserVar.Error = 1;

    msgString = getReport(ME,'extended');
    fprintf(UserVar.fid_experror,"%s \n\n",msgString);

end

if UserVar.Finished == 1
    UserVar.Breakout = 1;
end
        
cd ..
