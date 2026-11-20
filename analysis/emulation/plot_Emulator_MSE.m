function plot_Emulator_MSE
% plot_Emulator_MSE  Evaluate the RNN emulator on the test data, make Figure A3 and save the emulator error used in the Bayesian inference.
%
% PURPOSE
%   Predicts the (normalised) SVD coefficients of the training, validation and test data with the trained RNN emulator (a
%   TensorFlow model imported in MATLAB), undoes the normalisation, and
%     - plots the emulator output against the target for each SVD mode, with the R^2 of the test data (Figure A3);
%     - calculates the mean squared error between emulated and simulated (Ua) change in speed over the test data,
%       mse_RNN = 1/(N_test-1)*sum((emulated - simulated).^2), per mode of the truncated SVD basis (1 x number of modes, in the
%       units of the SVD coefficients), and saves it in MSE_RNN_<modelversion>_<...>.mat in the folder of the SVD file (the name of the SVD
%       file in which "SVD" is replaced by "MSE_RNN_<modelversion>"); Calc_BayesianInference reads it and uses
%       diag(mse_RNN) as the covariance of the emulator error;
%     - maps the nodal rmse between emulator and Ua over the training, validation and test data, prints the area-averaged rmse, and
%       plots the rmse of each sample against the parameters;
%     - for the test cases in n_test, maps the simulated, truncated and emulated change in speed.
%
% USER SETTINGS (top of the function)
%   modelversion, domain ("AMUND" or "SYNTH_PIG"), perturbation ("Calv_dh" or "dh"), trainingdataformat ("u" or "LOGu"), startyear,
%   targetyear (an empty string: emulator of the speed instead of the change in speed), slidinglaw (a vector),
%   cycle, only_grounded_ice, include_measurements, SVDcomponents, n_test.
%   Figure A3 (AMUND): modelversion "v4_tuned_model_full", domain "AMUND", perturbation "Calv_dh", startyear "2000", targetyear
%   "2020", slidinglaw ["Weertman" "Umbi"], cycle 2, SVDcomponents 25 (the settings of the SYNTH_PIG emulators, as set below, are
%   "v5_tuned_model_full", "dh", "Weertmanyr30", "Weertmanyr75", SVDcomponents 10).
%
% FILES READ (data; can be obtained upon request from the author, see README)
%   ./diagnosticdata/<domain>/<domain>_Delta_u_<years>[_<slidinglaw>].mat, and in ./emulators/<domain>: the trained TensorFlow model in
%   TF_files and the data_*.mat and SVD_*.mat files in mat_files (written by prepare_data_for_Delta_u_emulators and
%   RNN_network_optimisation_JDR.py)
%
% REQUIRES
%   Ua source code (Ua2D_DefaultParameters, UpdateMUA, FEintegrate2D, PlotMeshScalarVariable, PlotGroundingLines); MATLAB Deep
%   Learning Toolbox with the Converter for TensorFlow Models (or the Python interface with Keras for .keras
%   models), Statistics and Machine Learning Toolbox (fitlm); fig, othercolor, crameri (third party)

plotRNN=1;

modelversion = "v5_tuned_model_full";
domain="SYNTH_PIG"; % AMUND or SYNTH_PIG
perturbation="dh"; % Calv_dh or dh
trainingdataformat="u"; % u or LOGu
startyear="Weertmanyr30"; % 2000 for AMUND, e.g. Weertmanyr30 fo SYNTH_PIG
targetyear="Weertmanyr75"; % 2009, 2014, 2020 for AMUND, 35 for SYNTH_PIG. this can be an empty string to plot results for the u emulator, rather than the du emulator
slidinglaw=["Weertman" "Umbi"];
cycle=2;
only_grounded_ice=1;
include_measurements = 0;
SVDcomponents=10;
n_test=[];%[1:20]; % indices of test data to plot (integers between 1 and size of test dataset)

if targetyear ~= ""
    T=[];
    for ss=1:numel(slidinglaw)
        years=startyear+"-"+targetyear;
        try
            datafile = "./diagnosticdata/"+lower(domain)+"/"+domain+"_Delta_u_"+years+"_"+slidinglaw(ss)+".mat";
            tmp=load(datafile);
            MUA = tmp.MUA_yr2; GF = tmp.GF_yr2;
            Ttmp = tmp.Delta_u.(perturbation).map(:,:,cycle);
            T = [T; Ttmp];
        catch
            datafile = "./diagnosticdata/"+lower(domain)+"/"+domain+"_Delta_u_"+years+".mat";
            tmp=load(datafile);
            MUA =tmp.MUA_yr2; GF = tmp.GF_yr2;
            T = tmp.Delta_u.(perturbation).map(:,:,cycle);
            break
        end
    end
