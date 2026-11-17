function Calc_InverseResults_Ensemble
% Calc_InverseResults_Ensemble  Collect the results of the inversions of an ensemble.
%
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Needs the restart files of the inversions of the ensemble members (data that can be obtained upon request from
% the author).
%
% PURPOSE
%   For all (finished) experiments of the inverse run table within UserVar.idrange that have not been analysed yet and
%   for both inverse cycles (1: velocities only, 2: after spinup, velocities and dh/dt): reads the restart file
%   <home>/GLUE_Inverse/cases/<Domain>/<Domain>_Inverse_<ExpID>/<Domain>_Inverse_<ExpID>-RestartFile_InverseCycle<cycle>.mat
%   and stores in the structure data (one element per experiment): InverseExpID, cycle, m, n, SlidingLaw, the
%   regularisation parameters gaA, gaC, gsA, gsC, dhdt_err, startgeometry, the number of iterations (niter), the flux across
%   the grounding line (qGL) and the open boundary (qOB) per basin (summed and divided by 1e12), the total balanced
%   melt per basin (TotalBalancedMelt), the nodal balanced melt rate (BalancedMeltMap, CalcIceShelfMeltRates), and the
%   final misfit and regularisation of the inversion. The file is updated incrementally.
%   Settings as supplied: the AMUND posterior sample ("HPDSample") run table. For SYNTH_PIG (earlier runs):
%   UserVar.Table = UserVar.home+"GLUE_Inverse/RunTable_SYNTH_PIG_nsmbl_Weertmanyr30_Adjoint_Weertman_Enriched0_24-10-2025.csv",
%   inversiondata_filename = "./InversionData/SYNTH_PIG/SYNTH_PIG_Weertmanyr30_inversiondata_Weertman.mat".
%
% OUTPUT
%   inversiondata_filename (data, inverse_experiments_analyzed, MUA, GF), read by plot_PerturbationResults_Ensemble,
%   plot_InverseResults_Ensemble and Calc_PerturbationResults_Ensemble.
%
% REQUIRES
%   Calc_UaGLFlux_PerBasin, Calc_UaOBFlux_PerBasin, RemoveIceRisesAndIslands (same folder); ReadWritetable (ua_input/run);
%   Ua source code (CalcIceShelfMeltRates), inpoly (Ua / Mesh2d); basins_IMBIE_v2.mat in the current folder (data
%   that can be obtained upon request from the author)

only_finished=1;

% home folder of the Ua experiments (contains GLUE_Inverse)
UserVar.home = "/path/to/home/";
UserVar.type = "Inverse";

UserVar.Table = UserVar.home+"GLUE_"+UserVar.type+"/RunTable_AMUND_nsmbl_Adjoint_HPDSample_Enriched0_19-11-2025.csv";
UserVar.idrange = [100000 100999];

inversiondata_filename = "./InversionData/AMUND/AMUND_2000_inversiondata_HPDSample.mat";

if exist(inversiondata_filename,"file")
    load(inversiondata_filename);
else
    data=[];
    inverse_experiments_analyzed = [];
end

