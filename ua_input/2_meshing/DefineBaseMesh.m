function UserVar = DefineBaseMesh(UserVar,BaseMesh)
% DefineBaseMesh  Locate the files of a named base mesh.
%
% PURPOSE
%   Translates the name of a base mesh (the "startMesh" of the run table, e.g.
%   "AMUND_2000_meshmin1500_meshmax100000_refined" or "SYNTH_PIG") into the
%   files that make up the mesh, and stores them in UserVar.BaseMesh.
%
% INPUTS
%   UserVar.datafolder : folder that contains the folder GLUE_MeshData (with
%                        the mesh files)
%   UserVar.ExpID      : experiment number (only used in the error message)
%   BaseMesh           : name of the base mesh (see the cases below)
%
% OUTPUT (fields added to UserVar)
%   UserVar.BaseMesh.Mesh               : file with the mesh (variable MUA)
%   UserVar.BaseMesh.BCs                : file with the mesh boundary coordinates
%                                         (variable MeshBoundaryCoordinates)
%   UserVar.BaseMesh.FixedBoundaryPoints: file with the points along which
%                                         fixed boundary conditions are applied
%                                         (xOuter, yOuter), or '' if none
%
% MESH FILE NAMES (in <UserVar.datafolder>/GLUE_MeshData/)
%   AMUND: AMUND_basemesh_<name>_extrudemesh1_variableboundaryres1.mat,
%          AMUND_meshboundarycoordinates_<name>_extrudemesh1_variableboundaryres1.mat,
%          AMUND_fixedboundarypoints_<name>_extrudemesh1_variableboundaryres1.mat
%          where <name> is the base mesh name without "AMUND_"
%          (written by AMUND_GenerateBaseMesh)
%   ANT  : (only '2000_2009_2014_2020_meshmin1500_meshmax100000_refined', the
%          circum-Antarctic mesh from which AMUND_GenerateBaseMesh cuts the AMUND
%          meshes; can be obtained upon request from the author) ANT_basemesh_<name>_extrudemesh1_variableboundaryres1.mat
%          and ANT_meshboundarycoordinates_<name>_extrudemesh1_variableboundaryres1.mat
%   SYNTH_PIG: SYNTH_PIG_MeshFile_Ele22114_Nod3.mat, SYNTH_PIG_BoundaryCoordinates.mat,
%          SYNTH_PIG_FixedBoundaryPoints.mat (mesh created offline)

UserVar.BaseMesh.FixedBoundaryPoints = '';

switch char(BaseMesh)
    case '2000_2009_2014_2020_meshmin1500_meshmax100000_refined'
        % circum-Antarctic (ANT) mesh, only used as input of AMUND_GenerateBaseMesh
        UserVar.BaseMesh.BCs = UserVar.datafolder+"GLUE_MeshData/ANT_meshboundarycoordinates_"+BaseMesh+"_extrudemesh1_variableboundaryres1.mat";
        UserVar.BaseMesh.Mesh = UserVar.datafolder+"GLUE_MeshData/ANT_basemesh_"+BaseMesh+"_extrudemesh1_variableboundaryres1.mat";
    case {'AMUND_2000_2009_2014_2020_meshmin1500_meshmax100000_refined','AMUND_2000_meshmin1500_meshmax100000_refined',...
           'AMUND_2009_meshmin1500_meshmax100000_refined','AMUND_2014_meshmin1500_meshmax100000_refined',...
           'AMUND_2020_meshmin1500_meshmax100000_refined'}
        % Amundsen Sea meshes, one per ice front year (AMUND_GenerateBaseMesh)
        UserVar.BaseMesh.BCs = UserVar.datafolder+"GLUE_MeshData/AMUND_meshboundarycoordinates_"+erase(BaseMesh,"AMUND_")+...
            "_extrudemesh1_variableboundaryres1.mat";
        UserVar.BaseMesh.Mesh = UserVar.datafolder+"GLUE_MeshData/AMUND_basemesh_"+erase(BaseMesh,"AMUND_")+...
            "_extrudemesh1_variableboundaryres1.mat";
        UserVar.BaseMesh.FixedBoundaryPoints = UserVar.datafolder+"GLUE_MeshData/AMUND_fixedboundarypoints_"+erase(BaseMesh,"AMUND_")+...
            "_extrudemesh1_variableboundaryres1.mat";
    case 'SYNTH_PIG'
        % synthetic Pine Island Glacier mesh, created offline
        UserVar.BaseMesh.BCs = UserVar.datafolder + "GLUE_MeshData/SYNTH_PIG_BoundaryCoordinates.mat";
        UserVar.BaseMesh.Mesh = UserVar.datafolder + "GLUE_MeshData/SYNTH_PIG_MeshFile_Ele22114_Nod3.mat";
        UserVar.BaseMesh.FixedBoundaryPoints = UserVar.datafolder + "GLUE_MeshData/SYNTH_PIG_FixedBoundaryPoints.mat";
    otherwise
        error(['ExpID ',num2str(UserVar.ExpID),': Do not recognise Mesh flag in RunTable.']);
end

end
