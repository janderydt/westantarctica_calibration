function [UserVar,LSF,c]=DefineCalving(UserVar,CtrlVar,MUA,LSF,c,F,BCs)
% DefineCalving  Ua user input file of the synthetic SYNTH_PIG experiments: calving front (level set) and calving rate.
%
% PURPOSE
%   Only used for the "calving" experiments (CtrlVar.LevelSetMethod=1, set in DefineInitialInputs). At the start of the
%   run the level-set field LSF is initialised: with UserVar.RunType = "-c0isGL0-" the initial calving front is the grounding
%   line (LSF = +1 where the ice is grounded, -1 elsewhere); otherwise the front is given by UserVar.CalvingFront0 (Xc, Yc).
%   Experiments whose name contains "CalveFloating1" remove ungrounded ice at every time step, and "LakeCorrection1" sets
%   LSF to 1 at lake nodes. The calving rate c is NaN for a prescribed level set (CtrlVar.LevelSetEvolution =
%   "-Prescribed-"), defined at integration points if CtrlVar.CalvingLaw.Evaluation = "-int-", and otherwise a simple example law:
%   30000 m/yr where the cliff height is larger than 100 m.
%
% REQUIRES
%   Ua source code (LakeOrOcean3, DefineCalvingAtIntegrationPoints); inpoly2 (Ua / Mesh2d)

%% initialize LSF
if isempty(F.LSF)   % Do I need to initialize the level set function?

    % If, for example, all floating ice should be removed at the beginning of the simulations
    % then the level-set can simply be defined in such a way that LSF>0 where the ice is grounded, and <0 otherwise

    if contains(UserVar.RunType,"-c0isGL0-")  % -> Initial calving front (c0) is set a initial grounding line position (GL0)

        LSF=-ones(MUA.Nnodes,1) ;
        LSF(F.GF.node>0.5)=+1;    % LSF set dependent on the values grounded-floating mask
        Xc=[] ;  % If Xc and Yc are left empty, the Xc and Yc will be calculated as the zero control of the LSF field
        Yc=[] ;

    else

        Xc=UserVar.CalvingFront0.Xc;  % Here is is assumed that the user has defined the desired initial location of the calving front, and stored those in UserVar
        Yc=UserVar.CalvingFront0.Yc;

        % A rough sign-correct initialization for the LSF
        io=inpoly2([F.x F.y],[Xc(:) Yc(:)]);
        LSF=-ones(MUA.Nnodes,1) ;
        LSF(io)=+1;

    end

    % Not really needed, but it might then be good to initialize the level set so that LSF is approximately a signed distance
    % function.
    %

else

    % modify LSF at each timestep to remove any newly ungrounded ice
    if contains(CtrlVar.Experiment,"CalveFloating1")
        LSF(F.GF.node<=0.5 & LSF>0)=-1;
    end

end

if contains(CtrlVar.Experiment,"LakeCorrection1")

    [LakeNodes,OceanNodes,LakeElements,OceanElements] = LakeOrOcean3(CtrlVar,MUA,F.GF,[],"Relaxed");
    LSF(LakeNodes)=1;

end

%% Define calving rate (if needed)

if  CtrlVar.LevelSetEvolution=="-Prescribed-"

    c=nan;   % setting the calving rate to nan implies that the level set is not evolved

elseif  CtrlVar.CalvingLaw.Evaluation=="-int-"

    % Generally, one would define the calving rate at the nodes, unless the calving rate is a function of the level-set itself.
    %
    % It the calving rate, c, depends on the level set function, LSF, then various derivatives involving c and LSF (phi) need to be
    % calculated as well for the Newton-Raphson methods to achieve second-order convergence

    % If the calving law is defined at nodes, you still need to use DefineCalving.m as well to define LSF.

    % Generally there is no need to call 'DefineCalvingAtIntegrationPoints' from within DefineCalving.m and the calving rate, c,
    % returned by DefineCalving.m is not used.
    %
    % However, one might find it convenient to define c here as otherwise c is not defined at nodes and can not be plotted at a
    % nodal variable.
    %
    %
    %
    c=DefineCalvingAtIntegrationPoints(UserVar,CtrlVar,nan,nan,F) ;

else

    % Here the calving rate is defined at the nodes. This is presumably the most typical case

    CliffHeight=min((F.s-F.S),F.h) ;

    c=0*CliffHeight;
    c(CliffHeight>100)=30000;  % an example of calving law which depends linearly on the freeboard height.

end