%% AMUND
if contains(UserVar.Table,"AMUND")
    basins_to_analyze = {'F-G',...  % Getz
        'G-H',...  % PIG, Thwaites
        'H-Hp'}; % Abbott

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
%% SYNTH_PIG
elseif contains(UserVar.Table,"SYNTH_PIG")
    B.name = {'synth_pig'};
    B.x = {[-1e10 1e10 1e10 -1e10]'};
    B.y = {[-1e10 -1e10 1e10 1e10]'};
    B.x_center = 0;
    B.y_center = 0;
else
    error("What case?");
end

for tt=1:numel(UserVar.Table)

    %% read run table
    RunTable = ReadWritetable(UserVar,UserVar.Table(tt),[],'read');

    %% ExpIDs
    ExpID = RunTable{:,"ExpID"};
    Ind = find(ExpID>=UserVar.idrange(tt,1) & ExpID<=UserVar.idrange(tt,2));
    % only keep experiments that have not been analyzed yet
    if ~isempty(data)
        Ind_ignore = ismember(ExpID(Ind),inverse_experiments_analyzed);
    else
        Ind_ignore = 0*Ind;
    end
    % only keep experiments that have finished
    Ind_finished = RunTable{Ind,"Finished"}==1;
    if only_finished
        Ind = Ind(Ind_ignore==0 & Ind_finished==1);
    else
        Ind = Ind(Ind_ignore==0);
    end

    %% Gather data
    for ii=1:numel(Ind)

        UserVar.domain = RunTable{Ind(ii),"Domain"};
        folder = UserVar.home+"/GLUE_"+UserVar.type+"/cases/"+UserVar.domain+"/"+UserVar.domain+"_Inverse_"+ExpID(Ind(ii));

        % store in data array
        if isempty(data)
            data_ind = 1;
        else
            [~,data_ind] = ismember(Ind(ii),[data(:).InverseExpID]);
            if data_ind==0 % add new element to data structure
                ndata = numel(data);
                data_ind = ndata+1;
            end
        end

        for cc=1:2

            restartfile = folder+"/"+UserVar.domain+"_"+UserVar.type+"_"+ExpID(Ind(ii))+"-RestartFile_InverseCycle"+...
                string(cc)+".mat";

            if exist(restartfile,"file")

                inverse_experiments_analyzed(end+1) = ExpID(Ind(ii));

                try

                    load(restartfile,"UserVarInRestartFile","CtrlVarInRestartFile","F","MUA","InvFinalValues");

                    data(data_ind).InverseExpID = ExpID(Ind(ii));
                    data(data_ind).cycle(cc) = cc;
                    data(data_ind).m = F.m(1);
                    data(data_ind).n = F.n(1);
                    data(data_ind).SlidingLaw = CtrlVarInRestartFile.SlidingLaw;
                    data(data_ind).gaA = CtrlVarInRestartFile.Inverse.Regularize.logAGlen.ga;
                    data(data_ind).gaC = CtrlVarInRestartFile.Inverse.Regularize.logC.ga;
                    data(data_ind).gsA = CtrlVarInRestartFile.Inverse.Regularize.logAGlen.gs;
                    data(data_ind).gsC = CtrlVarInRestartFile.Inverse.Regularize.logC.gs;
                    if isfield(UserVarInRestartFile.Inverse,"dhdt_err")
                        data(data_ind).dhdt_err = UserVarInRestartFile.Inverse.dhdt_err;
                    else
                        data(data_ind).dhdt_err = nan;
                    end
                    data(data_ind).startgeometry = RunTable{Ind(ii),"startGeometry"};

                    if ExpID(Ind(ii))<10000 && cc>1

                        nvec_basins = numel(B);
                        nvec_nodes = MUA.Nnodes;

                        data(data_ind).niter(cc) = nan;

                        data(data_ind).qGL(:,cc) = nan*ones(nvec_basins,1);
                        data(data_ind).qOB(:,cc) = nan*ones(nvec_basins,1);
                        data(data_ind).TotalBalancedMelt(:,cc) = nan*ones(nvec_basins,1);

                        data(data_ind).BalancedMeltMap(:,cc) = nan*ones(nvec_nodes,1);

                        data(data_ind).misfit(cc) = nan;
                        data(data_ind).regularization(cc) = nan;

                    else

                        [B,~] = Calc_UaGLFlux_PerBasin(MUA,F,F.GF,B,CtrlVarInRestartFile);
                        B = Calc_UaOBFlux_PerBasin(MUA,F,F.GF,B,CtrlVarInRestartFile);
                        % Sum values of SMB, qGL and qOB for each basin
                        for bb=1:numel(B.x)
                            B.qGL_tot{bb} = sum(B.qGL{bb},'omitmissing')/1e12;
                            B.qOB_tot{bb} = sum(B.qOB{bb},'omitmissing')/1e12;
                        end
                        qGL = cell2mat(B.qGL_tot);
                        qOB = cell2mat(B.qOB_tot);
                        ab = CalcIceShelfMeltRates(CtrlVarInRestartFile,MUA,F.ub,F.vb,F.s,F.b,F.S,F.B,F.rho,F.rhow,0*F.ub,F.as,0*F.ub);
                        x = MUA.coordinates(:,1);
                        y = MUA.coordinates(:,2);
                        for bb=1:numel(B.x)
                            xB = B.x{bb};
                            yB = B.y{bb};
                            ab_tot = 0;
                            Indnan = [0; find(isnan(xB)); numel(xB)+1];
                            for nn=1:numel(Indnan)-1
                                if ~isempty([Indnan(nn)+1:Indnan(nn+1)-1])
                                    Indpoly = find(inpoly([x y],[xB(Indnan(nn)+1:Indnan(nn+1)-1) yB(Indnan(nn)+1:Indnan(nn+1)-1)]));
                                    ab_tot = ab_tot + sum(ab(Indpoly));
                                end
                            end
                            BalancedMelt(bb) = ab_tot;
                        end
                        data(data_ind).niter(cc) = UserVarInRestartFile.Inverse.IterationsDone;

                        data(data_ind).qGL(:,cc) = qGL(:);
                        data(data_ind).qOB(:,cc) = qOB(:);
                        data(data_ind).TotalBalancedMelt(:,cc) = BalancedMelt(:);
                        data(data_ind).BalancedMeltMap(:,cc) = ab(:);

                        data(data_ind).misfit(cc) = InvFinalValues.I;
                        data(data_ind).regularization(cc) = InvFinalValues.R;

                    end

                catch

                    warning("Unable to load file "+restartfile+".");

                end

            end

        end

        fprintf("done %s our of %s.\n",string(ii),string(numel(Ind)));

    end

    if ~isempty(Ind)
        GF = F.GF;
        inverse_experiments_analyzed = unique(inverse_experiments_analyzed,"stable");
        save(inversiondata_filename,"data","inverse_experiments_analyzed","MUA","GF","-v7.3");
    end

end
