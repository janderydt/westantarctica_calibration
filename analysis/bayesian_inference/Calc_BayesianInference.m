function Calc_BayesianInference(UserVar)
% Calc_BayesianInference  Bayesian inference of the model parameters from observed changes in speed.
%
% PURPOSE
%   Infers the posterior distribution of the ensemble parameters ([sliding law] log10(gaA), log10(gaC),
%   log10(gsA), log10(gsC), m, n, [log10(dhdt_err), cycle]) with MCMC (affine-invariant ensemble sampler, UQLab).
%   The forward model is an emulator (residual neural network, RNN) of the change in surface speed
%   (see prepare_data_for_Delta_u_emulators.m and RNN_network_optimisation_JDR.py), one emulator per
%   row of UserVar.slidinglaw (e.g. one per start-target year pair). The data are the observed changes
%   in speed projected onto the truncated SVD basis. The log-likelihood (customLogLikelihood) is Gaussian with
%   a covariance that is the sum of the measurement errors, the Ua (model) errors and the emulator errors,
%   all projected onto the SVD basis; the log-likelihoods of all emulators are added.
%
% INPUT
%   UserVar (struct; see Driver_BayesianInference for all fields): MCMC.a/Steps/NChains, l, std_ua, domain,
%   perturbation, slidinglaw, cycle, dataformat, only_grounded_ice, years, SVDcomponents, modelversion,
%   do_plots. Without arguments default values are used.
%
% FILES READ (data, relative to the current folder; can be obtained upon request from the author, see README)
%   ./emulators/<domain>/<modelversion>_<domain>_<perturbation>_<years>_<slidinglaw>_cycle<c>_floatingice<f>_includemeasurements0_*Comp<N>*
%       (trained emulator: TensorFlow SavedModel imported with importNetworkFromTensorFlow, or a .keras file)
%   ./emulators/<domain>/data_*.mat (X_train_C/S, T_train_C/S), SVD_*.mat (T_reproj, T_mean),
%       MSE_RNN_<modelversion>_*.mat (mse_RNN: emulator mean squared errors, from plot_Emulator_MSE, analysis/emulation)
%   ./diagnosticdata/<domain>/<domain>_Delta_u_<years>[_<slidinglaw>].mat (MUA_yr2, GF_yr2)
%   observed velocities: loadvelocitydata (same folder)
%
% OUTPUT
%   ./bayesiananalysis/<domain>/<name>_v<k>.mat with UserVar and myBayesianAnalysis (UQLab), and the files
%   written by Calc_MarginalsInference (same folder). The random number generator is seeded (rng(1)).
%
% REQUIRES
%   UQLab Rel. 2.0.0 (must be on the MATLAB path), Klear (Ua),
%   loadvelocitydata, Calc_MarginalsInference (same folder), plot_myBayesianAnalysis (folder figures); MATLAB: Deep Learning Toolbox with
%   the Deep Learning Toolbox Converter for TensorFlow Models (importNetworkFromTensorFlow), Statistics
%   and Machine Learning Toolbox (pdist2), tensorprod (R2022a or later); for .keras models the Python
%   interface with Keras

if nargin==0
    Klear
    %% user defined parameters
    UserVar.MCMC.a = 2;
    UserVar.MCMC.Steps = 200e3;
    UserVar.MCMC.NChains = 50;
    UserVar.l = 50e3; % range in the ua semivariogram
    UserVar.std_ua = 100; % in m/yr
    UserVar.domain = "AMUND";
    UserVar.perturbation = "Calv_dh";
    UserVar.slidinglaw = ["Umbi"; "Umbi"; "Umbi"];
    UserVar.cycle = [2; 2; 2]; % without spinup (cycle=1) or with spinup and dhdt (cycle=2)
    UserVar.dataformat = ["du"; "du"; "du"]; % use speed ("u"), log of speed ("LOGu") or change in speed ("du")
    UserVar.only_grounded_ice = [1; 1; 1];
    UserVar.years = ["2000-2009" "2000-2014" "2000-2020"]; % a vector with years for which velocity data is used
    UserVar.modelversion = "tuned_model";
    UserVar.do_plots = 1;
