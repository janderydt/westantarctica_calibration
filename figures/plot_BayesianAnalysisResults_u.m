function plot_BayesianAnalysisResults_u(myBayesianAnalysis,UserVar)
% plot_BayesianAnalysisResults_u  Plot the result of a Bayesian analysis (Figures 3 and 6).
%
% PURPOSE
%   Called at the end of calc_BayesianInference_u (UserVar.do_plots=1) or without arguments (file selection window; one
%   or two analyses; saved in the file as UserVar and myBayesianAnalysis, with myPosteriorDist). For each analysis:
%   (1) the MCMC chains of all parameters (figure 'MCMC_Chains');
%   (2) the "corner plot" (figure 'Distributions', saved as ./Figures/Aposterior_<name>.png): marginal posterior
%       distributions (histograms of the last 10% of the chains, fitted marginals, prior, maximum a posteriori point
%       MAP) on the diagonal and scatter plots of pairs of parameters below it. For AMUND the Ua training samples
%       (ensemble members) and a sample of 10 points of the 95% highest posterior density region (calc_HPDsample; saved
%       in ./BayesianAnalysis/<domain>/ as X_HPD) are added; for SYNTH_PIG the true values (n = 3, m = 4);
%   (3) AMUND only, after a question dialog: the difference between modelled and observed change in speed for each
%       epoch, for user-chosen parameters (emulator) or the HPD sample (the mean of the nearest Ua simulations),
%       saved as ./Figures/Delta_u_Mod_vs_Meas_<name>_v<k>.png (inset of Figure 6).
%
% INPUTS
%   myBayesianAnalysis, UserVar : as saved by calc_BayesianInference_u (optional)
%
% REQUIRES
%   UQLab Rel. 2.0.0, calc_HPDsample (same folder), loadvelocitydata (same folder), cmocean, fig (third party),
%   PlotMeshScalarVariable, PlotGroundingLines (Ua); MATLAB Statistics and Machine Learning Toolbox (hist3,
%   knnsearch, isoutlier), Deep Learning Toolbox with the Converter for TensorFlow Models; data in ./DiagnosticData and
%   ./Emulators (see calc_BayesianInference_u)

gpuDevice([]);
setenv('CUDA_VISIBLE_DEVICES','');

%% initialize UQLAB
addpath(genpath(getenv("froot_matlabfunctions")+"/../UQLab_Rel2.0.0"));

rng(1,'twister'); % set the random number generator for reproducible results
uqlab; % initialize uqlab

if nargin==0
    [fname,location] = uigetfile("./BayesianAnalysis/","MultiSelect","on");
    fname=string(fname);
    if numel(fname)>2
        error("Can only plot 2 distributions");
    elseif numel(fname)==2
        fname = fname([2 1]);
    end
else
    location = UserVar.location;
    file = dir(UserVar.location+"/"+UserVar.fname);
    fname = {file.name};
end

%% Variables (this will be the order in which variables are plotted)
Vars = ["n","Sliding law","m","log(dhdt_err)","log10(gaA)","log10(gaC)","log10(gsA)","log10(gsC)"];
%% Labels (same order as variables)
Labels = ["$n$","$\mathcal{S}$","$m$","${\rm log}_{10}(\gamma_{\dot h})$","${\rm log}_{10}(\gamma_{aA})$",...
    "${\rm log}_{10}(\gamma_{aC})$","${\rm log}_{10}(\gamma_{sA})$","${\rm log}_{10}(\gamma_{sC})$"];

if contains(fname,"SYNTH_PIG")
    xTrue = [3,1.25,4,NaN,NaN,NaN,NaN,NaN];
end

