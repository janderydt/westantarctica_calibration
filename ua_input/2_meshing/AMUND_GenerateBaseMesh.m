function AMUND_GenerateBaseMesh
% AMUND_GenerateBaseMesh  Cut the Amundsen Sea (AMUND) base meshes out of the
% circum-Antarctic refined base mesh.
%
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% This script needs the circum-Antarctic (ANT) refined base mesh (files
% ANT_basemesh_... and ANT_meshboundarycoordinates_... in ../2_meshing),
% which can be obtained upon request from the author.
% This script documents how the AMUND meshes were derived. The
% resulting AMUND meshes, boundaries and fixed boundary points are provided
% on Zenodo (DOI: see README).
%
% PURPOSE
%   For each ice front year, takes the circum-Antarctic (ANT) refined base mesh,
%   which contains the ice fronts of 2000, 2009, 2014 and 2020 as internal
%   boundaries, assigns each node to
%   an IMBIE basin, keeps only the elements that lie in the basins of interest
%   (Getz, Pine Island/Thwaites, Abbott), removes ice rises and islands that
%   are not connected to these basins, and saves the resulting regional mesh,
%   its boundary and the boundary points along which fixed boundary conditions
%   are applied.
%
% INPUTS
%   - basins_IMBIE_v2.mat : IMBIE v2 basin outlines (struct with x, y, name;
%       read with Define_Quantity_PerBasin). Data: can be obtained upon request from the author, see README.
%   - the ANT refined base mesh: DefineBaseMesh locates the files
%       (<UserVar.datafolder>/2_meshing/ANT_basemesh_<ANT_BaseMesh>_extrudemesh1_variableboundaryres1.mat
%       and ANT_meshboundarycoordinates_...), and ApplyMeshModifications
%       cuts it to the ice front of the year UserVar.Geometry and writes
%       "./_InitialMesh.mat" (since UserVar.Experiment is empty), which is
%       read back (UserVar.InitialMeshFileName). Here datafolder is the
%       parent of the current folder.
%   - the folders with the ANT scripts and helper functions (must be on the MATLAB path)
%
% OUTPUTS (current folder; one set per year in the variable "years")
%   AMUND_basemesh_<year>_meshmin1500_meshmax100000_refined_extrudemesh1_variableboundaryres1.mat
%       : MUA
%   AMUND_meshboundarycoordinates_<same tag>.mat : MeshBoundaryCoordinates
%   AMUND_fixedboundarypoints_<same tag>.mat     : xOuter, yOuter
%   Also written as by-products of ApplyMeshModifications:
%   _InitialMesh.mat and _MeshBoundaryCoordinates.mat.
%   DefineBaseMesh expects the AMUND files in <datafolder>/2_meshing:
%   copy them there.
%
% REQUIRES (see README)
%   Ua source code (Ua2D_DefaultParameters, DeactivateMUAelements, PlotMuaMesh, inpoly)
%   DefineBaseMesh, ApplyMeshModifications (same folder; renamed from
%   ANT_DefineBaseMesh and ANT_ApplyMeshModifications), inpoly2
%   Define_Quantity_PerBasin (same folder)
%
% RUN ORDER
%   first script of the mesh chain in this repository (its input, the ANT mesh,
%   is created elsewhere)

%% Settings

basins_to_analyze = {'','F-G',...  % Getz
    'G-H',...  % PIG, Thwaites
    'H-Hp'}; % Abbott
% NOTE: '' is the entry of B.name in basins_IMBIE_v2.mat with an empty name: it stands for the
% ice rises and ice rumples, which are therefore part of the selection (the ones that are not
% connected to the basins of interest are removed later, see PURPOSE).
CtrlVar=Ua2D_DefaultParameters; 
% name of the ANT base mesh (without prefix "ANT_basemesh_" and suffix
% "_extrudemesh1_variableboundaryres1") and of the AMUND base meshes (one per year)
ANT_BaseMesh = "2000_2009_2014_2020_meshmin1500_meshmax100000_refined";
years = ["2000" "2009" "2014" "2020"];
AMUND_BaseMesh = years+"_meshmin1500_meshmax100000_refined";

