function Calc_SemiVariogram
% Calc_SemiVariogram  Range of the spatial correlation of the speeds of the ensemble members (semivariogram).
%
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Needs the restart files of the inversions of the ensemble (data that can be obtained upon request from the author).
%
% PURPOSE
%   For every 10th finished inversion of the AMUND ensemble (run tables RunTable_ARCHER2_11-02-2025_20 to 23) and both inverse cycles,
%   reads the speed of the restart file and calculates the semivariogram of the speed on the nodes of the mesh, the mean
%   squared difference of the speed between nodes at distances of 5 to 500 km. An exponential model Y(h) = c0*(1-exp(-h/a0))
%   is fitted to it (zero nugget); the range is r = 3*a0, the distance at which the covariance is about 5% of its value at zero. The range is stored in
%   data(k).semivariogram_range(cycle) of the inversion data (inversiondata_AMUND_Weertman.mat) and the updated structure data is
%   saved in test.mat. (UserVar.l in Calc_BayesianInference is described as the range in the Ua semivariogram.)
%
% REQUIRES
%   ReadWritetable (ua_input/run); cell2nancat (third party); MATLAB Statistics and Machine Learning Toolbox (rangesearch) and
%   Curve Fitting Toolbox (fit, fittype)

only_finished=1;

% home folder of the Ua experiments (contains ANT_Inverse, the folder of the first AMUND inversion ensemble)
UserVar.home = "/path/to/home/";
UserVar.type = "Inverse";
UserVar.Table = UserVar.home+"ANT_"+UserVar.type+"/RunTable_ARCHER2_11-02-2025_"+string([20 21 22 23])+".csv";
UserVar.idrange = [20000,20999; 21000, 21999; 22000, 22999; 23000, 23999];

inversiondata_filename = "inversiondata_AMUND_Weertman.mat";

if exist(inversiondata_filename,"file")
    load(inversiondata_filename);
else
    data=[];
    inverse_experiments_analyzed = [];
end

kk=1;

for tt=1:numel(UserVar.Table)

    %% read run table
    RunTable = ReadWritetable(UserVar,UserVar.Table(tt),[],'read');

    %% ExpIDs
    ExpID = RunTable{:,"ExpID"};
    Ind = find(ExpID>=UserVar.idrange(tt,1) & ExpID<=UserVar.idrange(tt,2));
    % only keep experiments that have finished
    Ind_finished = RunTable{Ind,"Finished"}==1;
    if only_finished
        Ind = Ind(Ind_finished==1);
    end

    %% Gather data
    for ii=1:10:numel(Ind)

        folder = UserVar.home+"/ANT_"+UserVar.type+"/cases/AMUND_nsmbl_Inverse_"+ExpID(Ind(ii));

        [~,data_ind] = ismember(ExpID(Ind(ii)),[data(:).InverseExpID]);
        if data_ind==0 % add new element to data structure
            error("Experiment "+ExpID(Ind(ii))+" does not yet exist in "+inversiondata_filename);
        end

        for cc=1:2

            restartfile = folder+"/AMUND_nsmbl_Inverse_"+ExpID(Ind(ii))+"-RestartFile_InverseCycle"+...
                string(cc)+".mat";

            if exist(restartfile,"file")

                try

                    load(restartfile,"F","MUA");

                    data_tmp(kk).data_ind = data_ind;
                    data_tmp(kk).cc = cc;
                    data_tmp(kk).u = hypot(F.ub,F.vb);
                    if kk==1
                        data_tmp(kk).X = MUA.coordinates;
                    end
                    kk=kk+1;

                catch

                    warning("Unable to load file "+restartfile+".");

                end
            end
        end
    end
end

r = CalcRange(data_tmp);
for ii=1:numel(data_tmp)
    data(data_tmp(ii).data_ind).semivariogram_range(data_tmp(ii).cc) = r(ii);
end

save("test.mat","data");

end

function r = CalcRange(data)

persistent RS

dist = [500e3:-50e3:100e3 90e3:-10e3:10e3 5e3];
Y = zeros(numel(data),numel(dist));

% assemble range search if needed
assemble = 0;
if isempty(RS)
    assemble = 1;
else
end

if assemble
    nNodes = size(data(1).X,1);
    for ii=1:numel(dist)
        tmp = rangesearch(data(1).X,data(1).X,dist(ii),'SortIndices',false);
        tmp = cell2nancat(tmp);
        Inan = find(isnan(tmp));
        I = [0; Inan];
        Idx = zeros(nNodes,nNodes);
        for jj=1:nNodes
            Istart = I(jj)+1;
            Iend = I(jj+1)-1;
            Idx(1:Iend-Istart+1,jj)=tmp(Istart:Iend); % 1st dimension are node indices within range,
            % 2nd dimension are nodes
        end
        Idx_sum = sum(Idx,2); Idx_zero = find(Idx_sum==0);
        Idx(Idx_zero,:)=[];
        RS(ii).Idx = Idx;
        disp("Assembling range search. Done "+string(ii)+" out of "+string(numel(dist)));
    end
end

for ii=1:numel(dist)
    for kk = 1:numel(data)
        utmp = data(kk).u; utmp = [-9999; utmp];
        z = utmp(RS(ii).Idx+1);
        z(z==-9999)=nan;
        z2 = repmat(utmp(2:end)',size(z,1),1);
        dz = (z-z2).^2;
        Y(kk,ii) = mean(dz,'all','omitmissing'); % mse between speeds
        disp("range: "+string(ii)+"/"+string(numel(dist))+...
            ", experiments: "+string(kk)+"/"+string(numel(data)));
    end
end

% fit exponential curve Y(h) = c0*(1-exp(-h/a0)), where 3*a0 is the
% effective range (the h value where the covariance is approximately 5% of
% its value at zero) and c0 is the scale. The sill can be computed as
% Y(3*a0). In this model the nugget is zero.
mdl = fittype('c0*(1-exp(-h/a0))',independent="h",coefficients=["c0" "a0"]);

for kk=1:numel(data)
    fittedmdl = fit(dist(:),Y(kk,:)',mdl,start=[1e5 1e5]);
    r(kk)=3*fittedmdl.a0;
end

end
