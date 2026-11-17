function [UserVar,AGlen,n]=DefineAGlenDistribution(UserVar,CtrlVar,MUA,time,s,b,h,S,B,rho,rhow,GF)
% DefineAGlenDistribution  Ua user input file of the synthetic SYNTH_PIG experiments: rate factor AGlen and Glen exponent n.
%
% PURPOSE
%   n = UserVar.n. AGlen is defined as follows:
%     - run that is neither time dependent nor an inversion: read from CtrlVar.NameOfFileForReadingAGlenEstimate
%       (variables xA, yA, AGlen) and interpolated;
%     - time-dependent run: AGlenVersusTemp(-15), with 7.5 km wide shear margins along the lateral boundaries where AGlen
%       changes linearly towards AGlenVersusTemp(-10) at the boundary;
%     - inverse run: constant AGlenVersusTemp(-15).
%
% REQUIRES
%   Ua source code (AGlenVersusTemp)

n=UserVar.n;

x = MUA.coordinates(:,1); y = MUA.coordinates(:,2);

if (~CtrlVar.TimeDependentRun && ~CtrlVar.InverseRun)

    tmp = load(CtrlVar.NameOfFileForReadingAGlenEstimate);
    FAGlen = scatteredInterpolant(tmp.xA,tmp.yA,tmp.AGlen);
    AGlen = FAGlen(x,y);

elseif CtrlVar.TimeDependentRun

    AGlen = AGlenVersusTemp(-15)+ zeros(MUA.Nnodes,1);

    % 7.5 km wide shear margins
    xd=max(x(:)) ; xu=min(x(:)); yl=max(y(:)) ; yr=min(y(:));

    nodesl=find(abs(y-yl)<7.5e3);
    nodesr=find(abs(y-yr)<7.5e3);

    AGlen(nodesl) = AGlenVersusTemp(-10) + (AGlenVersusTemp(-15)-AGlenVersusTemp(-10))/(7.5e3)*(abs(y(nodesl)-yl));
    AGlen(nodesr) = AGlenVersusTemp(-10) + (AGlenVersusTemp(-15)-AGlenVersusTemp(-10))/(7.5e3)*(abs(y(nodesr)-yr));

elseif CtrlVar.InverseRun

        AGlen = AGlenVersusTemp(-15)+ zeros(MUA.Nnodes,1);

end

end
