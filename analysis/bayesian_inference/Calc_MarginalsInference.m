function Calc_MarginalsInference(location,fname)
% Calc_MarginalsInference  Fit the posterior distribution (marginals and copula) to the MCMC sample.
%
% PURPOSE
%   Reads the result of a Bayesian analysis (UQLab, see calc_BayesianInference_u), takes the last 10% of the steps
%   of all Markov chains as a sample of the posterior (at most 25e3 randomly selected points), and fits kernel-
%   smoothing marginals (type 'KS', bounds of the prior) and an automatically selected copula (UQLab inference).
%   A discrete variable (the sliding law "Sliding law", or "Cycle"; a continuous variable in [1 2] in the
%   inference, split at 1.5) splits the sample into classes, each with its own distribution; frac is the
%   fraction of the sample in the class. The result is added to the same file.
%
% INPUTS
%   location, fname : folder and file name(s) of the Bayesian analysis (.mat, with myBayesianAnalysis). Without
%                     arguments a file selection window opens.
%
% OUTPUT
%   myPosteriorDist(k).dist (UQLab input object), .frac : appended to the file (save ... -append); input of
%   calc_HPDsample
%
% REQUIRES
%   UQLab Rel. 2.0.0 (path via the environment variable "froot_matlabfunctions"), Klear (UaSource)

if nargin==0    
    Klear;
    
    %% initialize UQLAB
    addpath(genpath(getenv("froot_matlabfunctions")+"/../UQLab_Rel2.0.0"));
    rng(1,'twister'); % set the random number generator for reproducible results
    uqlab; % initialize uqlab
    %% load sample from existing Bayesian Analysis
    [fname,location] = uigetfile("./BayesianAnalysis/*.mat","MultiSelect","on");
end

fname = string(fname);

addpath("./BayesianAnalysis/");

for ff=1:numel(fname)

    load(location+"/"+fname(ff));
    

        mySolver = myBayesianAnalysis.Options.Solver;
        myPriorDist = myBayesianAnalysis.PriorDist;
        myResults = myBayesianAnalysis.Results;
        isdiscrete = 0;
        % TODO: discr, iOpts and MarginalIndex_discrete are not cleared between files of the loop (see the
        % clear statement at the end), which matters when files with and without a discrete variable are mixed

        SSInd=[];
        for ii=1:numel(myPriorDist.Marginals)
            Sample_tmp = []; 
            % Sample equilibrium distribution from Markov Chains; we use the final 
            % fraction npct of the Markov Chains (npct=0.1: the last 10% of the steps), i.e. discard the
            % rest as burn-in
            npct = 0.1;
            for jj = 1:mySolver.MCMC.NChains
                Sample_tmp = [Sample_tmp; ...
                    myResults.Sample(mySolver.MCMC.Steps-round(npct*mySolver.MCMC.Steps):end,ii,jj)];
            end
            % subsample // 25e3 is about the maximum number we can
            % computationally afford
            if isempty(SSInd) 
                if size(Sample_tmp,1)>25e3
                    SSInd = randi([1 size(Sample_tmp,1)],[25e3 1]);
                else
                    SSInd = 1:size(Sample_tmp,1);
                end
            end
            X(:,ii) = Sample_tmp(SSInd);    
            if ismember(myPriorDist.Marginals(ii).Name,["Cycle","Sliding law"])
                discr(1).ind = find(X(:,ii)<1.5);
                discr(2).ind = find(X(:,ii)>=1.5);
                isdiscrete = 1;
                MarginalIndex_discrete = ii;
            end
        end
        if exist("MarginalIndex_discrete",'var')
            X(:,MarginalIndex_discrete)=[];
        end

        %% For discrete variables, split distributions
        if isdiscrete
            for ii=1:numel(discr)
                for jj=1:size(X,2)
                    discr(ii).X(:,jj) = X(discr(ii).ind,jj);
                end
            end
        end

        %% Calculate marginals/copulas fully automated
        if isdiscrete
            for ii=1:numel(discr)
                % discrete set ii
                iOpts(ii).Inference.Data = discr(ii).X;
                iOpts(ii).Copula.Type = 'auto';
                itmp = 1:numel(myPriorDist.Marginals);
                itmp(itmp==MarginalIndex_discrete)=[];
                for jj=1:numel(itmp)
                    iOpts(ii).Marginals(jj).Name = myPriorDist.Marginals(itmp(jj)).Name;
                    iOpts(ii).Marginals(jj).Type = 'KS';
                    %    0 myPriorDist.Marginals(ii).Bounds(2)-myPriorDist.Marginals(ii).Bounds(1)]; % bounds for mean and std of gaussians
                    iOpts(ii).Marginals(jj).Bounds = [myPriorDist.Marginals(itmp(jj)).Bounds];
                end            
                if ~isempty(discr(ii).X)
                    myPosteriorDist(ii).frac = numel(discr(ii).ind)/size(X,1);
                    fprintf("Calling uq_createInput for discrete set %d: nMarginals=%d, nSamples=%d\n", ...
                        ii, numel(iOpts(ii).Marginals), size(discr(ii).X,1));
                    fprintf("Copula type: %s\n", iOpts(ii).Copula.Type);
                    for jj=1:numel(iOpts(ii).Marginals)
                        fprintf("  Marginal %d: Name=%s, Type=%s, Bounds=[%.4g %.4g]\n", ...
                            jj, iOpts(ii).Marginals(jj).Name, iOpts(ii).Marginals(jj).Type, ...
                            iOpts(ii).Marginals(jj).Bounds(1), iOpts(ii).Marginals(jj).Bounds(2));
                    end
                    myPosteriorDist(ii).dist = uq_createInput(iOpts(ii));
                else
                    myPosteriorDist(ii).dist = [];
                    myPosteriorDist(ii).frac = 0;
                end
            end

        else
            iOpts.Inference.Data = X;
            if numel(myPriorDist.Marginals) > 1
                iOpts.Copula.Type = 'auto';
            end
            for ii=1:numel(myPriorDist.Marginals)
                iOpts.Marginals(ii).Name = myPriorDist.Marginals(ii).Name;
                iOpts.Marginals(ii).Type = 'KS';
                iOpts.Marginals(ii).Inference.ParamBounds.bimodalgaussian = ...
                    [0 1;myPriorDist.Marginals(ii).Bounds;myPriorDist.Marginals(ii).Bounds;...
                    0 myPriorDist.Marginals(ii).Bounds(2)-myPriorDist.Marginals(ii).Bounds(1)]; % bounds for mean and std of gaussians
                iOpts.Marginals(ii).Bounds = myPriorDist.Marginals(ii).Bounds;
            end            
            myPosteriorDist.dist = uq_createInput(iOpts);     
            myPosteriorDist.frac = 1;
        end

        save(location+"/"+fname(ff),"myPosteriorDist","-append");  

    clear myBayesianAnalysis UserVar myPosteriorDist X f

end
