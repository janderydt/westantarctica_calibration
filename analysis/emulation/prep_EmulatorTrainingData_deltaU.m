function prep_EmulatorTrainingData_deltaU
% prep_EmulatorTrainingData_deltaU  Prepare training data for the emulators of the change in speed.
%
% PURPOSE
%   Reads maps of the change in surface speed (delta u) between startyear and targetyear from the
%   diagnostic perturbation experiments of all ensemble members (perturbation 'Calv', 'dhIS', 'dh'
%   or 'Calv_dh'; diagnostic run table names: Calv, ISthick, thick, Calv_thick), computes a singular
%   value decomposition (SVD) of the maps to reduce their dimensionality (the number of components is
%   the smallest number that describes SVD_targetpercentage of the variance, at most
%   max_SVD_components), and then optionally writes normalised training, validation and test data
%   for the TensorFlow RNN training (Python).
%   Currently emulators can only be trained for 1 startyear-targetyear pair at a time.
%
% USER SETTINGS (top of the function)
%   domain (AMUND or SYNTH_PIG), perturbation, startyear (2000 for AMUND, Weertmanyr30/Umbiyr30 for
%   SYNTH_PIG), targetyear (2009/2014/2020 for AMUND, Weertmanyr35/40/45/50 or Umbiyr50 for SYNTH_PIG),
%   slidinglaw and cycle (cycle 1: inversion without spinup, cycle 2: inversion after spinup),
%   only_grounded_ice, SVD settings, do_plots, write_outputs_for_TF.
%
% INPUTS (not part of the repository code, see README)
%   Calc_SVD_basis reads the postprocessed diagnostic data
%     ./DiagnosticData/<domain>/<domain>_Delta_u_<startyear>-<targetyear>[_<slidinglaw>].mat
%   (variables including MUA_yr2, GF_yr2) and the ensemble parameters (predictors X), and writes
%     ./Emulators/<domain>/SVD_files/SVD_<...>.mat  (S, T, T_mean, T_meas, X)
%
% OUTPUTS
%   Figures in ./Figures (.png); ./Emulators/<domain>/RNN/mat_files/*.mat (data for the RNN training).
%   The folders must exist.
%
% REQUIRES
%   Calc_SVD_basis (same folder), PlotNodalBasedQuantities_JDR (modified Ua plotting function in
%   froot_tools), fig, cmocean (plots), Ua2D_DefaultParameters (Ua)

addpath(getenv("froot_tools"));

%% -- perturbation data to use
domain = "AMUND"; % AMUND or SYNTH_PIG
perturbation = 'Calv_dh'; % can be 'Calv', 'dhIS', 'dh' or 'Calv_dh'
startyear = "2000"; % 2000 for AMUND, Weertmanyr30/Umbiyr30 for SYNTH_PIG
targetyear = "2009"; % 2009/2014/2020 for AMUND, Weertmanyr35/40/45/50 or Umbiyr50 for SYNTH_PIG
                     % Currently emulators can only be trained for 1
                     % startyear-targetyear pair at a time
slidinglaw = ["Weertman" "Umbi"]; % can be "Weertman", "Umbi" or ["Weertman" "Umbi"]
cycle = [2 2]; % cycle 1: inversion without spinup, cycle 2: inversion after spinup
               % Should have the same dimensions as slidinglaw
only_grounded_ice = 1;

%% -- SVD settings
add_measurements_to_SVD = 0;
use_existing_SVD_basis = 0;
SVD_basistoread = "Wc2_Uc2";
max_SVD_components = 25; % for a large number of SVD components the ML 
% algorithms might struggle to learn the variability in the highest 
% compoments. From basic tests, 25 seems like a reasonable number for AMUND, 
% and 10 seems like a reasonable number for SYNTH_PIG.
SVD_targetpercentage = 0.5; % minimum fraction of the variance (0.5 = 50%) that the retained components must
% describe; the number of components is capped by max_SVD_components. This needs to be high enough so we can
% reliably represent the measurements in the truncated SVD basis

%% -- outputs
do_plots = 1;
write_outputs_for_TF = 0;

%% ----------------------------------------- %%
%% No need to make changes beyond this point %%
%% ----------------------------------------- %%
% load X and T for perturbation data
data.domain = domain;
data.perturbation = perturbation;
data.startyear = startyear;
data.targetyear = targetyear;
data.slidinglaw = slidinglaw;
data.cycle = cycle;
data.only_grounded_ice = only_grounded_ice;
SVD_settings.add_measurements_to_SVD = add_measurements_to_SVD;

if use_existing_SVD_basis
    % check that basis exists
    SVD_filetoread = "./Emulators/"+domain+"/SVD_files/SVD_"+domain+"_"+perturbation+"_"+startyear+"-"+targetyear+"_"+...
        SVD_basistoread+"_floatingice"+string(1-only_grounded_ice)+"_includemeasurements"+string(add_measurements_to_SVD)+".mat";
    if ~exist(SVD_filetoread)
        warning("use_existing_SVD_basis=1, but requested basis does not exist. Creating new SVD file. Make sure you have set slidinglaw, cycle and only_grounded_ice to the correct values.")
        SVD_filetowrite = SVD_filetoread;
        Calc_SVD_basis(data,SVD_settings,SVD_filetowrite);
        warning("New SVD file created. Now check slidinglaw, cycle and only_grounded_ice and rerun.")
        return;
    else
        SVD_existing = load(SVD_filetoread);
    end
    S = SVD_existing.S;
    T = SVD_existing.T;
    T_mean = SVD_existing.T_mean;
end

% TODO: for a string array slidinglaw, char() returns one row per element, so slidinglaw_char(1,1,ii) is
% out of range for ii>1 (slidinglaw_char(ii,1) was probably intended): check
slidinglaw_char = char(slidinglaw); strtmp="";
for ii=1:numel(slidinglaw)
    strtmp = strtmp + slidinglaw_char(1,1,ii)+"c"+string(cycle(ii))+"_";
end
SVD_filetowrite = "./Emulators/"+domain+"/SVD_files/SVD_"+domain+"_"+perturbation+"_"+startyear+"-"+targetyear+"_"+...
    strtmp+"floatingice"+string(1-only_grounded_ice)+"_includemeasurements"+string(add_measurements_to_SVD)+".mat";
Calc_SVD_basis(data,SVD_settings,SVD_filetowrite);
SVD_new = load(SVD_filetowrite);

if ~use_existing_SVD_basis
    SVD_filetoread = SVD_filetowrite;
    S = SVD_new.S;
    T = SVD_new.T;
    T_mean = SVD_new.T_mean;
end

%% DIMENSIONALITY REDUCTION: use singular value decomposition of targets to
%% express each map of \Delta u in terms of its k dominant principal components
% do the full svd to calculate how many components are required for each
% increment in pct
tmp = (cumsum(diag(S).^2)./sum(diag(S).^2));
T_nComp = find(tmp>SVD_targetpercentage,1,'first');

if T_nComp > max_SVD_components
    SVD_targetpercentage = tmp(max_SVD_components);
    T_nComp = max_SVD_components;
end

fprintf("Retaining %s components in the SVD with %s percentage of the variance explained.\n",...
    string(T_nComp),string(SVD_targetpercentage));

T_pct1 = diag(S).^2./sum(diag(S).^2);
T_pct = T_pct1(1:T_nComp);

% return the left singular vectors U, diagonal matrix S of singular 
% values, and right singular vectors V for T_nComp largest singular values
[U_trunc,S_trunc,V_trunc] = svds(T-repmat(T_mean(:)',size(T,1),1),T_nComp);

% note that T is transposed compared to the canonical treatment of the
% svd. 
% [T]=n-by-m with n number of samples and m size of each sample
% [U]=n-by-n 
% [S]=n-by-m
% [V']=m-by-m
% T = U*S*V' = U*B with B=S*V' with [B]=n-by-m
% truncate decomposation at rank r:
% [T_trunc]=n-by-m
% [U_trunc]=n-by-r
% [S_trunc]=r-by-r: the eigen values
% [V_trunc']=r-by-m: the eigen basis
% T_trunc = U_trunc*S_trunc*V_trunc' = U_trunc*B_trunc with 
% B_trunc=S_trunc*V_trunc' with [B_trunc]=r-by-m
% So T_trunc = U_trunc*B_trunc
% => T_trunc*B_trunc' = U_trunc*B_trunc*B_trunc'
% ==> T_trunc*B_trunc'*inv(B_trunc*B_trunc') = U_trunc
% and define T_reproj = inv(B_trunc*B_trunc')*B_trunc
% then T_reproj' = B_trunc'*inv(B_trunc*B_trunc')
% with [T_reproj']=m-by-r
% and U_trunc = T_trunc*T_reproj';
% Instead of training the emulator with U_trunc, we train the emulator
% with T_hat = T*T_reproj'
% To reproject T_hat to the original basis, simply multiply with 
% B_trunc: T = T_hat*B_trunc
B_trunc = S_trunc*V_trunc';
T_reproj = (B_trunc*B_trunc')\B_trunc; % equivalent to inv(B*B')*B

%% TARGETS (training/input data). In this case, input data consists of 
%% simulated instantaneous changes in surface speed in response to changes
%% in ice-sheet geometry (ice thickness, calving front location). The input
%% data consists of num_nodes nodal values for nun_exp experiments.
% TODO: with add_measurements_to_SVD=1, T_hat has num_exp-1 rows, but seq (below) is a permutation of
% num_exp rows, so data = T_hat(seq,:) fails; and the statement below is missing a semicolon
if add_measurements_to_SVD
    T = SVD_new.T(2:end,:)
    T_hat = (T-repmat(T_mean(:)',size(T,1),1))*T_reproj';
    % we remove the first line here, which contains the measurements
    % because we don't want to include them in the training data        
else
    T = SVD_new.T;
    T_hat = (T-repmat(T_mean(:)',size(T,1),1))*T_reproj';
end

num_exp = size(SVD_new.T,1); num_nodes = size(SVD_new.T,2);

%% PREDICTORS
X = SVD_new.X;

if do_plots

    for ss=1:numel(slidinglaw)
    
        % load Ua mesh
        try 
            load("./DiagnosticData/"+domain+"/"+domain+"_Delta_u_"+startyear+"-"+targetyear+"_"+slidinglaw(ss)+".mat","MUA_yr2","GF_yr2");
        catch
            load("./DiagnosticData/"+domain+"/"+domain+"_Delta_u_"+startyear+"-"+targetyear+".mat","MUA_yr2","GF_yr2");
        end
        MUA = MUA_yr2; GF = GF_yr2;
    
        %% Can measurements be represented adequately in truncated basis?
        T_meas = SVD_new.T_meas(:)'-T_mean(:)';
        T_meas_trunc = T_meas*T_reproj';
        T_meas_reproj = T_meas_trunc*B_trunc; % reproject truncated field onto nodal basis
    
        H = fig('units','inches','width',80*12/72.27,'height',25*12/72.27,'fontsize',14,'font','Helvetica');
        tlo = tiledlayout(1,3,'TileSpacing','tight');
        
        t(1)=nexttile; hold on; 
        PlotNodalBasedQuantities_JDR(gca,MUA.connectivity,MUA.coordinates,T_meas(:)+T_mean(:)); 
        title(t(1),'\Delta U_{meas}');
        axis(t(1),"tight"); caxis(t(1),[0 1000]); colormap(t(1),flipud(cmocean('haline')));
        
        t(2)=nexttile; hold on; 
        PlotNodalBasedQuantities_JDR(gca,MUA.connectivity,MUA.coordinates,T_meas_reproj(:)+T_mean(:)); 
        title(t(2),'Truncated \Delta U_{meas}');
        axis(t(2),"tight"); caxis(t(2),[0 1000]); colormap(t(2),flipud(cmocean('haline')));
        
        t(3)=nexttile; hold on; 
        PlotNodalBasedQuantities_JDR(gca,MUA.connectivity,MUA.coordinates,T_meas(:)-T_meas_reproj(:)); 
        if domain == "AMUND"
            axis(t(3),"equal");
            caxis(t(3),[-250 250]); 
        else
            caxis(t(3),[-100 100]); 
        end

        axis(t(3),"tight","off"); colormap(t(3),flipud(cmocean('balance')));
        
        cb = colorbar(t(3));
        cb.Label.String = "$\Delta u_{\rm meas} - \hat{\Delta u}_{\rm meas}\;{\rm [m/yr]}$";
        cb.Label.Interpreter = "Latex";
        cb.FontSize = 14;
        cb.Layout.Tile = "East";
        
        title(tlo,strrep(SVD_filetoread+", SVD truncation: "+string(T_nComp)+" components, "+string(SVD_targetpercentage*100)+"%.","_","\_"));

        pos = get(H,"Position");
        set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
        Hname = "./Figures/"+domain+"_DeltaU_Measured_vs_Truncated.png";
        print(H,Hname,"-dpng","-r400");

        
        %% Are model data adequately represented in truncated basis?
        T_mod= SVD_new.T-repmat(SVD_new.T_mean(:)',size(T,1),1);
        T_mod_trunc = T_mod*T_reproj';
        T_mod_reproj = T_mod_trunc*B_trunc;
        
        H = fig('units','inches','width',80*12/72.27,'height',25*12/72.27,'fontsize',14,'font','Helvetica');
        tlo = tiledlayout(1,3,'TileSpacing','tight');
        
        t(1)=nexttile; hold on; 
        PlotNodalBasedQuantities_JDR(gca,MUA.connectivity,MUA.coordinates,mean(T_mod,1)'); 
        title(t(1),'\Delta U_{mod}');
        axis(t(1),"tight"); caxis(t(1),[0 1000]); colormap(t(1),flipud(cmocean('haline')));
        
        t(2)=nexttile; hold on; 
        PlotNodalBasedQuantities_JDR(gca,MUA.connectivity,MUA.coordinates,mean(T_mod_reproj,1)'); 
        title(t(2),'Truncated \Delta U_{mod}');
        axis(t(2),"tight"); caxis(t(2),[0 1000]); colormap(t(2),flipud(cmocean('haline')));
        
        t(3)=nexttile; hold on; 
        PlotNodalBasedQuantities_JDR(gca,MUA.connectivity,MUA.coordinates,mean(T_mod,1)'-mean(T_mod_reproj,1)'); 

        
        if domain == "AMUND"
            axis(t(3),"equal");
            caxis(t(3),[-1e-13 1e-13]);
        else
            caxis(t(3),[-1e-12 1e-12]);
        end

        axis(t(3),"tight","off"); colormap(t(3),flipud(cmocean('balance')));
        
        cb = colorbar(t(3));
        cb.Label.String = "$\langle\Delta u_{\rm mod} - \hat{\Delta u}_{\rm mod}\rangle_{\rm ensemble}\;{\rm [m/yr]}$";
        cb.Label.Interpreter = "Latex";
        cb.FontSize = 14;
        cb.Layout.Tile = "East";
        
        title(tlo,strrep(SVD_filetoread+", SVD truncation: "+string(T_nComp)+" components, "+string(SVD_targetpercentage*100)+"%.","_","\_"));

        pos = get(H,"Position");
        set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
        Hname = "./Figures/"+domain+"_DeltaU_Modelled_vs_Truncated.png";
        print(H,Hname,"-dpng","-r400");

    end
end

%% scramble data
% TODO: no random seed is set (rng); the permutation seq is saved in the output files
seq = randperm(num_exp);
data = T_hat(seq,:);
predictors = X(seq,:);

%% WRITE OUTPUTS for tensorflow
if write_outputs_for_TF
    % split targets and predictors into training, cross-validation and test
    % datasets
    val_idx = floor(num_exp*0.8);
    test_idx = floor(num_exp*0.1) + val_idx;
    
    T_train = data(1:val_idx,:); num_train = size(T_train,1);
    T_val = data(val_idx+1:test_idx,:); num_val = size(T_val,1);
    T_test = data(test_idx+1:end,:); num_test = size(T_test,1);
    
    X_train = predictors(1:val_idx,:);
    X_val = predictors(val_idx+1:test_idx,:);
    X_test = predictors(test_idx+1:end,:);

    % need to feed normalized data to tensorflow
    [X_train,X_train_C,X_train_S]=normalize(X_train);
    X_val = (X_val-repmat(X_train_C,num_val,1))./repmat(X_train_S,num_val,1);
    X_test = (X_test-repmat(X_train_C,num_test,1))./repmat(X_train_S,num_test,1);

    [T_train,T_train_C,T_train_S]=normalize(T_train);
    T_val = (T_val-repmat(T_train_C,num_val,1))./repmat(T_train_S,num_val,1);
    T_test = (T_test-repmat(T_train_C,num_test,1))./repmat(T_train_S,num_test,1);

    fname1 = sprintf('./Emulators/%s/RNN/mat_files/data_%s_%s_%s-%s_%s_cycle%s_floatingice%s_includemeasurements%s_Basis_%s-Comp%s-Var%s',...
        domain,domain,perturbation,startyear,targetyear,...
        join(slidinglaw,"-"),join(string(cycle),"-"),string(1-only_grounded_ice),string(add_measurements_to_SVD),...
        strrep(SVD_basistoread,"_","-"),...
        string(T_nComp),strrep(string(round(SVD_targetpercentage*1e4)/1e2),".","k"));
    fname2 = sprintf('./Emulators/%s/RNN/mat_files/SVD_%s_%s_%s-%s_%s_cycle%s_floatingice%s_includemeasurements%s_Basis_%s-Comp%s-Var%s',...
        domain,domain,perturbation,startyear,targetyear,...
        join(slidinglaw,"-"),join(string(cycle),"-"),string(1-only_grounded_ice),string(add_measurements_to_SVD), ...
        strrep(SVD_basistoread,"_","-"),...
        string(T_nComp),strrep(string(round(SVD_targetpercentage*1e4)/1e2),".","k"));
    save(fname1,'X_train','X_val','X_test','T_train','T_val','T_test',...
        'X_train_C','X_train_S','T_train_C','T_train_S');
    save(fname2, 'T_mean','V_trunc', 'S_trunc', 'B_trunc', 'T_reproj', 'T_pct','seq');
end

%% PLOTTING

if do_plots

    CtrlVar=Ua2D_DefaultParameters;
    CtrlVar.PlotXYscale = 1e3;

    cumulative_variance = cumsum(diag(S).^2)/sum(diag(S).^2);
    
    H=fig('units','inches','width',100*12/72.27,'height',25*12/72.27,'fontsize',14,'font','Helvetica');
    tlo4=tiledlayout(1,5,'TileSpacing','tight');

    for ii=1:min(size(V_trunc,2),5)

        nexttile;
        PlotNodalBasedQuantities_JDR(gca,MUA.connectivity,MUA.coordinates,V_trunc(:,ii),CtrlVar);
        colormap(cmocean('curl'));
        variance =100*[cumulative_variance(1); cumulative_variance(2:end)-cumulative_variance(1:end-1)];
        title(['mode ',num2str(ii),' (',num2str(variance(ii),'%2.2f'),'%  /  ',num2str(100*cumulative_variance(ii),'%2.2f'),'%)']); caxis([-0.05 0.05]);

        if domain=="AMUND"
            axis equal;
            caxis([-0.01 0.01]);
        end
        
        axis tight; axis off;
    
    end

    pos = get(H,"Position");
    set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
    Hname = "./Figures/"+domain+"_SVD_5DominantModes.png";
    print(H,Hname,"-dpng","-r400");

    cb.Layout.Tile = 'east';
    
    %% singular values
    figure, subplot(1,2,1)
    semilogy(diag(S),'k','linewidth',2); grid on;
    xlabel('r');
    ylabel('singlar value, \sigma_r');
    set(gca,'fontsize',14);
    subplot(1,2,2)
    plot(cumulative_variance,'k','linewidth',2); grid on;
    xlabel('r');
    ylabel('cumulative energy');
    set(gca,'fontsize',14);
end
