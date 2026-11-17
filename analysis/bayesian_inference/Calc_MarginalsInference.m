function Calc_MarginalsInference(location,fname)
% Calc_MarginalsInference  Fit the posterior distribution (marginals and copula) to the MCMC sample.
%
% PURPOSE
%   Reads the result of a Bayesian analysis (UQLab, see Calc_BayesianInference), takes the last 10% of the steps
%   of all Markov chains as a sample of the posterior (at most 25e3 randomly selected points), and fits kernel-
%   smoothing marginals (type 'KS', bounds of the prior) and an automatically selected copula (UQLab inference).
%   A discrete variable (the sliding law "Sliding law", or "Cycle"; a continuous variable in [1 2] in the
%   inference, split at 1.5) splits the sample into two classes, each with its own distribution; frac is the
%   fraction of the sample in the class. If the fit fails because there are too few points in a class ("GoF is not
%   finite"), the distribution of that class is left empty (frac = 0). The result is added to the same file.
%
% INPUTS
%   location, fname : folder and file name(s) of the Bayesian analysis (.mat, with myBayesianAnalysis). Without
%                     arguments a file selection window opens.
%
% OUTPUT
%   myPosteriorDist(k).dist (UQLab input object), .frac : appended to the file (save ... -append); input of
%   Calc_HPDsample
%
% REQUIRES
%   UQLab Rel. 2.0.0 (must be on the MATLAB path), Klear (Ua); the folder ./BayesianAnalysis/ has to be on the
%   MATLAB path

if nargin==0
    Klear;

    %% initialize UQLAB
    rng(1,'twister'); % set the random number generator for reproducible results
    uqlab; % initialize uqlab
    %% load sample from existing Bayesian Analysis
    [fname,location] = uigetfile("./BayesianAnalysis/*.mat","MultiSelect","on");
end

fname = string(fname);

for ff=1:numel(fname)

    load(location+"/"+fname(ff));

        mySolver = myBayesianAnalysis.Options.Solver;
        myPriorDist = myBayesianAnalysis.PriorDist;
        myResults = myBayesianAnalysis.Results;
        isdiscrete = 0;

        SSInd=[];
        for ii=1:numel(myPriorDist.Marginals)
            Sample_tmp = [];
            % Sample equilibrium distribution from Markov Chains; we use the final
            % npct% of the Markov Chains, i.e. discard the first (100-ncpt)% as burn-in
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
                I_discr1 = find(X(:,ii)<1.5);
                I_discr2 = find(X(:,ii)>=1.5);
                isdiscrete = 1;
                MarginalIndex_discrete = ii;
            end
        end
        X(:,MarginalIndex_discrete)=[];

        %% For discrete variables, split distributions
        X1=[]; X2=[];
        if isdiscrete
            for ii=1:size(X,2)
                X1(:,ii) = X(I_discr1,ii);
                X2(:,ii) = X(I_discr2,ii);
            end
        end

        %% Calculate marginals/copulas fully automated
        iOpts1=[]; iOpts2=[];
        if isdiscrete
            % discrete set 1
            iOpts1.Inference.Data = X1;
            iOpts1.Copula.Type = 'auto';
            itmp = 1:numel(myPriorDist.Marginals);
            itmp(itmp==MarginalIndex_discrete)=[];
            for ii=1:numel(itmp)
                iOpts1.Marginals(ii).Name = myPriorDist.Marginals(itmp(ii)).Name;
                iOpts1.Marginals(ii).Type = 'KS';
                iOpts1.Marginals(ii).Bounds = [myPriorDist.Marginals(itmp(ii)).Bounds];
            end
            if ~isempty(X1)
                myPosteriorDist(1).frac = numel(I_discr1)/size(X,1);
                try
                    myPosteriorDist(1).dist = uq_createInput(iOpts1);
                catch ME
                    if (strcmp(ME.identifier,'GoF is not finite'))
                        msg = "GoF is not finite. Suspect not enough samples to define marginals and copulas. "+...
                            "Fraction of sample points = "+string(myPosteriorDist(1).frac)+". Setting empty posterior distributions.\n";
                        fprintf(msg);
                        myPosteriorDist(1).dist = [];
                        myPosteriorDist(1).frac = 0;
                    end
                end
            else
                myPosteriorDist(1).dist = [];
                myPosteriorDist(1).frac = 0;
            end
            %  discrete set 2
            iOpts2.Inference.Data = X2;
            iOpts2.Copula.Type = 'auto';
            for ii=1:numel(itmp)
                iOpts2.Marginals(ii).Name = myPriorDist.Marginals(itmp(ii)).Name;
                iOpts2.Marginals(ii).Type = 'KS';
                iOpts2.Marginals(ii).Bounds = myPriorDist.Marginals(itmp(ii)).Bounds;
            end
            if ~isempty(X2)
                myPosteriorDist(2).frac = numel(I_discr2)/size(X,1);
                try
                    myPosteriorDist(2).dist = uq_createInput(iOpts2);
                catch ME
                    if (strcmp(ME.identifier,'GoF is not finite'))
                        msg = "GoF is not finite. Suspect not enough samples to define marginals and copulas. "+...
                            "Fraction of sample points = "+string(myPosteriorDist(2).frac)+". Setting empty posterior distributions.\n";
                        fprintf(msg);
                        myPosteriorDist(2).dist = [];
                        myPosteriorDist(2).frac = 0;
                    end
                end
            else
                myPosteriorDist(2).dist = [];
                myPosteriorDist(2).frac = 0;
            end
        else
            iOpts.Inference.Data = X;
            iOpts.Copula.Type = 'auto';
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