end

%% initialize UQLAB

rng(1,'twister'); % set the random number generator for reproducible results
clear uqlab;
uqlab; % initialize uqlab

%% define prior distribution
% prior distributions for gaA, gaC, gsA, gsC are (truncated) Gaussians in log10 space, based on an L-curve 
% analysis (plot_Lcurve.m, not part of this repository yet). Other parameters are given a uniform
% distribution over their support. The bounds might be set automatically,
% but just to be sure we add them here. They can be optained from 
% plot_Inverse_ParameterDistribution.m (same folder).
% NOTE: the ensemble of inversions (GenerateSampleSpace_Inverse) was sampled uniformly in log10
% over [3 6] for gsA, gsC and [-1 log10(100)] for gaA, gaC, wider than these priors.
% !!! Make sure that the order of priors is consistent with how the
% customLogLikelihood function expects the parameters as input. Check
% that these are also the parameters in the emulator training data (prepare_data_for_Delta_u_emulators.m,
% Calc_SVD_basis.m) for which the emulators have been trained. By default, we use
% X = [Slidinglaw log10(gaA) log10(gaC) log10(gsA) log10(gsC) m n log10(dhdt_err)];
PriorOpts.Name = 'Model parameters prior';

ind = 1;

if size(UserVar.slidinglaw,2)>1
    PriorOpts.Marginals(ind).Name = 'Sliding law';
    PriorOpts.Marginals(ind).Type = 'Uniform';
    PriorOpts.Marginals(ind).Parameters = [1 2]; % Weertman = 1, Umbi = 2
    PriorOpts.Marginals(ind).Bounds = [1 2];
    ind = ind+1;
end

PriorOpts.Marginals(ind).Name = 'log10(gaA)';
PriorOpts.Marginals(ind).Type = 'Gaussian';
PriorOpts.Marginals(ind).Parameters = [0.7 0.51]; % mean and std
% mean is based on L curve
% std is chosen such that integral under distribution between mean-1 
% and mean+1 (in log space) captures 95% of the variability
PriorOpts.Marginals(ind).Bounds = [-1 log10(50)];
ind = ind+1;

PriorOpts.Marginals(ind).Name = 'log10(gaC)';
PriorOpts.Marginals(ind).Type = 'Gaussian';
PriorOpts.Marginals(ind).Parameters = [0.7 0.51];
PriorOpts.Marginals(ind).Bounds = [-1 log10(50)];
ind = ind+1;

PriorOpts.Marginals(ind).Name = 'log10(gsA)';
PriorOpts.Marginals(ind).Type = 'Gaussian';
PriorOpts.Marginals(ind).Parameters = [4.3 0.51];
PriorOpts.Marginals(ind).Bounds = [3 6];
ind = ind+1;

PriorOpts.Marginals(ind).Name = 'log10(gsC)';
PriorOpts.Marginals(ind).Type = 'Gaussian';
PriorOpts.Marginals(ind).Parameters = [4.3 0.51];
PriorOpts.Marginals(ind).Bounds = [3 6];
ind = ind+1;

PriorOpts.Marginals(ind).Name = 'm';
PriorOpts.Marginals(ind).Type = 'Uniform';
PriorOpts.Marginals(ind).Parameters = [2 9];
PriorOpts.Marginals(ind).Bounds = [2 9];
ind = ind+1;

PriorOpts.Marginals(ind).Name = 'n';
PriorOpts.Marginals(ind).Type = 'Uniform';
PriorOpts.Marginals(ind).Parameters = [2 5];
PriorOpts.Marginals(ind).Bounds = [2 5];

