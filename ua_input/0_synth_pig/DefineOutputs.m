function UserVar=DefineOutputs(UserVar,CtrlVar,MUA,BCs,F,l,GF,InvStartValues,InvFinalValues,Priors,Meas,BCsAdjoint,RunInfo)
% DefineOutputs  Ua user input file of the synthetic SYNTH_PIG experiments: save the results.
%
% PURPOSE
%   Saves UserVar, CtrlVar, MUA and F in ./ResultsFiles/<Experiment>/ResultsFile-<Experiment>-<time>yr.mat, where <time> is
%   CtrlVar.time written with the format %09.3f and the decimal point replaced by "k" (for example 00030k000 for 30 years).
%%

plots='-save-';

%% SAVE outputs
if contains(plots,'-save-')

    % save data in files with running names
    % check if folder 'ResultsFiles' exists, if not create

    if exist(fullfile(cd,"ResultsFiles/"+CtrlVar.Experiment),'dir')~=7
        mkdir("./ResultsFiles/"+CtrlVar.Experiment) ;
    end

    FileName=sprintf("%s/ResultsFile-%s-%syr.mat",...
            "./ResultsFiles/"+CtrlVar.Experiment+"/",CtrlVar.Experiment,...
            replace(num2str(CtrlVar.time,'%09.3f'),".","k"));
    fprintf(' Saving data in %s \n',FileName)
    save(FileName,'UserVar','CtrlVar','MUA','F');

end
