function GenerateRunTable_Inverse(Domain,X,GradientCalc,SlidingLaw_input,Enrich,UseCatalogue)
%GENERATERUNTABLE_INVERSE Expand a UQLab sample table into a full
%GLUE run table (one row per simulation) and write it to CSV.
%
%   GenerateRunTable_Inverse(Domain,X,GradientCalc,SlidingLaw_input,...
%       Enrich,UseCatalogue)
%
%   For each row of the sample table X, this function builds one
%   complete run-table row containing everything Ua/GLUE needs to
%   submit that simulation: mesh/geometry/velocity source names,
%   inversion settings (iterations, spinup years, what to invert for),
%   regularization/prior values, and - if UseCatalogue=1 - a starting
%   point (startC) taken from a nearest-neighbour match in a catalogue of
%   finished runs.
%
%   The resulting table is written to a timestamped CSV
%   ("NewTable_<Domain>_<GradientCalc>_<SlidingLaw>_Enriched<Enrich>_
%   <date>.csv"), and additionally split into chunks of at most
%   MaxTableLength rows (each written to its own "..._<n>.csv") to keep
%   individual submission batches manageable.
%
%% INPUTS:
% -> Domain is the model domain/mesh identifier: "AMUND_nsmbl" or
%    "SYNTH_PIG_nsmbl". Must match one of the cases handled in the
%    startMesh switch below.
% -> X is a table with columns gsC, gsA, gaC, gaA, dhdt_err, m, n (and
%    slidinglaw if SlidingLaw_input=""), one row per simulation, as created
%    by GenerateSampleSpace_Inverse
% -> GradientCalc is "Adjoint" (case sensitive)
% -> SlidingLaw is any valid type of sliding law in Ua, e.g. Weertman
% -> Enrich is 0 or 1, it only affects the name of the csv file that is
%    produced
% -> UseCatalogue is 0 or 1. If 1, start values for Adjoint inversions are
%    looked up via nearest-neighbour search in a catalogue of finished
%    runs (selected interactively via a file picker) instead of the
%    default start values of 0. (Enrich==1 alone does not trigger this,
%    see the NOTE at the condition below.)
%
%% OUTPUTS ON DISK:
% -> UserVar.Table: the full run table as one CSV.
% -> One or more "..._<n>.csv" files: the same table split into chunks
%    of at most MaxTableLength rows each.
%
%   ORDER OF THE COLUMNS of each new row (names as in EmptyTable.csv):
%   Domain, pgid, ExpID, Submitted, SubmissionTime, Running, Error, ErrorTime,
%   Finished, FinishedTime, Restart, InverseIterations, InverseIterationsDone,
%   SpinupYears, SpinupYearsDone, InvertFor, GradientCalc, gsC, gsA, gaC, gaA,
%   Measurements, dhdt error scaling, velocity, startGeometry, startMesh,
%   SlidingLaw, m, muk, priorC, startC, n, priorAGlen, startAGlen, Comments.
%
%   WHICH PARTS CAN BE RUN OUTSIDE THE AUTHOR'S ENVIRONMENT
%   With GradientCalc="Adjoint" and UseCatalogue=0 (the configuration of
%   GenerateSampleSpace_Inverse) no results of earlier inversions are
%   used: startC and startAGlen are 0 for all domains, so the table can be
%   generated from the sample alone.
%   FOR TRANSPARENCY, NOT RUNNABLE: with UseCatalogue=1 the script reads
%   run tables of finished inversions chosen in a dialog window (start
%   values taken from earlier experiments; these run tables can be obtained upon request from the author).
%
%   REQUIRES:
%   ReadWritetable.m (in this repository: ua_input/run; must be on the MATLAB path), EmptyTable.csv
%   (provided in this folder), and the Statistics and Machine
%   Learning Toolbox (knnsearch).
%
%   See also GENERATESAMPLESPACE_INVERSE, READWRITETABLE.


if GradientCalc ~= "Adjoint"
    error("Only GradientCalc=""Adjoint"" is supported.");
end

%% Settings and output file name

MaxTableLength = 300; % Maximum rows per output CSV chunk (keeps individual
                      % submission batches to a manageable size).
UserVar.home = pwd;
DT=datetime;
DT.Format="dd-MM-yyyy";
% Timestamped output filename encodes Domain/GradientCalc/SlidingLaw/
% Enrich/date so successive runs never overwrite each other.
UserVar.Table = "NewTable_"+Domain+"_"+GradientCalc+"_"+SlidingLaw_input+"_Enriched"+string(Enrich)+"_"+string(DT)+".csv";
UserVar.type = "Inverse";

%% Read or create the run table
% Start from a template with the correct column headers if this exact
% table doesn't already exist.
if ~exist(UserVar.Table,"file")
    copyfile("EmptyTable.csv",UserVar.Table);
end

RunTable = ReadWritetable(UserVar,UserVar.Table,[],'read');

%% Build one run-table row per sample in X
for ind=1:size(X.m,1)

    % Map the abstract Domain name to the specific starting mesh used to
    % initialise the simulation geometry. AMUND: the name refers to the mesh
    % files AMUND_basemesh_<name without "AMUND_">_extrudemesh1_variableboundaryres1.mat
    % written by AMUND_GenerateBaseMesh (to be confirmed in the run scripts).
    % SYNTH_PIG: mesh created offline (mesh file provided with the repository).
    switch Domain
        case "AMUND_nsmbl"
            startMesh = "AMUND_2000_meshmin1500_meshmax100000_refined";
        case "SYNTH_PIG_nsmbl"
            startMesh = "SYNTH_PIG";
        otherwise
            error('case uknown');
    end

    % Round every sampled parameter to 4 decimal places, purely so that
    % values are stored/compared consistently in the CSV (avoids
    % floating-point noise producing spurious "different" experiments).
    m = round(X.m(ind)*1e4)/1e4;
    n = round(X.n(ind)*1e4)/1e4; 
    gsC = round(X.gsC(ind)*1e4)/1e4;         %gsC
    gsA = round(X.gsA(ind)*1e4)/1e4;         %gsA
    gaC = round(X.gaC(ind)*1e4)/1e4;         %gaC
    gaA = round(X.gaA(ind)*1e4)/1e4;         %gaA
    dhdt_err = round(X.dhdt_err(ind)*1e4)/1e4;
    % SlidingLaw_input="" signals "use whatever sliding law is stored
    % per-row in X" (e.g. for a mixed-sliding-law sample); otherwise a
    % single sliding law is applied to every row. Note: this branch
    % requires X to have a 'slidinglaw' column, which
    % GenerateSampleSpace_Inverse does not currently produce.
    if SlidingLaw_input==""
        SlidingLaw = X.slidinglaw(ind);
    else
        SlidingLaw = SlidingLaw_input;
    end

    % Prior for bed slipperiness C, derived from an assumed reference
    % basal shear stress (taub) and sliding velocity (ub) via the
    % sliding-law relation ub = taub^m * C, so C = ub/taub^m.
    taub = 80;
    ub = 750; % reference sliding velocity
    priorC = ub/taub^m;
    muk = 0.5; % Coulomb-law friction coefficient (fixed, not sampled).
    
    % Prior for ice rheology parameter A (Glen's law), derived
    % analogously from a reference stress (tau) and strain rate (eps):
    % eps = tau^n * A, so A = eps/tau^n.
    tau = 80; 
    eps = 0.0026; % reference strain rate (note: shadows MATLAB's eps)
    priorAGlen = eps/tau^n;
   
    % Decide how to obtain starting values (startC/startAGlen) for this
    % Adjoint inversion. There are two possibilities, handled by the
    % if/elseif below:
    %
    % 1) UseCatalogue==0 (this branch):
    %    No start values from earlier inversions: startC = startAGlen = 0
    %    (how the inverse run scripts interpret 0 is documented there).
    %    (If SlidingLaw=Weertman, Enrich=0, this is the expected path.)
    %
    % 2) UseCatalogue==1:
    %    Use a nearest-neighbour match (in gaC/gaA/gsC/gsA/m/n space)
    %    from a user-selected catalogue of already-finished inversions
    %    as the start value.
    % NOTE (intentional): the second branch is only reached when UseCatalogue==1; with
    % UseCatalogue==0 the first branch is used, also when Enrich==1.
    if GradientCalc == "Adjoint" && UseCatalogue == 0

        % Per-domain solver/geometry/velocity settings. No start values
        % from earlier inversions are used: startC and startAGlen are 0.
        switch Domain
            case "SYNTH_PIG_nsmbl"
                iterations = "10000+5000";
                spinupyears = "0.1";
                velocity = "30_Umbi";
                startGeometry = "30_Umbi";
                startC = 0;
                startAGlen = 0;

            otherwise % AMUND_nsmbl
                iterations = "10000+5000";
                spinupyears = "3";
                velocity = "2000";
                startGeometry = "2000";
                startC = 0;
                startAGlen = 0;
        end
        
        invertfor = "-logC-logA-"; % Invert for both bed slipperiness (C)
                                   % and ice rheology (A), in log space.

     elseif GradientCalc == "Adjoint" && (Enrich == 1 || UseCatalogue == 1)
        % Build a catalogue of finished experiments (once, on the first
        % iteration) by prompting the user to select one or more run
        % table CSVs. Each finished row contributes its
        % [gaC gaA gsC gsA m n] location plus its ExpID and SlidingLaw,
        % pooled across all selected tables.
        if ind == 1
            Start = []; ExpID_Start=[]; SlidingLaw_Start = [];
            UserVar2.type = "Inverse";
            UserVar2.home = pwd; 
            [RunTablesToRead,location] = uigetfile("/path/to/run_tables/*.csv","Select run tables with experiments for startAGlen and startC","MultiSelect","on");
            RunTablesToRead = string(RunTablesToRead);
            for tt=1:numel(RunTablesToRead)
                UserVar2.Table = location+"/"+RunTablesToRead(tt);
                RunTable_Start = ReadWritetable(UserVar2,UserVar2.Table,[],'read');
                % scan table for ExpID, Slidinglaw, m and n      
                gaC_Start = RunTable_Start{:,'gaC'};
                gaA_Start = RunTable_Start{:,'gaA'};
                gsC_Start = RunTable_Start{:,'gsC'};
                gsA_Start = RunTable_Start{:,'gsA'};
                m_Start = RunTable_Start{:,'m'};
                n_Start = RunTable_Start{:,'n'};
                Finished = RunTable_Start{:,'Finished'};
                Start_tmp = [gaC_Start(:) gaA_Start(:) gsC_Start(:) gsA_Start(:) m_Start(:) n_Start(:)];
                Start = [Start; Start_tmp(Finished==1,:)];
                SlidingLaw_Start = [SlidingLaw_Start; RunTable_Start{Finished==1,'SlidingLaw'}];
                ExpID_Start = [ExpID_Start; RunTable_Start{Finished==1,'ExpID'}];            
            end   
        end
        % Restrict the catalogue to entries with matching SlidingLaw,
        % then find the nearest neighbour to this row's
        % [gaC gaA gsC gsA m n] using standardised Euclidean distance
        % (each dimension scaled by its own variance, so no single
        % parameter with a larger numeric range dominates the match).
        I_slidinglaw = find(SlidingLaw_Start==SlidingLaw);
        [Idx,D] = knnsearch(Start(I_slidinglaw,:),[gaC gaA gsC gsA m n],"Distance","seuclidean");
        startC = ExpID_Start(I_slidinglaw(Idx));
        startAGlen = 0;
        iterations = "15000+5000";
        spinupyears = "3";
        invertfor = "-logC-logA-";

    end

    % Assemble the full run-table row for this sample. Columns marked
    % 0 / "01/01/2000 00:00:00" are status/bookkeeping fields (pgid,
    % ExpID, Submitted, Running, Error, Finished, Restart, etc.) that
    % get filled in later by the job-submission/monitoring machinery -
    % they start unset for every newly-generated row.
    Newrow = {Domain,...             %Domain
        0,...                               %pgid
        0,...                               %ExpID
        0,...                               %Submitted
        "01/01/2000 00:00:00",...           %SubmissionTime
        0,...                               %Running
        0,...                               %Error
        "01/01/2000 00:00:00",...           %ErrorTime
        0,...                               %Finished
        "01/01/2000 00:00:00",...           %FinishedTime
        0,...                               %Restart
        iterations,...                      %InverseIterations
        0,...                               %InverseIterationsDone
        spinupyears,...                     %SpinupYears
        0,...                               %SpinupYearsDone
        invertfor,...                       %InvertFor
        GradientCalc,...                    %GradientCalc
        gsC,...                             %gsC
        gsA,...                             %gsA
        gaC,...                             %gaC
        gaA,...                             %gaA
        "-uv-dhdt-",...                     %Measurements
        dhdt_err,...                        %dhdt error scaling
        velocity,...                        %velocity
        startGeometry,...                   %startGeometry
        startMesh,...                       %startMesh
        SlidingLaw,...                      %SlidingLaw
        m,...                               %m
        muk,...                             %muk
        priorC,...                          %priorC
        startC,...                          %startC
        n,...                               %n
        priorAGlen,...                      %priorAGlen
        startAGlen,...                      %startAGlen
        ""                                  %Comments
        };

    RunTable = [RunTable; Newrow];

end

%% Write the run table (full and chunked)
% Write the complete run table (all rows) to the main CSV...
[~] = ReadWritetable(UserVar,UserVar.Table,RunTable,'write');
% ...then also split it into chunks of at most MaxTableLength rows,
% each written to its own "<UserVar.Table>_<n>.csv", for easier/safer
% batch submission.
for nn = 1:ceil(height(RunTable)/MaxTableLength)
    IndexRange = (nn-1)*MaxTableLength+1:min(nn*MaxTableLength,height(RunTable));
    RunTable_tmp = RunTable(IndexRange,:);
    TableName = erase(UserVar.Table,".csv")+"_"+string(nn)+".csv";
    [~] = ReadWritetable(UserVar,TableName,RunTable_tmp,'write');
end
