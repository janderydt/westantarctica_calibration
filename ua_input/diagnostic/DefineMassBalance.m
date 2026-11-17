function [UserVar,as,ab]=DefineMassBalance(UserVar,CtrlVar,MUA,time,s,b,h,S,B,rho,rhow,GF)
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Part of the diagnostic stage, which needs the inversion results (restart files) of the
% ensemble members. These are not distributed with this repository.
%
% DefineMassBalance  Ua user input file (diagnostic stage): no surface or basal mass balance (as=ab=0).

as = 0*s;
ab = 0*s;

end