else
    years = trainingdataformat+startyear;
    datafile = "u_"+domain+"_"+perturbation+"_cycle"+string(cycle)+"_"+slidinglaw+"_"+startyear+".mat";
    load(datafile);
    T = speed.("yr"+string(startyear));
    MUA = MUA.("yr"+string(startyear)); GF = GF.("yr"+string(startyear));
    if trainingdataformat=="LOGu"
        T = log10(T);
    end
end

% check for nans and inf
if any(isnan(T))
    warning("Removing nan from T");
    [rows,~]=find(isnan(T));
    rows = unique(rows);
    T(rows,:)=[];
end
T_mean = mean(T,1);
T = T-repmat(T_mean(:)',size(T,1),1);

% remove floating ice?
if only_grounded_ice
    % remove floating nodes
    Nodes_floating = find(GF.node<0.5);
    T(:,Nodes_floating) = 0;
    T_mean(Nodes_floating) = 0;
end

%% RNN Tensorflow
if plotRNN

    TF_dir = dir("./emulators/"+lower(domain)+"/"+modelversion+"_"+domain+"_"+perturbation+"_"+years+...
        "_"+join(slidinglaw,"-")+"_cycle"+string(cycle)+"_floatingice"+string(1-only_grounded_ice)+...
        "_includemeasurements"+string(include_measurements)+"_*Comp"+string(SVDcomponents)+"*");

    if contains(TF_dir.name,".keras")
        netUpdated =  py.keras.models.load_model(TF_dir.folder+"/"+TF_dir.name, compile=false);
    else
        net=importNetworkFromTensorFlow(TF_dir.folder+"/"+TF_dir.name);
        netUpdated=initialize(net);
    end

    data_file = dir("./emulators/"+lower(domain)+"/data_"+domain+"_"+perturbation+"_"+years+...
        "_"+join(slidinglaw,"-")+"_cycle"+string(cycle)+"_floatingice"+string(1-only_grounded_ice)+...
        "_includemeasurements"+string(include_measurements)+"_*Comp"+string(SVDcomponents)+"*.mat");
    load(data_file.folder+"/"+data_file.name);

    SVD_file = dir("./emulators/"+lower(domain)+"/SVD_"+domain+"_"+perturbation+"_"+years+...
        "_"+join(slidinglaw,"-")+"_cycle"+string(cycle)+"_floatingice"+string(1-only_grounded_ice)+...
        "_includemeasurements"+string(include_measurements)+"_*Comp"+string(SVDcomponents)+"*.mat");
    load(SVD_file.folder+"/"+SVD_file.name);

    num_train = size(X_train,1);
    num_val = size(X_val,1);
    num_test = size(X_test,1);

    % emulate predictors
    if contains(TF_dir.name,".keras")
        Y_train = double(netUpdated.predict(py.numpy.array(X_train)));
        Y_val = double(netUpdated.predict(py.numpy.array(X_val)));
        Y_test = double(netUpdated.predict(py.numpy.array(X_test)));
    else
        Y_train=double(predict(netUpdated,X_train));
        Y_val=double(predict(netUpdated,X_val));
        Y_test=double(predict(netUpdated,X_test));
    end

    H=fig('name','MSE emulator','units','inches','width',100*12/72.27,'height',80*12/72.27,'fontsize',14,'font','Helvetica');
    ntiles = size(T_train,2);
    tlo = tiledlayout(ceil(sqrt(ntiles)),ceil(sqrt(ntiles)),"TileSpacing","loose","Padding","loose");
    for m=1:size(T_train,2)
        tile(m)=nexttile(tlo); hold on;
    end
    for m=1:size(T_train,2)
        g(1)=plot(tile(m),T_train(:,m),Y_train(:,m),'ok');
        g(2)=plot(tile(m),T_val(:,m),Y_val(:,m),'xg');
        g(3)=plot(tile(m),T_test(:,m),Y_test(:,m),'dm');
        mdl = fitlm(T_test(:,m),Y_test(:,m));
        R2(m) = mdl.Rsquared.Ordinary;
        title(tile(m),"mode "+num2str(m));
        xvec = xlim(tile(m));
        g(4)=plot(tile(m),[-10 10],[-10 10],'--k');
        xlim(tile(m),xvec); ylim(tile(m),xvec);
        grid(tile(m),"on"); box(tile(m),"on");
        xlabel(tile(m),[]); ylabel(tile(m),[]);
    end

    for m=1:size(T_train,2)
        pos = get(tile(m), 'position'); %[x,y,w,h]
        annotation('textbox',[pos(1)+0.1*pos(3),pos(2)+0.8*pos(4),0.5*pos(3),0.2*pos(4)],'string',"R^2 test data: "+sprintf('%3.2f',R2(m)),'FitBoxToText','on','VerticalAlignment','middle','HorizontalAlignment','center');
    end

    lg=legend(g(:),["training data","validation data","test data","target = emulated"]);
    lg.Layout.Tile = "north";
    lg.NumColumns=4;
    xlabel(tlo,"Target data"); ylabel(tlo,"Emulator output");

    % reconstruct spatial maps of emulated targets
    Y_train = Y_train.*repmat(T_train_S,num_train,1)+...
        repmat(T_train_C,num_train,1); % undo normalization
    Y_train_reproj = Y_train*B_trunc;% reproject onto nodal basis
    Y_val = Y_val.*repmat(T_train_S,num_val,1)+...
        repmat(T_train_C,num_val,1); % undo normalization
    Y_val_reproj = Y_val*B_trunc;% reproject onto nodal basis
    Y_test = Y_test.*repmat(T_train_S,num_test,1)+...
        repmat(T_train_C,num_test,1); % undo normalization
    Y_test_reproj = Y_test*B_trunc;% reproject onto nodal basis

    % ua outputs
    Ind_train_orig = seq(1:num_train);
    Ua_train_orig = T(Ind_train_orig,:);
    Ua_train_proj = Ua_train_orig*T_reproj';
    Ind_val_orig = seq(num_train+1:num_train+num_val);
    Ua_val_orig = T(Ind_val_orig,:);
    Ua_val_proj = Ua_val_orig*T_reproj';
    Ind_test_orig = seq(num_train+num_val+1:end);
    Ua_test_orig = T(Ind_test_orig,:);
    Ua_test_proj = Ua_test_orig*T_reproj';

    % sample data
    X_train_tmp = X_train.*repmat(X_train_S,num_train,1) + repmat(X_train_C,num_train,1);
    X_val_tmp = X_val.*repmat(X_train_S,num_val,1) + repmat(X_train_C,num_val,1);
    X_test_tmp = X_test.*repmat(X_train_S,num_test,1) + repmat(X_train_C,num_test,1);

    % reconstruct original target data
    T_test = T_test.*repmat(T_train_S,num_test,1)+...
        repmat(T_train_C,num_test,1); % undo normalization
    T_test = T_test*B_trunc;% reproject onto nodal basis

    %% calc mse of test data
    % ensemble mean in nodal basis
    mse_test = (Y_test_reproj-Ua_test_orig).^2;
    mse_test_ensemblemean = 1/(num_test-1)*sum(mse_test,1);
    % per sample
    CtrlVar = Ua2D_DefaultParameters;
    MUA = UpdateMUA(CtrlVar,MUA);
    for ss=1:size(Y_test_reproj,1)
        rmse_test_sample(ss) = sum(FEintegrate2D([],MUA,sqrt(mse_test(ss,:))'))./sum(FEintegrate2D([],MUA,0*mse_test(ss,:)'+1));
    end
    rmse_test_mean = mean(rmse_test_sample);
    fprintf("rmse between emulator and Ua over the test set, averaged over nodal domain: %4.2f m/yr\n",rmse_test_mean);

    % in truncated svd basis
    mse_RNN=1/(num_test-1)*sum((Y_test-Ua_test_proj).^2,1);

    MSE_file.name = strrep(SVD_file.name,"SVD","MSE_RNN_"+modelversion);
    MSE_file.folder = SVD_file.folder;
    save(MSE_file.folder+"/"+MSE_file.name,"mse_RNN");

    % plot some maps for particular test case
    for nn=n_test
        predictorvalues = X_test(nn,:).*X_train_S + X_train_C;
        Ua_test_orig_tmp = Ua_test_orig(nn,:);
        Y_test_reproj_tmp = Y_test_reproj(nn,:);
        T_test_tmp = T_test(nn,:);
        plot_comparison_emulator_ua(T_mean,Ua_test_orig_tmp,T_test_tmp,Y_test_reproj_tmp,MUA,GF,"",predictorvalues,trainingdataformat);
    end

    % plot mse for different svd trunctions
    plot_mse_nodal(mse_test_ensemblemean,"test","",MUA,GF);

    %% calc mse of training data
    % ensemble mean in nodal basis
    mse_train = (Y_train_reproj-Ua_train_orig).^2;
    mse_train_ensemblemean = 1/(num_train-1)*sum(mse_train,1);
    % per sample
    for ss=1:size(Y_train_reproj,1)
        rmse_train_sample(ss) = sum(FEintegrate2D([],MUA,sqrt(mse_train(ss,:))'))./sum(FEintegrate2D([],MUA,0*mse_train(ss,:)'+1));
    end
    rmse_train_mean = mean(rmse_train_sample);
    fprintf("rmse between emulator and Ua over the training set, averaged over nodal domain: %4.2f m/yr\n",rmse_train_mean);
    plot_mse_nodal(mse_train_ensemblemean,"training","",MUA,GF);

    %% calc mse of validation data
    % ensemble mean in nodal basis
    mse_val = (Y_val_reproj-Ua_val_orig).^2;
    mse_val_ensemblemean = 1/(num_val-1)*sum(mse_val,1);
    % per sample
    for ss=1:size(Y_val_reproj,1)
        rmse_val_sample(ss) = sum(FEintegrate2D([],MUA,sqrt(mse_val(ss,:))'))./sum(FEintegrate2D([],MUA,0*mse_val(ss,:)'+1));
    end
    rmse_val_mean = mean(rmse_val_sample);
    fprintf("rmse between emulator and Ua over the validation set, averaged over nodal domain: %4.2f m/yr\n",rmse_val_mean);
    plot_mse_nodal(mse_val_ensemblemean,"validation","",MUA,GF);

    %% plot mse in sample space
    plot_mse_sample(X_train_tmp,X_val_tmp,X_test_tmp,rmse_train_sample,rmse_val_sample,rmse_test_sample);
end

end

function plot_comparison_emulator_ua(T_mean,T_orig,Y_reproj_orig,Y_reproj,MUA,GF,pct,predictorvalues,trainingdataformat)

CM = crameri('batlow',15);
CM2 = flipdim(othercolor('RdYlBu11',15),1);

CtrlVar=Ua2D_DefaultParameters;
CtrlVar.PlotXYscale=1e3;
CtrlVar.PlotsXaxisLabel='' ;
CtrlVar.PlotsYaxisLabel='' ;

H=fig('units','inches','width',120*12/72.27,'height',60*12/72.27,'fontsize',14,'font','Helvetica');

tlo=tiledlayout(H,1,3,"TileSpacing","tight");

ax(1)=nexttile; hold on;
data_to_plot = T_orig(:);
PlotMeshScalarVariable(CtrlVar,MUA,data_to_plot);
PlotGroundingLines(CtrlVar,MUA,GF,[],[],[],'color','k');
plot(MUA.Boundary.x/CtrlVar.PlotXYscale,MUA.Boundary.y/CtrlVar.PlotXYscale,'-k','LineWidth',0.5);
colormap(ax(1),CM2);
cb=colorbar;
if trainingdataformat == "LOGu"
    caxis(ax(1),[-1 1]);
    cb.Label.String='log_{10}u [m/yr]';
else
    caxis(ax(1),[-300 300]);
    cb.Label.String='u [m/yr]';
end
axis equal; axis tight;
grid(ax(1),"off"); box(ax(1),"off"); axis(ax(1),"off");
yticklabels([]); xticklabels([]);
title('Ua');

ax(2)=nexttile; hold on;
data_to_plot = Y_reproj_orig(:);
PlotMeshScalarVariable(CtrlVar,MUA,data_to_plot);
PlotGroundingLines(CtrlVar,MUA,GF,[],[],[],'color','k');
plot(MUA.Boundary.x/CtrlVar.PlotXYscale,MUA.Boundary.y/CtrlVar.PlotXYscale,'-k','LineWidth',0.5);
colormap(ax(2),CM2); colorbar('off');
if trainingdataformat == "LOGu"
    caxis(ax(2),[-1 1]);
else
    caxis(ax(2),[-300 300]);
end
axis equal; axis tight;
grid(ax(2),"off"); box(ax(2),"off"); axis(ax(2),"off");
yticklabels([]); xticklabels([]);
title("Truncated SVD ("+pct+"%)");

ax(3)=nexttile; hold on;
data_toplot = Y_reproj(:);
PlotMeshScalarVariable(CtrlVar,MUA,data_toplot);
PlotGroundingLines(CtrlVar,MUA,GF,[],[],[],'color','k');
plot(MUA.Boundary.x/CtrlVar.PlotXYscale,MUA.Boundary.y/CtrlVar.PlotXYscale,'-k','LineWidth',0.5);
colormap(ax(3),CM2); cb2=colorbar;
if trainingdataformat == "LOGu"
    cb2.Label.String='u [m/yr]';
    caxis(ax(3),[-1 1]);
else
    cb2.Label.String='\Delta u [m/yr]';
    caxis(ax(3),[-300 300]);
end
title("Emulator");

axis equal; axis tight;
grid(ax(3),"off"); box(ax(3),"off"); axis(ax(3),"off");
yticklabels([]); xticklabels([]);

if numel(predictorvalues)==6
    title(tlo,sprintf('log10(gaA)=%3.1f, log10(gaC)=%3.1f, log10(gsA)=%3.1f, log10(gsC)=%3.1f, m=%2.2f, n=%2.2f',...
        predictorvalues));
else
    title(tlo,sprintf(['log10(gaA)=%3.1f, log10(gaC)=%3.1f, log10(gsA)=%3.1f, log10(gsC)=%3.1f, m=%2.2f, n=%2.2f, log10(dhdterr)=%3.1f'],...
        predictorvalues));
end

pos = get(H,"Position");
set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
fname = "./Figures/Deltau_example";
print(H,fname,"-dpng","-r400");

end

function plot_mse_nodal(mse,exp,pct,MUA,GF)

    %% mean rmse
    H=fig('units','inches','width',120*12/72.27,'height',30*12/72.27,'fontsize',14,'font','Helvetica');

    tlo=tiledlayout(1,numel(pct),"TileSpacing","tight");

    CM = flipdim(othercolor('RdYlBu7',15),1);
    CM2 = flipdim(othercolor('RdBu11',15),1);
    CtrlVar=Ua2D_DefaultParameters;
    CtrlVar.PlotXYscale=1e3;
    CtrlVar.PlotsXaxisLabel='' ;
    CtrlVar.PlotsYaxisLabel='' ;

    rmse = sqrt(mse);

    for ii=1:numel(pct)
        ax(ii)=nexttile; hold on;

        if ii==1
            PlotMeshScalarVariable(CtrlVar,MUA,log10(rmse(ii,:)'));
            caxis(ax(ii),[0 4]); colormap(ax(ii),CM);
            cb=colorbar; cb.Label.String='log_{10}(rmse) between emulator and Ua [m^2/yr^2]';
        else
            PlotMeshScalarVariable(CtrlVar,MUA,log10(rmse(ii,:)')-log10(rmse(1,:)'));
            caxis(ax(ii),[-1 1]); colormap(ax(ii),CM2);
            if ii==numel(pct)
                cb=colorbar; cb.Label.String='log_{10}(rmse_{pct}) - log_{10}(rmse_{95})';
            else
                colorbar("off");
            end
        end
        PlotGroundingLines(CtrlVar,MUA,GF,[],[],[],'color','k');
        plot(MUA.Boundary.x/CtrlVar.PlotXYscale,MUA.Boundary.y/CtrlVar.PlotXYscale,'-k','LineWidth',0.5);

        axis equal; axis tight;
        grid(ax(ii),"off"); box(ax(ii),"off"); axis(ax(ii),"off");
        yticklabels([]); xticklabels([]);
        title(exp+"  , "+pct(ii)+"%");
    end

end

%% rmse for each parameter
function plot_mse_sample(X_train,X_val,X_test,rmse_train,rmse_val,rmse_test)

    nparam = size(X_train,2);
    labels = ["Sliding law","log10(gaA)","log10(gaC)","log10(gsA)","log10(gsC)","m","n","log10(dhdt)"];

    H=fig('units','inches','width',120*12/72.27,'height',30*12/72.27,'fontsize',14,'font','Helvetica');

    tlo=tiledlayout(1,nparam,"TileSpacing","tight");

    for m=1:nparam
        nexttile; hold on;
        g(1)=plot(X_train(:,m),rmse_train,'ok');
        g(2)=plot(X_val(:,m),rmse_val,'xg');
        g(3)=plot(X_test(:,m),rmse_test,'dm');

        grid on; box on;
        if m>1
            yticklabels([]);
        end
        xlabel(labels(m));
    end

end
