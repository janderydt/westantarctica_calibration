function UserVar=ApplyMeshModifications(UserVar)
% ApplyMeshModifications  Apply modifications to a base mesh before Ua is started.
%
% PURPOSE
%   This is useful if, e.g., you have a base mesh that extends beyond the
%   intended domain boundary, and you would like to deactivate certain
%   elements of the base mesh. Here: the base mesh is cut to the ice front of
%   a given year (the boundary of that year in the file UserVar.BaseMesh.BCs),
%   elements that are not connected to any other element are removed, and the
%   resulting mesh and boundary are saved for Ua.
%
% INPUTS (fields of UserVar)
%   BaseMesh.Mesh : file with the base mesh (variable MUA)
%   BaseMesh.BCs  : file with MeshBoundaryCoordinates, either an n-by-2 matrix
%                   or a struct with fields yr<year> (one boundary per ice
%                   front year, as in the ANT mesh boundary file)
%   Geometry      : year of the ice front used to cut the mesh. If empty, the
%                   mesh is not modified. Alternatively (field Calv instead of
%                   Geometry): year of the calving front; not used if
%                   UserVar.LevelSetMethod==1.
%   casefolder, Experiment : folder and name of the experiment, used for the
%                   output files
%   ExpID         : experiment number (only used in an error message)
%
% OUTPUTS
%   Files <casefolder>/<Experiment>/<Experiment>_InitialMesh.mat (MUA) and
%   <casefolder>/<Experiment>/<Experiment>_MeshBoundaryCoordinates.mat
%   (MeshBoundaryCoordinates). Fields added to UserVar: BaseMesh.DeactivatedElements,
%   BaseMesh.DeactivatedNodes (indices in the base mesh),
%   MeshBoundaryCoordinatesFile, InitialMeshFileName, Nnodes, Nele.
%
% REQUIRES
%   Ua source code (Nodes2EleMean, Ua2D_DefaultParameters, DeactivateMUAelements),
%   inpoly2 (Ua / Mesh2d); MATLAB triangulation/neighbors

%% Load base mesh and domain boundary
load(UserVar.BaseMesh.Mesh);
load(UserVar.BaseMesh.BCs);

xEle=Nodes2EleMean(MUA.connectivity,MUA.coordinates(:,1));
yEle=Nodes2EleMean(MUA.connectivity,MUA.coordinates(:,2));

%% Find out whether and for which year the mesh has to be adapted
if isfield(UserVar,'Geometry')
    if isempty(UserVar.Geometry)
        adaptmesh = 0;
    else
        variable = UserVar.Geometry;
        adaptmesh = 1;
    end
elseif isfield(UserVar,'Calv')
    if isempty(UserVar.Calv) || UserVar.LevelSetMethod==1
        adaptmesh = 0;
    else
        variable = UserVar.Calv;
        adaptmesh = 1;
    end
else
    error("ExpID "+string(UserVar.ExpID)+": Do not know Geometry.");
end

if adaptmesh

    %% Boundary of the requested year
    if isfield(MeshBoundaryCoordinates,['yr',num2str(variable)])
        BCx = MeshBoundaryCoordinates.(['yr',num2str(variable)])(:,1);
        BCy = MeshBoundaryCoordinates.(['yr',num2str(variable)])(:,2); 
    else
        BCx = MeshBoundaryCoordinates(:,1);
        BCy = MeshBoundaryCoordinates(:,2); 
    end
        
    % take care of potential nans in boundary
    Inan = find(isnan(BCx));
    if ~isempty(Inan)
        BCx = BCx(1:Inan(1)-1);
        BCy = BCy(1:Inan(1)-1);
    end
    
    %% Deactivate elements outside the boundary
    % remove elements that have 1 node or more outside the boundary
    [cn1,~] = inpoly2([MUA.coordinates(MUA.connectivity,1),MUA.coordinates(MUA.connectivity,2)],[BCx(:) BCy(:)]);
    NodesToBeDeactivated = ~cn1;
    NodesToBeDeactivated = reshape(NodesToBeDeactivated,size(MUA.connectivity));
    ElementsToBeDeactivated = find(sum(NodesToBeDeactivated,2)>0);
    
    % then remove elements for which the center of gravity is outside the
    % boundary
    [cn2,~] = inpoly2([xEle(:) yEle(:)],[BCx(:) BCy(:)]);
    Indtmp = find(~cn2);
    ElementsToBeDeactivated = unique([ElementsToBeDeactivated(:); Indtmp(:)]);
    
    CtrlVar=Ua2D_DefaultParameters;
    
    MUA_tmp = DeactivateMUAelements(CtrlVar,MUA,ElementsToBeDeactivated);
    
    % remove 'disconnected' elements: ensure that each element has at least 1 edge
    % in common with 1 other element
    TR = triangulation(MUA_tmp.connectivity,MUA_tmp.coordinates);
    N = neighbors(TR); N(isnan(N))=0;
    N = sum(N,2); ElementsToBeDeactivated_2 = find(N==0);
    
    MUA_tmp = DeactivateMUAelements(CtrlVar,MUA_tmp,ElementsToBeDeactivated_2);
    
    %% Indices of deactivated elements and nodes (in the base mesh)
    xB = MUA_tmp.Boundary.x;
    yB = MUA_tmp.Boundary.y; 
    Inan = find(isnan(xB));
    if ~isempty(Inan)
        xB = xB(1:Inan(1)-1);
        yB = yB(1:Inan(1)-1);
    end
    I = find(~inpoly2([xEle(:) yEle(:)],[xB(:) yB(:)]));
    UserVar.BaseMesh.DeactivatedElements = I;
    
    x = MUA.coordinates(:,1);
    y = MUA.coordinates(:,2);
    [In,On] = inpoly2([x(:) y(:)],[xB(:) yB(:)]);
    I = [1:MUA.Nnodes]; I(unique([find(In(:)==1);find(On(:)==1)]))=[];
    UserVar.BaseMesh.DeactivatedNodes = I;

    MUA = MUA_tmp;

end

MUA.workers = [];
MUA.Deriv=[]; MUA.DetJ=[]; MUA.M=[]; MUA.dm=[]; % save some space

%% Save updated boundary and mesh for Ua
MeshBoundaryCoordinates = [MUA.Boundary.x(:) MUA.Boundary.y(:)];

MeshBoundaryCoordinatesFileName = UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.Experiment+"_MeshBoundaryCoordinates.mat";
InitialMeshFileName = UserVar.casefolder+"/"+UserVar.Experiment+"/"+UserVar.Experiment+"_InitialMesh.mat";

save(MeshBoundaryCoordinatesFileName,"MeshBoundaryCoordinates");
save(InitialMeshFileName,"MUA");

UserVar.MeshBoundaryCoordinatesFile = "./"+UserVar.Experiment+"_MeshBoundaryCoordinates.mat";
UserVar.InitialMeshFileName = "./"+UserVar.Experiment+"_InitialMesh.mat";
UserVar.Nnodes = MUA.Nnodes;
UserVar.Nele = MUA.Nele;

end 