% add dhdt if any cycle>1
if max(UserVar.cycle) > 1
    ind = ind+1;
    PriorOpts.Marginals(ind).Name = 'log(dhdt_err)';
    PriorOpts.Marginals(ind).Type = 'Uniform';
    PriorOpts.Marginals(ind).Parameters = [log10(0.05) log10(0.5)];
    PriorOpts.Marginals(ind).Bounds = [log10(0.05) log10(0.5)];
end

% add discrete variables
ncycle = numel(unique(UserVar.cycle));
if ncycle>1
    ind = ind+1;
    PriorOpts.Marginals(ind).Name = 'Cycle';
    PriorOpts.Marginals(ind).Type = 'Uniform';
    PriorOpts.Marginals(ind).Parameters = [0 1];
    PriorOpts.Marginals(ind).Bounds = [0 1];
end

myPriorDist = uq_createInput(PriorOpts);

%% define data
myData.y = loadvelocitydata(UserVar.domain,UserVar.dataformat,UserVar.years,UserVar.only_grounded_ice); % myData.y.(year).u and myData.y.(year).stdu 
    % are N-by-1 matrices with N the number of nodes in the Ua mesh for that year
myData.Name = 'velocity observations and errors';

%% define custom likelihood function
% function takes parameter values (Sliding law, log10(gaA), log19(gaC), log10(gsA), 
% log10(gsC), m, n, log10(dhdt_err)) and data (y), and returns the log-likelihood
% function at these points. The forward model and covariance matrix are 
% defined within the function.

myLogLikelihood = @(params,y) customLogLikelihood(params, y, UserVar);

%% define solver options
mySolver.Type = 'MCMC';
mySolver.MCMC.Sampler = 'AIES'; % MH, AM, HMC or AIES (default)
mySolver.MCMC.Steps = UserVar.MCMC.Steps; % T=300 default
mySolver.MCMC.NChains = UserVar.MCMC.NChains; % C=100 default
mySolver.MCMC.Visualize.Parameters = [];%1:numel(PriorOpts.Marginals);
mySolver.MCMC.Visualize.Interval = 50;

if mySolver.MCMC.Sampler == "AIES"
    mySolver.MCMC.a = UserVar.MCMC.a; % default a=2, Rosier et al.: a=1.5
elseif mySolver.MCMC.Sampler == "HMC"
    mySolver.MCMC.LeapfrogSteps = 10; % default 10
    mySolver.MCMC.LeapfrogSize = 0.01; % default 0.01
    mySolver.MCMC.Mass = 1; % default 1
else
    error("Define parameters for sampler.")
end

%% define the Bayesian inference model
BayesOpts.Name = 'Bayesian inference for Ua parameters';
BayesOpts.Type = 'Inversion';
BayesOpts.Prior = myPriorDist;
BayesOpts.Data = myData;
BayesOpts.LogLikelihood = myLogLikelihood;
BayesOpts.Solver = mySolver;
BayesOpts.Display = 'verbose'; % quiet, standard or verbose

%% perform analysis
myBayesianAnalysis = uq_createAnalysis(BayesOpts);

%% postprocessing and save
uq_postProcessInversionMCMC(myBayesianAnalysis,'pointEstimate','MAP','gelmanRubin','true');

UserVar.location = pwd+"/bayesiananalysis/"+lower(UserVar.domain)+"/";
if ~exist(UserVar.location,"dir")
    mkdir(UserVar.location);
end

fname = UserVar.domain+"_BayesianAnalysis";

fname = fname + "__EM_" + UserVar.modelversion + "-" + ...
        UserVar.dataformat(1)+"-"+...
        UserVar.perturbation+"-"+...
        strjoin(UserVar.slidinglaw(1,:),"-")+...
        "-cycle"+string(UserVar.cycle(1))+...
        "-floating"+string(1-UserVar.only_grounded_ice(1))+...
        "-SVDcomponents"+string(UserVar.SVDcomponents(1));

