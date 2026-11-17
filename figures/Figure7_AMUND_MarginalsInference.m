function Figure7_AMUND_MarginalsInference
% Figure7_AMUND_MarginalsInference  Figure 7: posterior marginal distributions for AMUND.
%
% PURPOSE
%   Plots the marginal posterior distributions of the parameters n, m, log(dhdt_err), log10(gaA), log10(gaC), log10(gsA),
%   log10(gsC) for the two sliding laws (S_pwr: solid, S_hybr: dashed) together with the prior, from the Bayesian analysis
%   files listed in getfilename (end of this file; 9 analyses with the AMUND emulators of the version in the file names):
%     (a) sensitivity to the model discrepancy: analyses 4-9 (three year pairs combined, sigma_eta = 0, 10, 20, 30, 40, 50 m/yr)
%     (b) sensitivity to the epoch length: analysis 4 (all epochs) and 1-3 (single epochs 2000-2009, 2000-2014, 2000-2020)
%   Saves ./Figure7a_AMUND_MarginalsInference.png and ./Figure7b_AMUND_MarginalsInference.png (the file names said "SYNTH").
%
% INPUT
%   Bayesian analysis files (with myPosteriorDist from Calc_MarginalsInference) in the folder froot
%
% REQUIRES
%   UQLab Rel. 2.0.0 (uqlab, uq_all_pdf), Klear (UaSource); cmocean, fig (third party)

Klear;

% TODO: machine-specific folder with the Bayesian analysis files (see getfilename at the end of this file)
froot = "/mnt/md0/Ua/cases/GLUE/GLUE_DataProcessing/BayesianAnalysis/AMUND/";

%% =========================================
%% INITIALIZE UQLAB
%% =========================================

addpath(genpath(getenv("froot_matlabfunctions")+"/../UQLab_Rel2.0.0"));

rng(1,'twister'); % set the random number generator for reproducible results
uqlab; % initialize uqlab

%% =========================================
%% LOAD DATA
%% =========================================

for ff=1:9

    load(froot+"/"+getfilename(ff));
    
    if ~exist("myPosteriorDist","var")
        error(getfilename(ff)+":  myPosteriorDist does not exist.");
    end

    data(ff).myPriorDist = myBayesianAnalysis.PriorDist;
    data(ff).myPosteriorDist = myPosteriorDist;
    data(ff).l = UserVar.l;
    data(ff).std_ua = UserVar.std_ua;
    data(ff).mpsrf = myBayesianAnalysis.Results.PostProc.MPSRF;
    tmp = split(UserVar.fname,"__");
    data(ff).fname = getfilename(ff);
    data(ff).nametag = erase(tmp(end),".mat");
    geomtag = char(tmp(3));
    geomInd = strfind(geomtag,"yr");
    if ~isempty(geomInd)
        data(ff).startyear = string(geomtag(geomInd(1)+2:geomInd(1)+3));
        data(ff).endyear = string(geomtag(geomInd(2)+2:geomInd(2)+3));
    else
        pat=digitsPattern(4);
        years=extract(geomtag,pat);
        data(ff).startyear = string(years{1});
        data(ff).endyear = string(years{2});
    end

    clear myPosteriorDist myBayesianAnalysis

end

%% =============================================
%% FIGURE 7a: SENSITIVITY TO MODEL DISCREPANCY
%% =============================================

%% Which simulations to plot? refer to list at the end of this script
sims = [4:9];
%% colormaps
CM_Pwr = parula(numel(sims)+3); CM_Pwr = [CM_Pwr(2:end-2,:)];%;[0.6 0.6 0.6]];
CM_Hybr = CM_Pwr;
%% linestyles
linestyle_Pwr = "-";
linestyle_Hybr = "--";
%% linewidth
linewidth = [ones(numel(sims)-1,1); 2];
%% variables (this will be the order in which variables are plotted)
vars_to_plot = ["n","m","log(dhdt_err)","log10(gaA)","log10(gaC)","log10(gsA)","log10(gsC)"];
%% Labels (same order as variables)
labels = ["$n$","$m$","${\rm log}_{10}(\gamma_{\dot h})$","${\rm log}_{10}(\gamma_{aA})$",...
    "${\rm log}_{10}(\gamma_{aC})$","${\rm log}_{10}(\gamma_{sA})$","${\rm log}_{10}(\gamma_{sC})$"];
