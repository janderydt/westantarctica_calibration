function B = Calc_UaOBFlux_PerBasin(MUA,F,GF,B,CtrlVar)
% Calc_UaOBFlux_PerBasin  Ice flux across the open (ocean) boundary of the Ua mesh, per basin.
%
% Part of the postprocessing of the diagnostic results (see Calc_PerturbationResults_Ensemble). It can be applied to any Ua
% result (MUA and F), for example the result files of the synthetic experiments in analysis/ua_resultsfiles.
%
% PURPOSE
%   Calculates the flux across the boundary edges of the mesh that are grounded (ice base at the bed at both
%   nodes) at the midpoints of these edges (FluxAcrossBoundary), removes anomalously high values (qOB>1e12),
%   and assigns each point to the nearest basin.
%
% INPUTS
%   MUA, F : Ua mesh and fields (F.b, F.B, F.ub, F.vb, F.h, F.rho); GF, CtrlVar are not used
%   B      : structure with basin information (x, y: cell arrays with the basin outlines)
%
% OUTPUT
%   B : input with added fields per basin: OBpoints, xOB, yOB, qOB (flux)
%
% REQUIRES
%   FluxAcrossBoundary (same folder). The fluxes qOB are in kg/yr

% We define OB (open boundary) nodes as boundary nodes that are not afloat.
x = MUA.coordinates(:,1);
y = MUA.coordinates(:,2);
% grounded fraction of edges
OB_GF = GF.node(MUA.Boundary.Edges);
% find edges where the ice base is at the bed at both nodes (water column thickness ~0, i.e. grounded):
h=F.b(MUA.Boundary.Edges)-F.B(MUA.Boundary.Edges);
IOB = find(sum(h,2)<eps);
% calculate midpoint of those edges
xOB = [x(MUA.Boundary.Edges(IOB,1)),x(MUA.Boundary.Edges(IOB,2))];
yOB = [y(MUA.Boundary.Edges(IOB,1)),y(MUA.Boundary.Edges(IOB,2))];

Fub=scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),F.ub);
Fvb=Fub; Frho=Fub; Fh=Fub;
Fvb.Values=F.vb;
Frho.Values=F.rho;
Fh.Values=F.h;

[xOB,yOB,qOB,qBx,qBy]=FluxAcrossBoundary(xOB,yOB,Fub,Fvb,Fh,Frho);
% remove anomalously high fluxes across boundary
I = find(qOB>1e12);
xOB(I)=[]; yOB(I)=[]; qOB(I)=[]; qBx(I)=[]; qBy(I)=[];

%% check proximity to basins
PQ = [xOB(:) yOB(:)]; dist = [];
for ii=1:numel(B.x)
    P = [B.x{ii} B.y{ii}];
    [~,dist(ii,:)] = dsearchn(P,PQ);
end
[~,I] = min(dist,[],1); 

for ii=1:numel(B.x)
    B.OBpoints{ii} = find(I==ii);
    B.xOB{ii} = xOB(B.OBpoints{ii});
    B.yOB{ii} = yOB(B.OBpoints{ii});
    B.qOB{ii} = qOB(B.OBpoints{ii});
end