for ee=1:size(UserVar.slidinglaw,1)
    fname = fname+"__EM"+string(ee)+"_"+...
        UserVar.years(ee);      
end

fname = fname+... 
    "__UaERR_l"+string(UserVar.l)+...
    "-stdua"+string(UserVar.std_ua)+...
    "__MCMC_a"+string(mySolver.MCMC.a)+...
    "-steps"+string(mySolver.MCMC.Steps)+...
    "-nchains"+string(mySolver.MCMC.NChains);

files = dir(UserVar.location+fname(1)+"*.mat"); labels = [];
for nn=1:numel(files)
    name = files(nn).name;
    tmp = split(name,"_");
    labels = [labels str2num(erase(tmp{end},[".mat","v"]))];
end
if isempty(labels)
    labels = 0;
end
UserVar.fname = fname(1)+"_v"+string(max(labels)+1)+".mat";

try 
    save(UserVar.location+UserVar.fname,"UserVar","myBayesianAnalysis","-v7.3");
catch
    % file name is likely too long
    % replace Weertman with W, and Umbi with U
    UserVar.fname = strrep(UserVar.fname,"Weertman","W");
    UserVar.fname = strrep(UserVar.fname,"Umbi","U");
    save(UserVar.location+UserVar.fname,"UserVar","myBayesianAnalysis","-v7.3");
end

Calc_MarginalsInference(UserVar.location,UserVar.fname);

%% print some results
uq_print(myBayesianAnalysis);

if UserVar.do_plots
    plot_myBayesianAnalysis(myBayesianAnalysis,UserVar);
end

end

function logL = customLogLikelihood(params, measurements, UserVar)

% NOTE: the emulators and covariance matrices are stored in persistent variables, which are only set at the first
% call in a MATLAB session: use "clear Calc_BayesianInference" before running with different settings.
persistent M Nem np

% evaluates the log likelihood for parameter values specified in params

% INPUTS:
% ** params is C-by-M matrix, where C is the number of MCMC chains and M is
% the number of parameters
% ** measurements is a data structure, as specified by the loadvelocitydata 
% function
% ** UserVar defines the emulators (domain, perturbation, slidinglaw, cycle, dataformat, years, ...)

% OUTPUT:
% ** logL is a C-by-1 vector

% Initialization
nReal = size(params,1); % number of queried realizations
% slidinglaw, cycle, dataformat, only_grounded_ice, years: one row per emulator
modelversion = UserVar.modelversion;
domain = UserVar.domain;
perturbation = UserVar.perturbation;
slidinglaw = UserVar.slidinglaw;
cycle = UserVar.cycle;
dataformat = UserVar.dataformat;
only_grounded_ice = double(UserVar.only_grounded_ice);
SVDcomponents = UserVar.SVDcomponents;
years = UserVar.years;
l = UserVar.l; % range in the semivariogram
%fac_su = UserVar.fac_su; % multiplication factor for model errors compared to observation errors
std_ua = UserVar.std_ua;

Nem = size(slidinglaw,1);

