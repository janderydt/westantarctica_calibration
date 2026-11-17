function GenerateSampleSpace_Inverse
%GENERATESAMPLESPACE_INVERSE Build a prior sample space for GLUE
%inverse simulations and write out the corresponding run table.
%
%   GenerateSampleSpace_Inverse() takes no input arguments and
%   returns no outputs. All configuration is set via the hard-coded
%   variables at the top of this function (Domain, GradientCalc,
%   SlidingLaw, SampleSize, etc.) - edit those directly to change what
%   is generated.
%
%   WHAT THIS FUNCTION DOES:
%   1. Defines a UQLab prior (PriorOpts): a set of independent marginal
%      distributions, one per calibration/regularization parameter,
%      each with an explicit .Type (all 'Uniform' as configured),
%      .Parameters, and .Bounds.
%   2. Draws a sample from that prior using either Latin Hypercube
%      Sampling (LHS) or a Sobol sequence.
%   3. For parameters that are naturally spaced on a log scale
%      (gsC, gsA, gaC, gaA), sampling is done directly in log10 space
%      (uniform sampling design; the truncated Gaussians informed by an L-curve
%      analysis, noted at each parameter, are the priors used in the Bayesian
%      inference, see Calc_BayesianInference) and the result
%      is transformed back to physical units afterwards.
%   4. Optionally enriches an existing LHS design with extra points
%      (only supported for SamplingMethod = 'LHS').
%   5. Saves the UQLab Input object and the resulting sample table (T)
%      to a .mat file for reproducibility/bookkeeping.
%   6. Calls GenerateRunTable_Inverse to turn the sample table into
%      a run table (one row per simulation to be submitted).
%
%   GradientCalc is "Adjoint": full continuous UQLab sampling of 7 parameters
%   (gsC, gsA, gaC, gaA, dhdt_err, m, n).
%
%   OUTPUTS ON DISK:
%   - "./UQ_input_<Domain>_GradientCalc_<GradientCalc>_SlidingLaw_
%     <SlidingLaw>_SampleSize_<SampleSize>_Enrich_<Enrich>.mat"
%     containing the UQLab Input object (myInput) and the sample table
%     (T).
%   - A run table CSV (and chunked CSVs), written by
%     GenerateRunTable_Inverse - see that function's help for
%     details.
%
%   REQUIRES (not part of this repository, see README):
%   - UQLab Rel. 2.0.0 (https://www.uqlab.com; free registration), which
%     must be on the MATLAB path
%   - GenerateRunTable_Inverse (same folder) and ReadWritetable (ua_input/run),
%     and EmptyTable.csv (provided in this folder)
%
%   See also GENERATERUNTABLE_INVERSE, UQ_CREATEINPUT,
%   UQ_GETSAMPLE, UQ_ENRICHLHS.


clearvars;
rng(1,'twister'); % Seed for reproducibility. Only affects LHS; Sobol
                   % sequences from uq_getSample are deterministic
                   % regardless of the RNG state.
uqlab; % Initialize the UQLab framework (must be called before any
       % uq_* function is used).

%% -------------------- %%
%% USER CONFIGURATION   %%
%% -------------------- %%
Domain = "AMUND_nsmbl";              % Model domain/mesh identifier; must match
                                     % a case handled in GenerateRunTable_Inverse.
GradientCalc = "Adjoint";            % only "Adjoint" is supported.
SlidingLaw = "Weertman";              % Sliding law tag passed straight through to
                                     % the run table (e.g. Weertman, Umbi).
SampleSize = 300;                    % Number of samples to draw from the Input
Enrich = 0;                          % 0/1: if 1, add EnrichSampleSize extra
                                     % points to an existing LHS design instead
                                     % of drawing a fresh sample. Only used to
                                     % pass through to GenerateRunTable_Inverse
                                     % (affects the output CSV filename) and to
                                     % gate the uq_enrichLHS call below.
EnrichSampleSize = 180;              % Number of extra points added when Enrich=1.
UseCatalogueOfFinishedSimulations=0; % 0/1: passed through to
                                     % GenerateRunTable_Inverse; if 1, start
                                     % values for new inversions are looked up
                                     % from a catalogue of already-finished runs
                                     % (nearest neighbour in parameter space)
                                     % instead of being left unset.
SamplingMethod = 'Sobol';            % 'LHS' or 'Sobol'. Note: uq_enrichLHS below
                                     % only supports 'LHS'; enrichment with
                                     % 'Sobol' will raise an error.

PriorOpts.Name = 'Parameter array for inverse simulations'; % UQLab prior model name.
ind = 1; % Running index into PriorOpts.Marginals, incremented manually
         % after each variable is defined (both branches below).

%% -------------------- %%
%% CONTINUOUS VARIABLES %%
%% -------------------- %%
% Table column order/names for the sample matrix X, shared by both
% branches below so the downstream array2table call (after the switch)
% doesn't need to know which branch produced X.
TableVarNames = {'gsC','gsA','gaC','gaA','dhdt_err','m','n'};

switch GradientCalc
    case "Adjoint"
        % Regularization parameters (gsC, gsA, gaC, gaA) are specified
        % directly in log10 space with a Uniform sampling design over plausible
        % ranges; .Bounds repeats the range. The priors used in the Bayesian
        % inference (Calc_BayesianInference) are truncated Gaussians in log10
        % space with the mean informed by an L-curve analysis and the std chosen
        % such that mean +/- 1 (in log10 space) captures ~95% of the probability
        % mass; the values are noted at each parameter below.

        %% Regularization: gsC, gsA (spatial length scales, log10(metres))
        % prior in the Bayesian inference: Gaussian, mean 4.3, std 0.51, bounds [3 6]
        PriorOpts.Marginals(ind).Name = 'log10(gsC)';
        PriorOpts.Marginals(ind).Type = 'Uniform';
        PriorOpts.Marginals(ind).Parameters = [3 6];
        PriorOpts.Marginals(ind).Bounds = [3 6];
        ind = ind+1;

        PriorOpts.Marginals(ind).Name = 'log10(gsA)';
        PriorOpts.Marginals(ind).Type = 'Uniform';
        PriorOpts.Marginals(ind).Parameters = [3 6];
        PriorOpts.Marginals(ind).Bounds = [3 6];
        ind = ind+1;

        %% Regularization: gaC, gaA (amplitude weights, log10(unitless))
        % prior in the Bayesian inference: Gaussian, mean 0.7 (L-curve), std 0.51, bounds [-1 log10(50)]
        PriorOpts.Marginals(ind).Name = 'log10(gaC)';
        PriorOpts.Marginals(ind).Type = 'Uniform';
        PriorOpts.Marginals(ind).Parameters = [-1 log10(100)];
        PriorOpts.Marginals(ind).Bounds = [-1 log10(100)];
        ind = ind+1;

        PriorOpts.Marginals(ind).Name = 'log10(gaA)';
        PriorOpts.Marginals(ind).Type = 'Uniform';
        PriorOpts.Marginals(ind).Parameters = [-1 log10(100)];
        PriorOpts.Marginals(ind).Bounds = [-1 log10(100)];
        ind = ind+1;

        %% dhdt Errors
        % dhdt_err: multiplicative scaling applied to the dhdt error
        % estimate used in the inversion cost function. Linear-uniform.
        PriorOpts.Marginals(ind).Name = 'dhdt_err';
        PriorOpts.Marginals(ind).Type = 'Uniform';
        PriorOpts.Marginals(ind).Parameters = [0.05 0.5];
        PriorOpts.Marginals(ind).Bounds = [0.05 0.5];
        ind = ind+1;

        %% Sliding law
        % m: sliding law exponent (e.g. Weertman m). Linear-uniform.
        PriorOpts.Marginals(ind).Name = 'm';
        PriorOpts.Marginals(ind).Type = 'Uniform';
        PriorOpts.Marginals(ind).Parameters = [2 9];
        PriorOpts.Marginals(ind).Bounds = [2 9];
        ind = ind+1;

        %% Ice Rheology
        % n: Glen's law exponent. Linear-uniform (alternative: Gaussian,
        % mean 3.5, std 0.75).
        PriorOpts.Marginals(ind).Name = 'n';
        PriorOpts.Marginals(ind).Type = 'Uniform';
        PriorOpts.Marginals(ind).Parameters = [2 5];
        PriorOpts.Marginals(ind).Bounds = [2 5];

        %% Latin hypercube or Sobol sequence
        myInput = uq_createInput(PriorOpts); % Register the prior with UQLab.
        uq_print(myInput);                   % Print a summary of the marginals for a sanity check.

        uq_selectInput(myInput);             % Make myInput the "active" UQLab input.
        X = uq_getSample(SampleSize,SamplingMethod); % Draw the design: SampleSize-by-7
                                                      % matrix, columns in the order
                                                      % [gsC gsA gaC gaA dhdt_err m n]
                                                      % (log10 space for the first four).

        % Keep a copy of the raw sample in "model/sampling space" (i.e.
        % log10 units for gsC/gsA/gaC/gaA) purely for plotting below -
        % this is the space the Gaussian priors were actually defined
        % in, so histograms/scatter plots of it look like the priors
        % you specified. Plotting the physical-space values instead
        % would show a skewed (log-normal-shaped) distribution for
        % those four variables, which is harder to sanity-check.
        Xplot = X;
        PlotNames = {'log10(gsC)','log10(gsA)','log10(gaC)','log10(gaA)','dhdt_err','m','n'};

        % Map the log10-space samples for gsC, gsA, gaC, gaA back to
        % physical units. dhdt_err, m and n were already sampled
        % directly in physical (linear) units, so columns 5-7 are left
        % untouched.
        X(:,1) = 10.^X(:,1); % gsC
        X(:,2) = 10.^X(:,2); % gsA
        X(:,3) = 10.^X(:,3); % gaC
        X(:,4) = 10.^X(:,4); % gaA

        nVar = numel(TableVarNames);

        % Quick visual sanity check of the design as a "corner plot":
        % diagonal panels show the marginal histogram of each variable,
        % lower-triangle panels show pairwise scatter (useful for
        % spotting sampling artefacts or unintended correlations
        % between parameters). The mirror-image upper triangle is
        % omitted since it carries no extra information, and axis
        % labels/tick labels are only drawn on the outer edges to avoid
        % repeating the same label 2*nVar times.
        lims = zeros(nVar,2); % shared axis range per variable, so a
                              % given variable spans the same range
                              % whether it's on the x- or y-axis
        for k = 1:nVar
            lo = min(Xplot(:,k)); hi = max(Xplot(:,k));
            pad = 0.05*(hi-lo);
            if pad==0, pad = 1; end % guard against a zero-width range
            lims(k,:) = [lo-pad, hi+pad];
        end

        figure;
        for ii = 1:nVar         % row = y-variable
            for jj = 1:ii       % column = x-variable; jj<=ii keeps only
                                % the lower triangle (+ diagonal)
                subplot(nVar,nVar,(ii-1)*nVar+jj);
                if ii==jj
                    histogram(Xplot(:,ii),15)
                    xlim(lims(ii,:));
                    set(gca,'YTick',[]); % histogram counts aren't
                                         % comparable across panels,
                                         % so the y-axis isn't informative
                else
                    plot(Xplot(:,jj),Xplot(:,ii),'ok','MarkerSize',3);
                    xlim(lims(jj,:));
                    ylim(lims(ii,:));
                end

                % Only label the outer edges: variable name on the
                % bottom row (x-axis) and left column (y-axis).
                if ii==nVar
                    xlabel(PlotNames{jj},'Interpreter','none');
                else
                    set(gca,'XTickLabel',[]);
                end
                if jj==1 && ii~=jj
                    ylabel(PlotNames{ii},'Interpreter','none');
                else
                    set(gca,'YTickLabel',[]);
                end
            end
        end

    otherwise
        error("Only GradientCalc=""Adjoint"" is supported.");

