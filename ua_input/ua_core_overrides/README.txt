Copies of Ua core functions that were used in the runs (pending decision, see TODO.md)
=====================================================================================

fminuncOutfun.m
    Ua's fminuncOutfun plus a few lines that stop fmincon when the walltime flag
    'UAstopFlag' (set by the timer in DefineInitialInputs) is true. The current UaSource
    master does not contain this walltime logic ('UAstopFlag' / 'stoppedduetowalltime').

InversionUsingMatlabOptimizationToolbox3.m
    Older version of Ua's InversionUsingMatlabOptimisationToolbox3 (note the spelling
    with z). It sets RunInfo.Inverse.stoppedduetowalltime (used in DefineOutputs). The
    current UaSource master calls InversionUsingMatlabOptimisationToolbox3 (with s,
    11 input arguments), so this file is only called by older Ua versions.

rLineminUa.m, BackTracking.m, CalcMeshDerivatives.m
    Older versions of Ua functions (the current UaSource versions have a different number
    of outputs / inputs; for example the current rLineminUa returns 11 outputs and the
    current CalcMeshDerivatives is a stub). They do not match any commit of the UaSource
    history that was available (earliest commit 2025-12). If your Ua version is older, they
    belong to that Ua version; if you use a current Ua version, they must NOT be placed
    before UaSource on the path.

Put this folder before UaSource on the MATLAB path only with the Ua version these files
were taken from.

Both master folders (GLUE_Inverse_9999 and GLUE_Diagnostic_9999) need these files: GLUE_UaJob
copies the *.m files of the master folder into every experiment folder. The diagnostic
upload contained an identical copy of CalcMeshDerivatives.m; it is not duplicated here.
