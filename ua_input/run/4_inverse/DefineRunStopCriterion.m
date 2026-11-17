function [UserVar,isStop]=DefineRunStopCriterion(UserVar,RunInfo,CtrlVar,MUA,BCs,F) 

%% DefineRunStopCriterion.m
%
% If the field 
%
%   CtrlVar.UseUserDefinedRunStopCriterion 
%
% is set to true in 
%
%   Ua2D_InitialUserInput.m
% 
% then the m-file 
%
%   DefineRunStopCriterion.m
%
% can be used to specify a run-stop criterion. Make sure this m-file is in your
% local run directory. 
%
% The criterion is used within the run-step loop, ie in both time dependent and
% time independent runs.
%
% Note that this criterion is not used in an inverse run and has therefore no
% effect on if and when an inverse run stops.
%
%%

% stop the run when the walltime flag has been raised (timer started in DefineInitialInputs)
StopFlag = getappdata(0,'UAstopFlag'); %get stop flag
if StopFlag
  isStop = true;
  UserVar.Spinup.stoppedduetowalltime = 1;
else
  isStop = false;
  UserVar.Spinup.stoppedduetowalltime = 0;
end

end
