Modified copies of Ua core functions that were used in the runs
================================================================

fminuncOutfun.m
    Ua's fminuncOutfun plus a few lines that stop fmincon when the walltime flag
    'UAstopFlag' (set by the timer in DefineInitialInputs) is true.

InversionUsingMatlabOptimizationToolbox3.m
    Version of the inversion function that sets RunInfo.Inverse.stoppedduetowalltime
    (used in DefineOutputs).

rLineminUa.m, BackTracking.m, CalcMeshDerivatives.m
    Versions of these Ua functions that were used in the runs.

Both master folders (4_inverse and 5_diagnostic) need these files: UaJob
copies the *.m files of the master folder into every experiment folder.
