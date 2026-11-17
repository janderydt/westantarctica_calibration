function Calc_SVD_basis(data,SVD_settings,SVD_filetowrite)
% Calc_SVD_basis  Assemble predictors and targets of the ensemble and calculate the SVD of the targets.
%
% PURPOSE
%   Collects, for all sliding laws, the ensemble parameters (predictors X) and the simulated changes in
%   surface speed (targets T, one row per ensemble member, one column per node) of the diagnostic
%   perturbation experiments between startyear and targetyear, calculates the measured change in speed
%   T_meas (extruded MEaSUREs / ITS_LIVE velocities of the two years, interpolated onto the Ua mesh), and
%   the singular values S of the targets after removal of the ensemble mean. Optionally only grounded ice is
%   kept (floating nodes set to zero) and the measurements are added to the SVD.
%
% INPUTS
%   data            : struct with domain ("AMUND" or "SYNTH_PIG"), perturbation ("Calv", "dhIS", "dh" or
%                     "Calv_dh"), startyear, targetyear, slidinglaw ("Weertman" and/or "Umbi"), cycle (per sliding
%                     law; 1: inversion without spinup, 2: inversion after spinup), only_grounded_ice
%   SVD_settings    : struct with add_measurements_to_SVD
%   SVD_filetowrite : output file
%   Without arguments, default settings (first block) are used.
%   Data (postprocessed diagnostic results, see README):
%     ./DiagnosticData/<domain>/<domain>_Delta_u_<startyear>-<targetyear>[_<slidinglaw>].mat with
%       MUA_yr2, GF_yr2 (mesh and grounding mask), gaA, gaC, gsA, gsC, m, n, dhdt_err, slidinglaw (one value per
%       ensemble member) and Delta_u.<perturbation>.map (members x nodes x cycle)
%     ../ua_input/1_interpolants/<velocity interpolants> (extruded velocities of both years:
%       GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat for 2000,
%       GriddedInterpolants_<yr>-<yr+1>_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat for AMUND, or
%       ScatteredInterpolants_Velocities_SYNTH_PIG_<year>.mat)
%
% OUTPUT
%   SVD_filetowrite (.mat; its folder must exist) with S (singular values), X (predictors: [sliding law index],
%   log10 of gaA, gaC, gsA, gsC, m, n, [log10 dhdt_err]), T (targets), T_mean, T_meanremoved, T_meas.
%
% REQUIRES
%   MATLAB only (no Ua functions)

if nargin==0
    % default settings when called without arguments
    %% -- perturbation data to use
    domain = "AMUND";
    perturbation = "Calv_dh"; % valid choices are "Calv", "dhIS", "dh" or "Calv_dh"
    startyear = "2000";
    targetyear = "2009";
    slidinglaw = ["Weertman" "Umbi"]; % valid choices are "Weertman" or "Umbi"
    cycle = [2 2]; % cycle 1: inversion without spinup, cycle 2: inversion after spinup
    only_grounded_ice = 0;
    
    %% -- SVD settings
    add_measurements_to_SVD = 0;

    %% filename
    strtmp = "";
    for ii=1:numel(slidinglaw)
        strtmp2 = char(slidinglaw(ii));
        strtmp = strtmp+strtmp2(1)+"c"+string(cycle(ii))+"_";
    end
    SVD_filetowrite = "./Emulators/"+domain+"/SVD_files/SVD_"+domain+"_"+perturbation+"_"+startyear+"-"+targetyear+"_"+...
        strtmp+"floatingice"+string(1-only_grounded_ice)+"_includemeasurements"+string(add_measurements_to_SVD)+".mat";

else
    if nargin<2
        error("Need 2 inputs.");
    else
        domain = data.domain;
        perturbation = data.perturbation;
        startyear = data.startyear;
        targetyear = data.targetyear;
        slidinglaw = data.slidinglaw;
        cycle = data.cycle;
        only_grounded_ice = data.only_grounded_ice;
        add_measurements_to_SVD = SVD_settings.add_measurements_to_SVD;
    end
end

X = []; T = [];