for Dist=1:numel(fname)

    load(string(location)+"/"+string(fname{Dist}));

    mySolver = myBayesianAnalysis.Options.Solver;
    myPriorDist = myBayesianAnalysis.PriorDist;
    myResults = myBayesianAnalysis.Results;
    
    uq_print(myBayesianAnalysis);
    
    %% gather some data
    MAP=myBayesianAnalysis.Results.PostProc.PointEstimate.X{:};
    
    nDiscrete = 0; SSInd=[];

    for ii=1:numel(myPriorDist.Marginals)
    
        Prior(ii).Sample = [];
        for jj = 1:mySolver.MCMC.NChains
            Prior(ii).Sample = [Prior(ii).Sample; ...
                myResults.Sample(1,ii,jj)];
        end
    
        % Sample equilibrium distribution from Markov Chains; we use the final 
        % npct% of the Markov Chains, i.e. discard the first (100-npct)% as burn-in
        npct = 0.1;
        Post(ii).Sample = [];
        for jj = 1:mySolver.MCMC.NChains
            Post(ii).Sample = [Post(ii).Sample; ...
                myResults.Sample(mySolver.MCMC.Steps-round(npct*mySolver.MCMC.Steps):end,ii,jj)];
        end
        % subsample // 25e3 is a good amount to plot
        if isempty(SSInd) 
            if size(Post(ii).Sample,1)>25e3
                SSInd = randi([1 size(Post(ii).Sample,1)],[25e3 1]);
            else
                SSInd = 1:size(Post(ii).Sample,1);
            end
        end
        Post(ii).Sample = Post(ii).Sample(SSInd);
    
        % Calculate spread of sample, discarding outliers that are outside the
        % 1% and 99% percentiles. This is used for plotting purposes ONLY
        Outliers = isoutlier(Post(ii).Sample,"percentiles",[1 99]);
        Post(ii).Sample_NoOutliers = Post(ii).Sample;
        Post(ii).Sample_NoOutliers(find(Outliers))=[];
        Post(ii).min = min(Post(ii).Sample_NoOutliers);
        Post(ii).max = max(Post(ii).Sample_NoOutliers);
        dsample = Post(ii).max-Post(ii).min;
        Post(ii).min = max([Post(ii).min-0.4*dsample myPriorDist.Marginals(ii).Bounds(1)]);
        Post(ii).max = min([Post(ii).max+0.4*dsample myPriorDist.Marginals(ii).Bounds(2)]);
        Post(ii).Name = myPriorDist.Marginals(ii).Name;
        Post(ii).Label = Labels(ii);
    
        % Identify discrete variables
        if Post(ii).Name=="Cycle"
            D1 = "no spinup";
            D2 = "3yr spinup";
            Post(ii).isDiscrete = 1;
            nDiscrete = nDiscrete+1;
            Post(ii).min = 0;
            Post(ii).max = 1;
        elseif Post(ii).Name=="Sliding law"
            D1 = "${\mathcal S}_{\rm pwr}$";
            D2 = "${\mathcal S}_{\rm hybr}$";
            Post(ii).isDiscrete = 1;
            nDiscrete = nDiscrete+1;
            Post(ii).min = 1;
            Post(ii).max = 2;
        else
            Post(ii).isDiscrete = 0;
        end
    end
    
    %% MCMC CHAINS
    H = findall(0,'type','figure','name','MCMC_Chains');
    if isempty(H)
        H=fig('name','MCMC_Chains','units','inches','width',120*12/72.27,'height',40*12/72.27,'fontsize',14,'font','Helvetica');
        tlo_fig = tiledlayout(1,numel(myPriorDist.Marginals),"TileSpacing","compact");
        for ii = 1:numel(myPriorDist.Marginals)
            ax_fig(ii) = nexttile(tlo_fig,ii); hold on;
        end
    else
        tlo_fig = H.Children;
        ax_fig = tlo_fig.Children;
    end

    CMlight = [0.6 0.6 0.6;1 0.6 0.6];
    CMdark = [0 0 0;1 0 0];
       
    for ii = 1:numel(myPriorDist.Marginals)
    
        for jj = 1:mySolver.MCMC.NChains        
            plot(ax_fig(ii),myResults.Sample(:,ii,jj),'-','color',CMlight(Dist,:));
        end
        plot(ax_fig(ii),ones(mySolver.MCMC.NChains,1),squeeze(myResults.Sample(1,ii,:)),'.','color',CMdark(Dist,:),'markersize',10);
        if myPriorDist.Marginals(ii).Name == "Sliding law"
            yticks(ax_fig(ii),[1.25 1.75]);
            yticklabels(ax_fig(ii),["Weertman","Umbi"]);
            ytickangle(ax_fig(ii),90);
        elseif myPriorDist.Marginals(ii).Name == "Cycle"
            yticks(ax_fig(ii),[0.25 0.75]);
            yticklabels(ax_fig(ii),["1","2"]);
        end
        ylabel(ax_fig(ii),myPriorDist.Marginals(ii).Name);
        grid(ax_fig(ii),"on"); box(ax_fig(ii),"on");
    end
    
    
    %% DISTRIBUTIONS
    if nDiscrete <= 1
        CM(1).map = flipud(cmocean('rain',64));
        Bu = [linspace(0.5,1,16)' linspace(0.7,1,16)' ones(16,1)];
        Rd = [ones(16,1) linspace(1,0.7,16)' linspace(1,0.5,16)'];
        CM(2).map = [Bu;Rd];
        % end
    else
        error("Implement additional colormaps");
    end

    % decide on plotting order
    for vv=1:numel(Vars)
        Ind_DistToPlot(vv) = find(strcmp({Post(:).Name},Vars(vv)));     
    end
    
    H = findall(0,'type','figure','name','Distributions');
    if isempty(H)
        H=fig('name','Distributions','units','inches','width',120*12/72.27,'height',80*12/72.27,'fontsize',18,'font','Helvetica');
        tlo_fig = tiledlayout(numel(Post),numel(Post),"TileSpacing","compact");         
    else
        tlo_fig = H.Children;
    end
    for i = 1:numel(Post)^2
        ax_fig(i) = nexttile(tlo_fig,i); hold on;
    end 

    %% load Ua samples
    years_tmp = split(UserVar.years(end),"-");
    yr1 = years_tmp(1);
    yr2 = years_tmp(2);
    slidinglaw = UserVar.slidinglaw(1);
    try
        load("./DiagnosticData/"+UserVar.domain+"/"+UserVar.domain+"_Delta_u_"+yr1+"-"+yr2+"_"+slidinglaw+".mat");
    catch
        load("./DiagnosticData/"+UserVar.domain+"/"+UserVar.domain+"_Delta_u_"+yr1+"-"+yr2+".mat");
    end
    ndist = numel(myPosteriorDist);
    for ind_discrete = 1:ndist
        frac = myPosteriorDist(ind_discrete).frac;
        if frac > 0
            X_Ua(ind_discrete).sample = [log10(gaA(:)) log10(gaC(:)) log10(gsA(:)) log10(gsC(:)) m(:) n(:)];
            if UserVar.cycle(end)==2 % add dhdt_err to predictors
                X_Ua(ind_discrete).sample = [X_Ua(ind_discrete).sample log10(dhdt_err(:))];
            end
            % pad with NaNs for sliding law
            X_Ua(ind_discrete).sample = [ones(numel(gaA(:)),1)+0.25+(ind_discrete-1)*0.5 X_Ua(ind_discrete).sample];
        else
            X_Ua(ind_discrete).sample = [];
        end
    end    

    %% load HPD samples
    fname_HPD = strrep(fname,"BayesianAnalysis","HPD");
    if ~exist(fname_HPD,"file")
        X_HPD = calc_HPDsample(myPosteriorDist,10);
        % save to file
        save("./BayesianAnalysis/"+UserVar.domain+"/"+fname_HPD,"X_HPD");
    else
        load("./BayesianAnalysis/"+UserVar.domain+"/"+fname_HPD);
    end

    iycounter = 0;
    for iy=Ind_DistToPlot

        iycounter = iycounter + 1;
        ixcounter = 0;
    
        for ix=Ind_DistToPlot

            ixcounter = ixcounter+1;
            
            % only plot in lower triangle of tiled layout
            Ind = (iycounter-1)*numel(Post)+ixcounter;

            edges=[]; xmid=[]; ymid=[];
    
            if ix==iy
                % histograms Posterior Distributions
                if Post(ix).isDiscrete
                    edges = linspace(1,2,3);
                    xmid = 0.5*(edges(1:end-1)+edges(2:end));
                    dx = edges(2)-edges(1);
                    [n,~,~] = histcounts(Post(ix).Sample,edges,"Normalization","probability"); 
                    b(1)=bar(ax_fig(Ind),xmid(1),n(1)/dx);
                    b(1).FaceColor='flat';
                    b(1).CData = CM(2).map(1,:);
                    b(1).EdgeColor = [0.5 0.5 1];
                    b(1).BarWidth = 0.485;
                    b(2)=bar(ax_fig(Ind),xmid(2),n(2)/dx);
                    b(2).FaceColor='flat';
                    b(2).CData = CM(2).map(32,:);
                    b(2).EdgeColor = [1 0.5 0.5];
                    b(2).BarWidth = 0.485;
                    MAPx = 1.25+(round(MAP(ix))-1)*0.5;    
                else
                    edges = linspace(Post(ix).min,Post(ix).max,50);
                    xmid = 0.5*(edges(1:end-1)+edges(2:end));
                    dx = edges(2)-edges(1);
                    if nDiscrete == 0
                        [nhist,~,~] = histcounts(Post(ix).Sample,edges,"Normalization","probability"); 
                        b = bar(ax_fig(Ind),xmid,nhist/dx);   
                        b.FaceColor = CM(2).map(1,:);
                        b.BarWidth = 1;
                        b.EdgeColor = [0.5 0.5 1];
                        b.LineWidth = 0.5;
                        
                    elseif nDiscrete == 1
                        % split data into two parts
                        Ind1 = find(Post(1).Sample<1.5);
                        Ind2 = find(Post(1).Sample>=1.5);
                        [n1,~,~] = histcounts(Post(ix).Sample(Ind1),edges); 
                        [n2,~,~] = histcounts(Post(ix).Sample(Ind2),edges); 
                        b(1) = bar(ax_fig(Ind),xmid,n1(:)'/(dx*sum([n1,n2])));
                        b(2) = bar(ax_fig(Ind),xmid,n2(:)'/(dx*sum([n1,n2])));
                        b(1).FaceColor =  CM(2).map(1,:);
                        b(1).EdgeColor = [0.5 0.5 1];
                        b(1).LineWidth = 0.5; 
                        b(1).BarWidth = 1;
                        b(2).FaceColor = CM(2).map(32,:);
                        b(2).EdgeColor = [1 0.5 0.5];
                        b(2).LineWidth = 0.5; 
                        b(2).BarWidth = 1;
                    else
                        error("plotting so far only implemented for 1 discrete variable.");
                    end

                    if exist("myPosteriorDist","var")
                        for dd=1:numel(myPosteriorDist)
                            if isfield(myPosteriorDist(dd),"dist")
                                if ~isempty(myPosteriorDist(dd).dist)
                                    Indtmp = find(strcmp(Post(ix).Name,{myPosteriorDist(dd).dist.Marginals(:).Name}));
                                    X = linspace(myPosteriorDist(dd).dist.Marginals(Indtmp).Bounds(1),myPosteriorDist(dd).dist.Marginals(Indtmp).Bounds(2),1e3);
                                    f = uq_all_pdf(X(:),myPosteriorDist(dd).dist.Marginals(Indtmp));
                                    plot(ax_fig(Ind),X,f*myPosteriorDist(dd).frac,'-','color',[0.3 0.3 1]+(dd-1)*[0.7 0 -0.7],'linewidth',1.5);
                                end
                            end
                        end
                    end
                    MAPx = MAP(ix);        

                end  
                if Dist==1
                    Ymax_diag(ix) = 0;
                end
                for bb=1:numel(b)
                    Ymax_diag(ix) = max([Ymax_diag(ix) max(b(bb).YData)]);
                end
                % Prior Distributions
                Parameters = myPriorDist.Options.Marginals(ix).Parameters;
                Bounds = myPriorDist.Options.Marginals(ix).Bounds;
                switch myPriorDist.Options.Marginals(ix).Type
                    case "Gaussian"
                        xPrior = linspace(Bounds(1),Bounds(2),100);
                        Value = 1/(Parameters(2)*sqrt(2*pi))*exp(-0.5*((xPrior-Parameters(1))/Parameters(2)).^2);
                    case "Uniform"
                        Bounds = Parameters;
                        xPrior = linspace(Bounds(1),Bounds(2),100);
                        Value = 0*xPrior+1/(Parameters(2)-Parameters(1));                           
                end
                prior=plot(ax_fig(Ind),xPrior,Value,'--','color',[0 0 0],'linewidth',1.5);      
                
                % true values
                if contains(fname,"SYNTH_PIG")
                    plot(ax_fig(Ind),[xTrue(ixcounter) xTrue(ixcounter)],[0 2],'-k','linewidth',2);
                end
                % MAP
                plot(ax_fig(Ind),[MAPx MAPx],[0 10*Ymax_diag(ix)],':','Color',[0.5 0 1],'linewidth',2);

            elseif  (iycounter>ixcounter && Dist==1) || (iycounter<ixcounter && Dist==2)
                % scatter of data
                if Post(ix).isDiscrete
                    edges{2} = linspace(1,2,3);
                    MAPx = 1.25+(round(MAP(ix))-1)*0.5;
                else
                    edges{2} = linspace(Post(ix).min,Post(ix).max,50); % edges in second (x) dimension
                    MAPx = MAP(ix);
                end
                if Post(iy).isDiscrete
                    edges{1} = linspace(1,2,3);
                    MAPy = 1.25+(round(MAP(iy))-1)*0.5;
                else
                    edges{1} = linspace(Post(iy).min,Post(iy).max,50); % edges in second (x) dimension
                    MAPy = MAP(iy);
                end            
                xmid = 0.5*(edges{2}(1:end-1)+edges{2}(2:end));
                ymid = 0.5*(edges{1}(1:end-1)+edges{1}(2:end));
                [Xedge,Yedge] = ndgrid(edges{2},edges{1});
                if nDiscrete == 1
                    % split data into two parts
                    Ind1 = find(Post(1).Sample<=1.5);
                    Ind2 = find(Post(1).Sample>1.5);
                    nSample = numel(Post(1).Sample);
                    values1 = hist3([Post(iy).Sample(Ind1) Post(ix).Sample(Ind1)],'Edges',edges);
                    values2 = hist3([Post(iy).Sample(Ind2) Post(ix).Sample(Ind2)],'Edges',edges);
                    sum_values = sum([values1,values2],"all");
                    if Post(ix).isDiscrete
                        values1 = -values1/sum_values; 
                        values2 = values2/sum_values;
                        values1(values1==0)=nan; values2(values2==0)=nan;
                        pcolor(ax_fig(Ind),Xedge(:,2:end-1)+[0.01 0 -0.01]',Yedge(:,2:end-1),values1(2:end-1,:)'); shading(ax_fig(Ind),"flat");
                        pcolor(ax_fig(Ind),Xedge(:,2:end-1)+[0.01 0 -0.01]',Yedge(:,2:end-1),values2(2:end-1,:)'); shading(ax_fig(Ind),"flat");
                        colormap(ax_fig(Ind),CM(2).map);
                        caxis(ax_fig(Ind),[-0.05 0.05]);

                    elseif Post(iy).isDiscrete
                        values1 = -values1/sum_values; 
                        values2 = values2/sum_values;
                        values1(values1==0)=nan; values2(values2==0)=nan;
                        pcolor(ax_fig(Ind),Xedge(2:end-1,:),Yedge(2:end-1,:)+[0.01 0 -0.01],values1(:,2:end-1)'); shading(ax_fig(Ind),"flat");
                        pcolor(ax_fig(Ind),Xedge(2:end-1,:),Yedge(2:end-1,:)+[0.01 0 -0.01],values2(:,2:end-1)'); shading(ax_fig(Ind),"flat");
                        colormap(ax_fig(Ind),CM(2).map);
                        clim(ax_fig(Ind),[-0.05 0.05]);

                    else
                        Sample11 = Post(ix).Sample(Ind1); Sample12 = Post(iy).Sample(Ind1); n1 = round(0.5*nSample*sum(values1,"all")/sum_values);
                        Sample21 = Post(ix).Sample(Ind2); Sample22 = Post(iy).Sample(Ind2); n2 = round(0.5*nSample*sum(values2,"all")/sum_values);
                        if n1>0
                            scatter(ax_fig(Ind),Sample11(end-n1:end),Sample12(end-n1:end),12,...
                                "MarkerFaceColor",[0.5 0.7 1],"MarkerFaceAlpha",5e-2,'MarkerEdgeColor','none');
                        end
                        if n2>0
                            scatter(ax_fig(Ind),Sample21(end-n2:end),Sample22(end-n2:end),12,...
                                "MarkerFaceColor",[1 0.7 0.5],"MarkerFaceAlpha",5e-2,'MarkerEdgeColor','none');
                        end
                        R1_tmp = corrcoef(Sample11,Sample12); R1(Ind) = R1_tmp(1,2);
                        R2_tmp = corrcoef(Sample21,Sample22); R2(Ind) = R2_tmp(1,2);
                     end
                else
                    scatter(ax_fig(Ind),Post(ix).Sample(end-10000:end),Post(iy).Sample(end-10000:end),5,...
                        "MarkerFaceColor",[1 0.5 0.5],"MarkerFaceAlpha",0.2,'MarkerEdgeColor','none');
                end  

                if contains(fname,"AMUND")
                    for dd=1:numel(X_HPD)
                        if ~isempty(X_HPD(dd).sample)
                            xua = plot(ax_fig(Ind),X_Ua(dd).sample(:,ix),X_Ua(dd).sample(:,iy),'*','Color',[0.929 0.694 0.125],'MarkerFaceColor',[0.929 0.694 0.125],'MarkerSize',3);
                            xhpd = plot(ax_fig(Ind),X_HPD(dd).sample(:,ix),X_HPD(dd).sample(:,iy),'ok','MarkerFaceColor','k','MarkerSize',2);
                        end
                    end
                end
            else

                if numel(fname)==1
                    axis(ax_fig(Ind),'off');
                end
    
            end

            if Dist==1
                Xmin(ix,iy) = Post(ix).min;
                Xmax(ix,iy) = Post(ix).max;
                Ymin(ix,iy) = Post(iy).min;
                Ymax(ix,iy) = Post(iy).max;
            else
                Xmin(ix,iy) = min([Xmin(ix,iy) Post(ix).min]);
                Xmax(ix,iy) = max([Xmax(ix,iy) Post(ix).max]);
                Ymin(ix,iy) = min([Ymin(ix,iy) Post(iy).min]);
                Ymax(ix,iy) = max([Ymax(ix,iy) Post(iy).max]);
            end

            if Dist == numel(fname)

                xlim(ax_fig(Ind),[Xmin(ix,iy) Xmax(ix,iy)]);
                if ixcounter~=iycounter
                    ylim(ax_fig(Ind),[Ymin(ix,iy) Ymax(ix,iy)]);
                    tmp = yticks(ax_fig(Ind));
                    if numel(tmp)>4
                        yticks(ax_fig(Ind),linspace(min(tmp),max(tmp),4));
                    end
                else
                    ylim(ax_fig(Ind),[0 Ymax_diag(ix)+0.15*Ymax_diag(ix)]);
                end

                if ixcounter==1
                    if iycounter==1
                        ylabel(ax_fig(Ind),[]);
                        yticks(ax_fig(Ind),[]);
                        yticklabels(ax_fig(Ind),[]);
                    elseif Post(iy).isDiscrete
                        yticks(ax_fig(Ind),ymid);
                        yticklabels(ax_fig(Ind),[D1,D2]);
                        ax_fig(Ind).TickLabelInterpreter = 'latex';
                        ylabel(ax_fig(Ind),[],"interpreter","latex");
                    else
                        ylabel(ax_fig(Ind),Labels(iycounter),"interpreter","latex");
                    end
                else
                    yticklabels(ax_fig(Ind),[]);
                end
                if iycounter==numel(Post)
                    if Post(ix).isDiscrete
                        xticks(ax_fig(Ind),xmid);
                        xticklabels(ax_fig(Ind),[D1,D2]);
                        ax_fig(Ind).TickLabelInterpreter = 'latex';
                        xlabel(ax_fig(Ind),[]);
                    else
                        xlabel(ax_fig(Ind),Labels(ixcounter),"interpreter","latex");
                    end
                else
                    xticklabels(ax_fig(Ind),[]); 
                end
            end
            grid(ax_fig(Ind),'on'); box(ax_fig(Ind),'on');
        end
    end

    % legend
    Ind = numel(Post);
    map = plot(ax_fig(Ind),[-1e10 -1e10],[0 1],':','Color',[0.5 0 1],'linewidth',2);
    
    if contains(fname,"SYNTH_PIG")
        true=plot(ax_fig(Ind),[-1e10 -1e10],[0 1],'-k','linewidth',1.5);
        legend(ax_fig(Ind),[prior,b(1),true,map],["Prior","Posterior","True value","Maximum a posteriori"]);
    else
        legend(ax_fig(Ind),[prior,b(1),map,xua,xhpd],["Prior","Posterior","Maximum a posteriori","Úa training samples","95% credible region"]);
    end

    % correlations
    for nn=1:numel(R1)
        if R1(nn)~=0
            pos = get(ax_fig(nn), 'position'); %[x,y,w,h]
            annotation('textbox',[pos(1)+0.65*pos(3),pos(2)+0.78*pos(4),0.3*pos(3),0.2*pos(4)],'string',...
                "("+sprintf('%3.2f',R1(nn))+"; "+sprintf('%3.2f',R2(nn))+")",...  
                'FitBoxToText','on','VerticalAlignment','middle','HorizontalAlignment','center',...
                'FontSize',9,'EdgeColor','none');
        end
    end

    pos = get(H,"Position");
    set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
    Hname = "./Figures/Aposterior_"+erase(UserVar.fname,".mat");
    Hname = replace(Hname,"Weertman","W");
    Hname = replace(Hname,"Umbi","U");
    print(H,Hname,"-dpng","-r400");

    %% SELECTED SAMPLES
    if contains(UserVar.domain,"AMUND")

        %% Sample choice: 1 = user values, 0 = HPD samples
        answer = questdlg('What would you like to plot?', ...
            'User input',...
	        'User parameter choice','HPD samples','Nothing','Nothing');
        
        if answer == "User parameter choice"

                prompt = {'Sliding Law:','log10(gaA):','log10(gaC):','log10(gsA):','log10(gsC):','m','n','log10(dhdt_err)'};
                dlgtitle = 'Input';
                fieldsize = [ones(numel(prompt),1) 45*ones(numel(prompt),1)];
                definput = {'1.25 (W) or 1.75 (U)','[-1...1.7]','[-1...1.7]','[3...6]','[3...6]','[2...9]','[2...5]','[-1.3...-0.3]'};
                Sample = inputdlg(prompt,dlgtitle,fieldsize,definput); 
                Sample = str2double(Sample);

        end
                     
        if answer ~= "Nothing"

            H=fig('units','inches','width',40*12/72.27,'height',50*12/72.27,'fontsize',14,'font','Helvetica');   
            tlo = tiledlayout(2,2,"TileSpacing","tight");
    
            tmp_grids = load("./DiagnosticData/AMUND/AMUND_perturbation_grids.mat");
    
            for yy=1:numel(UserVar.years)
    
                tmp = load("./DiagnosticData/AMUND/AMUND_Delta_u_"+UserVar.years(yy)+"_HPDSample.mat");
    
                %% OBS
                out = LoadVel(UserVar.domain,UserVar.dataformat(yy),UserVar.years(yy),0);
                years_tmp = split(UserVar.years(yy),"-");
                yr1 = years_tmp(1);
                yr2 = years_tmp(2);
                Delta_u_OBS = out.("yr"+yr1+"_yr"+yr2).du;
    
                if answer == "User parameter choice"
    
                    %% USER CHOICE
    
                    TF_dir = dir("./Emulators/"+UserVar.domain+"/RNN/TF_files/"+UserVar.modelversion+"_"+UserVar.domain+"_"+UserVar.perturbation+"_"+UserVar.years(yy)+...
                        "_"+join(UserVar.slidinglaw(yy,:),"-")+"_cycle"+string(UserVar.cycle(yy))+"_floatingice"+string(1-UserVar.only_grounded_ice(yy))+...
                        "_includemeasurements0_*Comp"+string(UserVar.SVDcomponents(yy))+"*");
    
                    if contains(TF_dir.name,".keras")
                        % Import TensorFlow
                        py.keras.device('/cpu:0');
                        Net =  py.keras.models.load_model(TF_dir.folder+"/"+TF_dir.name, compile=false);
                    else
                        Net_tmp=importNetworkFromTensorFlow(TF_dir.folder+"/"+TF_dir.name);
                        Net=initialize(Net_tmp);
                    end
    
                    data_file = dir("./Emulators/"+UserVar.domain+"/RNN/mat_files/data_"+UserVar.domain+"_"+UserVar.perturbation+"_"+UserVar.years(yy)+...
                        "_"+join(UserVar.slidinglaw(yy,:),"-")+"_cycle"+string(UserVar.cycle(yy))+"_floatingice"+string(1-UserVar.only_grounded_ice(yy))+...
                        "_includemeasurements0"+"_*Comp"+string(UserVar.SVDcomponents(yy))+"*.mat");
                    load(data_file.folder+"/"+data_file.name,"X_train_C","X_train_S","T_train_C","T_train_S");
                
                    SVD_file = dir("./Emulators/"+UserVar.domain+"/RNN/mat_files/SVD_"+UserVar.domain+"_"+UserVar.perturbation+"_"+UserVar.years(yy)+...
                        "_"+join(UserVar.slidinglaw(yy,:),"-")+"_cycle"+string(UserVar.cycle(yy))+"_floatingice"+string(1-UserVar.only_grounded_ice(yy))+...
                        "_includemeasurements0"+"_*Comp"+string(UserVar.SVDcomponents(yy))+"*.mat");
                    load(SVD_file.folder+"/"+SVD_file.name,"T_reproj","T_mean","B_trunc");
                    % -- apply normalization to parameters before feeding into emulator
                    predictors = (Sample(:)'-X_train_C)./X_train_S;
            
                    % -- evaluate emulator 
                    if contains(TF_dir.name,".keras")
                        predictors = single(predictors);
                        if isvector(predictors)
                            predictors = reshape(predictors, 1 ,[]);
                            predictors = {predictors};
                        end
                        np = py.importlib.import_module('numpy');
                        predictors_np = np.array(predictors);  % shape: [batch_size, input_dim]
                        modelRun = double(Net.call(predictors_np, pyargs('training', false)));
                    else
                        modelRun = double(predict(Net,predictors)); 
                    end
                    % -- Undo normalization of the output and project to nodal basis
                    modelRun = modelRun.*T_train_S+T_train_C;
                    Delta_u_SAMPLE = modelRun*B_trunc+T_mean;
                    if Sample(1)==1.25
                        Sample1="{\mathcal S}_{\rm pwr}";
                    else
                        Sample1="{\mathcal S}_{\rm hybr}";
                    end
                    titlestring = ["$n="+sprintf("%2.1f",double(Sample(7)))+...
                        ",\;\mathcal{S}="+Sample1+...
                        ",\;m="+sprintf("%2.2f",double(Sample(6)))+...
                        ",\;\log_{10}(\gamma_{\dot h})="+sprintf("%2.1f",double(Sample(8)))+",$";
                        "$\log_{10}(\gamma_{aA})="+sprintf("%2.1f",double(Sample(2)))+...
                        ",\;\log_{10}(\gamma_{aC})="+sprintf("%2.1f",double(Sample(3)))+...
                        ",\;\log_{10}(\gamma_{sA})="+sprintf("%2.1f",double(Sample(4)))+...
                        ",\;\log_{10}(\gamma_{sC})="+sprintf("%2.1f",double(Sample(5)))+"$"];
    
                elseif answer == "HPD samples"
    
                    %% HPD
                    % compare the changes in flow speed, averaged over the 10 random 
                    % samples in the 95% credible region, to the observed changes for each
                    % of the different epochs (2000-2009, 2000-2014, 2000-2020).
                    
                    X_HPD_sim = [log10(tmp.gaA(:)) log10(tmp.gaC(:)) log10(tmp.gsA(:)) log10(tmp.gsC(:)) tmp.m(:) tmp.n(:)];
                    X_HPD_full = [X_HPD(1).sample;X_HPD(2).sample];
                    [Ind_sim,D] = knnsearch(X_HPD_sim,X_HPD_full(:,[2:7]));
                    if all(D<0.01)
                        Delta_u_SAMPLE = mean(tmp.Delta_u.Calv_dh.map(Ind_sim,:,2),1); 
                    else
                        warning("No HPD samples available for "+UserVar.years(yy));
                        Delta_u_SAMPLE = NaN*Delta_u_OBS;
                    end
                    titlestring = "HPD Sample";              
    
                end

                nexttile; 
                if yy==3
                    axis off;
                    nexttile;
                end
                Delta_u_SAMPLE(tmp.GF_yr2.node<0.5)=nan;
                PlotMeshScalarVariable([],tmp.MUA_yr2,Delta_u_SAMPLE(:)-Delta_u_OBS(:)); hold on;
                colormap(cmocean('balance',32));
                caxis([-500 500]);
        
                CtrlVar.PlotGLs = 0;
                CtrlVar.PlotXYscale = 1;
                [xGL,yGL]=PlotGroundingLines(CtrlVar,tmp_grids.("MUA_"+yr2),tmp_grids.("GF_"+yr2),[],[],[],'-k','linewidth',1);
                plot(xGL,yGL,'-k','linewidth',1)
                plot(tmp_grids.("MUA_"+yr2).Boundary.x,tmp_grids.("MUA_"+yr2).Boundary.y,'-','color',[0.5 0.5 0.5],'linewidth',0.5);
                axis equal; axis off;
                xlim([-1749160 -1278660]); ylim([-748745 -82125]);
                title(UserVar.years(yy));
                colorbar("off");
    

            end
            
            cb = colorbar;
            cb.Label.String = "$\Delta u_{\rm mod} - \Delta u_{\rm meas}\;{\rm [m/yr]}$";
            cb.Label.Interpreter = "Latex";
            cb.FontSize = 14;
            cb.Layout.Tile = "East";
    
            pos = get(H,"Position");
            set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
            Hname_tmp = "./Figures/Delta_u_Mod_vs_Meas_"+erase(UserVar.fname,".mat");
            Hname_tmp = replace(Hname_tmp,"Weertman","W");
            Hname_tmp = replace(Hname_tmp,"Umbi","U");
            vv=1;
            Hname = Hname_tmp+"_v"+string(vv); 
    
            while exist(Hname+".png","file")
                vv=vv+1;
                Hname = Hname_tmp+"_v"+string(vv);
            end
            
            print(H,Hname,"-dpng","-r400");

        end

    end

    clearvars UserVar myBayesianAnalysis myPosteriorDist MAP Prior Post myPriorDist mySolver myResults
end

end

function out = LoadVel(domain,dataformat,years,only_grounded_ice)
% interface of loadvelocitydata (struct input)
UserVar.domain = domain;
UserVar.dataformat = dataformat;
UserVar.years = years;
UserVar.only_grounded_ice = only_grounded_ice;
out = loadvelocitydata(UserVar);
end
