function Plot_MarginalsInference
% Plot_MarginalsInference  Plot the posterior marginals of several Bayesian analyses together with the prior.
%
% PURPOSE
%   Reads Bayesian analyses (UQLab results with the fitted posterior distribution myPosteriorDist, see Calc_MarginalsInference)
%   selected in a file window (or, if only one file is selected, all files in ./BayesianAnalysis/ with a given range l and/or standard deviation std_ua
%   of the Ua errors for the cycle and floating-ice setting at the top) and plots the posterior marginals of n, m, log(dhdt_err),
%   log10(gaA), log10(gaC), log10(gsA) and log10(gsC) in one row of panels, with the prior (dashed) and, for SYNTH_PIG, the true
%   values (n = 3, m = 4). The sliding laws (S_pwr, S_hybr) are plotted in separate colours. The figure is saved as
%   ./Figures/Aposterior_ErrorSensitivity_<domain>.png. Figures 4 and 7 are made with Figure4_SYNTH_MarginalsInference.m and
%   Figure7_AMUND_MarginalsInference.m.
%
% FILES READ (data; can be obtained upon request from the author, see README)
%   ./BayesianAnalysis/*.mat (variables myBayesianAnalysis, myPosteriorDist, UserVar)
%
% REQUIRES
%   UQLab Rel. 2.0.0 (must be on the MATLAB path), Klear (Ua), cmocean, fig (third party)

Klear;

%% initialize UQLAB

rng(1,'twister'); % set the random number generator for reproducible results
uqlab; % initialize uqlab

%% load sample from existing Bayesian Analysis
[fname,location] = uigetfile("./BayesianAnalysis/*.mat","MultiSelect","on");

if isscalar(fname)

    clear fname;
    cycle = 2;
    floating_ice = 0;
    std_ua = [];
    l = 50000;

    ind = 1;
    location = "./BayesianAnalysis/";
    files = dir(location+"*cycle"+string(cycle)+"_floatingice"+string(floating_ice)+"*.mat");
    for ff=1:numel(files)
        load(files(ff).folder+"/"+files(ff).name,"UserVar");
        if ~isempty(std_ua) & ~isempty(l)
            if UserVar.std_ua==std_ua && UserVar.l==l
                fname(ind)=string(files(ff).name);
                ind = ind +1;
            end
        elseif isempty(std_ua) & ~isempty(l)
            if UserVar.l==l
                fname(ind)=string(files(ff).name);
                ind = ind +1;
            end
        elseif ~isempty(std_ua) & isempty(l)
            if UserVar.std_ua==std_ua
                fname(ind)=string(files(ff).name);
                ind = ind +1;
            end
        end
    end
end
fname = string(fname);

for ff=1:numel(fname)

    load(location+"/"+fname(ff));

    if ~exist("myPosteriorDist","var")
        error(fname(ff)+":  myPosteriorDist does not exist.");
    end

    data(ff).myPriorDist = myBayesianAnalysis.PriorDist;
    data(ff).myPosteriorDist = myPosteriorDist;
    data(ff).l = UserVar.l;
    data(ff).std_ua = UserVar.std_ua;
    data(ff).mpsrf = myBayesianAnalysis.Results.PostProc.MPSRF;
    tmp = split(UserVar.fname,"__");
    data(ff).fname = fname(ff);
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

% reorder data
if ~isscalar(unique([data(:).std_ua]))
    [~,I] = sort([data(:).std_ua],'ascend');
    data = data(I);
    std_ua = unique([data(:).std_ua]);
    for ii=1:numel(std_ua)
        I=find([data(:).std_ua]==std_ua(ii));
        % reorder data
        [~,I2] = sort([data(I).l],'ascend');
        data(I) = data(I(I2));
    end
elseif ~isscalar(unique([data(:).endyear]))
    [~,I] = sort([data(:).endyear],'ascend');
    data = data(I);
end

std_ua = unique([data(:).std_ua]);
l = unique([data(:).l]);

linestyle = ["-","--",":","-.","-","--",":","-.","-","--",":","-.","-","--",":","-."];

if isscalar(l) && ~isscalar(std_ua)
    CM = cmocean('ice',numel(std_ua)+1); CM=CM(1:end-1,:);
    CM = [CM; flipud(cmocean('matter',numel(std_ua)+1))]; CM=CM(1:end-1,:);
    linewidth = linspace(0.5,2,numel(std_ua));
elseif ~isscalar(l) && isscalar(std_ua)
    CM = cmocean('ice',numel(l)+1); CM=CM(1:end-1,:);
    CM = [CM; flipud(cmocean('matter',numel(l)+1))]; CM=CM(1:end-1,:);
    linewidth = linspace(0.5,2,numel(l));
else
    CM1 = cmocean('ice',numel(data)+4); CM1=CM1(3:end-2,:);
    CM2 = flipud(cmocean('matter',numel(data)+4)); CM2=CM2(3:end-2,:);
    CM = [CM1; CM2];
    linewidth = linspace(0.5,2,numel(data));
end

for ff=1:numel(data)
        data(ff).linewidthind = 2;%find(std_ua==data(ff).std_ua);
        data(ff).linestyleind = ff;%find(std_ua==data(ff).std_ua);
        data(ff).colorind = ff;%find(l==data(ff).l);
end

%% Variables (this will be the order in which variables are plotted)
Vars_to_plot = ["n","m","log(dhdt_err)","log10(gaA)","log10(gaC)","log10(gsA)","log10(gsC)"];
nmarginals = numel(Vars_to_plot);
%% Labels (same order as variables)
Labels = ["$n$","$m$","${\rm log}_{10}(\gamma_{\dot h})$","${\rm log}_{10}(\gamma_{aA})$",...
    "${\rm log}_{10}(\gamma_{aC})$","${\rm log}_{10}(\gamma_{sA})$","${\rm log}_{10}(\gamma_{sC})$"];
if contains(fname(1),"SYNTH_PIG")
    xTrue = [3,4,NaN,NaN,NaN,NaN,NaN];
end
SL = ["\mathcal{S}_{\rm pwr}","\mathcal{S}_{\rm hybr}"];

%% PLOT
H=fig('units','inches','width',120*12/72.27,'height',25*12/72.27,'fontsize',14,'font','Helvetica');

tlo_fig = tiledlayout(1,nmarginals,"TileSpacing","compact");
for i = 1:nmarginals
    ax_fig(i) = nexttile(tlo_fig,i); hold on;
end

for jj=1:nmarginals
    % marginal to plot:
    try
        Ind = find(strcmp({data(1).myPosteriorDist(1).dist.Marginals(:).Name},Vars_to_plot(jj)));
    catch
        Ind = find(strcmp({data(1).myPosteriorDist(2).dist.Marginals(:).Name},Vars_to_plot(jj)));
    end
    for ii=1:numel(data)
        ndiscrete = numel(data(ii).myPosteriorDist);
        for kk=1:ndiscrete
            if ~isempty(data(ii).myPosteriorDist(kk).dist)
                X = linspace(data(ii).myPosteriorDist(kk).dist.Marginals(Ind).Bounds(1),data(ii).myPosteriorDist(kk).dist.Marginals(Ind).Bounds(2),50);
                f = uq_all_pdf(X(:),data(ii).myPosteriorDist(kk).dist.Marginals(Ind))*data(ii).myPosteriorDist(kk).frac;
            else
                X = [nan nan];
                f = [nan nan];
            end
            if jj==1
                nn = (kk-1)*numel(data)+ii;
                g(nn) = plot(ax_fig(jj),X,f,linestyle(data(ii).linestyleind),'color',CM((kk-1)*numel(data)+data(ii).colorind,:),...
                    'LineWidth',linewidth(data(ii).linewidthind),'markersize',4);
                if nn==1
                    if numel(unique([data(:).endyear]))>1
                        label(nn) = "$({\mathcal S} = " + SL(kk) + ",\,\Delta t = t_1-t_0 = " +...
                            string(double(data(ii).endyear)-double(data(ii).startyear))+"\,{\rm years})$";
                    else
                        label(nn) = "$({\mathcal S} = " + SL(kk) + ",\, \ell=" + string(data(ii).l) + ",\, \sigma_{\eta}^2=" + string(data(ii).std_ua) + ")$";
                    end
                else
                    if numel(unique([data(:).endyear]))>1
                        label(nn) = "$(" + SL(kk) + ",\," + string(double(data(ii).endyear)-double(data(ii).startyear)) + "\,{\rm years})$";
                    else
                        label(nn) = "$(" + SL(kk) + "," + string(data(ii).l) + "," + string(data(ii).std_ua) + ")$";
                    end
                end
                fprintf("Plotting %s\n",data(ii).fname);
            %                        'LineWidth',linewidth(data(ii).linewidthind),'markersize',4);
            else
                plot(ax_fig(jj),X,f,linestyle(data(ii).linestyleind),'color',CM((kk-1)*numel(data)+data(ii).colorind,:),...
                                    'LineWidth',linewidth(data(ii).linewidthind),'markersize',4);
            end
        end
    end
    % plot prior
    IndPrior = find(strcmp({data(1).myPriorDist.Options.Marginals(:).Name},Vars_to_plot(jj)));
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
    prior=plot(ax_fig(jj),xPrior,Value,'--k','linewidth',1.5);
    % plot true value
    if contains(fname(1),"SYNTH_PIG")
        true=plot(ax_fig(jj),[xTrue(jj) xTrue(jj)],[-10 10],"-k","linewidth",1.5);
    end
    xlim(ax_fig(jj),xlim_tmp);
    ylim(ax_fig(jj),ylim_tmp);
end

for ii=1:nmarginals
    grid(ax_fig(ii),'on');
    box(ax_fig(ii),'on');
    yticklabels(ax_fig(ii),[]);
    xlabel(ax_fig(ii),Labels(ii),"Interpreter","latex");
    numcolumns = numel(g)/2;
    if ii==1
        if contains(fname(1),"SYNTH_PIG")
            leg=legend([g(1:numcolumns)';prior;g(numcolumns+1:2*numcolumns)';true],[label(1:numcolumns)';"${\rm prior}$";...
                label(numcolumns+1:2*numcolumns)';"${\rm true\, values}$"],...
                'Orientation','Horizontal','NumColumns',numcolumns+1,"Interpreter","latex");
        else
            leg=legend([g(:);prior],[label(:);"${\rm prior}$"],...
                'Orientation','Horizontal','NumColumns',numcolumns,"Interpreter","latex");
        end
        leg.Layout.Tile = 'north';
    end
end

pos = get(H,"Position");
set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
if contains(fname(1),"SYNTH_PIG")
    Hname = "./Figures/Aposterior_ErrorSensitivity_SYNTH_PIG";
elseif contains(fname(1),"AMUND")
    Hname = "./Figures/Aposterior_ErrorSensitivity_AMUND";
else
    error("Do not recognise case");
end
print(H,Hname,"-dpng","-r400");