for ii=1:numel(slidinglaw)

    % Load perturbation data
    try       
        tmp = load("./DiagnosticData/"+domain+"/"+domain+"_Delta_u_"+startyear+"-"+targetyear+"_"+slidinglaw(ii)+".mat");
        tmp.slidinglaw = repmat(slidinglaw(ii),size(tmp.gaA));        
    catch
        tmp = load("./DiagnosticData/"+domain+"/"+domain+"_Delta_u_"+startyear+"-"+targetyear+".mat");
    end 
    % Ua target grid
    MUA = tmp.MUA_yr2; GF = tmp.GF_yr2;

    %% SUBSET OF DATA FOR GIVEN SLIDING LAW
    Ind = find(tmp.slidinglaw == slidinglaw(ii)); Ind=Ind(:);

    %% PREDICTORS
    gaA=tmp.gaA(:);
    gaC=tmp.gaC(:);
    gsA=tmp.gsA(:);
    gsC=tmp.gsC(:);
    m=tmp.m(:);
    n=tmp.n(:);

    if numel(slidinglaw)>1
        Xtmp = [Ind*0+ii log10(gaA(Ind)) log10(gaC(Ind)) log10(gsA(Ind)) log10(gsC(Ind)) m(Ind) n(Ind)];
    else
        Xtmp = [log10(gaA(Ind)) log10(gaC(Ind)) log10(gsA(Ind)) log10(gsC(Ind)) m(Ind) n(Ind)];
    end

    if cycle(ii)==2 % add dhdt_err to predictors
        dhdt_err = tmp.dhdt_err(:);
        Xtmp = [Xtmp log10(dhdt_err(Ind))];
    elseif cycle(ii)==1 && max(cycle)>1
        Xtmp = [Xtmp 0*Ind];
    end
    Xtmp = double(Xtmp);

    %% TARGETS (training/input data). In this case, input data consists of 
    %% simulated instantaneous changes in surface speed in response to changes
    %% in ice-sheet geometry (ice thickness, calving front location). The input
    %% data consists of num_nodes nodal values for nun_exp experiments.
    Ttmp = tmp.Delta_u.(perturbation).map(Ind,:,cycle(ii));

    % check for nans and inf
    if any(isnan(Ttmp) | isinf(Ttmp))
        warning("Removing nan from T");
        [rows_to_delete,~]=find(isnan(Ttmp));
        rows_to_delete = unique(rows_to_delete);
        Xtmp(rows_to_delete,:)=[];
        Ttmp(rows_to_delete,:)=[];
    end
    % check dimensions of input data; rows: experiments, columns: nodes
    if numel(size(Ttmp))==2
        num_exp = size(Ttmp,1); num_nodes = size(Ttmp,2);
        if num_nodes < num_exp % number of experiments is highly likely to be smaller than number of nodes
            Ttmp = Ttmp'; % transpose data
            num_exp = size(Ttmp,1); num_nodes = size(Ttmp,2);
        end
    else
        error("check dimensions of input data");
    end

    %% ASSEMBLE FULL MATRICES
    X = [X; Xtmp];
    T = [T; Ttmp];
end

% remove mean
T_mean = mean(T,1);
T_meanremoved = T-repmat(T_mean(:)',size(T,1),1);

%% Load observations 
% for AMUND, using extruded velocity fields because data gaps (and
% corresponding large errors) are not dealt with properly by the Bayesian
% inference in the SVD basis. The EXTRUDED velocities fill data gaps by extruding the
% velocities along flowlines (Create_ExtrudedFields_GriddedInterpolants, option '-v-').
for yy=[startyear targetyear]
    if yy=="2000"
        fname = "GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat";
    else
        if contains(domain,"AMUND")
            fname = "GriddedInterpolants_"+string(double(yy))+"-"+string(double(yy)+1)+...
            "_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat";
        elseif contains(domain,"SYNTH_PIG")
            fname = "ScatteredInterpolants_Velocities_SYNTH_PIG_"+yy+".mat";
        else
            error("Do not recognise domain")
        end
    end
    load("../ua_input/1_interpolants/"+fname);
    v_tmp = hypot(Fus.Values,Fvs.Values);
    Fu = Fus; Fu.Values = v_tmp;
    std_tmp = hypot(Fxerr.Values,Fyerr.Values);
    Fstd = Fus; Fstd.Values = std_tmp;
    v.("yr"+yy).F = Fu;
    std.("yr"+yy).F = Fstd;
end

% interpolate initial and final speed onto Ua mesh
u_init = v.("yr"+startyear).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
std_init = std.("yr"+startyear).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
u_target = v.("yr"+targetyear).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
std_target = std.("yr"+targetyear).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
deltau = u_target-u_init; % measured change in speed (m/yr)

T_meas = deltau(:);

if any(isnan(T_meas))
    error("dT_meas contains nans. Consider using extruded field or inpaint_nans.");
end

% optionally add the measurements as the first row of T (the mean of the model ensemble is subtracted)
if add_measurements_to_SVD    
    T = [T_meas(:)'; T];
    T_meanremoved = T-repmat(T_mean(:)',size(T,1),1);
end

%% remove floating nodes   
if only_grounded_ice   
    Nodes_floating = find(GF.node<0.5);
    T(:,Nodes_floating) = 0;
    T_meas(Nodes_floating) = 0;
    T_mean(Nodes_floating) = 0;
end

[~,S,~] = svd(T_meanremoved,'econ');

%% save data
save(SVD_filetowrite,"S","X","T","T_mean","T_meanremoved","T_meas");
