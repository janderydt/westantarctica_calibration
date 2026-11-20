function plot_PerturbationResults_Ensemble(domain,diagnostic_to_plot,parameter_to_plot,cycles_to_plot,slidinglaw,startyear,targetyear,file_with_perturbation_data_to_read,file_with_perturbation_data_to_write)
% plot_PerturbationResults_Ensemble  Analyse and plot the diagnostic (perturbation) experiments of the ensemble and write the Delta_u files.
%
% PURPOSE
%   Reads the collected results of the diagnostic experiments (data of Calc_PerturbationResults_Ensemble) and of the
%   inversions (data of Calc_InverseResults_Ensemble) of the ensemble members, and depending on diagnostic_to_plot
%     "Delta_u"   : calculates for every member, perturbation (Calv, dhIS, dh, Calv_dh) and inversion cycle the change in speed
%                   between the start year and the target year (nodal maps and means over the basins of interest), saves these together with the
%                   inversion parameters in file_with_perturbation_data_to_write, and plots the ensemble mean and standard
%                   deviation of the log10 change in speed next to the observed change (and misfits between modelled
%                   and observed changes);
%     "Delta_qGL" / "Delta_qOB" : plots the change in grounding line / open boundary flux of the perturbation experiments
%                   against one of the parameters m, n, gaA, gaC, gsA, gsC (next to it a histogram of the values returned by
%                   Calc_Delta_qGL and the change in discharge of Rignot et al. 2019).
%   The file written for "Delta_u" is the Delta_u file read by Calc_SVD_basis and loadvelocitydata:
%   ./diagnosticdata/<domain>/<domain>_Delta_u_<startyear>-<targetyear>[_<slidinglaw>].mat with the variables Delta_u
%   (Delta_u.<perturbation>.map: members x nodes x cycles, and .<basin>: means), MUA_yr1, MUA_yr2, GF_yr1, GF_yr2, misfit, gsA,
%   gsC, gaA, gaC, dhdt_err, m, n, slidinglaw. The file is only written if file_with_perturbation_data_to_write is given
%   (see the example below).
%
% INPUTS (arguments; without arguments the values for AMUND below are used)
%   domain, diagnostic_to_plot, parameter_to_plot, cycles_to_plot, slidinglaw (e.g. "Weertman" and/or "Umbi", or "HPDSample"),
%   startyear, targetyear, file_with_perturbation_data_to_read, file_with_perturbation_data_to_write
%
% FILES READ (data; can be obtained upon request from the author, see README)
%   ./diagnosticdata/<domain>/<domain>_<startyear>_perturbationdata.mat (Calc_PerturbationResults_Ensemble),
%   ./inversiondata/<domain>/<domain>_<startyear>_inversiondata_<slidinglaw>.mat (Calc_InverseResults_Ensemble),
%   ./diagnosticdata/<domain>/<domain>_perturbation_grids.mat (meshes MUA_<year> and grounding masks GF_<year> of the
%   years), basins_IMBIE_v2.mat in the current folder, and for "Delta_u" the extruded velocity and geometry interpolants in
%   ../ua_input/1_interpolants
%
% REQUIRES
%   Ua source code (Ua2D_DefaultParameters, DeactivateMUAelements, FEintegrate2D, PlotMeshScalarVariable,
%   PlotGroundingLines), Define_Quantity_PerBasin (ua_input/2_meshing), RemoveIceRisesAndIslands (same folder);
%   fig, othercolor, PlotNodalBasedQuantities_JDR (third party / modified Ua plotting function, must be on the MATLAB
%   path); Calc_Delta_qGL (same folder; for "Delta_qGL")

%% example usage:
% domain = "SYNTH_PIG";
% parameter_to_plot = 'gsA'; % m, n, gaA, gaC, gsA, gsC
% cycles_to_plot = [1 2]; %[1 2]
% slidinglaw = ["Weertman" "Umbi"]; % Weertman or Umbi or HPDSample
% startyear = "Weertmanyr30";
% targetyear =  "Weertmanyr50";
% diagnostic_to_plot = "Delta_u";
% file_with_perturbation_data_to_read = "./diagnosticdata/"+lower(domain)+"/"+domain+"_"+startyear+"_perturbationdata.mat";
% file_with_perturbation_data_to_write = "./diagnosticdata/"+lower(domain)+"/"+domain+"_Delta_u_"+startyear+"-"+targetyear+"_"+slidinglaw+".mat";
% plot_PerturbationResults_Ensemble(domain,diagnostic_to_plot,parameter_to_plot,cycles_to_plot,slidinglaw,startyear,targetyear,...
%   file_with_perturbation_data_to_read,file_with_perturbation_data_to_write);

if nargin==0
    domain = "AMUND";
    diagnostic_to_plot = "Delta_u"; % Delta_qGL, Delta_qOB, Delta_u
    parameter_to_plot = "gsA"; % m, n, gaA, gaC, gsA, gsC
    cycles_to_plot = [1 2]; %[1 2]
    slidinglaw = "Weertman"; % Weertman or Umbi
    startyear = "2000";
    targetyear =  "2020";
    file_with_perturbation_data_to_read = "./diagnosticdata/"+lower(domain)+"/"+domain+"_"+startyear+"_perturbationdata.mat";
end

if contains(domain,"AMUND")
    basins_to_analyze = {'F-G',...  % Getz
        'G-H',...  % PIG, Thwaites
        'H-Hp'}; % Abbott
    % load basins
    filename = 'basins_IMBIE_v2.mat';
    B = load(filename);
    B = RemoveIceRisesAndIslands(B);

