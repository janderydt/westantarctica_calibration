function  BCs=DefineBoundaryConditions(UserVar,CtrlVar,MUA,BCs,time,s,b,h,S,B,ub,vb,ud,vd,GF)
% DefineBoundaryConditions  Ua user input file: boundary conditions.
%
% PURPOSE
%   Velocities are fixed (to the measured velocities, UserVar.VelocityInterpolants)
%   at the boundary nodes within 1 m of the line given by the fixed boundary points
%   (UserVar.BaseMesh.FixedBoundaryPoints, variables xOuter, yOuter). In the second and
%   later spinup cycles the ice thickness of floating nodes is fixed.
%
% REQUIRES
%   Ua source code (DistanceToLineSegment)

  
if ~isempty(UserVar.BaseMesh.FixedBoundaryPoints)
         
    % load points that define the line-segments along which the BCs are to be defined
    tmp=load(UserVar.BaseMesh.FixedBoundaryPoints);

    if ~isfield(tmp,"xOuter")
        try
            xOuter = tmp.FixedBoundaryCoordinates(:,1);
            yOuter = tmp.FixedBoundaryCoordinates(:,2);
        catch
            error("Check format of Fixed boundary coordinates file");
        end
    else
        xOuter = tmp.xOuter;
        yOuter = tmp.yOuter;
    end

    AA=[xOuter(1:end-1) yOuter(1:end-1)] ; BB=[xOuter(2:end) yOuter(2:end)];

    x = MUA.coordinates(:,1); y = MUA.coordinates(:,2);

    % find all boundary nodes within 1m distance from the line segment.
    tolerance=1;
    I = DistanceToLineSegment([x(MUA.Boundary.Nodes) y(MUA.Boundary.Nodes)],AA,BB,tolerance);
    
    BCs.vbFixedNode=MUA.Boundary.Nodes(I);
    BCs.ubFixedNode=MUA.Boundary.Nodes(I);
    
    load(UserVar.VelocityInterpolants);

    Fus.Method = "linear";
    Fus.ExtrapolationMethod = "nearest";

    Fvs.Method = "linear";
    Fvs.ExtrapolationMethod = "nearest";

    BCs.ubFixedValue=Fus(x(BCs.ubFixedNode),y(BCs.ubFixedNode));
    BCs.vbFixedValue=Fvs(x(BCs.vbFixedNode),y(BCs.vbFixedNode));
    
    nanInd = find(isnan(BCs.ubFixedValue) | isnan(BCs.vbFixedValue));
    BCs.ubFixedValue(nanInd)=0;
    BCs.vbFixedValue(nanInd)=0;

end

if UserVar.SpinupCycle && UserVar.Spinup.Cycle > 1

    %% spinup: keep ice thickness for ice shelves fixed
    if CtrlVar.AdaptMesh==0

        IndIS= find(GF.node < 0.5);
        BCs.hFixedNode=IndIS;
        BCs.hFixedValue=h(IndIS);

        fprintf("Adding fixed ice shelf thickness condition to BCs.\n");

    else
    
        fprintf("Implement fixed ice shelf thickness for a changing mesh.\n");
        error("Implement fixed ice shelf thickness for a changing mesh");
        
    end

end

end