%% Load basins
filename = 'basins_IMBIE_v2.mat'; 
B = load(filename);

UserVar.casefolder = pwd;
UserVar.datafolder = pwd+"/../";
UserVar.Experiment = "";

UserVar = DefineBaseMesh(UserVar,ANT_BaseMesh);

%% Loop over years
for yy=1:numel(years)
    UserVar.Geometry = double(years(yy));
    UserVar = ApplyMeshModifications(UserVar);
    tmp = load(UserVar.InitialMeshFileName);
    MUA = tmp.MUA; 

    % identify basin id of each MUA node
    [MUA.basins,~] = Define_Quantity_PerBasin(MUA.coordinates(:,1),MUA.coordinates(:,2),B,0);
    MUA_basinnames = erase({MUA.basins(:).name},'-');
    basinnodes_all = [];
    for bb=1:numel(basins_to_analyze) 
        basin = char(erase(basins_to_analyze{bb},'-'));
        [~,BasinInd] = ismember(basin,MUA_basinnames);
        basinnodes = MUA.basins(BasinInd).ind;
        basinnodes_all = [basinnodes_all; basinnodes];
    end
    % deactivate all elements with a node outside the basins of interest
    ElementsToBeDeactivated=any(~ismember(MUA.connectivity,basinnodes_all),2);
    [MUA,MUA.k,MUA.l]=DeactivateMUAelements(CtrlVar,MUA,ElementsToBeDeactivated);
    Ind_nan = find(isnan(MUA.Boundary.x));

    % only keep largest fully connected domain: this throws away ice rises and
    % islands that are not connected to the basins of interest
    % (assumes that the first boundary loop is the outer one)
    MUA.Boundary.x = MUA.Boundary.x(1:Ind_nan(1)-1);
    MUA.Boundary.y = MUA.Boundary.y(1:Ind_nan(1)-1);
    % deactivate any elements outside the new boundary
    basinnodes = find(~inpoly(MUA.coordinates,[MUA.Boundary.x MUA.Boundary.y]));
    ElementsToBeDeactivated=any(ismember(MUA.connectivity,basinnodes),2);
    [MUA,MUA.k,MUA.l]=DeactivateMUAelements(CtrlVar,MUA,ElementsToBeDeactivated);

    MeshBoundaryCoordinates = [MUA.Boundary.x(:) MUA.Boundary.y(:)];

    % coordinates of boundary points at eastern and western edge, used to
    % delimit boundary along which fixed boundary conditions nedd to be
    % applied.
    xE = -1830660; yE = 300814;
    xW = -814920; yW = -1324640;
    [LE,IndE] = min(hypot(MUA.Boundary.x(:)-xE,MUA.Boundary.y(:)-yE));
    [LW,IndW] = min(hypot(MUA.Boundary.x(:)-xW,MUA.Boundary.y(:)-yW));
    xOuter = MUA.Boundary.x(min(IndE,IndW):max(IndE,IndW));
    yOuter = MUA.Boundary.y(min(IndE,IndW):max(IndE,IndW));
    
    % check: mesh (black), boundary (magenta) and fixed boundary points (green)
    figure; PlotMuaMesh(CtrlVar,MUA,[],'k'); hold on;
    plot(MUA.Boundary.x,MUA.Boundary.y,'-m');
    plot(xOuter,yOuter,'-og');
    title(years(yy));

    %% Save mesh, boundary coordinates and fixed boundary points
    save("AMUND_basemesh_"+AMUND_BaseMesh(yy)+"_extrudemesh1_variableboundaryres1.mat","MUA");
    save("AMUND_meshboundarycoordinates_"+AMUND_BaseMesh(yy)+"_extrudemesh1_variableboundaryres1.mat","MeshBoundaryCoordinates");
    save("AMUND_fixedboundarypoints_"+AMUND_BaseMesh(yy)+"_extrudemesh1_variableboundaryres1.mat","xOuter","yOuter");

end

end
