function RunTable = ReadWritetable(UserVar,TableToReadOrWrite,NewTable,mode)
% ReadWritetable  Read or write a GLUE run table (CSV).
%
% PURPOSE
%   Reads a run table with the correct variable types, or writes a run table.
%   When writing for a single experiment (UserVar.ExpID), only the row of
%   that experiment is replaced, so that the rows of other experiments in the
%   table are kept.
%
% INPUTS
%   UserVar           : struct. UserVar.type ("Inverse" or "Diagnostic")
%                       is needed for 'read' (sets the variable
%                       types). UserVar.ExpID is used by 'write' (optional).
%   TableToReadOrWrite: full <path/name> of the table to read/write
%   NewTable          : table to write; only required when mode=='write'
%   mode              : 'read' or 'write'
%
% OUTPUT
%   RunTable          : the table that was read (empty for mode 'write')
%
% BEHAVIOUR OF mode=='write'
%   - UserVar.ExpID missing or empty: NewTable is written as the whole table.
%   - UserVar.ExpID set and the file does not exist (or is empty): NewTable is
%     written as the whole table.
%   - UserVar.ExpID set and the file exists: the row with this ExpID in the
%     existing table is replaced by the row with this ExpID of NewTable. If the
%     ExpID is not in the existing table, NewTable replaces the whole file.
%   NOTE: this is a read-modify-write without any file locking, so runs that
%   update the same table at the same time can overwrite each other's changes.

RunTable = [];

switch mode 
    case 'read'
        if exist(TableToReadOrWrite,'file')
            % set some variable types    
            opts = setoptions(UserVar,TableToReadOrWrite);

            % read table
            RunTable=readtable(TableToReadOrWrite,opts);

        else
            error("Runtable "+string(TableToReadOrWrite)+" does not exist");
        end

    case 'write'
      
        if isfield(UserVar,'ExpID')

            if ~isempty(UserVar.ExpID)

                % check if table already exists
                if ~isfile(TableToReadOrWrite) % if not, simply write

                    writetable(NewTable,TableToReadOrWrite);

                else % if table already exists, only replace relevant row

                    % read existing version of the table
                    opts = setoptions(UserVar,TableToReadOrWrite);
	                RunTable_old = readtable(TableToReadOrWrite,opts);

                    if numel(RunTable_old)==0

                        writetable(NewTable,TableToReadOrWrite);

                    else
                    
                        ind_old = find(RunTable_old{:,'ExpID'}(:) == UserVar.ExpID);

                        if ~isempty(ind_old)
    
                            % only write the line that matters for this experiment, not the
                            % whole table
                            ind_new = find(NewTable{:,'ExpID'}(:) == UserVar.ExpID);  
                            % replace 1 line and write
                            RunTable_old(ind_old,:) = NewTable(ind_new,:);
    
                            writetable(RunTable_old,TableToReadOrWrite);
    
                        else
    
                            writetable(NewTable,TableToReadOrWrite);
    
                        end
   
                    end

                end

            else

                writetable(NewTable,TableToReadOrWrite);

            end

        else

            writetable(NewTable,TableToReadOrWrite);

        end

end


end


function opts = setoptions(UserVar,TableToReadOrWrite)
% Detect the import options of the CSV and force the types of columns whose
% type cannot be detected reliably (e.g. text that can look like numbers).
% NOTE: contains() matches substrings and is case sensitive, and later
% assignments override earlier ones (e.g. 'InverseIterationsDone' is first
% set to char as part of 'InverseIterations', then to double).

opts = detectImportOptions(TableToReadOrWrite);

% types common to all tables
I=find(contains(opts.VariableNames,'SubmissionTime'));
opts.VariableTypes(I)={'string'};
I=find(contains(opts.VariableNames,'ErrorTime'));
opts.VariableTypes(I)={'string'};
I=find(contains(opts.VariableNames,'FinishedTime'));
opts.VariableTypes(I)={'string'};
I=find(contains(opts.VariableNames,'Domain'));
opts.VariableTypes(I)={'string'};

% types specific to the type of table
if UserVar.type == "Inverse"

    I=find(contains(opts.VariableNames,'InverseIterations'));
    opts.VariableTypes(I)={'char'};
    I=find(contains(opts.VariableNames,'InverseIterationsDone'));
    opts.VariableTypes(I)={'double'};
    I=find(contains(opts.VariableNames,'SpinupYears'));
    opts.VariableTypes(I)={'char'};
    I=find(contains(opts.VariableNames,'SpinupYearsDone'));
    opts.VariableTypes(I)={'double'};
    I=find(contains(opts.VariableNames,'Comments'));
    opts.VariableTypes(I)={'char'};
    % NOTE: the run table column is called 'Velocity' (capital V, as in EmptyTable.csv); the
    % lower case variable 'velocity' in GenerateRunTable_Inverse is written by position.
    I=find(contains(opts.VariableNames,'Velocity'));
    opts.VariableTypes(I)={'string'};
    I=find(contains(opts.VariableNames,'startGeometry'));
    opts.VariableTypes(I)={'string'};
                
elseif UserVar.type == "Diagnostic"

    I=find(contains(opts.VariableNames,'Calv'));
    opts.VariableTypes(I)={'string'};
    I=find(contains(opts.VariableNames,'ISthick'));
    opts.VariableTypes(I)={'string'};
    I=find(contains(opts.VariableNames,'GIthick'));
    opts.VariableTypes(I)={'string'};

end

end
