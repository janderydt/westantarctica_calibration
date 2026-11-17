# TODO (short list)

Only things that are still open. The long history (changes made, flagged items you accepted, decisions) is in
`/mnt/user-data/removed/TODO_full_log.md`.

## A. Missing code (upload when you can)
- The script that creates `DiagnosticData/<domain>/<domain>_perturbation_grids.mat` (meshes `MUA_<year>` and grounding masks `GF_<year>` of each year, read by `plot_PerturbationResults_Ensemble` and `loadvelocitydata`) and the `_HPDSample` versions of the data files.
- The script that turns the sample of `Calc_HPDsample` into the `HPDSample` run table.
- `FluxAcrossGroundingLine_JDR` (`RemoveIceRisesAndIslands` is now in `analysis/postprocessing`).
- `plot_Lcurve` (L-curve analysis, mentioned in the comments of the priors in `Calc_BayesianInference`).
- Scripts that create the other interpolant files: dh/dt (`GriddedInterpolants_dhdt_01-Jun-<year>.mat`, `dhdt_<year>_<year+1>.mat`), RACMO surface mass balance (`ScatteredInterpolants_SMB.mat`), SYNTH_PIG geometry / velocity / dh/dt.
- SYNTH_PIG synthetic experiments (`ua_input/0_synth_pig`, all Define* files received; order spinup -> cold -> warm documented): still missing which files are copied or renamed between the runs (restart files, `C-Estimate_<law>_m<m>.mat`, `AGlen-Estimate_<law>_m<m>.mat`) and the launcher; I can draft a short "how to run" in the README.
- The launcher around `UaWrapper`, an example `ua_config` file, and what merges the experiment run tables into the global one.
- `GenerateRunTable_Diagnostic` in the version that writes all 24 columns (`InverseAFill`, `InverseCFill`), if it differs from the one you sent.
- Names / sources only (not necessarily files): `isapprox`, `inpaint_nans` and the helper functions (`demresize`, `gridbin`, `filt2`, `geoimread`, ...).

## B. Questions for you
1. **File names** (the paper-time versions have the same mismatch): `Calc_BayesianInference` and `plot_Emulator_MSE` read `..._cycle2_floatingice...`, but `prepare_data_for_Delta_u_emulators` writes `..._cycle2-2_floatingice...` for an emulator with two sliding laws (AMUND). Which names do your emulator files have? (Then one side is changed.)
2. Confirm: AMUND emulators are v4, SYNTH_PIG emulators are v5 (noted in the docstring of the training script).
3. `GenerateRunTable_Diagnostic` (the three TODO comments in the code): confirm the file name(s) and domain, the years (2000 to 2020), the perturbations (`Original`, `Calv_thick`, `it = 2`) and the mesh name `AMUND_<year>_meshmin1500_meshmax100000_refined`.
4. Priors: the Bayesian priors (truncated Gaussians for gaA, gaC, gsA, gsC; log-uniform `dhdt_err`) differ from the uniform sampling design of the ensemble. Does this match the paper?
5. Naming: rename the remaining `GLUE_...` folder and file names (`GLUE_Data`, `GLUE_Interpolants`, `GLUE_MeshData`, `GLUE_HelperFunctions`, `GLUE_Inverse`, `GLUE_Diagnostic`, `GLUE_<type>_9999`, `RunTable_GLUE_*`), the `v5_` output prefix, and `Calc_HPDsample` / `HPD`? Is `ua_input/run/ua_core_overrides` the right place?
6. SYNTH_PIG user files: are the options for the "calving" (level set, `DefineCalving`), "nochange" and "test" experiments used in the paper? If not, I remove them.
7. `plot_InverseResults_Ensemble.m` (scatter matrix of the inversion ensemble, in `analysis/postprocessing`): is it used for a figure of the paper? (It is not in `figures/README_figures.md`.)
8. Paper-time versus later versions (the repository keeps the later version where it contains the paper-time functionality; the file and function names are the paper-time names): `plot_myBayesianAnalysis` (later: figure height 80 instead of 70, fewer y ticks, no title with the file name, and the "selected samples" dialog; Figures 3 and 6 are made with which version?), `prepare_data_for_Delta_u_emulators` (later: also saves the Figures A1 and A2; the data processing is identical), `Calc_InverseResults_Ensemble`, `Calc_PerturbationResults_Ensemble`, `plot_PerturbationResults_Ensemble` (later: both domains in one script, file names as arguments; the paper-time versions were set up for SYNTH_PIG and wrote `<domain>_Delta_u_<years>.mat`).

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
- Optional minor items: `Figure5` 2014 block uses `h2000(Ind) = 0` (probably `h2000_tmp`); in `plot_myBayesianAnalysis` the check for an existing HPD file looks in the wrong folder.

