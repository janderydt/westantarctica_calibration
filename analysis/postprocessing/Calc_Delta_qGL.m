function qGL = Calc_Delta_qGL(cycle,basins_to_analyze)
% Calc_Delta_qGL  Grounding line flux of the inversions of the ensemble (for the Delta_qGL plot).
%
% PURPOSE
%   Returns for every member of the inversion ensemble (AMUND, Weertman sliding) the grounding line flux (Gt/yr), summed over
%   the first three basins of the inversion data (Getz, Pine Island-Thwaites and Abbot), for the inverse cycle
%   (default 2). Used by plot_PerturbationResults_Ensemble for the histogram next to the Delta_qGL plot.
%
% INPUT
%   cycle (inverse cycle, default 2), basins_to_analyze (not used; the first three basins are summed)
%
% OUTPUT
%   qGL : 1-by-number of members
%
% FILES READ (data; can be obtained upon request from the author, see README)
%   ./inversiondata/amund/AMUND_2000_inversiondata_Weertman.mat (written by Calc_InverseResults_Ensemble); basins_IMBIE_v2.mat
%
% REQUIRES
%   RemoveIceRisesAndIslands (same folder)

if nargin==0
    UserVar.cycle = 2;
    basins_to_analyze = {'F-G',...  % Getz
    'G-H',...  % PIG, Thwaites
    'H-Hp'}; % Abbott
else
    UserVar.cycle = cycle;
end

% gather basin data
filename = 'basins_IMBIE_v2.mat';
B = load(filename);
B = RemoveIceRisesAndIslands(B);
BasinInd = [1:3];

% load inversion data
load("./inversiondata/amund/AMUND_2000_inversiondata_Weertman.mat");

m = [data(:).m];
n = [data(:).n];
gaA = [data(:).gaA];
gaC = [data(:).gaC];
gsA = [data(:).gsA];
gsC = [data(:).gsC];
expID = [data(:).InverseExpID];

for ii=1:numel(data)
    if UserVar.cycle==1
        ind_finished(ii) = ismember(data(ii).niter(UserVar.cycle),[5000,15000]);
        qGL_tmp = data(ii).qGL(:,UserVar.cycle);
    elseif UserVar.cycle==2
        if numel(data(ii).niter)>1
            ind_finished(ii) = ismember(data(ii).niter(UserVar.cycle),[6000,16000]);
            qGL_tmp = data(ii).qGL(:,UserVar.cycle);
        else
            ind_finished(ii) = 0;
            qGL_tmp = nan*ones(numel(B.name),1);
        end
    end
    qGL(ii) = sum(qGL_tmp(BasinInd));
end
