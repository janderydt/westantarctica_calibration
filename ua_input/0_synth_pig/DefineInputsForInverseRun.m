function [UserVar,InvStartValues,Priors,Meas,BCsAdjoint,RunInfo]=DefineInputsForInverseRun(UserVar,CtrlVar,MUA,BCs,F,l,GF,InvStartValues,Priors,Meas,BCsAdjoint,RunInfo)
% DefineInputsForInverseRun  Ua user input file of the synthetic SYNTH_PIG experiments: inputs of the inversion test.
%
% PURPOSE
%   The synthetic "measurements" of the inversion are the velocities of the result file of the experiment "warm"
%   (after 15 years: ./ResultsFiles/ResultsFile-warm_<SlidingLaw>-%15%yr.mat), interpolated on the mesh, with an error
%   of 1 m/yr. The start values and the priors are constant: C = ub/tau^m (ub = 100 m/yr, tau = 80 kPa) and AGlen =
%   AGlenVersusTemp(-15); m, muk and n are taken from DefineSlipperyDistribution and DefineAGlenDistribution.
%
% FILES READ (results of an earlier synthetic experiment; data that can be obtained upon request from the author)
%   the result file of the experiment "warm" mentioned above
%
% REQUIRES
%   Ua source code (AGlenVersusTemp)

fprintf('Reading inputs for inverse run \n');

exp = "warm";
yr1 = "15";
tmp = load("./ResultsFiles/ResultsFile-"+exp+"_"+UserVar.SidingLaw+"-%"+yr1+"%yr.mat");

x = MUA.coordinates(:,1); y = MUA.coordinates(:,2);

Fus = scatteredInterpolant(tmp.MUA.coordinates(:,1),tmp.MUA.coordinates(:,2),tmp.F.ub);
Fvs = scatteredInterpolant(tmp.MUA.coordinates(:,1),tmp.MUA.coordinates(:,2),tmp.F.vb);

Meas.us = Fus(x,y);
Meas.vs = Fvs(x,y);

usError = 0*Meas.us+1; % We add some small errors here.
vsError = 0*Meas.us+1;
Meas.usCov=sparse(1:MUA.Nnodes,1:MUA.Nnodes,usError.^2,MUA.Nnodes,MUA.Nnodes);
Meas.vsCov=sparse(1:MUA.Nnodes,1:MUA.Nnodes,vsError.^2,MUA.Nnodes,MUA.Nnodes);

fprintf('Reading start values for AGlen and C...\n');

[UserVar,~,InvStartValues.m,InvStartValues.q,InvStartValues.muk]=DefineSlipperyDistribution(UserVar,CtrlVar,MUA,CtrlVar.time,F.s,F.b,F.s-F.b,F.S,F.B,F.rho,F.rhow,GF);
ub = 100; tau = 80;
InvStartValues.C = 0*x+ub./tau.^InvStartValues.m(1);

[UserVar,~,InvStartValues.n]=DefineAGlenDistribution(UserVar,CtrlVar,MUA,CtrlVar.time,F.s,F.b,F.s-F.b,F.S,F.B,F.rho,F.rhow,GF);
InvStartValues.AGlen = 0*x+AGlenVersusTemp(-15);
fprintf('done \n');

%% Define Priors
Priors.B=F.B;
Priors.C = InvStartValues.C;
Priors.m = InvStartValues.m(1);
Priors.muk = InvStartValues.muk(1);

Priors.AGlen = InvStartValues.AGlen;
Priors.n=InvStartValues.n(1);

disp(['Constant prior value for C: ',num2str(Priors.C(1))]);
disp(['Constant prior value for AGlen: ',num2str(Priors.AGlen(1))]);

Priors.rho = F.rho;
Priors.rhow = F.rhow;

end
