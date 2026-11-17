function plot_InverseResults_Ensemble
% plot_InverseResults_Ensemble  Plot a result of the inversions of the ensemble against the parameters.
%
% PURPOSE
%   Reads the inversion data of the ensemble (Calc_InverseResults_Ensemble) and plots, as a 7 x 7 matrix of scatter plots of
%   all pairs of the parameters (m, n, gaA, gaC, gsA, gsC, dhdt_err), the variable variable_to_plot of the selected inverse
%   cycle (UserVar.cycle) as the colour of the markers: 'misfit', 'qGL' (grounding line flux), 'qOB' (open boundary flux),
%   'niter' (number of iterations) or 'BalancedMelt'; the size of the markers decreases with the misfit. For
%   'BalancedMelt' the ensemble mean and standard deviation of the balanced melt rate are mapped. The figure is saved as
%   ./Figures/ParameterDistribution_<variable>.png and a histogram of the variable is made. Experiments are selected with
%   UserVar.idrange.
%
% FILES READ (data; can be obtained upon request from the author, see README)
%   the inversion data file(s) in file_with_inversion_data_to_read (variables data, inverse_experiments_analyzed, MUA, GF)
%
% REQUIRES
%   Ua source code (PlotGroundingLines); fig, othercolor, PlotNodalBasedQuantities_JDR (third party / modified Ua plotting
%   function, must be on the MATLAB path)

variable_to_plot = 'misfit'; %options: qGL, niter, misfit, qOB, BalancedMelt

slidinglaws = ["Weertman"];
file_with_inversion_data_to_read = "./InversionData/SYNTH_PIG/SYNTH_PIG_Weertman-yr30_inversiondata_"+slidinglaws+".mat";

%% load data
for nn=1:numel(file_with_inversion_data_to_read)
    if exist(file_with_inversion_data_to_read(nn),"file")
        tmp=load(file_with_inversion_data_to_read(nn));
        if nn==1
            data = tmp.data;
            inverse_experiments_analyzed = tmp.inverse_experiments_analyzed(:);
        else
            data = [data, tmp.data];
            inverse_experiments_analyzed = [inverse_experiments_analyzed; tmp.inverse_experiments_analyzed(:)];
        end
        MUA = tmp.MUA;
        GF = tmp.GF;
    else
        error(file_with_inversion_data_to_read(nn)+" does not exist");
    end
end

UserVar.type = "Inverse";
UserVar.cycle = 2;
UserVar.idrange = [10000 10999];

ExpID = [data(:).InverseExpID];
Ind = find(~ismember(ExpID,[UserVar.idrange(1):UserVar.idrange(end)]));
data(Ind)=[];

% define size for markers: resize with misfit
for ii=1:numel(data)
    if numel(data(ii).misfit)>=UserVar.cycle
        misfit(ii) = data(ii).misfit(UserVar.cycle);
        ind_finished(ii) = 1;%ismember(data(ii).niter(UserVar.cycle),[2000]);
    else
        misfit(ii) = nan;
        ind_finished(ii) = 0;
    end
end
misfit = misfit(:);
N = misfit-min(misfit,[],"omitmissing");
N = N./max(N,[],"omitmissing");
alphavalue = 1-N;
marker_size = 50*alphavalue(:)+eps;
plotdata = nan*misfit;