end

% Optionally extend an existing Latin Hypercube design with extra
% points rather than drawing a fresh sample. This is only meaningful
% for GradientCalc="Adjoint" (myInput must exist), and only supported
% for SamplingMethod='LHS' - uq_enrichLHS has no Sobol equivalent here.
%% Optional: enrich an existing Latin hypercube design
if Enrich

    if SamplingMethod == "LHS"
        Xnew = uq_enrichLHS(X,EnrichSampleSize,myInput);
    else
        error("not implemented");
    end
    X = Xnew;

end

% Wrap the raw sample matrix in a table with named columns. Column
% names come from TableVarNames (defined above the switch) rather than
% from PriorOpts.Marginals(:).Name, because the Adjoint branch's names
% (e.g. 'log10(gsC)') describe the sampling space, not the physical
% variable, and aren't valid MATLAB table variable names anyway. This
% table (T) is what gets passed on to GenerateRunTable_Inverse and
% saved to disk below.
T=array2table(X,'VariableNames',TableVarNames);

% Save the UQLab Input object and sample table for reproducibility -
% lets you re-inspect exactly which distributions/sample produced a
% given run table later, without re-running the sampling.
filename = "./UQ_input_"+Domain+"_GradientCalc_"+GradientCalc+"_SlidingLaw_"+...
    SlidingLaw+"_SampleSize_"+string(SampleSize)+"_Enrich_"+string(Enrich)+".mat";
save(filename,"myInput","T");

%% Write the run table
% Turn the sample table into a run table (one row per simulation),
% writing the resulting CSV(s) to disk. See
% GenerateRunTable_Inverse.m for details of that process.
GenerateRunTable_Inverse(Domain,T,GradientCalc,SlidingLaw,Enrich,UseCatalogueOfFinishedSimulations);
