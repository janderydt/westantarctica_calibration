function GenerateRunTable_Diagnostic
% GenerateRunTable_Diagnostic  Create the run table of the diagnostic experiments.
%
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Needs the run tables of the inverse experiments (finished experiments and their
% ExpIDs), which depend on earlier model runs (these data can be obtained upon request from the author). NOTE: this version builds rows with 22
% values, but EmptyTable.csv (= RunTable_GLUE_Diagnostic_9999.csv) has 24 columns (it also has
% InverseAFill and InverseCFill): the script and the table are out of sync.
%
% PURPOSE
%   Uses existing run tables of inverse simulations as a basis to construct a new (or add
%   to an existing) run table for diagnostic simulations. Each finished inverse simulation
%   that is not yet in the diagnostic table becomes the starting point of one diagnostic
%   simulation per perturbation in "pert" (Original, Calv, ISthick, thick, Calv_thick):
%     Original   : velocity solve with the original configuration (old mesh and geometry)
%     Calv       : new calving front (mesh of the new year)
%     ISthick    : new ice shelf thickness
%     thick      : new ice shelf and grounded ice thickness
%     Calv_thick : new calving front, ice shelf thickness and grounded ice thickness
%   Currently only runs with spinup are created (it=2; it=1 would be without spinup).
%   NOTE: the A and C fields remain unchanged in these experiments.
%
% OUTPUT
%   RunTable_Diagnostic_<Modeldomain>_Weertman__OLD-<old>__NEW-<new>.csv in the current folder
%   (a copy of EmptyTable.csv if it does not exist; an existing table is saved as .orig)
%
% REQUIRES
%   ReadWritetable (ua_input/run; must be on the MATLAB path); EmptyTable.csv in the current folder

UserVar.home = pwd;

%% original inversion run table(s)
% run tables of the inverse experiments that are used as starting points
% TODO: confirm the file name(s) and the model domain
RunTable_inverse_files = "../GLUE_Inverse/RunTable_AMUND_nsmbl_Adjoint_HPDSample_Enriched0_19-11-2025.csv";
Modeldomain = "AMUND_nsmbl"; % "AMUND_nsmbl" or "SYNTH_PIG_nsmbl"
% for SYNTH_PIG_nsmbl: RunTable_inverse_files = "../GLUE_Inverse/RunTable_SYNTH_PIG_nsmbl_Weertmanyr30_Adjoint_"+["Weertman" "Umbi"]+"_Enriched0_24-10-2025.csv";

%% year for original and new geometry
ExpID_oldgeom = "2000"; % AMUND_nsmbl: "2000"; SYNTH_PIG_nsmbl: "Weertmanyr30"
ExpID_newgeom = "2020"; % AMUND_nsmbl: "2009", "2014" or "2020"; SYNTH_PIG_nsmbl: e.g. "Weertmanyr35"
% TODO: confirm the years used in the project

%% which perturbations?
pert = ["Original", "Calv_thick"]; % Original, Calv, ISthick, thick, Calv_thick

%% construct new run table or append to existing run table
UserVar.Table = "./RunTable_Diagnostic_"+Modeldomain+"_Weertman__OLD-"+ExpID_oldgeom+"__NEW-"+ExpID_newgeom+".csv";
if ~exist(UserVar.Table,"file")
    copyfile("EmptyTable.csv",UserVar.Table);
else
    copyfile(UserVar.Table,UserVar.Table+".orig");
end
UserVar.type = "Diagnostic";
RunTable_diagnostic = ReadWritetable(UserVar,UserVar.Table,[],'read');