%% Plotting
switch variable_to_plot
    case 'qGL'
        for ii=find(ind_finished==1)
            plotdata(ii) = sum(data(ii).qGL(:,UserVar.cycle)');
        end
        cmin = 400;
        cmax = 500;
        cbLabel = "Grounding line flux [Gt/yr]";
    case 'qOB'
        for ii=find(ind_finished==1)
            plotdata(ii) = sum(data(ii).qOB(:,UserVar.cycle)'/1e12);
        end
        cmin = 1000;
        cmax = 3000;
        cbLabel = "Open Boundary flux [Gt/yr]";
    case 'niter'
        for ii=find(ind_finished==1)
            plotdata(ii) = data(ii).niter(:,UserVar.cycle)';
        end
        cmin = 0;
        cmax = max(niter(:));
        cbLabel = "Number of iterations";
    case 'misfit'
        for ii=find(ind_finished==1)
            plotdata(ii) = data(ii).misfit(:,UserVar.cycle)';
        end
        cmin = 0;%min(plotdata);
        cmax = 400;%max(plotdata)/100;
        cbLabel = "Misfit";
    case 'BalancedMelt'
        for ii=find(ind_finished==1)
            ab(ii,:) = data(ii).BalancedMeltMap(:,UserVar.cycle)';
            plotdata(ii) = -sum(data(ii).TotalBalancedMelt(:,UserVar.cycle)');
        end
        ab_av = mean(ab,1,"omitmissing");
        ab_std = std(ab,1,"omitmissing");
        cmin = 0;
        cmax = 2e5;
        cbLabel = "Balanced melt";

end

m = [data(:).m]; m = m(:);
n = [data(:).n]; n = n(:);
gaA = [data(:).gaA]; gaA = gaA(:);
gaC = [data(:).gaC]; gaC = gaC(:);
gsA = [data(:).gsA]; gsA = gsA(:);
gsC = [data(:).gsC]; gsC = gsC(:);
dhdt_err = [data(:).dhdt_err]; dhdt_err = dhdt_err(:);

if variable_to_plot == "BalancedMelt"

    H=fig('units','inches','width',120*12/72.27,'height',60*12/72.27,'fontsize',14,'font','Helvetica');

    tlo=tiledlayout(H,1,2,TileSpacing="none");

    xmin = min(MUA.coordinates(:,1)); xmax = max(MUA.coordinates(:,1));
    ymin = min(MUA.coordinates(:,2)); ymax = max(MUA.coordinates(:,2));
    CtrlVar.PlotXYscale = 1e3;

    %% ensemble-average change in balanced melt
    ax(1)=nexttile(tlo); hold on;
    ab_av(abs(ab_av)<eps)=nan;
    PlotNodalBasedQuantities_JDR(ax(1),MUA.connectivity,MUA.coordinates,ab_av(:),CtrlVar);
    plot(ax(1),MUA.Boundary.x/CtrlVar.PlotXYscale,MUA.Boundary.y/CtrlVar.PlotXYscale,'-k');
    PlotGroundingLines(CtrlVar,MUA,GF,[],[],[],'color','k','LineWidth',1);
    CM1 = othercolor('RdYlBu8',50);
    CM2 = othercolor('BuPu9',5);
    CM = [CM1;CM2];
    colormap(ax(1),CM);
    title(ax(1),"Balanced melt","Interpreter","none");
    axis(ax(1),"off");
    caxis(ax(1),[-50 5]);
    xlim(ax(1),[xmin xmax]/CtrlVar.PlotXYscale);
    ylim(ax(1),[ymin ymax]/CtrlVar.PlotXYscale);
    axis(ax(1),"equal");
    cb1=colorbar(ax(1)); cb1.Label.String="Ensemble mean balanced melt rate [m/yr]";

    %% standard deviation
    ax(2)=nexttile(tlo); hold on;
    PlotNodalBasedQuantities_JDR(ax(2),MUA.connectivity,MUA.coordinates,ab_std(:),CtrlVar);
    plot(ax(2),MUA.Boundary.x/CtrlVar.PlotXYscale,MUA.Boundary.y/CtrlVar.PlotXYscale,'-k');
    PlotGroundingLines(CtrlVar,MUA,GF,[],[],[],'color','k','LineWidth',1);
    colormap(ax(2),CM);
    title(ax(2),"Balanced melt","Interpreter","none");
    axis(ax(2),"off");
    caxis(ax(2),[-10 10]);
    xlim(ax(2),[xmin xmax]/CtrlVar.PlotXYscale);
    ylim(ax(2),[ymin ymax]/CtrlVar.PlotXYscale);
    axis(ax(2),"equal");
    cb=colorbar(ax(2)); cb.Label.String="Ensemble standard deviation of balanced melt [m/yr]";

end

H=fig('units','inches','width',120*12/72.27,'height',80*12/72.27,'fontsize',14,'font','Helvetica');

dummydata = nan*plotdata;

colormap('jet');

tlo_fig = tiledlayout(7,7,"TileSpacing","compact");
for i = 1:49
    ax_fig(i) = nexttile(tlo_fig,i); hold on;
end

ind = 1;
% row 1: m
s(ind)=scatter(ax_fig(ind),m,m,marker_size,dummydata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),"m"); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),n,m,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaA,m,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaC,m,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsA,m,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsC,m,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),dhdt_err,m,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;

