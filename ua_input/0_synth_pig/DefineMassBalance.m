function [UserVar,as,ab]=DefineMassBalance(UserVar,CtrlVar,MUA,time,s,b,h,S,B,rho,rhow,GF)
% DefineMassBalance  Ua user input file of the synthetic SYNTH_PIG experiments: surface and basal mass balance.
%
% PURPOSE
%   Surface mass balance as: 1 m/yr everywhere, increasing linearly towards the upstream end of the domain (for a domain
%   that starts at x = 0: 15 m/yr at the upstream boundary, 1 m/yr 150 km downstream of it). Basal mass balance ab (m/yr, negative is melt) only for the
%   experiments "cold" (cold ocean temperature profile: low melt) and "warm" (warm ocean temperature profile: high melt): no melt where the base is above -200 m, melt increasing
%   linearly from 0 at -200 m to 20 m/yr ("cold") or 200 m/yr ("warm") at -600 m, constant below -600 m; no melt for
%   other experiments. ab is set to 0 at lake nodes and at nodes that are not ocean.
%
% REQUIRES
%   Ua source code (LakeOrOcean3)

x = MUA.coordinates(:,1); y=MUA.coordinates(:,2);
xu=min(x(:));

nodesu=find(abs(x-xu)<1.5e5); [~,ind]=sort(MUA.coordinates(nodesu,2)); nodesu=nodesu(ind);

a=s*0+1;
a(nodesu)=1-(x(nodesu)-1.5e5)/1.5e5*14;

as=a ;

ab=0*a;

% 200 to 600 thermocline
ind1 = find(b>-200);
ind2 = find(b<-200 & b>-600);
% low melt: 0 -> -20
if contains(CtrlVar.Experiment,"cold")
    ab = ab-20;
    ab(ind1) = 0;
    ab(ind2) = (-20-0)/(-600+200)*(b(ind2)+200);
% high melt: 0 -> -200
elseif contains(CtrlVar.Experiment,"warm")
    ab = ab-200;
    ab(ind1) = 0;
    ab(ind2) = (-200-0)/(-600+200)*(b(ind2)+200);
end

NodesDownstreamOfGroundingLines="Relaxed"; % strict
[LakeNodes,OceanNodes,LakeElements,OceanElements] = LakeOrOcean3(CtrlVar,MUA,GF,[],NodesDownstreamOfGroundingLines);
ab(LakeNodes) = 0;
ab(~OceanNodes) = 0;

end
