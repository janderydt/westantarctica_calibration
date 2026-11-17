function HPD = calc_HPDsample(myPosteriorDist,N)
% calc_HPDsample  Sample from the 95% highest posterior density (HPD) region of a posterior distribution.
%
% PURPOSE
%   For each discrete class of the posterior (e.g. a sliding law) the posterior is given as a UQLab
%   distribution (marginals and copula). 1e5 Monte Carlo samples are drawn from it, sorted by their
%   probability density, and round(N*frac) samples are picked at random from the high-density samples
%   (frac = fraction of the N samples assigned to this class).
%
% INPUTS
%   myPosteriorDist : struct array (one element per discrete class) with fields
%                     .frac : fraction of the N samples for this class (0: none)
%                     .dist.Marginals(i).Name/Type/Parameters/Bounds and .dist.Copula : the posterior
%                      (UQLab input definition; result of the Bayesian inference, not part of this repository)
%   N               : total number of samples
%
% OUTPUT
%   HPD(k).sample   : round(N*frac) rows; first column is the value of the (continuous) sliding law variable of the
%                     inference, 1.25 + (k-1)*0.5: calc_BayesianInference_u rounds this variable to the sliding law index
%                     (1 = Weertman, 2 = Umbi), so class k=1 gives 1.25 (Weertman) and k=2 gives 1.75 (Umbi);
%                     then one column per marginal. Empty if frac=0.
%
% REQUIRES
%   UQLab (uqlab, uq_createInput, uq_selectInput, uq_getSample, uq_evalPDF); Statistics and Machine Learning
%   Toolbox (randsample). The random number generator is seeded (rng(1)).

rng(1,'twister'); % set the random number generator for reproducible results
uqlab; % initialize uqlab

ndist = numel(myPosteriorDist);

for ind_discrete = 1:ndist

    frac = myPosteriorDist(ind_discrete).frac;
    Input = [];

    if frac > 0

        % distributions
        for ii=1:numel(myPosteriorDist(ind_discrete).dist.Marginals)
            Input.Marginals(ii).Name = myPosteriorDist(ind_discrete).dist.Marginals(ii).Name;
            Input.Marginals(ii).Type = myPosteriorDist(ind_discrete).dist.Marginals(ii).Type;
            Input.Marginals(ii).Parameters = myPosteriorDist(ind_discrete).dist.Marginals(ii).Parameters;
            Input.Marginals(ii).Bounds = myPosteriorDist(ind_discrete).dist.Marginals(ii).Bounds;       
        end
        Input.Copula(1) = myPosteriorDist(ind_discrete).dist.Copula;  
        Input.Copula(1).Family=[];
        Input.Copula(1).Rotation=[];   

        myDist = uq_createInput(Input);

        Nsamples = 1e5;
        uq_selectInput(myDist);
        Xsamples = uq_getSample(Nsamples,'MC');
        f_samples = uq_evalPDF(Xsamples, myDist);
        
        % 1. Sort PDF values descending:
        [f_sorted, idx] = sort(f_samples, 'descend');
        X_sorted = Xsamples(idx,:);
        
        % 2. Compute cumulative probability
        % TODO: the samples are drawn from the distribution itself, so each sample has the same weight; here the
        % samples are weighted by their pdf value, which gives a smaller region than the 95% HPD region.
        % The 95% HPD region would be the first ceil(p*Nsamples) samples of the sorted list.
        cum_prob = cumsum(f_sorted) / sum(f_sorted);  % approximate cumulative probability
        
        % 3. Find PDF threshold for desired probability p (here e.g. 95%)
        p = 0.95;
        hpd_idx = find(cum_prob >= p, 1);

        % 4. randomly pick round(frac*N) samples from hpd
        idx_random = randsample(hpd_idx,round(N*frac));
        HPD(ind_discrete).sample = X_sorted(idx_random,:);

        % add a first column with the sliding law variable of the inference (rounded to the sliding law index there):
        % 1.25 (Weertman) for ind_discrete=1, 1.75 (Umbi) for ind_discrete=2 (not NaN)
        HPD(ind_discrete).sample = [ones(numel(idx_random),1)+0.25+(ind_discrete-1)*0.5 HPD(ind_discrete).sample];
    else
        HPD(ind_discrete).sample = [];
    end

end