% row 2: n
s(ind)=scatter(ax_fig(ind),m,n,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),"n"); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),n,n,marker_size,dummydata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaA,n,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaC,n,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsA,n,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsC,n,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),dhdt_err,n,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;

% row 3: gaA
s(ind)=scatter(ax_fig(ind),m,gaA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),"gaA"); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),n,gaA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaA,gaA,marker_size,dummydata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaC,gaA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsA,gaA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsC,gaA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),dhdt_err,gaA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;

% row 4: gaC
s(ind)=scatter(ax_fig(ind),m,gaC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),"gaC"); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),n,gaC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaA,gaC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaC,gaC,marker_size,dummydata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsA,gaC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsC,gaC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),dhdt_err,gaC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;

% row 5: gsA
s(ind)=scatter(ax_fig(ind),m,gsA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),"gsA"); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),n,gsA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaA,gsA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaC,gsA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsA,gsA,marker_size,dummydata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsC,gsA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),dhdt_err,gsA,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); xticklabels(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;

% row 6: gsC
s(ind)=scatter(ax_fig(ind),m,gsC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),"gsC"); xlabel(ax_fig(ind),"m");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),n,gsC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),"n"); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaA,gsC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaC,gsC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsA,gsC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsC,gsC,marker_size,dummydata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),dhdt_err,gsC,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),""); yticklabels(ax_fig(ind),"");
ind = ind+1;

% row 7: dhdt
s(ind)=scatter(ax_fig(ind),m,dhdt_err,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),"dhdt_err"); xlabel(ax_fig(ind),"m");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),n,dhdt_err,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),"n"); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaA,dhdt_err,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),"gaA"); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gaC,dhdt_err,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),"gaC"); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsA,dhdt_err,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),"gsA"); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),gsC,dhdt_err,marker_size,plotdata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),"gsC"); yticklabels(ax_fig(ind),"");
ind = ind+1;
s(ind)=scatter(ax_fig(ind),dhdt_err,dhdt_err,marker_size,dummydata,'filled','MarkerEdgeColor','none'); ylabel(ax_fig(ind),""); xlabel(ax_fig(ind),"dhdt_err"); yticklabels(ax_fig(ind),"");
ind = ind+1;

for i = 1:49
    grid(ax_fig(i),"on");
    box(ax_fig(i),"on");
    clim(ax_fig(i),[cmin cmax]);
end

cb=colorbar;
cb.Layout.Tile='east';
clim([cmin cmax]);
cb.Label.String = cbLabel;

for ii=1:numel(s)
    s(ii).AlphaData = alphavalue;
    s(ii).MarkerFaceAlpha='flat';
end

% Save
pos = get(H,"Position");
set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
fname = "./Figures/ParameterDistribution_"+variable_to_plot;
print(H,fname,"-dpng","-r400");

%% histogram
figure; hold on;
bins = linspace(min(plotdata),max(plotdata),20);
h1=histogram(plotdata,bins);
h2=histogram(plotdata(ind_finished==1),bins);
xlabel(cbLabel);
grid on; box on;
