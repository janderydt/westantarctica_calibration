function [UserVar,isStop]=DefineRunStopCriterion(UserVar,RunInfo,CtrlVar,MUA,BCs,F)
% DefineRunStopCriterion  Ua user input file of the synthetic SYNTH_PIG experiments: run-stop criterion.
%
% PURPOSE
%   Stops the run (isStop = true) if the application flag 'UAstopFlag' is true. The flag is not set in this folder,
%   so by default the run is not stopped. Not used in an inverse run.

StopFlag = getappdata(0,'UAstopFlag'); %get stop flag
if StopFlag
  isStop = true;
  UserVar.stoppedduetowalltime = 1;
else
  isStop = false;
  UserVar.stoppedduetowalltime = 0;
end

end
