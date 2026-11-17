function [UserVar,as,ab]=DefineMassBalance(UserVar,CtrlVar,MUA,F)
% DefineMassBalance  Ua user input file: surface and basal mass balance.
%
% PURPOSE
%   Surface mass balance as (m ice equivalent/yr), from
%     - SYNTH_PIG_nsmbl: an analytical function of x
%     - AMUND_nsmbl    : RACMO climatology 2000-2018 (m w.e./yr) from
%                        <datafolder>/1_interpolants/ScatteredInterpolants_SMB.mat
%                        (variable Fsmb_RACMO), converted with the nodal density
%   Basal mass balance ab: zero for inverse runs. In spinup runs, "balanced
%   melt" on ocean-connected floating nodes: ab = -dhdt, so that the thickness of
%   the ice shelves stays approximately constant. In the second and later spinup
%   cycles, ab=0 and as is corrected with the observed dhdt (file
%   <datafolder>/1_interpolants/dhdt_<year>_<year+1>.mat) while the ice shelf
%   thickness is fixed (see DefineBoundaryConditions).
%
% REQUIRES
%   Ua source code (GetBoundaryConditions, dhdtExplicitSUPG, IceSheetIceShelves,
%   LakeOrOcean3, CalcMeshMask)

persistent Fsmb

x=MUA.coordinates(:,1);
y=MUA.coordinates(:,2);

%% Surface mass balance:  
if isempty(Fsmb)

    if ismember(string(UserVar.Domain),"SYNTH_PIG_nsmbl")

        xu=min(x(:)); 
        nodesu=find(abs(x-xu)<1.5e5); [~,ind]=sort(MUA.coordinates(nodesu,2)); nodesu=nodesu(ind);
        a=x*0+1;
        a(nodesu)=1-(x(nodesu)-1.5e5)/1.5e5*14;
        Fsmb = scatteredInterpolant(x,y,a);

    elseif ismember(string(UserVar.Domain),"AMUND_nsmbl")

        load(UserVar.datafolder+"1_interpolants/ScatteredInterpolants_SMB.mat","Fsmb_RACMO");
    
        % RACMO climatology between 2000 and 2018
        Istart = find(contains(string(Fsmb_RACMO.years),"2000"));
        Iend = find(contains(string(Fsmb_RACMO.years),"2018"));
        dn = Iend-Istart+1;
        RACMO_smb = 0;
        for ii=1:dn
            yrstr = "yr"+string(1999+ii);
            RACMO_smb = RACMO_smb + Fsmb_RACMO.(yrstr).Values;
        end
        Fsmb = Fsmb_RACMO.climatology; Fsmb.Values = RACMO_smb/dn;  % in m w.e. / yr

    end

end

as = Fsmb(x,y);
as = as*1000./max(F.rho,500); % transfer to m ice equivalent / yr, putting some random cutoff on the density to avoid unrealistically high accumulation rates

%% Basal mass balance: "balanced melt"  
if UserVar.SpinupCycle

    ab = 0*x;

    if F.time>0
        F.as = as;
        F.ab = ab;
        BCs=BoundaryConditions;
        [~,BCs]=GetBoundaryConditions(UserVar,CtrlVar,MUA,BCs,F);
        [~,dhdt]=dhdtExplicitSUPG(UserVar,CtrlVar,MUA,F,BCs);
        ab = -dhdt;
    end
    
    % apply melt on nodes downstream of GL
    GF =IceSheetIceShelves(CtrlVar,MUA,F.GF);   
    NodesDownstreamOfGroundingLines="Relaxed"; % strict
    [LakeNodes,OceanNodes,LakeElements,OceanElements] = LakeOrOcean3(CtrlVar,MUA,GF,[],NodesDownstreamOfGroundingLines);
    ab(LakeNodes) = 0;
    ab(~OceanNodes) = 0;


    % NOTE: the above approach keeps the ice thickness of floating nodes
    % approximately constant, but allows grounded ice to thin, which might lead to
    % grounding line retreat. Applying zero melt rates in newly ungrounded nodes
    % made no meaningful difference and is not compatible with restarts (the melt
    % nodes would have to be saved).

    %% Make adjustments for second spinup cycle: adjust surface mass
    %% balance as -> as - dhdt and run to steady state with fixed ice shelf thickness
    if UserVar.SpinupCycle && UserVar.Spinup.Cycle > 1

        ab = 0*x; % ab can be zero because we keep ice shelf thickness fixed as boundary condition

        dhdt_filename = UserVar.datafolder+"/1_interpolants/dhdt_"+string(UserVar.Geometry)+"_"+string(UserVar.Geometry+1)+".mat";

        if exist(dhdt_filename,"file")==2

            if isempty(Fdhdt)
                load(dhdt_filename);
                % only retain floating nodes from Paolo and grounded nodes from
                % Otosaka
                FGFmask = scatteredInterpolant(x,y,GF.node);
                GFo = FGFmask(Xo,Yo);
                GFp = FGFmask(Xp,Yp);
                Io = find(GFo > 0.5 & ~isnan(dhdto));
                Ip = find(GFp < 0.5 & ~isnan(dhdtp));
                xnew = [Xo(Io); Xp(Ip)]; ynew = [Yo(Io); Yp(Ip)];
                dhdt_obs = [dhdto(Io); dhdtp(Ip)];
                Fdhdt = scatteredInterpolant(xnew(:),ynew(:),dhdt_obs(:),'natural');
            end

        else

            error(dhdt_filename+" does not exist.");

        end

        as = as - Fdhdt(x,y);
        fprintf("Removed observed dhdt from as.\n");
            
    end

elseif UserVar.InverseCycle

    ab = 0*x;

end

end
