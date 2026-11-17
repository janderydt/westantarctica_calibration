function [UserVar,RunInfo,F,l,EleSizeDesired,ElementsToBeRefined,ElementsToBeCoarsened]=...
% DefineDesiredEleSize  Ua user input file of the synthetic SYNTH_PIG experiments: desired element sizes (empty).
%
% PURPOSE
%   Empty: no changes are made to the desired element sizes or to the elements to be refined or coarsened.
%   Called by Ua when the mesh is adapted (CtrlVar.AdaptMesh=1, set in DefineInitialInputs for time-dependent runs).
    DefineDesiredEleSize(UserVar,RunInfo,CtrlVar,MUA,BCs,F,l,x,y,EleSizeDesired,ElementsToBeRefined,ElementsToBeCoarsened,NodalErrorIndicators)

%% This script is called at the end of NewDesiredEleSizesAndElementsToRefineOrCoarsen2
%% For local refinement, specify ElementsToBeRefined
%% For global refinement, specify EleSizeDesired