SL = ["\mathcal{S}_{\rm pwr}","\mathcal{S}_{\rm hybr}"];
titlestr = "Sensitivity to model discrepancy";

plot_marginals(data(sims),CM_Pwr,CM_Hybr,linestyle_Pwr,linestyle_Hybr,linewidth,vars_to_plot,labels,SL,titlestr,'a');

%% =============================================
%% FIGURE 7b: EPOCH LENGTH
%% =============================================

CM_Pwr_tmp = CM_Pwr;

%% Which simulations to plot? refer to list at the end of this script
sims = [4 1:3];
%% colormaps
CM_Pwr(1,:) = [0.5 0.5 0.5];
CM_Pwr(2,:) = CM_Pwr_tmp(end,:);
CM_Pwr(3,:) = CM_Pwr_tmp(2,:);
CM_Pwr(4,:) = CM_Pwr_tmp(4,:);

CM_Hybr = CM_Pwr;

%% linewidth
linewidth = [1; 2*ones(numel(sims)-1,1)];
titlestr = "Sensitivity to epoch length";

plot_marginals(data(sims),CM_Pwr,CM_Hybr,linestyle_Pwr,linestyle_Hybr,linewidth,vars_to_plot,labels,SL,titlestr,'b');

end

%% =============================================
%% HELPER FUNCTIONS
%% =============================================

function plot_marginals(data,CM_Pwr,CM_Hybr,linestyle_Pwr,linestyle_Hybr,linewidth,vars_to_plot,xLabels,SL,tlo_title,tag)

    nmarginals = numel(vars_to_plot);

    H=fig('units','inches','width',120*12/72.27,'height',25*12/72.27,'fontsize',16,'font','Helvetica');
    
    tlo_fig = tiledlayout(1,nmarginals,"TileSpacing","compact");
    for i = 1:nmarginals
        ax_fig(i) = nexttile(tlo_fig,i); hold on;
    end
    
    for jj=1:nmarginals
        % marginal to plot:
        try
            Ind = find(strcmp({data(1).myPosteriorDist(1).dist.Marginals(:).Name},vars_to_plot(jj)));
        catch
            Ind = find(strcmp({data(1).myPosteriorDist(2).dist.Marginals(:).Name},vars_to_plot(jj)));
        end
        legInd=1;
        for ii=1:numel(data)
            ndiscrete = numel(data(ii).myPosteriorDist);
            for kk=1:ndiscrete
                nn = (kk-1)*numel(data)+ii;
                switch kk
                    case 1
                        CM = CM_Pwr;
                        linestyle = linestyle_Pwr;
                    case 2
                        CM = CM_Hybr;
                        linestyle = linestyle_Hybr;
                end
                if ~isempty(data(ii).myPosteriorDist(kk).dist)
                    X = linspace(data(ii).myPosteriorDist(kk).dist.Marginals(Ind).Bounds(1),data(ii).myPosteriorDist(kk).dist.Marginals(Ind).Bounds(2),50);            
                    f = uq_all_pdf(X(:),data(ii).myPosteriorDist(kk).dist.Marginals(Ind))*data(ii).myPosteriorDist(kk).frac;
                else
                    X = [nan nan];
                    f = [nan nan];
                end
                if jj==1
                    if data(ii).myPosteriorDist(kk).frac > 0
                        g(legInd) = plot(ax_fig(jj),X,f,linestyle,'color',CM(ii,:),'LineWidth',linewidth(ii),'markersize',4);
   
                        if numel(unique([data(:).endyear]))>2
                            if legInd==1
                                label(legInd) = "$" + SL(kk) + ",\,\{\Delta t_i\}_{i=1}^3,\,t_i\in\{2009,\,2014,\,2020\}$";
                            else
                                label(legInd) = "$" + SL(kk) + ",\,\Delta t=" + string(double(data(ii).startyear) + "-" + string(double(data(ii).endyear))) + "$";
                            end
                        else
                            label(legInd) = "$" + SL(kk) + ",\,\sigma_\eta=" + string(data(ii).std_ua) + "{\,\rm m/yr}$";
                        end
                        fprintf("Plotting %s\n",data(ii).fname);
                        legInd = legInd + 1;
                    end
                else
                    if data(ii).myPosteriorDist(kk).frac > 0
                        plot(ax_fig(jj),X,f,linestyle,'color',CM(ii,:),'LineWidth',linewidth(ii),'markersize',4);
                    end
                end
            end
        end
        % plot prior
        IndPrior = find(strcmp({data(1).myPriorDist.Options.Marginals(:).Name},vars_to_plot(jj)));
        Parameters = data(1).myPriorDist.Options.Marginals(IndPrior).Parameters;
        Bounds = data(1).myPriorDist.Options.Marginals(IndPrior).Bounds;
        switch data(1).myPriorDist.Options.Marginals(IndPrior).Type
            case "Gaussian"
                xPrior = linspace(Bounds(1),Bounds(2),100);
                Value = 1/(Parameters(2)*sqrt(2*pi))*exp(-0.5*((xPrior-Parameters(1))/Parameters(2)).^2);
            case "Uniform"
                Bounds = Parameters;
                xPrior = linspace(Bounds(1),Bounds(2),100);
                Value = 0*xPrior+1/(Parameters(2)-Parameters(1));                           
        end
        xlim_tmp = get(ax_fig(jj),"xlim"); xlim_tmp(1) = max(xlim_tmp(1),Bounds(1)); xlim_tmp(2) = min(xlim_tmp(2),Bounds(2)); 
        ylim_tmp = get(ax_fig(jj),"ylim"); ylim_tmp(2) = max(ylim_tmp(2),max(Value)+0.05);
        prior=plot(ax_fig(jj),xPrior,Value,':','color',[0.5 0.5 0.5],'linewidth',2.5); 
        xlim(ax_fig(jj),xlim_tmp);
        ylim(ax_fig(jj),ylim_tmp);
        if jj==1
            figlabel = text(ax_fig(jj),xlim_tmp(1)-1,ylim_tmp(end),"("+tag+")");
            figlabel.FontSize = 20;
        end
    end

    for ii=1:nmarginals
        grid(ax_fig(ii),'on'); 
        box(ax_fig(ii),'on');
        yticklabels(ax_fig(ii),[]);
        xlabel(ax_fig(ii),xLabels(ii),"Interpreter","latex","fontsize",16);
        if numel(g)>5
            numrows = 2;
            numcolumns = ceil(numel(g)/numrows);
        else
            numcolumns = numel(g);
        end
        if ii==1
            leg=legend([g(:);prior],[label(:);"${\rm Prior}$"],...
                'Orientation','Horizontal','NumColumns',numcolumns+1,"Interpreter","latex");
            leg.Layout.Tile = 'north';
            leg.FontSize = 16;
        end
    end

    title(tlo_fig,tlo_title,'fontsize',20);
    
    pos = get(H,"Position");
    set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
    Hname = "./Figure7"+tag+"_AMUND_MarginalsInference";
    print(H,Hname,"-dpng","-r400");

