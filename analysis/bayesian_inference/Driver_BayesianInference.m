function Driver_BayesianInference
% Driver_BayesianInference  Run the Bayesian inference (Calc_BayesianInference) for one or several settings.
%
% PURPOSE
%   Defines the settings of the inference in a table (one row per run: range l and standard deviation std_ua of the
%   Ua (model) errors, MCMC parameters, optionally the years) and the emulators to use, then calls
%   Calc_BayesianInference for each row.
%
% SETTINGS FOR AMUND (as set below)
%   l = 50 km, std_ua = 40 m/yr, AIES sampler with a=2, 100e3 steps and 25 chains, three emulators
%   (one per year pair 2000-2009, 2000-2014, 2000-2020), each for both sliding laws, perturbation "Calv_dh",
%   cycle 2 (inversion after spinup, with dhdt), change in speed ("du"), grounded ice only, 25 SVD
%   components, emulator version "v4_tuned_model_full".
% SETTINGS FOR SYNTH_PIG (earlier runs, not set here)
%   domain "SYNTH_PIG", perturbation "dh", l = 1e4, std_ua = 50, SVDcomponents = 10, one emulator per
%   year pair "Weertmanyr30-Weertmanyr35", "-Weertmanyr40", "-Weertmanyr45", "-Weertmanyr50", "-Weertmanyr75".
%
% REQUIRES
%   Calc_BayesianInference and its requirements; the working folder (below) has to contain the folders
%   emulators, diagnosticdata (and bayesiananalysis, created if needed).

% make sure we're in the right folder
% folder that contains emulators, diagnosticdata (and bayesiananalysis, created if needed)
cd("/path/to/analysis/folder");

l = [50e3]';
std_ua = [40]'; %m/yr
a = 0*l+2;
steps = 0*l + 100e3;
nchains = 0*l + 25;
years = []; % if not empty: one set of years per row of the table, instead of UserVar.years below

cycle = zeros(numel(l),1)+2;

try
    T = table(l,std_ua,a,steps,nchains,cycle,years);
catch
    T = table(l,std_ua,a,steps,nchains,cycle);
end

for ii=1:size(T,1)
    fprintf("=========================================================\n");
    disp(T);
    fprintf("=========================================================\n");
    fprintf("    %s  --  Currently executing row %d\n",string(datetime('now')),ii);
    fprintf("=========================================================\n");
    UserVar.l = l(ii); % range in the ua semivariogram
    UserVar.std_ua = std_ua(ii);
    UserVar.MCMC.a = a(ii);
    UserVar.MCMC.Steps = steps(ii);
    UserVar.MCMC.NChains = nchains(ii);
    UserVar.domain = "AMUND";
    UserVar.perturbation = "Calv_dh";
    %% NOTE: slidinglaw variable has a row for each emulator, and columns to specify the sliding laws in each emulator.
    %% For example, to use a single emulator with Weertman and Umbi sliding laws, set UserVar.slidinglaw = ["Weertman" "Umbi"];
    %% or to use 2 emulators, one for Weertman and one for Umbi, set UserVar.slidinglaw = ["Weertman"; "Umbi"];
    UserVar.slidinglaw = ["Weertman" "Umbi";...
       "Weertman" "Umbi";...
       "Weertman" "Umbi"];
    %% NOTE: cycle, dataformat, only_groundedice, years and SVDcomponents are vectors with rows equal to dim(slidinglaw,1), i.e. the number of emulators
    UserVar.cycle = [2;2;2]; % without spinup (cycle=1) or with spinup and dhdt (cycle=2)
    UserVar.dataformat = ["du";"du";"du"]; % use speed ("u"), log of speed ("LOGu") or change in speed ("du")
    UserVar.only_grounded_ice = [1;1;1];
    UserVar.years = ["2000-2009";"2000-2014";"2000-2020"]; % a vector with years for which velocity data is used
    if ~isempty(years)
        UserVar.years = years(ii);
    end
    UserVar.SVDcomponents = [25 25 25];
    UserVar.modelversion = "v4_tuned_model_full";
    UserVar.do_plots = 0;
    try 
        disp(struct2table(UserVar));
    catch
        unfold(UserVar);
    end
    Calc_BayesianInference(UserVar);
    clear Calc_BayesianInference; % clears the persistent emulators of the previous run
    close all;
end
