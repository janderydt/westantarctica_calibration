function main_PerturbationResultsEnsemble
% main_PerturbationResultsEnsemble  Collect the results of the diagnostic (perturbation) experiments of an ensemble.
%
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Needs the results of the diagnostic experiments (ResultsFiles of each experiment) and the inversion data
% of the ensemble members; these data can be obtained upon request from the author.
%
% PURPOSE
%   For all finished experiments of the diagnostic run table(s) (within UserVar.idrange) that have not been
%   analysed yet: reads the result file of the experiment (CtrlVar, F, MUA), calculates the ice flux across the
%   grounding line (qGL) and across the open boundary (qOB) in each basin of interest (Calc_UaGLFlux_PerBasin,
%   Calc_UaOBFlux_PerBasin; summed over each basin and divided by 1e12: the fluxes are in kg/yr, so the totals are in Gt/yr), and stores them,
%   together with the nodal speed and the inversion parameters, in the structure data, with one element per
%   inversion (ensemble member) and fields Original / Calv / dhIS / dh / Calv_dh, each with a field yr<year> (qGL.<basin>,
%   qOB.<basin>, cycle, ExpID, speed). The type of perturbation is taken from the Comments column of the
%   run table (see GenerateRunTable_Diagnostic).
%   The file is updated incrementally: experiments in perturbation_experiments_analyzed are skipped.
%
% INPUTS
%   Diagnostic run table (UserVar.Table), diagnostic results
%   <UserVar.home>/GLUE_Diagnostic/cases/<Domain>/<Domain>_Diagnostic_<ExpID>/ResultsFiles/*.mat,
%   inversion data (inversiondata_filename; structure data with InverseExpID, gaC, gaA, gsC, gsA, dhdt_err,
%   misfit, startgeometry for each inversion; created by a script not yet received), basins_IMBIE_v2.mat (IMBIE v2 basin outlines; data that
%   can be obtained upon request from the author)
%
% OUTPUT
%   perturbationdata_filename (data, perturbation_experiments_analyzed)
%
% REQUIRES (not part of this repository yet)
%   Calc_UaGLFlux_PerBasin, Calc_UaOBFlux_PerBasin, RemoveIceRisesAndIslands; ReadWritetable
%   (ua_input/3_runtable)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% MAKE CHANGES IN THIS BLOCK AS REQUIRED
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% home folder of the Ua experiments (contains GLUE_Diagnostic)
UserVar.home = "/path/to/home/";
UserVar.type = "Diagnostic";

% settings for SYNTH_PIG (earlier runs): UserVar.Table = UserVar.home+"GLUE_Diagnostic/RunTable_Diagnostic_SYNTH_PIG_nsmbl__OLD-Weertmanyr30__NEW-Weertmanyr75.csv",
% idrange = [750000 759999], slidinglaws = ["Weertman" "Umbi"],
% inversiondata_filename = "./InversionData/SYNTH_PIG/SYNTH_PIG_Weertmanyr30_inversiondata_"+slidinglaws+".mat"
UserVar.Table = UserVar.home+"GLUE_Diagnostic/RunTable_Diagnostic_AMUND_nsmbl__HPDSample__OLD-2000__NEW-2020.csv";
UserVar.idrange = [120000 129999];
slidinglaws = [];
inversiondata_filename = "./InversionData/AMUND/AMUND_2000_inversiondata_HPDSample.mat";

perturbationdata_filename = "./DiagnosticData/AMUND/AMUND_2000_perturbationdata_HPDSample.mat";

if contains(UserVar.Table,"AMUND")
    % AMUNDSEN SEA
    basins_to_analyze = {'F-G',...  % Getz
        'G-H',...  % PIG, Thwaites
        'H-Hp'}; % Abbot
    
    % load basins (IMBIE v2) and keep only the basins of interest; RemoveIceRisesAndIslands is not part of this repository yet
    filename = 'basins_IMBIE_v2.mat'; 
    B = load(filename);
    B = RemoveIceRisesAndIslands(B);
    Ind = contains(B.name,basins_to_analyze);
    Bfields= fields(B);
    for ii=1:numel(Bfields)
        if ~contains(Bfields{ii},'note')
            tmp = B.(Bfields{ii});
            B.(Bfields{ii}) = tmp(Ind);
        end
    end
elseif contains(UserVar.Table,"SYNTH_PIG")
    %% SYNTH_PIG
    B.name = {'synth_pig'};
    B.x = {[-1e10 1e10 1e10 -1e10]'};
    B.y = {[-1e10 -1e10 1e10 1e10]'};
    B.x_center = 0;
    B.y_center = 0;
    basins_to_analyze = {'SYNTH_PIG'};
else
    error("Do not recognize basin")
end

if exist(perturbationdata_filename,"file")
    load(perturbationdata_filename);
else
    data=[];    
    perturbation_experiments_analyzed = [];
end

data_inverse = [];
for ii=1:numel(inversiondata_filename)
    tmp = load(inversiondata_filename(ii));
    data_inverse = [data_inverse, tmp.data];
end

for tt=1:numel(UserVar.Table)

    % read run table
    RunTable = ReadWritetable(UserVar,UserVar.Table(tt),[],'read');
    
    % ExpIDs
    ExpID = RunTable{:,"ExpID"};
    Ind = find(ExpID>=UserVar.idrange(tt,1) & ExpID<=UserVar.idrange(tt,2));
    
    % only keep experiments that have not been analyzed yet
    if ~isempty(data)
        Ind_ignore = ismember(ExpID(Ind),perturbation_experiments_analyzed);
    else
        Ind_ignore = 0*Ind;
    end
    % only keep experiments that have finished
    Ind_finished = RunTable{Ind,"Finished"}==1;
    Ind = Ind(Ind_ignore==0 & Ind_finished==1);
    Comments = RunTable{Ind,"Comments"};
    
    %% Gather data
    for ii=1:numel(Ind)

        perturbation_experiments_analyzed(end+1) = ExpID(Ind(ii));
        InverseExpID = RunTable{Ind(ii),"InverseA"};
        InverseCycle = RunTable{Ind(ii),"InverseCycleA"};
        Domain = RunTable{Ind(ii),"Domain"};
        Ind_inverse = find([data_inverse(:).InverseExpID]==InverseExpID);
        folder = UserVar.home+"/GLUE_Diagnostic/cases/"+Domain+"/"+Domain+"_Diagnostic_"+ExpID(Ind(ii));
        outputfiles = dir(folder+"/ResultsFiles/*.mat");

        if ~isempty(outputfiles)

            outputfile = outputfiles(1).folder + "/" + outputfiles(1).name;
            expinfo = Comments{ii};
            load(outputfile,"CtrlVar","F","MUA");      

            % Obtain Ua fluxes across the grounding line (qGL) into floating areas
            [B,~] = Calc_UaGLFlux_PerBasin(MUA,F,F.GF,B,CtrlVar);
            
            % Obtain Ua fluxes across the open boundary (qOB) into the ocean
            B = Calc_UaOBFlux_PerBasin(MUA,F,F.GF,B,CtrlVar); 
    
            % Sum values of SMB, qGL and qOB for each basin
            for bb=1:numel(B.x) 
                B.qGL_tot{bb} = sum(B.qGL{bb},'omitmissing')/1e12; 
                B.qOB_tot{bb} = sum(B.qOB{bb},'omitmissing')/1e12; 
                B.qtot{bb} = B.qGL_tot{bb}+B.qOB_tot{bb}; 
            end
          
            % store in data array
            if isempty(data)
                data_ind = 1;            
            else
                ExpID_list=[];
                for nn=1:numel(data)
                    ExpID_list(nn)=data(nn).Inverse.ExpID;
                end
                [~,data_ind] = ismember(InverseExpID,ExpID_list);
                if data_ind==0 % add new element to data structure
                    ndata = numel(data);
                    data_ind = ndata+1;
                end
            end

            data(data_ind).Inverse.ExpID = InverseExpID;
            data(data_ind).m = F.m(1);
            data(data_ind).n = F.n(1);
            data(data_ind).SlidingLaw = CtrlVar.SlidingLaw;
            data(data_ind).Inverse.gaC = data_inverse(Ind_inverse).gaC;
            data(data_ind).Inverse.gaA = data_inverse(Ind_inverse).gaA;
            data(data_ind).Inverse.gsC = data_inverse(Ind_inverse).gsC;
            data(data_ind).Inverse.gsA = data_inverse(Ind_inverse).gsA;
            data(data_ind).Inverse.dhdt_err = data_inverse(Ind_inverse).dhdt_err;
            data(data_ind).Inverse.misfit(InverseCycle) = data_inverse(Ind_inverse).misfit(InverseCycle);
            data(data_ind).startgeometry = data_inverse(Ind_inverse).startgeometry;

            startyear = data(data_ind).startgeometry;

            if contains(expinfo,"Original")
                year = data(data_ind).startgeometry;   
                fieldname = 'Original';
            elseif contains(expinfo,"Ice front geometry")
                year = RunTable{Ind(ii),"Calv"};
                fieldname = 'Calv';
            elseif contains(expinfo,"Ice shelf thickness")
                year = RunTable{Ind(ii),"ISthick"};
                fieldname = 'dhIS';
            elseif contains(expinfo,"Ice thickness")
                year = RunTable{Ind(ii),"ISthick"};
                fieldname = 'dh';
            elseif contains(expinfo,"Ice front and thickness")
                year = RunTable{Ind(ii),"Calv"};
                fieldname = 'Calv_dh';
            else
                error("Unknown experiment info "+expinfo);
            end

            %initialize structure
            if ~contains(year,"yr")
                yearfld = "yr"+year;
            else
                yearfld = year;
            end

            if year==startyear
                 geomfields = "Original";
            else
                 geomfields = ["Calv","dhIS","dh","Calv_dh"];
            end

            for ff=1:numel(geomfields)

                if ~isfield(data(data_ind),geomfields(ff)) || ...
                    ~isfield(data(data_ind).(geomfields(ff)),yearfld)

                    for bb=1:numel(basins_to_analyze)
                        basin = char(erase(basins_to_analyze(bb),'-'));
                        data(data_ind).(geomfields{ff}).(yearfld).qGL.(basin)=[];
                        data(data_ind).(geomfields{ff}).(yearfld).qOB.(basin)=[];
                    end
                    data(data_ind).(geomfields{ff}).(yearfld).cycle=[];
                    data(data_ind).(geomfields{ff}).(yearfld).ExpID=[];
                    data(data_ind).(geomfields{ff}).(yearfld).speed=[];
                end

            end

            % save data
            for bb=1:numel(basins_to_analyze)
                basin = char(erase(basins_to_analyze(bb),'-'));
                data(data_ind).(fieldname).(yearfld).qGL.(basin)(end+1) = cell2mat(B.qGL_tot(bb));
                data(data_ind).(fieldname).(yearfld).qOB.(basin)(end+1) = cell2mat(B.qOB_tot(bb));               
            end           
            data(data_ind).(fieldname).(yearfld).cycle(end+1) = InverseCycle;
            data(data_ind).(fieldname).(yearfld).ExpID(end+1) = ExpID(Ind(ii));
            
            % store the nodal speed (m/yr) of this experiment
            data(data_ind).(fieldname).(yearfld).speed(:,end+1) = hypot(F.ub(:),F.vb(:));

        end             
        fprintf("Done %s out of %s.\n",string(ii),string(numel(Ind)));
    end
end

save(perturbationdata_filename,"data","perturbation_experiments_analyzed","-v7.3");