end

function filename = getfilename(ii)
    switch ii
        case 1
            filename = "AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2009__UaERR_l0-stdua0__MCMC_a2-steps100000-nchains25_v1.mat";
        case 2
            filename = "AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2014__UaERR_l0-stdua0__MCMC_a2-steps100000-nchains25_v1.mat";
        case 3
            filename = "AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2020__UaERR_l0-stdua0__MCMC_a2-steps100000-nchains25_v1.mat";
        case 4 
            filename = "AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2009__EM2_2000-2014__EM3_2000-2020__UaERR_l0-stdua0__MCMC_a2-steps200000-nchains50_v1.mat";
        case 5
            filename = "AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2009__EM2_2000-2014__EM3_2000-2020__UaERR_l50000-stdua10__MCMC_a2-steps100000-nchains25_v1.mat";
        case 6
            filename = "AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2009__EM2_2000-2014__EM3_2000-2020__UaERR_l50000-stdua20__MCMC_a2-steps100000-nchains25_v1.mat";
        case 7
            filename = "AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2009__EM2_2000-2014__EM3_2000-2020__UaERR_l50000-stdua30__MCMC_a2-steps100000-nchains25_v1.mat";
        case 8
            filename = "AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2009__EM2_2000-2014__EM3_2000-2020__UaERR_l50000-stdua40__MCMC_a2-steps100000-nchains25_v1.mat";
        case 9
            filename = "AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2009__EM2_2000-2014__EM3_2000-2020__UaERR_l50000-stdua50__MCMC_a2-steps250000-nchains50_v1.mat";
    end

end