for tt=1:numel(RunTable_inverse_files)
    %% read original run table
    UserVar.type = "Inverse";
    RunTable_inverse =  ReadWritetable(UserVar,RunTable_inverse_files(tt),[],'read');
          
    IndOriginalGeometry = find(contains(RunTable_diagnostic.Comments,"Original"));
    
    ExistingInverseRunsInDiagnosticTable=RunTable_diagnostic.InverseA(IndOriginalGeometry);

    gsA = RunTable_inverse.gsA(:); fig_gsA = figure(name="gsA"); plot([1:numel(gsA)],log10(gsA),'ok','markerfacecolor','k'); title('gsA');
    gaA = RunTable_inverse.gaA(:); fig_gaA = figure(name="gaA"); plot([1:numel(gaA)],log10(gaA),'ok','markerfacecolor','k'); title('gaA');
    gsC = RunTable_inverse.gsC(:); fig_gsC = figure(name="gsC"); plot([1:numel(gsC)],log10(gsC),'ok','markerfacecolor','k'); title('gsC');
    gaC =  RunTable_inverse.gaC(:); fig_gaC = figure(name="gaC"); plot([1:numel(gaC)],log10(gaC),'ok','markerfacecolor','k'); title('gaC');
    m =  RunTable_inverse.m(:);
    n =  RunTable_inverse.n(:);
    dhdt_err =  RunTable_inverse.dhdt_err(:);

    if isempty(ExistingInverseRunsInDiagnosticTable)
        ExistingInverseRunsInDiagnosticTable = [];
    else
        if iscell(ExistingInverseRunsInDiagnosticTable)
            ExistingInverseRunsInDiagnosticTable = unique(cell2mat(ExistingInverseRunsInDiagnosticTable));
        else
            ExistingInverseRunsInDiagnosticTable = unique(ExistingInverseRunsInDiagnosticTable);
        end
    end
    
    % base mesh of the new geometry (calving front), see DefineBaseMesh
    % TODO: changed from Modeldomain+"_"+year+"_meshmin..." ("AMUND_nsmbl_2020_...") to the mesh
    % names used by DefineBaseMesh ("AMUND_2020_...")
    if Modeldomain=="AMUND_nsmbl"
        BaseMesh="AMUND_"+string(ExpID_newgeom)+"_meshmin1500_meshmax100000_refined";
    elseif Modeldomain=="SYNTH_PIG_nsmbl"
        BaseMesh="SYNTH_PIG";
    end

    
    for ii=1:size(RunTable_inverse,1)

        %% criteria to add: not yet in the diagnostic table, and finished
        % (the roughness filter that excluded regularisation-driven inversions in an earlier
        % version of this script was removed)
        % existing diagnostic run?
        existing = ismember(RunTable_inverse.ExpID(ii),ExistingInverseRunsInDiagnosticTable);
        finished = RunTable_inverse.Finished(ii);    

        if ~existing & finished

            figure(fig_gsA); hold on; plot(ii,log10(gsA(ii)),'dg','markersize',10,'linewidth',2); 
            figure(fig_gaA); hold on; plot(ii,log10(gaA(ii)),'dg','markersize',10,'linewidth',2); 
            figure(fig_gsC); hold on; plot(ii,log10(gsC(ii)),'dg','markersize',10,'linewidth',2); 
            figure(fig_gaC); hold on; plot(ii,log10(gaC(ii)),'dg','markersize',10,'linewidth',2); 
    
            Newrows=[];
            Newrow_tmp=[];
        
            for it=2 % 1: no spinup, 2: with spinup (use 1:2 for both)
            
                Newrow_tmp = ...
                    {RunTable_inverse.Domain{ii},...    %Domain
                    0,...                               %pgid
                    0,...                               %ExpID
                    0,...                               %Submitted
                    "2000-01-01 00:00:00",...           %SubmissionTime
                    0,...                               %Running
                    0,...                               %Error
                    "2000-01-01 00:00:00",...           %ErrorTime
                    0,...                               %Finished
                    "2000-01-01 00:00:00",...           %FinishedTime
                    0,...                               %Restart
                    BaseMesh,...                        %BaseMesh
                    RunTable_inverse.ExpID(ii),...      %InverseA
        	        it,...                              %InverseCycleA
        	        RunTable_inverse.ExpID(ii),...      %InverseC
        	        it,...                              %InverseCycleC
        	        ExpID_oldgeom,...                   %Calv
        	        ExpID_oldgeom,...                   %ISthick
        	        it,...                              %InverseCycleIS (1=no spinup, 2=spinup)
        	        ExpID_oldgeom,...                   %GIthick
        	        it,...                              %InverseCycleGI (1=no spinup, 2=spinup)
                    ""                                  %Comments
                    };
        
                %% add details about geometry
                % Original geometry
                if ismember("Original",pert)
                    Newrow_tmp_orig = Newrow_tmp;
                    Newrow_tmp_orig{end} = "Original geometry "+string(RunTable_inverse.startGeometry(ii));
                    Newrow_tmp_orig{12} = strrep(BaseMesh,"_"+string(ExpID_newgeom)+"_","_"+string(ExpID_oldgeom)+"_");
                    RunTable_diagnostic = [RunTable_diagnostic ; Newrow_tmp_orig];
                end

                % Calv
                if ismember("Calv",pert)
                    Newrow_tmp_Calv = Newrow_tmp;
                    Newrow_tmp_Calv{17} = ExpID_newgeom;
                    Newrow_tmp_Calv{end} = "Ice front geometry "+string(ExpID_newgeom);
                    RunTable_diagnostic = [RunTable_diagnostic ; Newrow_tmp_Calv];
                end
        
                % ISthick
                if ismember("ISthick",pert)
                    Newrow_tmp_ISthick = Newrow_tmp;
                    Newrow_tmp_ISthick{12} = strrep(BaseMesh,"_"+string(ExpID_newgeom)+"_","_"+string(ExpID_oldgeom)+"_");
                    Newrow_tmp_ISthick{18} = ExpID_newgeom;
                    Newrow_tmp_ISthick{end} = "Ice shelf thickness "+string(ExpID_newgeom);
                    RunTable_diagnostic = [RunTable_diagnostic ; Newrow_tmp_ISthick];
                end
        
                % ISthick and GIthick      
                if ismember("thick",pert)
                    Newrow_tmp_thick = Newrow_tmp;
                    Newrow_tmp_thick{12} = strrep(BaseMesh,"_"+string(ExpID_newgeom)+"_","_"+string(ExpID_oldgeom)+"_");
                    Newrow_tmp_thick{18} = ExpID_newgeom;
                    Newrow_tmp_thick{20} = ExpID_newgeom;
                    Newrow_tmp_thick{end} = "Ice thickness "+string(ExpID_newgeom);
                    RunTable_diagnostic = [RunTable_diagnostic ; Newrow_tmp_thick];
                end
        
                % Calv, ISthick and GIthick
                if ismember("Calv_thick",pert)
                    Newrow_tmp_Calv_thick = Newrow_tmp;
                    Newrow_tmp_Calv_thick{17} = ExpID_newgeom; 
                    Newrow_tmp_Calv_thick{18} = ExpID_newgeom; 
                    Newrow_tmp_Calv_thick{20} = ExpID_newgeom; 
                    Newrow_tmp_Calv_thick{end} = "Ice front and thickness "+string(ExpID_newgeom);
                    RunTable_diagnostic = [RunTable_diagnostic ; Newrow_tmp_Calv_thick];
                end
    
            end
    
        end
    
    end
end

UserVar.type = "Diagnostic";
ReadWritetable(UserVar,UserVar.Table,RunTable_diagnostic,'write');