elseif contains(domain,"SYNTH_PIG")
    basins_to_analyze = {'SYNTH_PIG'};
    B.name = {'SYNTH_PIG'};
    B.x = {[-1e10 1e10 1e10 -1e10]'};
    B.y = {[-1e10 -1e10 1e10 1e10]'};
    B.x_center = 0;
    B.y_center = 0;
else
    error("Domain unknown");
end

CtrlVar=Ua2D_DefaultParameters;

%% prepare meshes
if diagnostic_to_plot=="Delta_u"

    UserVar.casefolder=pwd;
    UserVar.datafolder=pwd+"/../ua_input/";
    UserVar.Experiment="";

    %% corresponding GF masks
    if contains(domain,"AMUND")
        load("./diagnosticdata/amund/AMUND_perturbation_grids.mat");
        switch startyear
            case "2000"
                MUA_yr1 = MUA_2000;
                GF_yr1 = GF_2000;
            case "2009"
                MUA_yr1 = MUA_2009;
                GF_yr1 = GF_2009;
            case "2014"
                MUA_yr1 = MUA_2014;
                GF_yr1 = GF_2014;
            case "2018"
                MUA_yr1 = MUA_2018;
                GF_yr1 = GF_2018;
            case "2020"
                MUA_yr1 = MUA_2020;
                GF_yr1 = GF_2020;
        end
        switch targetyear
            case "2000"
                MUA_yr2 = MUA_2000;
                GF_yr2 = GF_2000;
            case "2009"
                MUA_yr2 = MUA_2009;
                GF_yr2 = GF_2009;
            case "2014"
                MUA_yr2 = MUA_2014;
                GF_yr2 = GF_2014;
            case "2018"
                MUA_yr2 = MUA_2018;
                GF_yr2 = GF_2018;
            case "2020"
                MUA_yr2 = MUA_2020;
                GF_yr2 = GF_2020;
        end
    elseif contains(domain,"SYNTH_PIG")
        load("./diagnosticdata/synth_pig/SYNTH_PIG_perturbation_grids.mat");
        switch startyear
            case "Weertmanyr30"
                MUA_yr1 = MUA_Weertmanyr30;
                GF_yr1 = GF_Weertmanyr30;
            case "Umbiyr30"
                MUA_yr1 = MUA_Umbiyr30;
                GF_yr1 = GF_Umbiyr30;
        end
        switch targetyear
            case "Weertmanyr35"
                MUA_yr2 = MUA_Weertmanyr35;
                GF_yr2 = GF_Weertmanyr35;
            case "Weertmanyr40"
                MUA_yr2 = MUA_Weertmanyr40;
                GF_yr2 = GF_Weertmanyr40;
            case "Weertmanyr45"
                MUA_yr2 = MUA_Weertmanyr45;
                GF_yr2 = GF_Weertmanyr45;
            case "Weertmanyr50"
                MUA_yr2 = MUA_Weertmanyr50;
                GF_yr2 = GF_Weertmanyr50;
            case "Weertmanyr75"
                MUA_yr2 = MUA_Weertmanyr75;
                GF_yr2 = GF_Weertmanyr75;
            case "Umbiyr35"
                MUA_yr2 = MUA_Umbiyr35;
                GF_yr2 = GF_Umbiyr35;
            case "Umbiyr40"
                MUA_yr2 = MUA_Umbiyr40;
                GF_yr2 = GF_Umbiyr40;
            case "Umbiyr45"
                MUA_yr2 = MUA_Umbiyr45;
                GF_yr2 = GF_Umbiyr45;
            case "Umbiyr50"
                MUA_yr2 = MUA_Umbiyr50;
                GF_yr2 = GF_Umbiyr50;
        end
    end

    % identify basin id of each MUA node
    [MUA_yr1.basins,~] = Define_Quantity_PerBasin(MUA_yr1.coordinates(:,1),MUA_yr1.coordinates(:,2),B,0);
    MUA_basinnames = erase({MUA_yr1.basins(:).name},'-');
    basinnodes_all = [];
    for bb=1:numel(basins_to_analyze)
        basin = char(erase(basins_to_analyze{bb},'-'));
        [~,BasinInd] = ismember(basin,MUA_basinnames);
        basinnodes = MUA_yr1.basins(BasinInd).ind;
        basinnodes_all = [basinnodes_all; basinnodes];
    end
    ElementsToBeDeactivated=any(~ismember(MUA_yr1.connectivity,basinnodes_all),2);
    [MUA_yr1,MUA_yr1.k,MUA_yr1.l]=DeactivateMUAelements(CtrlVar,MUA_yr1,ElementsToBeDeactivated);
    Ind_nan = find(isnan(MUA_yr1.Boundary.x));
    if ~isempty(Ind_nan)
        MUA_yr1.Boundary.x = MUA_yr1.Boundary.x(1:Ind_nan(1)-1);
        MUA_yr1.Boundary.y = MUA_yr1.Boundary.y(1:Ind_nan(1)-1);
    end

    % target year
    [MUA_yr2.basins,~] = Define_Quantity_PerBasin(MUA_yr2.coordinates(:,1),MUA_yr2.coordinates(:,2),B,0);
    MUA_basinnames = erase({MUA_yr2.basins(:).name},'-');
    basinnodes_all=[];
    for bb=1:numel(basins_to_analyze)
        basin = char(erase(basins_to_analyze{bb},'-'));
        [~,BasinInd] = ismember(basin,MUA_basinnames);
        basinnodes = MUA_yr2.basins(BasinInd).ind;
        basinnodes_all = [basinnodes_all; basinnodes];
    end
    ElementsToBeDeactivated=any(~ismember(MUA_yr2.connectivity,basinnodes_all),2);
    [MUA_yr2,MUA_yr2.k,MUA_yr2.l]=DeactivateMUAelements(CtrlVar,MUA_yr2,ElementsToBeDeactivated);
    Ind_nan = find(isnan(MUA_yr2.Boundary.x));
    if ~isempty(Ind_nan)
        MUA_yr2.Boundary.x = MUA_yr2.Boundary.x(1:Ind_nan(1)-1);
        MUA_yr2.Boundary.y = MUA_yr2.Boundary.y(1:Ind_nan(1)-1);
    end

    original_node_numbers = MUA_yr1.k(find(~isnan(MUA_yr1.k)));
    GF_yr1.node=GF_yr1.node(original_node_numbers);
    original_node_numbers = MUA_yr2.k(find(~isnan(MUA_yr2.k)));
    GF_yr2.node=GF_yr2.node(original_node_numbers);
end

%% load data
if exist(file_with_perturbation_data_to_read,"file")
    load(file_with_perturbation_data_to_read,"data","perturbation_experiments_analyzed");
else
    error(file_with_perturbation_data_to_read+" does not exist");
end

data_inverse = [];

for ss=1:numel(slidinglaw)
    tmp = load("./inversiondata/"+lower(domain)+"/"+domain+"_"+startyear+"_inversiondata_"+slidinglaw(ss)+".mat");
    data_inverse = [data_inverse tmp.data];
end

if ~contains(startyear,"yr")
    startyear = "yr"+startyear;
end
if ~contains(targetyear,"yr")
    targetyear = "yr"+targetyear;
end

% available drainage basins
available_basins = fieldnames(data(1).Original.(startyear).qGL);
% check that data for basins_to_analyze is available and set up data structure
for bb=1:numel(basins_to_analyze)
    if ~ismember(erase(basins_to_analyze{bb},'-'),available_basins)
        error("Data for basin "+basins_to_analyze{bb}+" is not available.")
    end
    basin = char(erase(basins_to_analyze{bb},'-'));
    qGL_orig.(basin) = nan+zeros(numel(data),2);
    qGL_calv.(basin) = nan+zeros(numel(data),2);
    qGL_dhIS.(basin) = nan+zeros(numel(data),2);
    qGL_dh.(basin) = nan+zeros(numel(data),2);
    qGL_calvdh.(basin) = nan+zeros(numel(data),2);
end

%% gather data in a user-friendly format
qGL_orig.total = zeros(numel(data),2); qOB_orig.total = zeros(numel(data),2);
qGL_calv.total = zeros(numel(data),2); qOB_calv.total = zeros(numel(data),2);
qGL_dhIS.total = zeros(numel(data),2); qOB_dhIS.total = zeros(numel(data),2);
qGL_dh.total = zeros(numel(data),2); qOB_dh.total = zeros(numel(data),2);
qGL_calvdh.total = zeros(numel(data),2); qOB_calvdh.total = zeros(numel(data),2);

misfit = zeros(numel(data),2);
gsA = zeros(numel(data),1);
gsC = zeros(numel(data),1);
gaA = zeros(numel(data),1);
gaC = zeros(numel(data),1);
dhdt_err = zeros(numel(data),1);

Delta_u = []; Fu_original = [];

for ii=1:numel(data)

    for bb=1:numel(basins_to_analyze)

        basin = char(erase(basins_to_analyze{bb},'-'));

        switch diagnostic_to_plot

            % grounding line flux
            case "Delta_qGL"
                qGL_orig_tmp =  data(ii).Original.(startyear).qGL.(basin)(:)';
                if size(qGL_orig_tmp,2)==2
                    qGL_orig.(basin)(ii,:) = qGL_orig_tmp;
                end

                qGL_calv_tmp = data(ii).Calv.(targetyear).qGL.(basin)(:)';
                if size(qGL_calv_tmp,2)==2
                    qGL_calv.(basin)(ii,:) = qGL_calv_tmp;
                end

                qGL_dhIS_tmp = data(ii).dhIS.(targetyear).qGL.(basin)(:)';
                if size(qGL_dhIS_tmp,2)==2
                    qGL_dhIS.(basin)(ii,:) = qGL_dhIS_tmp;
                end

                qGL_dh_tmp = data(ii).dh.(targetyear).qGL.(basin)(:)';
                if size(qGL_dh_tmp,2)==2
                    qGL_dh.(basin)(ii,:) = qGL_dh_tmp;
                end

                qGL_calvdh_tmp = data(ii).Calv_dh.(targetyear).qGL.(basin)(:)';
                if size(qGL_calvdh_tmp,2)==2
                    qGL_calvdh.(basin)(ii,:) = qGL_calvdh_tmp;
                end

                if ~isempty(qGL_orig.(basin))
                    qGL_orig.total(ii,:) = qGL_orig.total(ii,:)+qGL_orig.(basin)(ii,:);
                end
                if ~isempty(qGL_calv.(basin))
                    qGL_calv.total(ii,:) = qGL_calv.total(ii,:)+qGL_calv.(basin)(ii,:);
                end
                if ~isempty(qGL_dhIS.(basin))
                    qGL_dhIS.total(ii,:) = qGL_dhIS.total(ii,:)+qGL_dhIS.(basin)(ii,:);
                end
                if ~isempty(qGL_dh.(basin))
                    qGL_dh.total(ii,:) = qGL_dh.total(ii,:)+qGL_dh.(basin)(ii,:);
                end
                if ~isempty(qGL_calvdh.(basin))
                    qGL_calvdh.total(ii,:) = qGL_calvdh.total(ii,:)+qGL_calvdh.(basin)(ii,:);
                end

            % open boundary (calving) flux
            case "Delta_qOB"
                qOB_orig.(basin)(ii,:) = data(ii).Original.(startyear).qOB.(basin)(:)';
                qOB_calv.(basin)(ii,:) = data(ii).Calv.(targetyear).qOB.(basin)(:)';
                qOB_dhIS.(basin)(ii,:) = data(ii).dhIS.(targetyear).qOB.(basin)(:)';
                qOB_dh.(basin)(ii,:) = data(ii).dh.(targetyear).qOB.(basin)(:)';
                qOB_calvdh.(basin)(ii,:) = data(ii).Calv_dh.(targetyear).qOB.(basin)(:)';
                if ~isempty(qOB_orig.(basin))
                    qOB_orig.total(ii,:) = qOB_orig.total(ii,:)+qOB_orig.(basin)(ii,:);
                end
                if ~isempty(qOB_calv.(basin))
                    qOB_calv.total(ii,:) = qOB_calv.total(ii,:)+qOB_calv.(basin)(ii,:);
                end
                if ~isempty(qOB_dhIS(basin))
                    qOB_dhIS.total(ii,:) = qOB_dhIS.total(ii,:)+qOB_dhIS.(basin)(ii,:);
                end
                if ~isempty(qOB_dh.(basin))
                    qOB_dh.total(ii,:) = qOB_dh.total(ii,:)+qOB_dh.(basin)(ii,:);
                end
                if ~isempty(qOB_calvdh.(basin))
                    qOB_calvdh.total(ii,:) = qOB_calvdh.total(ii,:)+qOB_calvdh.(basin)(ii,:);
                end

            % changes in speed - only keep data for the selected basins
            case "Delta_u"

                perturbations_to_analyze=["Calv","dhIS","dh","Calv_dh"];
                Ind_tmp=[];

                for ff=1:numel(perturbations_to_analyze)
                    if ~contains(startyear,["2000","30"])
                        if ~isfield(data(ii).(perturbations_to_analyze(ff)),startyear) ||...
                            ~isfield(data(ii).(perturbations_to_analyze(ff)),targetyear)
                            Ind_tmp = [Ind_tmp ff]; % perturbation to remove
                        end
                    else
                        if ~isfield(data(ii).(perturbations_to_analyze(ff)),targetyear)
                            Ind_tmp = [Ind_tmp ff];
                        end
                    end
                end
                perturbations_to_analyze(unique(Ind_tmp))=[];

                for ff=perturbations_to_analyze

                    if contains(ff,"Calv")
                        MUA_target = MUA_yr2;
                    else
                        MUA_target = MUA_yr1;
                    end
                    MUA_start = MUA_yr1;

                    for cc=1:size(data(ii).(ff).(targetyear).speed,2)

                        if contains(startyear,["2000","30"])
                            speed_yr1 = data(ii).Original.(startyear).speed(:,cc);
                        else
                            Ind_start = find(data(ii).(ff).(startyear).cycle==cc);
                            if ~isempty(Ind_start)
                                speed_yr1 = data(ii).(ff).(startyear).speed(:,Ind_start);
                            else
                                speed_yr1 = nan*ones(1e6,1); % some large array
                            end
                        end
                        Ind_end = find(data(ii).(ff).(targetyear).cycle==cc);
                        if ~isempty(Ind_end)
                            speed_yr2 = data(ii).(ff).(targetyear).speed(:,Ind_end);
                        else
                            speed_yr2 = nan*ones(1e6,1); % some large array
                        end

                        if contains(ff,"Calv")
                            original_node_numbers = MUA_start.k(find(~isnan(MUA_start.k)));
                            % interpolate original and perturbed speed to same grid
                            if isempty(Fu_original)
                                Fu_original = scatteredInterpolant(MUA_start.coordinates(:,1),MUA_start.coordinates(:,2),speed_yr1(original_node_numbers),"natural","boundary");
                            else
                                Fu_original.Values = speed_yr1(original_node_numbers);
                            end
                            u_original_interp = Fu_original(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
                            original_node_numbers = MUA_target.k(find(~isnan(MUA_target.k)));
                            du = speed_yr2(original_node_numbers)-u_original_interp;
                        else
                            original_node_numbers = MUA_target.k(find(~isnan(MUA_target.k)));
                            du = speed_yr2(original_node_numbers) - speed_yr1(original_node_numbers);
                        end
                        Intdu=FEintegrate2D(CtrlVar,MUA_target,du);
                        IntA=FEintegrate2D(CtrlVar,MUA_target,0*du+1);
                        Ind_notnan=find(~isnan(Intdu));
                        Delta_u.(ff).(basin)(ii,cc) = sum(Intdu(Ind_notnan))/sum(IntA(Ind_notnan));
                        if bb==numel(basins_to_analyze)
                            if ~isfield(Delta_u.(ff),'map')
                                Delta_u.(ff).map = zeros(numel(data),MUA_target.Nnodes,size(data(ii).Original.(startyear).speed,2));
                            end
                            Delta_u.(ff).map(ii,:,cc) = du(:);
                        end
                    end
                end

            otherwise

                error("diagnostic_to_plot "+diagnostic_to_plot+" not known.");

        end

        % inversion parameters
        misfit(ii,:) = data(ii).Inverse.misfit(:)';
        gsA(ii,1) = [data(ii).Inverse.gsA];
        gsC(ii,1) = [data(ii).Inverse.gsC];
        gaA(ii,1) = [data(ii).Inverse.gaA];
        gaC(ii,1) = [data(ii).Inverse.gaC];
        dhdt_err(ii,1) = [data(ii).Inverse.dhdt_err];
        slidinglaw(ii) = data(ii).SlidingLaw;

    end

    fprintf("Done %s out of %s.\n",string(ii),string(numel(data)));

end

m = [data(:).m];
n = [data(:).n];

if diagnostic_to_plot=="Delta_u"
    save(file_with_perturbation_data_to_write, ...
        "Delta_u","MUA_yr1","MUA_yr2","GF_yr1","GF_yr2",...
        "misfit","gsA","gsC","gaA","gaC","dhdt_err","m","n","slidinglaw");
end

CtrlVar.PlotXYscale = 1e3;

N = misfit-min(misfit);
N = N./max(N);
alphavalue = 1-N;
markersize = 50*alphavalue+eps;
newcolors = [0.83 0.14 0.14
             1.00 0.54 0.00
             0.47 0.25 0.80
             0.25 0.80 0.54];

%% PLOTTING
figure; hold on;

switch diagnostic_to_plot

    case {'Delta_qGL','Delta_qOB'}

        H=fig('units','inches','width',70*12/72.27,'height',50*12/72.27,'fontsize',14,'font','Helvetica');

        ax1=subplot("position",[0.1 0.1 0.5 0.85]); hold on;
        ax2=subplot("position",[0.65 0.1 0.3 0.85]); hold on;

        switch parameter_to_plot
            case 'n'
                xdata = n(:);
            case 'm'
                xdata = m(:);
            case 'gsA'
                xdata = gsA(:);
            case 'gsC'
                xdata = gsC(:);
            case 'gaA'
                xdata = gaA(:);
            case 'gaC'
                xdata = gaC(:);
            otherwise
                xdata = [];
        end

        for cc=cycles_to_plot

            switch diagnostic_to_plot

                case 'Delta_qGL'

                    qorig = qGL_orig.total(:,cc);
                    ydata1 = qGL_calv.total(:,cc)-qorig;
                    ydata2 = qGL_dhIS.total(:,cc)-qorig;
                    ydata3 = qGL_dh.total(:,cc)-qorig;
                    ydata4 = qGL_calvdh.total(:,cc)-qorig;
                    yaxislabel = "\Deltaq_{GL} [Gt/yr]";
                    dq = Calc_Delta_qGL(cc,basins_to_analyze);

                case 'Delta_qOB'

                    qorig = qOB_orig.total(:,cc);
                    ydata1 = qOB_calv.total(:,cc)-qorig;
                    ydata2 = qOB_dhIS.total(:,cc)-qorig;
                    ydata3 = qOB_dh.total(:,cc)-qorig;
                    ydata4 = qOB_calvdh.total(:,cc)-qorig;
                    yaxislabel = "\Delta q_{OB} [Gt/yr]";
                    dq = nan;

                otherwise

                    continue;

            end

            if cc==1
                marker='o';
            elseif cc==2
                marker='s';
            end

            scat((cc-1)*4+1)=scatter(ax1,xdata,ydata1,markersize(:,1),marker,"filled",'MarkerEdgeColor','none');
            scat((cc-1)*4+2)=scatter(ax1,xdata,ydata2,markersize(:,1),marker,"filled",'MarkerEdgeColor','none');
            scat((cc-1)*4+3)=scatter(ax1,xdata,ydata3,markersize(:,1),marker,"filled",'MarkerEdgeColor','none');
            scat((cc-1)*4+4)=scatter(ax1,xdata,ydata4,markersize(:,1),marker,"filled",'MarkerEdgeColor','none');

        end

        colororder(ax1,[newcolors;newcolors]);

        xlim(ax1,[floor(min(xdata)) ceil(max(xdata))]);

        for ii=0:4*cycles_to_plot(end)-1
            scat(ii+1).AlphaData = alphavalue(:,floor(ii/4)+1);
            scat(ii+1).MarkerFaceAlpha='flat';
        end

        for ii=1:4
            scat(ii)=plot(ax1,0,0,'o','color',newcolors(ii,:),'MarkerSize',10,'MarkerFaceColor',newcolors(ii,:));
        end

        if numel(cycles_to_plot)==2
            scat(9)=plot(ax1,0,0,'ok','markersize',10);
            scat(10)=plot(ax1,0,0,'sk','markersize',10);
            legend(ax1,[scat(1:4) scat(9) scat(10)],{'Calving','Ice Shelf thickness','Ice thickness','Calving + Ice thickness','no spinup','with spinup'},...
            'NumColumns',2,'Location','northwest');
        else
            legend(ax1,scat(1:4),{'Calving','Ice Shelf thickness','Ice thickness','Calving + Ice thickness'},...
            'NumColumns',2,'Location','northwest');
        end

        xlabel(ax1,parameter_to_plot); ylabel(ax1,yaxislabel);

        if ismember(diagnostic_to_plot,["gsA","gsC","gaA","gaC"])
            ax1.XScale='log';
        end
        ax1.YScale='log';
        grid(ax1,"on")
        box(ax1,"on");
        ax1_ylim = ylim(ax1);
        ylim(ax1,[1 ax1_ylim(2)]);
        ax1_ylim = ylim(ax1);
        yticks(ax1,[10:10:100 200:100:1000]);
        yticklabels(ax1,["10","","","","","","","","","100","","","","","","","","","1000"]);
        set(ax1,"YMinorGrid","off");
        title(ax1,"Ua perturbation experiments");

        % histogram
        [N,edges] = histcounts(dq,25,"Normalization","percentage");
        barh(ax2,0.5*(edges(1:end-1)+edges(2:end)),N);
        h=plot(ax2,[0 100],[100 100],'--k','linewidth',1.5); %change in dicharge (Gt/yr) according to Rignot 2019
        ax2.YScale='log';
        grid(ax2,"on")
        box(ax2,"on");
        xlabel(ax2,"Percentage");
        yticklabels(ax2,"");
        ylim(ax2,ax1_ylim);
        xlim(ax2,[0,15])
        yticks(ax2,[10:10:100 200:100:1000]);
        set(ax2,"YMinorGrid","off");
        legend(ax2,h,"Rignot et al. 2019","location","southeast");
        title(ax2,"'Measured' change");

        % Save
        pos = get(H,"Position");
        set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
        fname = "./Figures/"+diagnostic_to_plot+"_"+parameter_to_plot;
        print(H,fname,"-dpng","-r400");

    case "Delta_u"

        xmin = min(MUA_target.coordinates(:,1)); xmax = max(MUA_target.coordinates(:,1));
        ymin = min(MUA_target.coordinates(:,2)); ymax = max(MUA_target.coordinates(:,2));

        fields_to_plot = fields(Delta_u);

        % observed change in velocity
        if startyear=="yr2000"
            load("../ua_input/1_interpolants/"+lower(domain)+"/GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities_EXTRUDED","Fus","Fvs","Fxerr","Fyerr");
        else
            if contains(domain,"AMUND")
                yr_first = double(erase(startyear,"yr")); if yr_first==2020, yr_first = 2019; end % the velocity of 2020 is the 2019-2020 field
                load("../ua_input/1_interpolants/"+lower(domain)+"/GriddedInterpolants_"+string(yr_first)+"-"+...
                    string(yr_first+1)+"_MeaSUREs_ITSLIVE_Velocities_EXTRUDED",...
                    "Fus","Fvs","Fxerr","Fyerr");
            elseif contains(domain,"SYNTH_PIG")
                load("../ua_input/1_interpolants/"+lower(domain)+"/ScatteredInterpolants_Velocities_SYNTH_PIG_"+startyear+".mat","Fus","Fvs","Fxerr","Fyerr");
            end
        end
        uxstart = Fus(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        uxerrstart = Fxerr(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        uystart = Fvs(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        uyerrstart = Fyerr(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        ustart = hypot(uxstart,uystart);
        uerrstart = sqrt((uxstart.^2.*uxerrstart.^2+uystart.^2.*uyerrstart.^2)./(uxstart.^2+uystart.^2+eps));

        if targetyear=="yr2000"
            load("../ua_input/1_interpolants/"+lower(domain)+"/GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities_EXTRUDED","Fus","Fvs","Fxerr","Fyerr");
        else
            if contains(domain,"AMUND")
                yr_first = double(erase(targetyear,"yr")); if yr_first==2020, yr_first = 2019; end % the velocity of 2020 is the 2019-2020 field
                load("../ua_input/1_interpolants/"+lower(domain)+"/GriddedInterpolants_"+string(yr_first)+"-"+...
                    string(yr_first+1)+"_MeaSUREs_ITSLIVE_Velocities_EXTRUDED",...
                    "Fus","Fvs","Fxerr","Fyerr");
            elseif contains(domain,"SYNTH_PIG")
                load("../ua_input/1_interpolants/"+lower(domain)+"/ScatteredInterpolants_Velocities_SYNTH_PIG_"+targetyear+".mat","Fus","Fvs","Fxerr","Fyerr");
            end
        end
        uxtarget = Fus(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        uxerrtarget = Fxerr(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        uytarget = Fvs(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        uyerrtarget = Fyerr(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        utarget = hypot(uxtarget,uytarget);
        uerrtarget = sqrt((uxtarget.^2.*uxerrtarget.^2+uytarget.^2.*uyerrtarget.^2)./(uxtarget.^2+uytarget.^2+eps));

        % observed change in ice-sheet geometry
        if contains(domain,"AMUND")
            load("../ua_input/1_interpolants/"+lower(domain)+"/GriddedInterpolants_Geometry_01-Jun-"+erase(startyear,"yr")+"_EXTRUDED","Fs","Fb");
            hstart = Fs(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2)) - Fb(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
            load("../ua_input/1_interpolants/"+lower(domain)+"/GriddedInterpolants_Geometry_01-Jun-"+erase(targetyear,"yr")+"_EXTRUDED","Fs","Fb");
            htarget = Fs(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2)) - Fb(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        elseif contains(domain,"SYNTH_PIG")
            load("../ua_input/1_interpolants/"+lower(domain)+"/ScatteredInterpolants_Geometry_SYNTH_PIG_"+startyear,"Fs","Fb");
            hstart = Fs(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2)) - Fb(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
            load("../ua_input/1_interpolants/"+lower(domain)+"/ScatteredInterpolants_Geometry_SYNTH_PIG_"+targetyear,"Fs","Fb");
            htarget = Fs(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2)) - Fb(MUA_target.coordinates(:,1),MUA_target.coordinates(:,2));
        end

        dspeed_meas = utarget-ustart; %dspeed(dspeed<0)=nan;
        dspeed_meas_err = hypot(uerrstart,uerrtarget);
        dh_meas = htarget-hstart;

        for cc=cycles_to_plot

            %% plot distribution of misfit between modelled perturbation in speed and measured change in speed

            % prep data: remove areas with small/negative changes in measured speed
            dspeed_meas_clean = dspeed_meas;
            dspeed_meas_clean(abs(dspeed_meas)<1 | dspeed_meas<=0) = nan;

            mask = ones(MUA_target.Nnodes,1);

            area_floating = FEintegrate2D(CtrlVar,MUA_target,1-GF_yr2.node);
            area_grounded = FEintegrate2D(CtrlVar,MUA_target,GF_yr2.node);

            tmp = fields(Delta_u);
            I_dh = find(tmp=="dh");
            I_calvdh = find(tmp=="Calv_dh");

            if ~isempty(I_calvdh)
                Itmp = I_calvdh;
            elseif ~isempty(I_dh)
                Itmp = I_dh;
            else
                error("no maps of dh or calv_dh");
            end

            for nn=1:size(Delta_u.(tmp{Itmp}).map,1)

                % modelled change in speed
                dspeed_mod = squeeze(Delta_u.(tmp{Itmp}).map(nn,:,cc))';
                dspeed_mod_clean = dspeed_mod;
                dspeed_mod_clean(abs(dspeed_mod)<1 | dspeed_mod<=0) = nan;

                dspeed_log_err = 1./(dspeed_mod_clean*log(10)).*dspeed_meas_err;

                %% calculate misfit. there are various ways of defining the
                %% misfit function

                % 1. mean square error
                misfit_mse_tmp = (dspeed_mod_clean - dspeed_meas_clean).^2;

                misfit_floating_tmp = FEintegrate2D(CtrlVar,MUA_target,(1-GF_yr2.node).*misfit_mse_tmp);
                area_floating_tmp = area_floating; area_floating_tmp(isnan(misfit_floating_tmp))=[];

                misfit_grounded_tmp = FEintegrate2D(CtrlVar,MUA_target,GF_yr2.node.*misfit_mse_tmp);
                area_grounded_tmp = area_grounded; area_grounded_tmp(isnan(misfit_grounded_tmp))=[];

                misfit_mse_floating(nn) = sum(misfit_floating_tmp,"all","omitmissing")/sum(area_floating_tmp,"all","omitmissing");
                misfit_mse_grounded(nn) = sum(misfit_grounded_tmp,"all","omitmissing")/sum(area_grounded_tmp,"all","omitmissing");

                % 2. mse of log
                misfit_logdiff_tmp = (log10(dspeed_mod_clean) - log10(dspeed_meas_clean)).^2;%./(dspeed_log_err+eps)).^2;

                misfit_floating_tmp = FEintegrate2D(CtrlVar,MUA_target,(1-GF_yr2.node).*misfit_logdiff_tmp);
                area_floating_tmp = area_floating; area_floating_tmp(isnan(misfit_floating_tmp))=[];

                misfit_grounded_tmp = FEintegrate2D(CtrlVar,MUA_target,GF_yr2.node.*misfit_logdiff_tmp);
                area_grounded_tmp = area_grounded; area_grounded_tmp(isnan(misfit_grounded_tmp))=[];

                misfit_logdiff_floating(nn) = sum(misfit_floating_tmp,"all","omitmissing")/sum(area_floating_tmp,"all","omitmissing");
                misfit_logdiff_grounded(nn) = sum(misfit_grounded_tmp,"all","omitmissing")/sum(area_grounded_tmp,"all","omitmissing");

                disp("done "+num2str(nn)+" out of "+num2str(size(Delta_u.(tmp{Itmp}).map,1)));
            end

            H=fig('units','inches','width',120*12/72.27,'height',60*12/72.27,'fontsize',14,'font','Helvetica');

            tlo_fig = tiledlayout(1,1,"TileSpacing","compact");
            ax(1) = nexttile(tlo_fig); hold on;

            PlotNodalBasedQuantities_JDR(ax(1),MUA_target.connectivity,MUA_target.coordinates,dh_meas,CtrlVar);
            plot(MUA_target.Boundary.x/CtrlVar.PlotXYscale,MUA_target.Boundary.y/CtrlVar.PlotXYscale,'-k');
            plot(MUA_start.Boundary.x/CtrlVar.PlotXYscale,MUA_start.Boundary.y/CtrlVar.PlotXYscale,'--k');
            PlotGroundingLines(CtrlVar,MUA_target,GF_yr2,[],[],[],'-k','linewidth',1);
            CM = othercolor('RdBu11',15);
            colormap(ax(1),CM);
            axis(ax(1),"off");
            caxis(ax(1),[-100 100]);
            xlim(ax(1),[xmin xmax]/CtrlVar.PlotXYscale);
            ylim(ax(1),[ymin ymax]/CtrlVar.PlotXYscale);
            axis(ax(1),"equal");

            cb2=colorbar(ax(1)); cb2.Label.String="Change in ice thickness [m]";

            figure; tlo=tiledlayout(3,2,"TileSpacing","Compact");

            nexttile; title("Grounded");
            yyaxis left; hold on;
            plot(m,misfit_mse_grounded,'o','markersize',3);
            ylabel('Misfit MSE');
            yyaxis right; hold on;
            plot(m,misfit_logdiff_grounded,'o','markersize',3);
            ylabel('Misfit log difference');
            xlabel('m');

            nexttile; title("Floating");
            yyaxis left; hold on;
            plot(m,misfit_mse_floating,'o','markersize',3);
            ylabel('Misfit MSE');
            yyaxis right; hold on;
            plot(m,misfit_logdiff_floating,'o','markersize',3);
            ylabel('Misfit log difference');
            xlabel('m');

            nexttile;
            yyaxis left; hold on;
            plot(n,misfit_mse_grounded,'o','markersize',3);
            ylabel('Misfit MSE');
            yyaxis right; hold on;
            plot(n,misfit_logdiff_grounded,'o','markersize',3);
            ylabel('Misfit log difference');
            xlabel('n');

            nexttile;
            yyaxis left; hold on;
            plot(n,misfit_mse_floating,'o','markersize',3);
            ylabel('Misfit MSE');
            yyaxis right; hold on;
            plot(n,misfit_logdiff_floating,'o','markersize',3);
            ylabel('Misfit log difference');
            xlabel('n');

            nexttile;
            yyaxis left; hold on;
            plot(dhdt_err,misfit_mse_grounded,'o','markersize',3);
            ylabel('Misfit MSE');
            yyaxis right; hold on;
            plot(dhdt_err,misfit_logdiff_grounded,'o','markersize',3);
            ylabel('Misfit log difference');
            xlabel('dhdt_err');

            nexttile;
            yyaxis left; hold on;
            plot(dhdt_err,misfit_mse_floating,'o','markersize',3);
            ylabel('Misfit MSE');
            yyaxis right; hold on;
            plot(dhdt_err,misfit_logdiff_floating,'o','markersize',3);
            ylabel('Misfit log difference');
            xlabel('dhdt_err');

            H=fig('units','inches','width',120*12/72.27,'height',60*12/72.27,'fontsize',14,'font','Helvetica');

            tlo(cc*999)=tiledlayout(H,2,numel(fields_to_plot)+1,'TileSpacing','none','TileIndexing', 'columnmajor');

            for ff=1:numel(fields_to_plot)

                deltau_av = mean(Delta_u.(fields_to_plot{ff}).map(:,:,cc),1,"omitmissing");
                deltau_std = std(Delta_u.(fields_to_plot{ff}).map(:,:,cc),1,"omitmissing");

                if contains(fields_to_plot{ff},'Calv')
                    MUA = MUA_target;
                    MUA2 = MUA_start;
                else
                    MUA = MUA_start;
                    MUA2 = MUA_target;
                end

                xmin = min(MUA.coordinates(:,1)); xmax = max(MUA.coordinates(:,1));
                ymin = min(MUA.coordinates(:,2)); ymax = max(MUA.coordinates(:,2));

                %% ensemble-average change in speed
                ax(ff)=nexttile(tlo(cc*999)); hold on;
                log_deltau_av = deltau_av(:);
                log_deltau_av(log_deltau_av<0)=nan;
                log_deltau_av = log10(log_deltau_av);
                PlotNodalBasedQuantities_JDR(ax(ff),MUA.connectivity,MUA.coordinates,log_deltau_av(:),CtrlVar);
                plot(MUA.Boundary.x/CtrlVar.PlotXYscale,MUA.Boundary.y/CtrlVar.PlotXYscale,'-k');
                plot(MUA2.Boundary.x/CtrlVar.PlotXYscale,MUA2.Boundary.y/CtrlVar.PlotXYscale,'--k');
                PlotGroundingLines(CtrlVar,MUA_target,GF_yr2,[],[],[],'-k','linewidth',1);
                CM = flipdim(othercolor('RdYlBu8',15),1);
                colormap(ax(ff),CM);
                title(ax(ff),fields_to_plot{ff},"Interpreter","none");
                axis(ax(ff),"off");
                caxis(ax(ff),[-0.25 3.5]);
                xlim(ax(ff),[xmin xmax]/CtrlVar.PlotXYscale);
                ylim(ax(ff),[ymin ymax]/CtrlVar.PlotXYscale);
                axis(ax(ff),"equal");

                %% standard deviation
                ax(numel(fields_to_plot)+ff)=nexttile(tlo(cc*999)); hold on;
                PlotNodalBasedQuantities_JDR(ax(numel(fields_to_plot)+ff),MUA.connectivity,MUA.coordinates,log10(deltau_std(:)+eps),CtrlVar);
                plot(MUA.Boundary.x/CtrlVar.PlotXYscale,MUA.Boundary.y/CtrlVar.PlotXYscale,'-k');
                plot(MUA2.Boundary.x/CtrlVar.PlotXYscale,MUA2.Boundary.y/CtrlVar.PlotXYscale,'--k');
                PlotGroundingLines(CtrlVar,MUA_target,GF_yr2,[],[],[],'-k','linewidth',1);
                colormap(ax(numel(fields_to_plot)+ff),CM);
                axis(ax(numel(fields_to_plot)+ff),"off");
                caxis(ax(numel(fields_to_plot)+ff),[-0.25 3.5]);
                xlim(ax(numel(fields_to_plot)+ff),[xmin xmax]/CtrlVar.PlotXYscale);
                ylim(ax(numel(fields_to_plot)+ff),[ymin ymax]/CtrlVar.PlotXYscale);
                axis(ax(numel(fields_to_plot)+ff),"equal");

                if ff==numel(fields_to_plot)
                     cb=colorbar(ax(2*numel(fields_to_plot))); cb.Label.String="Ensemble standard deviation of log_{10}(\Deltau) [m/yr]";
                end

            end

            ax(numel(fields_to_plot)+1)=nexttile(tlo(cc*999)); hold on;
            PlotNodalBasedQuantities_JDR(ax(numel(fields_to_plot)+1),MUA_target.connectivity,MUA_target.coordinates,log10(dspeed_meas_clean+eps),CtrlVar);
            plot(MUA_target.Boundary.x/CtrlVar.PlotXYscale,MUA_target.Boundary.y/CtrlVar.PlotXYscale,'-k');
            plot(MUA_start.Boundary.x/CtrlVar.PlotXYscale,MUA_start.Boundary.y/CtrlVar.PlotXYscale,'--k');
            PlotGroundingLines(CtrlVar,MUA_target,GF_yr2,[],[],[],'-k','linewidth',1);
            colormap(ax(numel(fields_to_plot)+1),CM);
            title(ax(numel(fields_to_plot)+1),"Observations");
            axis(ax(numel(fields_to_plot)+1),"off");
            caxis(ax(numel(fields_to_plot)+1),[-0.25 3.5]);
            xlim(ax(numel(fields_to_plot)+1),[xmin xmax]/CtrlVar.PlotXYscale);
            ylim(ax(numel(fields_to_plot)+1),[ymin ymax]/CtrlVar.PlotXYscale);
            axis(ax(numel(fields_to_plot)+1),"equal");

            cb2=colorbar(ax(numel(fields_to_plot)+1)); cb2.Label.String="Log_{10} change in speed [m/yr]";

            title(tlo(cc*999),"Cycle "+num2str(cc));

            % Save
            pos = get(H,"Position");
            set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
            fname = "./Figures/"+diagnostic_to_plot+"_cycle"+string(cc);
            print(H,fname,"-dpng","-r400");

        end

    otherwise

        error("unknown case")

end
