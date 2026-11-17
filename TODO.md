# TODO (short list)

Only things that are still open. The long history (changes made, flagged items you accepted, decisions) is in
`/mnt/user-data/removed/TODO_full_log.md`.

## A. Missing code (upload when you can)
- `plot_Emulator_MSE` / `FigureA3_Emulator_MSE.m`: writes the `MSE_RNN_<modelversion>_*.mat` files that `calc_BayesianInference_u` reads (and makes Figure A3).
- The script that writes `DiagnosticData/<domain>/<domain>_Delta_u_*.mat` (also the `_HPDSample` files and `AMUND_perturbation_grids.mat`).
- The script that creates `InversionData/<domain>/*_inversiondata_*.mat`.
- The script that turns the sample of `calc_HPDsample` into the `HPDSample` run table.
- `RemoveIceRisesAndIslands` and `FluxAcrossGroundingLine_JDR`.
- `plot_Lcurve` and `plot_InverseParameterDistribution` (mentioned in the comments of the priors).
- Scripts that create the other interpolant files: dh/dt (`GriddedInterpolants_dhdt_01-Jun-<year>.mat`, `dhdt_<year>_<year+1>.mat`), RACMO surface mass balance (`ScatteredInterpolants_SMB.mat`), SYNTH_PIG geometry / velocity / dh/dt.
- The launcher around `UaWrapper`, an example `ua_config` file, and what merges the experiment run tables into the global one.
- `GenerateRunTable_Diagnostic` in the version that writes all 24 columns (`InverseAFill`, `InverseCFill`), if it differs from the one you sent.
- Names / sources only (not necessarily files): `isapprox`, `inpaint_nans` and the helper functions (`demresize`, `gridbin`, `filt2`, `geoimread`, ...).

## B. Questions for you
1. **File names**: the emulator / data / SVD / MSE lookups in `calc_BayesianInference_u` and `plot_BayesianAnalysisResults_u` expect `..._cycle2_...`, but `prep_EmulatorTrainingData_deltaU` writes `cycle2-2` for two sliding laws. Which one do your files use? (Then one side is changed.)
2. Confirm: AMUND emulators are v4, SYNTH_PIG emulators are v5 (noted in the docstring of the training script).
3. `GenerateRunTable_Diagnostic` (the three TODO comments in the code): confirm the file name(s) and domain, the years (2000 to 2020), the perturbations (`Original`, `Calv_thick`, `it = 2`) and the mesh name `AMUND_<year>_meshmin1500_meshmax100000_refined`.
4. Priors: the Bayesian priors (truncated Gaussians for gaA, gaC, gsA, gsC; log-uniform `dhdt_err`) differ from the uniform sampling design of the ensemble. Does this match the paper?
5. Naming: rename the remaining `GLUE_...` folder and file names (`GLUE_Data`, `GLUE_Interpolants`, `GLUE_MeshData`, `GLUE_HelperFunctions`, `GLUE_Inverse`, `GLUE_Diagnostic`, `GLUE_<type>_9999`, `RunTable_GLUE_*`), the `v5_` output prefix, and `calc_HPDsample` / `HPD`? Is `ua_input/run/ua_core_overrides` the right place?

## C. Data and publication
- Zenodo: DOIs for the meshes (AMUND meshes with boundary and fixed-boundary files, SYNTH_PIG mesh files) and the processed data.
- Decide what else to ship: trained emulators (SavedModel folders and `RNN/mat_files`), the Bayesian analysis files used by Figures 3, 4, 6 and 7 (large), the `*_EXTRUDED.mat` interpolants, the ensemble run tables and `UQ_input_..._SampleSize_300_Enrich_0.mat`.
- Licences: of the original Rosier et al. training script, `LICENSE` of this repository, third-party data.
- `.gitignore`; a contact for the data "upon request".

## D. README still to fill
- Title, paper citation and DOI, contact, DOIs in "Data availability".
- Table of the public input datasets (name, version, citation, link).
- Versions: UaSource commit, MATLAB release, Python packages of `tf213_env`, the MATLAB function used to import the TensorFlow models, names / versions of the third-party functions (`cmocean`, `fig`, `demresize`, ...).
- Interfaces of the reader functions (`measures_annual`, `itslive_annual`, `measures_amundsen`, `bedmap2_interp`, `read_Bamber_2004`) and the folder layout of a run (master folders, working folders): I can draft both from the code.

## E. Before publishing
- **Test run**: none of the cleaned scripts has been executed; run at least steps 3, 7, 8 and the figures that can be made from the processed data.
- Optional minor items: `Figure5` 2014 block uses `h2000(Ind) = 0` (probably `h2000_tmp`); in `plot_BayesianAnalysisResults_u` the check for an existing HPD file looks in the wrong folder.