function  BCs=DefineBoundaryConditions(UserVar,CtrlVar,MUA,BCs,time,s,b,h,S,B,ub,vb,ud,vd,GF)
% DefineBoundaryConditions  Ua user input file of the synthetic SYNTH_PIG experiments: boundary conditions.
%
% PURPOSE
%   Zero basal velocity (Dirichlet) on the upstream boundary and on the two lateral boundaries of the domain; the
%   downstream (ocean) boundary is free.

%%
x=MUA.coordinates(:,1); y=MUA.coordinates(:,2);

% find nodes along boundary for which Dirichlet boundary conditions apply
xd=max(x(:)) ; xu=min(x(:)); yl=max(y(:)) ; yr=min(y(:));

nodesu=find(abs(x-xu)<1); [~,ind]=sort(MUA.coordinates(nodesu,2)); nodesu=nodesu(ind);
nodesl=find(abs(y-yl)<1); [~,ind]=sort(MUA.coordinates(nodesl,1)); nodesl=nodesl(ind);
nodesr=find(abs(y-yr)<1); [~,ind]=sort(MUA.coordinates(nodesr,1)); nodesr=nodesr(ind);

% fixed nodes
BCs.ubFixedNode=[nodesu;nodesl;nodesr] ;  BCs.ubFixedValue=[0*nodesu;0*nodesl;0*nodesr];
BCs.vbFixedNode=[nodesu;nodesl;nodesr] ;  BCs.vbFixedValue=[0*nodesu;0*nodesl;0*nodesr];

end