% Load forward model(s)
if isempty(M)

    for ii=1:Nem

        % Record some basis stats about emulator
        M(ii).Slidinglaw = slidinglaw(ii,:);
        M(ii).Year = years(ii);

        if dataformat(ii) == "LOGu"
            yearstr = "LOGu"+years(ii); 
        else
            yearstr = years(ii);
        end

        % Check Calc_SVD_basis.m to see
        % what parameters the emulator is trained for, and in what order
        % The default is X = [log10(gaA) log10(gaC) log10(gsA) log10(gsC) m n log10(dhdt_err)];

        TF_dir = dir("./emulators/"+lower(domain)+"/"+modelversion+"_"+domain+"_"+perturbation+"_"+years(ii)+...
            "_"+strjoin(slidinglaw(ii,:),"-")+"_cycle"+string(cycle(ii))+"_floatingice"+string(1-only_grounded_ice(ii))+...
            "_includemeasurements0"+"_*Comp"+string(SVDcomponents(ii))+"*");

        if numel(TF_dir)>1

            error("There seem to be multiple emulators with this name: ./emulators/"+lower(domain)+"/"+...
                modelversion+"_"+domain+"_"+perturbation+"_"+years(ii)+...
            "_"+strjoin(slidinglaw(ii,:),"-")+"_cycle"+string(cycle(ii))+"_floatingice"+string(1-only_grounded_ice(ii))+...
            "_includemeasurements0"+"_*Comp"+string(SVDcomponents(ii))+"*");

        end

        if contains(TF_dir.name,".keras")
            M(ii).keras = 1;
            py.keras.device('/cpu:0');
            M(ii).net =  py.keras.models.load_model(TF_dir.folder+"/"+TF_dir.name, compile=false);
        else
            M(ii).keras = 0;
            net_tmp = importNetworkFromTensorFlow(TF_dir.folder+"/"+TF_dir.name);  
            M(ii).net=initialize(net_tmp);
        end

        data_file = dir("./emulators/"+lower(domain)+"/data_"+domain+"_"+perturbation+"_"+years(ii)+...
            "_"+strjoin(slidinglaw(ii,:),"-")+"_cycle"+string(cycle(ii))+"_floatingice"+string(1-only_grounded_ice(ii))+...
            "_includemeasurements0"+"_*Comp"+string(SVDcomponents(ii))+"*.mat");
        load(data_file.folder+"/"+data_file.name,"X_train_C","X_train_S","T_train_C","T_train_S");
    
        SVD_file = dir("./emulators/"+lower(domain)+"/SVD_"+domain+"_"+perturbation+"_"+years(ii)+...
            "_"+strjoin(slidinglaw(ii,:),"-")+"_cycle"+string(cycle(ii))+"_floatingice"+string(1-only_grounded_ice(ii))+...
            "_includemeasurements0"+"_*Comp"+string(SVDcomponents(ii))+"*.mat");
        load(SVD_file.folder+"/"+SVD_file.name,"T_reproj","T_mean");

        MSE_file = dir("./emulators/"+lower(domain)+"/MSE_RNN_"+modelversion+"_"+domain+"_"+perturbation+"_"+years(ii)+...
            "_"+strjoin(slidinglaw(ii,:),"-")+"_cycle"+string(cycle(ii))+"_floatingice"+string(1-only_grounded_ice(ii))+...
            "_includemeasurements0"+"_*Comp"+string(SVDcomponents(ii))+"*.mat");
        load(MSE_file.folder+"/"+MSE_file.name);
        MSE = mse_RNN;

        [nModes,nNodes] = size(T_reproj);
        M(ii).X_train_C = X_train_C;
        M(ii).X_train_S = X_train_S;
        M(ii).T_train_C = T_train_C;
        M(ii).T_train_S = T_train_S;
        
        if dataformat(ii) == "du"
            stdstr = "stddu";
            ustr = "du";
            yearstr2 = "yr"+replace(years(ii),"-","_yr");
        else
            stdstr = "stdu";
            ustr = "u";
            yearstr2 = "yr"+years(ii);
        end

        % Subtract mean and deal with nans in data
        data_tmp = measurements(1).(yearstr2).(ustr)(:)-T_mean(:);
        std_tmp = measurements(1).(yearstr2).(stdstr)(:);
        Indnan = find(isnan(data_tmp) | isnan(std_tmp));
        if dataformat(ii) == "LOGu"
            data_tmp(Indnan) = 0; 
            std_tmp(Indnan) = 3;
        elseif dataformat(ii) == "u"
            data_tmp(Indnan) = 0; 
            std_tmp(Indnan) = 1e3;
        elseif dataformat(ii) == "du"
            data_tmp(Indnan) = 0; 
            std_tmp(Indnan) = 1e3;
        end

        % Project data onto truncated space. Make sure that this does not
        % distort the data too much, i.e. the data can be represented well in the
        % truncated base. To check this, you need to reproject M(ii).data back onto
        % the nodal base by multiplying with B_trunc, which is saved in SVD_"+perturbation+"_****
        % If the data cannot be faithfully represented using the truncated
        % basis functions then you might want to try adding the data to the SVD
        % decomposition, or increase the number of basis functions (both
        % are options in prepare_data_for_***_emulators.m)
        M(ii).data = data_tmp'*T_reproj';

        % Assemble covariance matrices
        % 1. measurement errors
        S_meas = T_reproj*diag(std_tmp.^2)*T_reproj';

        % 2. Ua (model) errors: spatially correlated Gaussian errors with standard deviation std_ua (m/yr) and
        % range l (m)
        if std_ua~=0 || l~=0
            try
                load("diagnosticdata/"+lower(domain)+"/"+domain+"_Delta_u_"+yearstr+"_"+slidinglaw(ii,1)+".mat","MUA_yr2","GF_yr2");
            catch
                load("diagnosticdata/"+lower(domain)+"/"+domain+"_Delta_u_"+yearstr+".mat","MUA_yr2","GF_yr2");
            end
            MUA = MUA_yr2;
            GF= GF_yr2;
            D_tmp = pdist2(MUA.coordinates,MUA.coordinates,"squaredeuclidean");
            su_nodal = std_ua*ones(MUA.Nnodes,1);
            if only_grounded_ice(ii)==0
                su_nodal(GF.node<0.5)=2*su; % give floating nodes a larger error (not used in the paper, only_grounded_ice = 1; su is not defined)
            end
            TP = tensorprod(su_nodal,su_nodal,2);
            D_tmp = TP.*exp(-D_tmp/(2*l^2));
    
            S_ua = T_reproj*D_tmp*T_reproj';
            clear D_tmp
        else
            S_ua = 0*S_meas;
        end

        % 3. Emulator errors: obtained from plot_Emulator_MSE
        S_emulator = diag(MSE);

        M(ii).S = S_meas + S_emulator + S_ua;
        M(ii).detS = det(M(ii).S);
        M(ii).Sinv = inv(M(ii).S);
    end    
