function [B,GL] = Calc_UaGLFlux_PerBasin(MUA,F,GF,B,CtrlVar)
% Calc_UaGLFlux_PerBasin  Ice flux across the Ua grounding line, per basin.
%
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Part of the postprocessing of the diagnostic results (see main_PerturbationResultsEnsemble); the diagnostic
% results can be obtained upon request from the author.
%
% PURPOSE
%   Calculates the flux across the grounding line of a Ua result and assigns the grounding line segments and
%   flux values at the midpoints of the grounding line edges to the nearest basin.
%
% INPUTS
%   MUA, F, GF, CtrlVar : Ua mesh, fields (F.ub, F.vb, F.ud, F.vd, F.h, F.rho, F.GF), grounding-floating mask, CtrlVar
%   B : structure with basin information (x, y: cell arrays with the basin outlines). One way to construct B is
%       to use the IMBIE basin outlines (routines from C. Greene):
%         B = load('basins_IMBIE_v2.mat'); B = RemoveIceRisesAndIslands(B);
%       (basins_IMBIE_v2.mat: data; can be obtained upon request from the author)
%
% OUTPUTS
%   B  : input with added fields per basin: GLpoints (indices of grounding line midpoints), xGL, yGL, qGL (flux)
%   GL : structure array of the grounding line segments (x, y, xmid, ymid, qGL, length l and total length L,
%        basinindex), sorted by length
%
% REQUIRES
%   Ua source code (GLgeometry, LineUpEdges2); FluxAcrossGroundingLine_JDR (modified version of Ua's
%   FluxAcrossGroundingLine; not yet received)

% GL flux
GLgeo=GLgeometry(MUA.connectivity,MUA.coordinates,GF,CtrlVar);
xa=GLgeo(:,3) ;  xb=GLgeo(:,4) ; ya=GLgeo(:,5) ;  yb=GLgeo(:,6) ;
[xGL,yGL]=LineUpEdges2(CtrlVar,xa,xb,ya,yb);

% GL fluxes will be defined at midpoints
[xGLmid,yGLmid,qGL,qGLx,qGLy,Fub,Fvb,Fr,Fh,LakeNodes,GLgeo,ubGL,vbGL] = FluxAcrossGroundingLine_JDR(CtrlVar,MUA,F.GF,F.ub,F.vb,F.ud,F.vd,F.h,F.rho,[],[],[],[],[],xGL,yGL,GLgeo);

%% keep n longest GL segments
I = find(isnan(xGL)); I = [0;I(:);numel(xGL)+1];
% make structure for individual GL segements
for ii=1:numel(I)-1
    GL(ii).x = xGL(I(ii)+1:I(ii+1)-1);
    GL(ii).y = yGL(I(ii)+1:I(ii+1)-1);
    if numel(GL(ii).x)>1
        GL(ii).xmid = xGLmid(I(ii)+1:I(ii+1)-2);
        GL(ii).ymid = yGLmid(I(ii)+1:I(ii+1)-2);
        GL(ii).qGL = qGL(I(ii)+1:I(ii+1)-2);
        GL(ii).l = hypot(GL(ii).x(2:end)-GL(ii).x(1:end-1),GL(ii).y(2:end)-GL(ii).y(1:end-1)); 
        L = cumsum(GL(ii).l);
        GL(ii).L = L(end);
        GL(ii).ind = 0*GL(ii).x+ii;        
    else
        GL(ii).xmid = GL(ii).x;
        GL(ii).ymid = GL(ii).y;
        GL(ii).qGL = 0;
        GL(ii).l = 0;
        GL(ii).L = 0;
        GL(ii).ind = ii;
    end
    GL(ii).basinindex = [];
end
n_tokeep = numel(GL); % keep all segments
[~,I] = maxk([GL(:).L],n_tokeep);

GL = GL(I);

%% check proximity to basins
xGL = cell2mat({GL(:).xmid}'); yGL = cell2mat({GL(:).ymid}'); qGL = cell2mat({GL(:).qGL}');
PQ = [xGL yGL]; dist = [];
for ii=1:numel(B.x)
    P = [B.x{ii} B.y{ii}];
    [~,dist(ii,:)] = dsearchn(P,PQ);
end
[~,I] = min(dist,[],1); 

for ii=1:numel(B.x)
    B.GLpoints{ii} = find(I==ii);
    B.xGL{ii} = xGL(B.GLpoints{ii});
    B.yGL{ii} = yGL(B.GLpoints{ii});
    B.qGL{ii} = qGL(B.GLpoints{ii});
end

for ii=1:numel(GL)
    basinindex = I(1:numel(GL(ii).xmid));        
    GL(ii).basinindex = mode(basinindex);
    I(1:numel(GL(ii).xmid))=[];
end
