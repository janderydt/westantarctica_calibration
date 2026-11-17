function UaWrapper(ua_config,pgid,type,row_number,expid_new)
% UaWrapper  Launch an experiment of the GLUE ensemble in Ua (inverse or diagnostic).
%
% PURPOSE
%   Entry point of a job. First looks for existing experiments in the global run table
%   (ExpID~=0, no error, not submitted / running / finished: new runs or restarts) and
%   runs the first one; if there is none, takes a new row of the run table (ExpID==0),
%   gives it a unique ExpID, creates its experiment folder and runs it. For type
%   "Inverse" the wrapper alternates between inverse and spinup cycles (information
%   from GetUserVar_Inverse, runs through UaJob) until the run is finished or
%   a restart is required (walltime); the experiment run table is updated after each
%   cycle and at the end by CleanUp. When the run has ended, MATLAB quits. If
%   there is nothing to do, a file <pgid>_job_submitted is written and MATLAB quits.
%
% INPUTS (all optional strings; see the arguments block)
%   ua_config  : text file with the settings of the job (relative to the home folder).
%                Lines starting with # are comments. Keys:
%                  runtype = "Inverse"    (or Diagnostic)
%                  pgid = <integer>
%                  walltime = hh:mm:ss    and  walltime_remaining = hh:mm:ss
%                  runtable = "<run table .csv, relative to the home folder>"
%                  idrange = [1:999]      (range of random ExpIDs)
%                  debug = 0 or 1
%                Without a config file: walltime = 1 year, runtable =
%                RunTable_<hostname>.csv, idrange = [1 999], debug = 0.
%   pgid       : job id (on linux workstations each job has a unique pgid)
%   type       : run type when no config file is given
%   row_number : row of the run table of the experiment to submit
%   expid_new  : unique experiment id for row_number (required with row_number)
%
% FOLDER LAYOUT (home = current folder when MATLAB is started)
%   <home>/4_inverse/, <home>/5_diagnostic/   master folders of the run types Inverse and Diagnostic:
%                                   Ua user files (*.m) and the empty run table EmptyTable.csv
%   <home>/cases/<Domain>/<Domain>_<type>_<ExpID>/   experiment folders (created)
%   <home>/../                      (= ua_input) with the folders 1_interpolants and 2_meshing (data)
%   Log files: <home>/jobs_master_<hostname>.log, <experiment>.log in each experiment
%   folder, stderr_jobid<pgid>_expid<ExpID>.out in <home>.
%
% REQUIRES
%   A Ua installation (UaSource, https://github.com/GHilmarG/UaSource) set up on the path in
%   the host block below; ReadWritetable, GetUserVar_Inverse (and
%   GetUserVar_Diagnostic for that run type),
%   UaJob, CleanUp. The helper functions (third-party functions, see README) and the interpolant files (1_interpolants) must be on the MATLAB path.
%   An external launcher that starts MATLAB and watches the <pgid>_job_submitted file
%   is not part of this repository.

arguments
    ua_config (1,1) string = ''
    pgid (1,1) string = ''
    type (1,1) string = ''
    row_number (1,1) string = ''
    expid_new (1,1) string = ''
end

%% Ua source code
% TODO: replace by the folder of your Ua source code (or remove if Ua is already on the MATLAB path)
addpath("/path/to/ua/source/folder");

% name of the host: used in the names of the default run table (RunTable_<hostname>.csv) and of the log
% file. On ARCHER2 (host names "nid...") it is set to "ARCHER2": UaJob then does not update the global
% run table after every Ua run (all experiments run at the same time there).
[~,hostname] = system("hostname");
UserVar.hostname = string(strtrim(hostname));
if startsWith(UserVar.hostname,"nid")
    UserVar.hostname = "ARCHER2";
end

UserVar.home = pwd+"/";

%% deal with inputs
if nargin == 0
    error("You need to either provide a config file or pgid and type. Instead got none.");
elseif nargin == 4
    error("You have specified a row number, but also need to provide a unique experiment id for that row.")
end
if nargin > 1
    pgid = str2double(pgid);
end
if nargin == 5
    row_number = round(double(row_number));
    expid_new = round(double(expid_new));
end

% read inputs from config file
if ua_config~=""    
    configfile = UserVar.home+"/"+ua_config;
    if ~exist(configfile,"file")
        error("Config file "+configfile+" does not exist.");
    end
    fileID = fopen(configfile,"r"); 
    tline = fgetl(fileID);
    while ischar(tline)	
        if ~isempty(tline)
            if ~startsWith(tline(1), '#')
                % process lines / type and pgid should not be overwritten
                % by information from the config file
                if contains(tline,'runtype')
                    if strlength(type)==0
                        type = string(erase(tline,["runtype"," ","=",""""]));
                    end
                elseif contains(tline,'pgid')
                    if isempty(pgid)
                        pgid = str2num(erase(tline,["pgid"," ","="]));
                    end
                elseif contains(tline,'walltime=')
                    walltime = seconds(duration(erase(tline,["walltime"," ","="])));
                elseif contains(tline,'walltime_remaining=')
                    walltime_remaining = seconds(duration(erase(tline,["walltime_remaining"," ","="])));
                elseif contains(tline,'runtable=')
                    runtable = UserVar.home+"/"+string(erase(tline,["runtable"," ","=",""""]));
                elseif contains(tline,'idrange=')
                    idrange = str2double(split(string(erase(tline,["idrange"," ","=","""","[","]"])),":"));
                elseif contains(tline,'debug=')
                    debug = str2double(string(erase(tline,["debug"," ","=","""","[","]"])));
                end
            end
        end
        % Now read the next line.
        tline = fgetl(fileID);
    end
    % All done reading all lines, so close the file.
    fclose(fileID);
else
    % No config file specified, define default values
    walltime = 31557600; % set to some large number
    walltime_remaining = walltime;
    runtable = UserVar.home+"/RunTable_"+UserVar.hostname+".csv";
    idrange = [1 999];
    debug = 0;
end

% check that all inputs are now available
if isempty(type) || isempty(walltime) || isempty(pgid) || isempty(walltime_remaining) || isempty(runtable)
    error("One of the following mandatory input variables is empty: type ("+string(type)+"), "+ ...
    "walltime ("+string(walltime)+"), walltime_remaining ("+string(walltime_remaining)+"), pgid ("+string(pgid)+"), ",...
    "runtable ("+string(runtable)+"), idrange ("+string(idrange)+").");
else
    UserVar.type = string(type);
    UserVar.pgid = pgid;
    UserVar.walltime = walltime; 
    UserVar.walltime_remaining = walltime_remaining;
    UserVar.runtable_global = string(runtable);
    UserVar.idrange = idrange;
    UserVar.debug = debug;
end

%% initialize global log file
logfile = UserVar.home+"/jobs_master_"+UserVar.hostname+".log";
fid = fopen(logfile,'a+');
UserVar.fid_masterlog = fid;

%% read run table
RunTable = ReadWritetable(UserVar,UserVar.runtable_global,[],'read');

%% if row_number is specified as input, check whether it is an existing simulation
if ~isempty(RunTable)
    Iexisting = find(RunTable{:,'ExpID'}~=0 & RunTable{:,'Error'}==0);
    if ~isempty(Iexisting)
        if string(row_number)~=""
            % check if row_number is an existing simulation
            if ismember(row_number,Iexisting)
                Iexisting = row_number;
            else
                Iexisting = [];
            end
        end     
    end   
end

%% launch jobs
% initialize some variables
UserVar.configfile = ua_config;
UserVar.datafolder = UserVar.home + "/../";
UserVar.Restart = 0;
something_submitted = 0; kk=1;

% does cases folder exist?
casesfolder = UserVar.home + "/cases/";
if ~exist(casesfolder,"dir")
    cmd = "mkdir "+casesfolder;
    system(cmd,"-echo");
end

% first deal with existing jobs
if ~isempty(Iexisting)

    while something_submitted==0 && kk<=numel(Iexisting)
   
        % table row
        ind = Iexisting(kk);

        % domain name and case folder
        UserVar.Domain = RunTable{ind,'Domain'};
        UserVar.casefolder = UserVar.home + "/cases/" + UserVar.Domain +"/";
        if ~exist(UserVar.casefolder,"dir")
            cmd = "mkdir "+UserVar.casefolder;
            system(cmd,"-echo");
        end

        % experiment name and unique ID       
        UserVar.ExpID = RunTable{ind,'ExpID'};
        UserVar.Experiment = UserVar.Domain+"_"+UserVar.type+"_"+string(UserVar.ExpID);

        % check if not submitted, not running, not finished
        indnsnr = RunTable{ind,'Submitted'}==0 & RunTable{ind,'Running'}==0 & RunTable{ind,'Finished'}==0;
        
        if indnsnr

            % initialize experiment log and error files
            logfile = UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.Experiment+".log";
            
            fid = fopen(logfile,'a+');
            UserVar.fid_experimentlog = fid;
            errorfile = UserVar.home+"/stderr_jobid"+string(UserVar.pgid)+"_expid"+string(UserVar.ExpID)+".out";
            UserVar.fid_experror = fopen(errorfile,'a+');

            fprintf(UserVar.fid_experimentlog,'============================\n');
            fprintf(UserVar.fid_experimentlog,string(datetime("now"))+"\n");    
            fprintf(UserVar.fid_experimentlog,"> UaWrapper: ExpID %s has been not yet been submitted. Let's check if a " + ...
                "restart is required...",string(RunTable{ind,'ExpID'}));

            % initialze some variables
            UserVar.Finished = 0;
            UserVar.Breakout = 0;
            UserVar.runtable_exp = UserVar.casefolder + "/" + UserVar.Experiment + "/RunTable_" + UserVar.Experiment + ".csv";

            % new run or restart?
            if RunTable{ind,'Restart'}==1
                UserVar.Restart = 1;
                fprintf(UserVar.fid_experimentlog,"yes.\n");
                fprintf(UserVar.fid_experimentlog,"> UaWrapper: Restarting ExpID %s...\n",string(RunTable{ind,'ExpID'}));
            else
                UserVar.Restart = 0;
                fprintf(UserVar.fid_experimentlog,"no.\n");
            end

            % now gather run info and launch job
            if type=="Diagnostic"

                something_submitted=1;
                Inew = [];

                % run info
                UserVar = GetUserVar_Diagnostic(RunTable,ind,UserVar);

                % launch Ua job
                UserVar = UaJob(RunTable,ind,UserVar,pgid);

            elseif type=="Inverse"

                while ~UserVar.Breakout

                    something_submitted=1;
                    Inew = [];

                    % read Runtable again in case any changes were made by other
                    % processes
                    RunTable=ReadWritetable(UserVar,UserVar.runtable_global,[],'read');
                    ind = find(RunTable{:,'ExpID'}(:) == UserVar.ExpID);
     
                    % initialize User variables
                    UserVar = GetUserVar_Inverse(RunTable,ind,UserVar);
    
                    % cumulative sum of number of iterations at the end of each
                    % inverse cycle
                    it_tmp = cumsum(UserVar.Inverse.Iterations);
    
                    %% Inverse cycle
                    if UserVar.InverseCycle
                    
                        while (UserVar.Inverse.IterationsDone < it_tmp(UserVar.Inverse.Cycle) && ~UserVar.Breakout)

                            % maximum number of iterations per Ua run (same on all hosts;
                            % Ua stops earlier when the walltime is reached)
                            if contains(UserVar.hostname,"ARCHER2")
                                nit = 100000;
                            else
                                nit = 100000;
                            end
        
                            UserVar.TargetIterations = min(nit,it_tmp(UserVar.Inverse.Cycle)-UserVar.Inverse.IterationsDone);
                            fprintf(UserVar.fid_experimentlog,"> UaWrapper: Doing %s iterations or as many as walltime allows.\n",string(UserVar.TargetIterations));
    
                            UserVar = UaJob(RunTable,ind,UserVar,pgid);
    
                            %adjust Individual Runtable
                            RunTable=ReadWritetable(UserVar,UserVar.runtable_exp,[],'read');
                            ind = find(RunTable{:,'ExpID'}(:) == UserVar.ExpID);
                            RunTable{ind,"InverseIterationsDone"} = UserVar.Inverse.IterationsDone;   
                            RunTable{ind,"Restart"} = UserVar.Restart;
                            [~] = ReadWritetable(UserVar,UserVar.runtable_exp,RunTable,'write');
                
                        end   

                        it_tmp = cumsum(UserVar.Inverse.Iterations);

                        fprintf(UserVar.fid_experimentlog,'============================\n');
                        fprintf(UserVar.fid_experimentlog,string(datetime("now"))+"\n");                     
                        if UserVar.Restart
                            fprintf(UserVar.fid_experimentlog,"> UaWrapper: %s: Breaking out of inverse cycle %s due to walltime constraints. Done %s iterations out of %s.\n",...
                            UserVar.Experiment,string(UserVar.Inverse.Cycle),string(UserVar.Inverse.IterationsDone),string(it_tmp(end)));
                        else
                            fprintf(UserVar.fid_experimentlog,"> UaWrapper: %s: Breaking out of inverse cycle %s. Done %s iterations out of %s.\n",...
                            UserVar.Experiment,string(UserVar.Inverse.Cycle),string(UserVar.Inverse.IterationsDone),string(it_tmp(end)));
                        end
    
                    %% Spinup cycle
                    elseif UserVar.SpinupCycle
    
                        UserVar = UaJob(RunTable,ind,UserVar,pgid);
    
                        %adjust Runtable
                        RunTable=ReadWritetable(UserVar,UserVar.runtable_exp,[],'read');
                        ind = find(RunTable{:,'ExpID'}(:) == UserVar.ExpID);
                        RunTable{ind,"SpinupYearsDone"} = UserVar.Spinup.YearsDone;   

                        [~] = ReadWritetable(UserVar,UserVar.runtable_exp,RunTable,'write');

                        fprintf(UserVar.fid_experimentlog,'============================\n');
                        fprintf(UserVar.fid_experimentlog,string(datetime("now"))+"\n");                        
                        fprintf(UserVar.fid_experimentlog,"> UaWrapper: %s: End spinup cycle %s.\n",UserVar.Experiment,string(UserVar.Spinup.Cycle));
    
                    end

        
                end

            end

            % 
            CleanUp(UserVar);
    
            diary off

        end

        kk=kk+1;

    end
    
end

if something_submitted % something has been submitted and run has finished -> quit matlab
    quit;
else
    RunTable = ReadWritetable(UserVar,UserVar.runtable_global,[],'read');
    if ~isempty(RunTable)
        Inew = find(RunTable{:,'ExpID'}==0);
        if ~isempty(Inew)
            if string(row_number)~=""
                % check if row_number is a new simulation
                if ismember(row_number,Inew)
                    Inew = row_number;
                    ExpID = expid_new;
                else
                    Inew = [];
                    ExpID = 0;
                end
            else
                ExpID = 0;
            end            
        end
    else
        fprintf(UserVar.fid_masterlog,"Empty RunTable - stop job and quit.\n");
        quit;
    end
end

%% deal with new jobs if all existing jobs have been dealt with
% A new experiment gets a unique ExpID (random number in UserVar.idrange, unless given
% as an argument), its own folder cases/<Domain>/<Domain>_<type>_<ExpID> (a copy of the
% master folder 4_inverse or 5_diagnostic) and is run in the same way as an existing one.
if ~isempty(Inew)

    ind = Inew(1);

    % if expid hasn't been specified as input then generate unique ExpID
    % and write to global runtable
    if ExpID == 0
        existingID = RunTable{:,"ExpID"};
        while ismember(ExpID,existingID) 
            ExpID = randi([UserVar.idrange(1) UserVar.idrange(2)]);
        end   
        RunTable{ind,"ExpID"} = ExpID; UserVar.ExpID = ExpID;
        RunTable{ind,"pgid"} = pgid;
        RunTable{ind,"Submitted"} = 1;
        RunTable{ind,"SubmissionTime"} = string(datetime("now","format","yyyy-MM-dd HH:mm:ss"));
        fprintf(UserVar.fid_masterlog,"   ...Writing global RunTable %s...",UserVar.runtable_global);     
        [~]=ReadWritetable(UserVar,UserVar.runtable_global,RunTable,'write');
        fprintf(UserVar.fid_masterlog,"done.\n");
    else
        RunTable{ind,"ExpID"} = ExpID;
        RunTable{ind,"pgid"} = pgid;
    end

    % initialize some UserVars
    UserVar.ExpID = ExpID;
    UserVar.Finished = 0;
    UserVar.Restart = 0;
    UserVar.Breakout = 0;
    UserVar.Domain = RunTable{ind,'Domain'};
    UserVar.Experiment = UserVar.Domain+"_"+UserVar.type+"_"+string(UserVar.ExpID);
    
    % make copy of master folder for new experiment
    % if new folder already exists: rename first
    masterfolder = "4_inverse"; if strcmp(type,"Diagnostic"), masterfolder = "5_diagnostic"; end
    sourcefolder = UserVar.home+"/"+masterfolder+"/";
    UserVar.casefolder = UserVar.home + "/cases/" + UserVar.Domain +"/";
    if ~exist(UserVar.casefolder,"dir")
        cmd = "mkdir "+UserVar.casefolder;
        system(cmd,"-echo");
    end
    newfolder = UserVar.casefolder+"/"+UserVar.Domain+"_"+type+"_"+string(ExpID);
    if exist(newfolder,"dir") == 7
        movefile(newfolder,newfolder+"_old/");
    else
        % The MATLAB copyfile command frequently (but not always) 
        % caused an error: MATLAB:COPYFILE:OSError
        % We therefore use a system command instead, which seems to be more
        % reliable
        cmd = "mkdir "+newfolder;
        [status,cmdout] = system(cmd,"-echo");

        cmd = "cp "+sourcefolder+"/* "+newfolder+"/";  
        [status,cmdout] = system(cmd,"-echo");
    end

    % rename RunTable file
    UserVar.runtable_exp = UserVar.casefolder + "/" + UserVar.Experiment + "/RunTable_" + UserVar.Experiment + ".csv";
    movefile(newfolder+"/EmptyTable.csv",UserVar.runtable_exp);

    % initialize experiment log and error files
    logfile = UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.Experiment+".log";
    fid = fopen(logfile,'a+');
    UserVar.fid_experimentlog = fid;
    errorfile = UserVar.home+"/stderr_jobid"+string(UserVar.pgid)+"_expid"+string(UserVar.ExpID)+".out";
    UserVar.fid_experror = fopen(errorfile,'a+');

    fprintf(UserVar.fid_experimentlog,'============================\n');
    fprintf(UserVar.fid_experimentlog,string(datetime("now"))+"\n");    
    
    % now gather run info
    if type=="Diagnostic"

        % initialize User variables
        UserVar = GetUserVar_Diagnostic(RunTable,ind,UserVar);

        UserVar.Restart = 0;

        % launch Ua job
        UserVar = UaJob(RunTable,ind,UserVar,pgid);

    elseif type=="Inverse"

        while ~UserVar.Breakout
            
            % read Runtable again in case any changes were made by other
            % processes
               
            % initialize User variables
            UserVar = GetUserVar_Inverse(RunTable,ind,UserVar);
    
            % cumulative sum of number of iterations at the end of each
            % inverse cycle
            it_tmp = cumsum(UserVar.Inverse.Iterations);
    
            %% Inverse cycle
            if UserVar.InverseCycle
            
                while (UserVar.Inverse.IterationsDone < it_tmp(UserVar.Inverse.Cycle) && ~UserVar.Breakout)
    
                    % maximum number of iterations per Ua run (same on all hosts)
                    if contains(UserVar.hostname,"ARCHER2")
                        nit = 100000;
                    else
                        nit = 100000;
                    end

                    UserVar.TargetIterations = min(nit,it_tmp(UserVar.Inverse.Cycle)-UserVar.Inverse.IterationsDone);
                    fprintf(UserVar.fid_experimentlog,"> UaWrapper: Doing %s iterations or as many as walltime allows.\n",string(UserVar.TargetIterations));
    
                    UserVar = UaJob(RunTable,ind,UserVar,pgid);
    
                    %adjust Runtable
                    RunTable=ReadWritetable(UserVar,UserVar.runtable_exp,[],'read');
                    ind = find(RunTable{:,'ExpID'}(:) == UserVar.ExpID);
                    RunTable{ind,"InverseIterationsDone"} = UserVar.Inverse.IterationsDone;  
                    RunTable{ind,"Restart"} = UserVar.Restart;
                    [~] = ReadWritetable(UserVar,UserVar.runtable_exp,RunTable,'write');

                end     

                it_tmp = cumsum(UserVar.Inverse.Iterations);

                fprintf(UserVar.fid_experimentlog,'============================\n');
                fprintf(UserVar.fid_experimentlog,string(datetime("now"))+"\n");                     
                if UserVar.Restart
                    fprintf(UserVar.fid_experimentlog,"> UaWrapper: %s: Breaking out of inverse cycle %s due to walltime constraints. Done %s iterations out of %s.\n",...
                    UserVar.Experiment,string(UserVar.Inverse.Cycle),string(UserVar.Inverse.IterationsDone),string(it_tmp(end)));
                else
                    fprintf(UserVar.fid_experimentlog,"> UaWrapper: %s: Breaking out of inverse cycle %s. Done %s iterations out of %s.\n",...
                    UserVar.Experiment,string(UserVar.Inverse.Cycle),string(UserVar.Inverse.IterationsDone),string(it_tmp(end)));
                end
    
            %% Spinup cycle
            elseif UserVar.SpinupCycle
    
                UserVar = UaJob(RunTable,ind,UserVar,pgid);

                %adjust Runtable
                RunTable=ReadWritetable(UserVar,UserVar.runtable_exp,[],'read');
                ind = find(RunTable{:,'ExpID'}(:) == UserVar.ExpID);
                RunTable{ind,"SpinupYearsDone"} = UserVar.Spinup.YearsDone;   
                [~] = ReadWritetable(UserVar,UserVar.runtable_exp,RunTable,'write');

                fprintf(UserVar.fid_experimentlog,'============================\n');
                fprintf(UserVar.fid_experimentlog,string(datetime("now"))+"\n");                
                fprintf(UserVar.fid_experimentlog,"> UaWrapper: %s: Breaking out of spinup cycle %s.\n",UserVar.Experiment,string(UserVar.Spinup.Cycle));
    
            end

        end
    end

    CleanUp(UserVar);

    diary off

else

    fid2 = fopen( UserVar.home+"/"+string(UserVar.pgid)+"_job_submitted", 'wt' );
    fclose(fid2);

end

% At the end always exit matlab to avoid rogue jobs
quit;