end

% Deal with discrete variable in case of multiple sliding laws
if size(slidinglaw,2) > 1  % sliding law is a discrete variable that takes multiple values
    params(:,1)=round(params(:,1));
end

% Loop through years
logL = zeros(nReal,1);

for ee=1:Nem

    predictors = (params-repmat(M(ee).X_train_C,nReal,1))./repmat(M(ee).X_train_S,nReal,1);

    % Evaluate forward model. 
    if M(ee).keras
        predictors = single(predictors);
        if isvector(predictors)
            predictors = reshape(predictors, 1 ,[]);
            predictors = {predictors};
        end
        if isempty(np)
            np = py.importlib.import_module('numpy');
        end
        predictors_np = np.array(predictors);  % shape: [batch_size, input_dim]
        modelRun = double(M(ee).net.call(predictors_np, pyargs('training', false)));
    else
        modelRun = double(predict(M(ee).net,predictors));
    end

    % Undo normalization of the output but keep in the projected basis to 
    % make it compatible with data
    modelRun = modelRun.*repmat(M(ee).T_train_S,nReal,1)+repmat(M(ee).T_train_C,nReal,1);
    Nout = size(modelRun,2);

    % Assemble log likelihood
    prefac = -0.5*log((2*pi)^Nout*M(ee).detS);
    diff = modelRun - M(ee).data;
    Ndistrib = -0.5*sum((diff*M(ee).Sinv).*diff,2);
    logLikeli = prefac + Ndistrib;
    logL = logL+logLikeli;
    
end
end
