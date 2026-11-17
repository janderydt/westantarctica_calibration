# To-do list: reproducibility repository

Last updated after: AI-use statement added to `README.md` and `WORKFLOW.md` (authors to confirm the wording); plotting scripts of the paper cleaned (`figures/`).
All updated files are kept in /mnt/user-data/outputs (download at the end).
Scripts removed from the repository (ANT mesh chain) are kept outside the output folder in /mnt/user-data/removed/ANT_meshing and can be restored.

## 0. NEXT: still to send

- [x] Run table scripts: `ua_input/runtable/GLUE_GenerateSampleSpace_Inverse.m`, `GLUE_GenerateRunTable_Inverse.m`, `GLUE_ReadWritetable.m`
- [x] Ua user input files for the **inverse** stage (inverse and spinup cycles): `ua_input/inverse/*`, `ua_input/ua_core_overrides/*`
- [x] `GLUE_UaWrapper`, `GLUE_UaJob`, `GLUE_CleanUp` (`ua_input/run`; shared by inverse and diagnostic)
- [ ] The launcher around the wrapper (shell/queue script that starts MATLAB, passes `ua_config`/`pgid`, watches `<pgid>_job_submitted`), an example `ua_config` text file, and whatever copies the experiment run tables back into the global run table (`GLUE_CleanUp` only writes the experiment table; `GLUE_UaJob` says the global table is updated once all simulations are finished on ARCHER2)
- [x] Diagnostic stage: `GLUE_GenerateRunTable_Diagnostic`, `GLUE_GetUserVar_Diagnostic`, Define* files (`ua_input/diagnostic`)
- [x] First analysis scripts: `analysis/emulation/prep_EmulatorTrainingData_deltaU.m`, `analysis/bayesian_inference/calc_HPDsample.m`
- [ ] **Postprocessing** scripts that read the results of the inverse and diagnostic runs and write the reduced data used for emulation, calibration and plotting ("for transparency, not runnable"), in particular the one that writes `DiagnosticData/<domain>/<domain>_Delta_u_<startyear>-<targetyear>[_<slidinglaw>].mat`
- [x] RNN training script (Python): `analysis/emulation/RNN_network_optimisation_JDR_v5.py` (+ draft `requirements_RNN.txt`)
- [x] Bayesian inference: `main_BayesianInference_u.m`, `calc_BayesianInference_u.m`
- [x] `loadvelocitydata`, `Calc_MarginalsInference` (fits `myPosteriorDist`, input of `calc_HPDsample`), `main_PerturbationResultsEnsemble` (postprocessing of the diagnostic results, "for transparency, not runnable"); `Calc_UaGLFlux_PerBasin`, `Calc_UaOBFlux_PerBasin` (basin fluxes, also "for transparency, not runnable"); `FluxAcrossBoundary` (helper of the open-boundary flux)
- [x] Figure scripts (`figures/`): Figures 1, 2, 3 + 6 (`plot_BayesianAnalysisResults_u`), 4, 5, 7, and `README_figures.md`
- [ ] Remaining: `FigureA3_Emulator_MSE.m` (Figure A3; probably also writes the `MSE_RNN_*.mat` files that the likelihood needs: is this `plot_Emulator_MSE`?), `plot_Lcurve`, `plot_InverseParameterDistribution`, the script that writes the `InversionData/<domain>/*_inversiondata_*.mat` files, the script that writes `DiagnosticData/<domain>/<domain>_Delta_u_*.mat` (and the `_HPDSample` and `_perturbation_grids` files)
- [ ] Is the **Transient** run type used in this project? The wrapper (`GLUE_GetUserVar_Transient`), `GLUE_ReadWritetable` and the run table types have a transient branch. If not, I remove it.
- [ ] Anything that launches/chains the runs (job scripts, restart handling) and the code that updates the run table (`Submitted`, `Running`, `Finished`, `ExpID`, ...)
- [ ] Note which of these depend on raw model output -> "for transparency, not runnable" where needed

## Proposed pipeline / run order (ua_input)

0. `ua_input/runtable/GLUE_GenerateSampleSpace_Inverse.m` (calls `GLUE_GenerateRunTable_Inverse.m`, `GLUE_ReadWritetable.m`) -> run table CSV(s) with the parameters of every ensemble member
1. `ua_input/interpolants/Create_BMv3_B2_Bam2009_RAMP2_RefGeomGriddedInterpolants.m`  -> reference geometry
2. `Create_MeaSUREs_ITSLIVE_1996_2003_VelocityGriddedInterpolants.m` and `Create_MeaSUREs_ITSLIVE_20xx_VelocityGriddedInterpolants.m` -> velocities (NOTE: `Calc_SVD_basis` needs the EXTRUDED velocities of the start and target years: `Create_ExtrudedFields_GriddedInterpolants` option `'-v-'`, so the 20xx velocity script and the velocity extrusion ARE needed for 2009/2014/2020)
3. `Create_Geometry_from_reference_and_ds.m` (uses `Calc_ITSLIVE_CPOM_Paolo2023_Deltas.m`, `Calc_dh_from_ds.m`) -> geometry for a target date (e.g. 01-Jun-2000)
4. `Create_ExtrudedFields_GriddedInterpolants.m` (uses `ExtrudeField.m`) -> `GriddedInterpolants_Geometry_01-Jun-<year>_EXTRUDED.mat`
   The inverse stage reads (from `<datafolder>/GLUE_Interpolants`): the EXTRUDED geometry of the year `startGeometry` and the NOT extruded `GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities.mat` (`Velocity = "2000"`). So extruded velocities and the 20xx velocity script are only needed if the diagnostic stage uses other years (to be checked).
5. `ua_input/meshing/AMUND_GenerateBaseMesh.m` (FOR TRANSPARENCY, NOT RUNNABLE: needs the circum-Antarctic mesh, which is created elsewhere and not distributed; uses `GLUE_DefineBaseMesh.m`, `GLUE_ApplyMeshModifications.m`, `Define_Quantity_PerBasin.m`) -> AMUND base meshes for 2000/2009/2014/2020
6. SYNTH_PIG mesh: created offline (file provided)
8. Diagnostic stage in Ua (type "Diagnostic"): `GLUE_GenerateRunTable_Diagnostic` builds the diagnostic run table from the inverse run tables (one velocity solve per finished inversion and perturbation: Original, Calv, ISthick, thick, Calv_thick); `GLUE_GetUserVar_Diagnostic` + Define* files in `ua_input/diagnostic` (master folder `GLUE_Diagnostic_9999`). Needs the inversion results (restart files), not distributed.
9. Analysis (planned layout `analysis/`): postprocessing of the inverse and diagnostic results -> `DiagnosticData/` (delta u maps, not runnable) -> `analysis/emulation/prep_EmulatorTrainingData_deltaU.m` (`Calc_SVD_basis`, SVD, data for the TensorFlow RNN) -> emulator training (`analysis/emulation/RNN_network_optimisation_JDR_v5.py`, Python/TensorFlow 2.13; writes `Emulators/<domain>/RNN/TF_files/v5_tuned_model_*`) -> postprocessing of the posterior-sample experiments (`analysis/postprocessing/main_PerturbationResultsEnsemble.m`, not runnable; writes `perturbationdata_*.mat` with grounding-line and open-boundary fluxes per basin) / Bayesian inference (`analysis/bayesian_inference/main_BayesianInference_u.m` -> `calc_BayesianInference_u.m`; MCMC with UQLab, emulators imported in MATLAB; writes `BayesianAnalysis/<domain>/*.mat`) -> `analysis/bayesian_inference/calc_HPDsample.m` (sample from the posterior; probably the origin of the `HPDSample` inverse run table) -> figures.
7. Inverse stage in Ua (user input files in `ua_input/inverse`, started by `GLUE_UaWrapper` -> `GLUE_UaJob` -> `Ua2D`, finished by `GLUE_CleanUp`; scripts in `ua_input/run`): `GLUE_GetUserVar_Inverse` reads the run table row and calls `GLUE_DefineBaseMesh` + `GLUE_ApplyMeshModifications`. Cycles: inverse 1 (10000 iterations, velocities only) -> spinup 1 (3 years) -> inverse 2 (5000 iterations, velocities and dhdt) for `InverseIterations="10000+5000"`, `SpinupYears="3"`.

## 1. Files / information YOU need to provide

- [ ] **MESH FILES FOR ZENODO** (you upload: AMUND and SYNTH_PIG only). Still needed: DOI/URL; I then replace `DOI: TODO` in the header of `AMUND_GenerateBaseMesh.m` and in the README. Files expected by `GLUE_DefineBaseMesh` in `<datafolder>/GLUE_MeshData/`:
      - AMUND, for each year 2000, 2009, 2014, 2020: `AMUND_basemesh_<year>_meshmin1500_meshmax100000_refined_extrudemesh1_variableboundaryres1.mat`, `AMUND_meshboundarycoordinates_<same>.mat`, `AMUND_fixedboundarypoints_<same>.mat` (12 files)
      - SYNTH_PIG (created offline, **you will provide a copy**): `SYNTH_PIG_MeshFile_Ele22114_Nod3.mat`, `SYNTH_PIG_BoundaryCoordinates.mat`, `SYNTH_PIG_FixedBoundaryPoints.mat` (3 files); a short description of how it was made (software, boundary, geometry) would be good
- [ ] **For the run table scripts**:
      - `EmptyTable.csv`: created from the header of `RunTable_GLUE_Inverse_9999.csv` (35 columns) in `ua_input/runtable/`; the scripts expect it at `../GLUE_Inverse/EmptyTable.csv`
      - the **actual run table CSV(s) used for the ensemble** (`NewTable_AMUND_nsmbl_Adjoint_Weertman_Enriched0_<date>.csv` and chunks `..._1.csv`, and the SYNTH_PIG table) and `UQ_input_..._SampleSize_300_Enrich_0.mat` (small; probably the most useful files to ship in `data/ua_input`)
      - UQLab Rel. 2.0.0 is third party (free registration, cannot be redistributed): README only
- [ ] **For `AMUND_GenerateBaseMesh.m`**: the file `basins_IMBIE_v2.mat` (source/link of the IMBIE v2 basins; struct with `x`, `y`, `name`). Which region is the basin with the empty name `''` that the script includes?
- [x] **Ua**: the repository needs a Ua installation (UaSource, https://github.com/GHilmarG/UaSource); no specific commit is recorded (your decision). Note for the README: the five files in `ua_input/ua_core_overrides` are older/modified copies of Ua core functions that are copied into every experiment folder (they shadow UaSource there); `fminuncOutfun.m` and `InversionUsingMatlabOptimizationToolbox3.m` hold the walltime restart logic. Decide whether to ship all five (default: yes) or only these two.
- [ ] **Data preparation scripts for `GLUE_Interpolants` (not yet seen):** `GriddedInterpolants_dhdt_01-Jun-<year>.mat` (variables `Fdhdt_CPOM` or `Fdhdt`, optional `Fdhdt_err`), `ScatteredInterpolants_SMB.mat` (RACMO, `Fsmb_RACMO` with `.years`, `.yrXXXX`, `.climatology`), `dhdt_<year>_<year+1>.mat` (only for more than one spinup cycle; variables `Xo,Yo,dhdto,Xp,Yp,dhdtp`). Which scripts create them?
- [ ] **SYNTH_PIG input files** (small, ship with the SYNTH_PIG mesh): `ScatteredInterpolants_Geometry_SYNTH_PIG_30_Umbi.mat`, `ScatteredInterpolants_Velocities_SYNTH_PIG_30_Umbi.mat`, `ScatteredInterpolants_dhdt_SYNTH_PIG_30_Umbi.mat` (the surface mass balance of SYNTH_PIG is a formula in `DefineMassBalance`). How were they made?
- [ ] `isapprox` (used in `DefineOutputs`; not in UaSource) and `inpaint_nans` (used in `DefineGeometryAndDensities`): source/location. `v2struct`, `DistanceToLineSegment`, `HelmholtzEquation` etc. are in UaSource.
- [ ] Is `GradientCalc = "FixPoint"` used in this project? If not, the FixPoint branches (sample space, `DefineInputsForInverseRun` error boxes, `DefineSlipperyDistribution` smoothing) can be removed.
- [ ] **`GLUE_GenerateRunTable_Diagnostic` is out of sync with the diagnostic run table** (you re-uploaded the same version; it is byte-identical to the first upload): the script creates rows with 22 values, but `RunTable_GLUE_Diagnostic_9999.csv` has 24 columns (it also has `InverseAFill` and `InverseCFill`, columns 14 and 17). Please send the current version of the script and say what the Fill columns mean (no uploaded script uses them).
- [x] **Inversion results (restart files) will NOT be shared**: the whole diagnostic stage (`ua_input/diagnostic`, all files) is therefore marked "FOR TRANSPARENCY, NOT RUNNABLE" in the file headers. The inverse stage is runnable from scratch (it needs only the interpolants, meshes and run table).
- [ ] **`HPDSample` run table**: `calc_HPDsample` draws samples from the 95% HPD region of the posterior; I assume this is the origin of the `HPDSample` inverse run table (parameters re-run with inversion + diagnostic). Which script turns `HPD.sample` into the run table (probably a call of `GLUE_GenerateRunTable_Inverse`)? And which script produces `myPosteriorDist`?
- [ ] **Roughness filter**: the earlier version of the diagnostic run table script excluded inversions with regularisation-driven C or AGlen (`roughness_regression`, from `GLUE_DataProcessing/projects/05_du_diagnostic_AMUND_v2026_BReed`, with Round 1 tables of the removed v2026 domain). I removed it together with the v2026 references. If the AMUND_nsmbl diagnostics used a filter, I need `roughness_regression` and its inputs.
- [ ] **Which geometries are perturbed in the project?** I set `ExpID_oldgeom = "2000"` and `ExpID_newgeom = "2020"` (AMUND_nsmbl; "2009" and "2014" are also allowed) and `pert = ["Original","Calv_thick"]`, `it = 2` (with spinup): please confirm. SYNTH_PIG: old `Weertmanyr30`, new e.g. `Weertmanyr35`...`Weertmanyr75`, `Umbiyr...`.
- [x] `Calc_SVD_basis` received. Still needed for `prep_EmulatorTrainingData_deltaU.m`: the postprocessing script that writes `DiagnosticData/<domain>/<domain>_Delta_u_<start>-<target>[_<slidinglaw>].mat` (variables listed in the header of `Calc_SVD_basis`; "for transparency, not runnable"; the data files themselves are postprocessed data to ship, sizes?). Third party plotting helpers (README only): `fig` (C. Greene), `cmocean` (File Exchange); `PlotNodalBasedQuantities_JDR` (your modified Ua plotting function in `froot_tools`: stays an external dependency, not included in this repository). Perturbation names confirmed: `Calv`, `dhIS`, `dh`, `Calv_dh` = diagnostic run table `Calv`, `ISthick`, `thick`, `Calv_thick`.
- [ ] **For `calc_HPDsample.m`**: UQLab (third party, README only) and the input `myPosteriorDist` (result of the Bayesian inference; ship it if small).
- [ ] **Licence / attribution of `RNN_network_optimisation_JDR_v5.py`**: adapted from the training script of Rosier et al. (2025, The Cryosphere 19, 2527, https://tc.copernicus.org/articles/19/2527/2025/). Check the licence of the original code (code availability statement of the paper) and put the attribution in the README / LICENSE. The header keeps the original author handle `shrro` and the modification note.
- [ ] **Trained emulators**: which files will be shipped (e.g. on Zenodo)? The SavedModel folders `Emulators/<domain>/RNN/TF_files/v5_tuned_model_full_<fname>` and `v5_tuned_model_<fname>` (and the SVD/data `.mat` files in `RNN/mat_files`) are needed by the Bayesian inference; sizes? Which of the two models (full = trained on training + validation data, or training only) is used in the inference?
- [ ] Python environment: `requirements_RNN.txt` is a draft (TensorFlow 2.13 / Keras 2, keras-tuner, numpy, scipy); please give the exact package versions of `tf213_env` and the MATLAB release/function used to import the models.
- [ ] **Functions called by `calc_BayesianInference_u`**: `loadvelocitydata`, `Calc_MarginalsInference`, `plot_BayesianAnalysisResults_u` (was called `Plot_myBayesianAnalysis.m`; now in `figures/`) received. Still needed: `plot_Emulator_MSE` / `FigureA3_Emulator_MSE` (creates `MSE_RNN_<modelversion>_*.mat` with `mse_RNN`, needed by the likelihood), and the L-curve / parameter distribution scripts mentioned in the comments of the priors (`plot_Lcurve`, `plot_InverseParameterDistribution`). `unfold` (called only if `struct2table` fails) is not in UaSource.
- [ ] **Which emulator version was used in the paper?** `main_BayesianInference_u` uses `modelversion = "v4_tuned_model_full"`, while the training script you sent writes `v5_tuned_model_*`. Are v4 and v5 the same code (then the name should be updated), or were the posterior results made with v4 emulators?
- [ ] **For `main_PerturbationResultsEnsemble.m`** (postprocessing of the diagnostic results of the posterior sample): `RemoveIceRisesAndIslands`, `FluxAcrossGroundingLine_JDR` (your modified copy of Ua's `FluxAcrossGroundingLine` with the extra outputs `xGLmid, yGLmid` and inputs `xGL, yGL, GLgeo`; needed by `Calc_UaGLFlux_PerBasin`) (`FluxAcrossBoundary` received), the script that creates the inversion data files `InversionData/<domain>/<domain>_2000_inversiondata_HPDSample.mat` (structure `data` with `InverseExpID, gaC, gaA, gsC, gsA, dhdt_err, misfit, startgeometry`), the source of `basins_IMBIE_v2.mat`, and the script(s) that create the `Delta_u` files of the full ensemble (`DiagnosticData/<domain>/<domain>_Delta_u_*.mat`). Which postprocessed outputs will be shipped for the plotting (e.g. `DiagnosticData/AMUND/AMUND_2000_perturbationdata_HPDSample.mat`, sizes?)
- [ ] **Data reader functions** (`measures_annual`, `itslive_annual`, `measures_amundsen`, `bedmap2_interp`, `read_Bamber_2004`): you said they are proprietary or only read binary data files, so users write their own. Plan: I document the expected interface of each in the README (arguments, outputs, grid orientation), derived from how the scripts call them. Tell me if you would rather ship simple versions.
- [ ] **Generic helpers** (`demresize`, `gridbin`, `cell2nancat`, `filt2`, `geoimread`, `inpaint_nans`, and the `GLUE_HelperFunctions` folder): you think they come from the Greene toolboxes. For the README I still need the exact toolbox names/versions (or links), and what `GLUE_HelperFunctions` contains (`inpaint_nans` is from J. D'Errico, File Exchange).
- [ ] **Modified BedMachine file** `BedMachineAntarctica-v3-PIGdig_PHolland.nc` (bed `bed_pigdig`, from P. Holland): not downloadable from NSIDC. Share it (Zenodo?) or document how it was made, and get P. Holland's OK.
- [ ] Download links / versions for the input data sets of the interpolant scripts (for the README): MEaSUREs annual, MEaSUREs Amundsen Sea (ALOS, ERS-1, RADARSAT, TDX), MEaSUREs 450m v2, MEaSUREs Central Antarctica 1997, ITS_LIVE annual + 240m mosaic, BedMachine v3, Bedmap2, Bamber 2009 DEM, RAMP2, Nilsson et al. (2023), Paolo et al. (2023), Otosaka et al. (2023) (DOIs are in the header of `Calc_ITSLIVE_CPOM_Paolo2023_Deltas.m`).
- [ ] Decide which generated interpolants to publish (the `*_EXTRUDED.mat` velocity and geometry files, if the AMUND runs read them; check sizes, probably Zenodo).
- [ ] Versions used: UaSource commit, MATLAB release.

## 2. Resolved by the UaSource repository (https://github.com/GHilmarG/UaSource)

- `inpoly2`, `inpoly`, `DeactivateMUAelements`, `PlotMuaMesh`, `Nodes2EleMean`, `Ua2D_DefaultParameters`, `HeavisideApprox`, `DiracDelta` and the other Ua functions used so far are in UaSource (checked against a clone of the current master, 2026-11-05).

## 3. Possible bugs / questions (flagged, NOT changed in the code)

`Create_BMv3_B2_Bam2009_RAMP2_RefGeomGriddedInterpolants.m`
- [ ] `Surface_UseBedMachine3` branch actually reads Bedmap2 (`bedmap2_interp`), does `addpath` on a `.nc` file, and `s_bm3` is never used later. Copy/paste leftover?
- [ ] `Bed_UseBedmap3` stops with an error ("need to define density"); the option is not usable.
- [ ] Needs `./GeoTiffFiles` to exist when `CreateGeotiff=1` (default when called without arguments); same in the other interpolant scripts.

`Create_Geometry_from_reference_and_ds.m` and `Calc_ITSLIVE_CPOM_Paolo2023_Deltas.m`
- [ ] **As configured only Nilsson et al. (2023, grounded ice) is used** (`useOtosaka=0`, `usePaolo=0`), so `ds` is NaN on ice shelves and `Create_Geometry...` then sets it to 0 there (no surface correction on floating ice), although the text and the cache file name (`ds_Nilsson_Paolo_<date>.mat`) suggest Paolo et al. is included. Intended? Adjust the README/description, or set `usePaolo = 1`.
- [ ] Target/reference dates use day-of-year/length-of-year, the data times use (date-start)/(end-start): up to ~1 day offset.
- [ ] `addpath(getenv("froot_tools"))` is not needed in `Calc_ITSLIVE_CPOM_Paolo2023_Deltas`; `ds_source_string` is built but not returned.
- [ ] File names contain `string(datetime)` ("01-Jun-2020"): month abbreviation depends on the MATLAB language setting.

`Create_MeaSUREs_ITSLIVE_1996_2003_VelocityGriddedInterpolants.m`
- [ ] Step 1: `v_source(~nanind)` where `nanind` is an index list (from `find`): `~nanind` is all false, so the source map stays 0 there.
- [ ] The `fprintf` after step 1 uses `years(ii)` outside the loop (prints the last year only).

`Create_ExtrudedFields_GriddedInterpolants.m`
- [ ] With the default `'-v-geom-'`, `Fsource` is cleared before the geometry block loads, so it is saved as an empty struct. Use `'-v-'` and `'-geom-'` in separate calls, or fix.
- [x] `'-scalar-'` output file name: resolved, it is used by the diagnostic stage with `"-scalar-"+prefix` (`DefineAGlenDistribution`, `DefineSlipperyDistribution` in `ua_input/diagnostic`), so the file is `<prefix>_EXTRUDED.mat`. NOTE for the README: `Create_ExtrudedFields_GriddedInterpolants` and `ExtrudeField` are called at RUN TIME by the diagnostic stage and must be on the MATLAB path (e.g. in `GLUE_Data/GLUE_HelperFunctions`), together with `GriddedInterpolants_Geometry_01-Jun-2000.mat` (not extruded) and the 1996-2003 velocities.
- [ ] Debug `figure`/`imagesc` calls are active in the `-v-` and `-geom-` blocks.

`GLUE_GenerateSampleSpace_Inverse.m`
- [ ] `Enrich=1`: `uq_enrichLHS` gets `X` with columns 1-4 already in physical units while `myInput` is in log10 space (TODO in code); not checked whether `Xnew` also contains the original points. Also only works for `SamplingMethod='LHS'`; as configured it is `'Sobol'` and `Enrich = 0`.
- [ ] `GradientCalc="FixPoint"`: `myInput` does not exist, so `save(...,"myInput","T")` only warns.
- [ ] Priors in the header and comments said Gaussian for gsC/gsA/gaC/gaA; the active priors are **Uniform** in log10 space (comments corrected; Gaussians kept as short notes). Confirm that Uniform is what the paper describes.
- [ ] Removed unreachable placeholder code after `return` (discrete variables: spinup, dhdt, meshrefinement, coulomb).

`GLUE_GenerateRunTable_Inverse.m`
- [ ] `Enrich==1` does not trigger the catalogue branch (only `UseCatalogue==1` does), contrary to the old help text (TODO in code).
- [x] `startMesh` strings: resolved. `GLUE_GetUserVar_Inverse` passes `RunTable{ind,"startMesh"}` to `GLUE_DefineBaseMesh`.
- [ ] Hard-coded absolute path of the `uigetfile` start folder (catalogue branch only, `UseCatalogue=1`, "for transparency, not runnable").
- [ ] Variable `eps` shadows MATLAB's `eps` (harmless here).
- [ ] Folder layout: the script calls `addpath('../')` and `copyfile("../GLUE_Inverse/EmptyTable.csv",...)`, i.e. expects `GLUE_ReadWritetable.m` in the parent folder and `GLUE_Inverse/EmptyTable.csv` next to the working folder. To be replaced by the central config / `setup_paths.m`.
- [x] `startC = 0` / `startAglen = 0`: resolved. 0 = constant prior value (`priorC`, `priorAGlen`); `-9999` = (C only) initial guess from measured velocities; `> 0` = ExpID of an earlier experiment (`GLUE_GetUserVar_Inverse`, `DefineSlipperyDistribution`). Note: the run table column is called `startAglen` (small g).

`GLUE_ReadWritetable.m`
- [x] `contains(...,'Velocity')`: resolved, the run table column is called `Velocity` (capital V) in the header.
- [ ] 'write' with `UserVar.ExpID` is a read-modify-write without file locking: parallel runs updating the same table can overwrite each other's rows. Keep in mind for the run scripts.
- [ ] Table types `"Diagnostic"` and `"Transient"` exist in `setoptions`: is there a transient stage in the project, or only inverse + diagnostic?

`GLUE_DefineBaseMesh.m` / `GLUE_ApplyMeshModifications.m`
- [ ] `GLUE_DefineBaseMesh` keeps the case of the circum-Antarctic mesh (input of `AMUND_GenerateBaseMesh`), the AMUND cases and SYNTH_PIG; the combined case `AMUND_2000_2009_2014_2020_...` refers to files that `AMUND_GenerateBaseMesh` does not produce (it writes one mesh per year).
- [ ] `GLUE_DefineBaseMesh` error message uses `UserVar.ExpID`, which is not set when called from `AMUND_GenerateBaseMesh`.
- [x] `GLUE_ApplyMeshModifications` with `UserVar.Calv`: resolved. The diagnostic stage sets `UserVar.Calv` (no `Geometry` field), `LevelSetMethod=0`; for AMUND the boundary file of the mesh is a plain matrix, so the calving front is determined by the mesh chosen in the `BaseMesh` column (new year for Calv, old year for Original/ISthick/thick). The inverse stage sets `UserVar.Geometry` (empty for SYNTH_PIG, so the mesh is not cut).
- [ ] `GLUE_ApplyMeshModifications` writes `<casefolder>/<Experiment>/<Experiment>_InitialMesh.mat` (and `..._MeshBoundaryCoordinates.mat`): in `AMUND_GenerateBaseMesh` `Experiment=""`, so `_InitialMesh.mat` and `_MeshBoundaryCoordinates.mat` are left in the working folder.

`AMUND_GenerateBaseMesh.m` / `Define_Quantity_PerBasin.m`
- [ ] Assumes the first boundary loop of the deactivated mesh is the outer one (`Ind_nan(1)`), and that the boundary indices between the nodes nearest `(xE,yE)` and `(xW,yW)` are the seaward segment (check the green line in the figure).
- [ ] Hard-coded coordinates `xE,yE,xW,yW` (fixed-boundary delimiters) and paths to the Ua case folders (`froot_ua`, `froot_tools`), possibly not needed any more now that `Define_Quantity_PerBasin` is in the repository.
- [ ] `Define_Quantity_PerBasin`: the loop over the NaN-separated parts of a basin outline stops one part early unless `B.x{ii}` ends with a NaN; holes in outlines are not treated as holes; nodes not inside any basin go to the basin with the nearest boundary point (so every node gets a basin).

`ua_input/inverse` (inverse and spinup stage)
- [ ] `DefineMassBalance`: `Fdhdt` is not declared persistent, so the branch for the second and later spinup cycles fails with an undefined variable; and `UserVar.Geometry+1` appends "1" if `UserVar.Geometry` is a string (file name `dhdt_2000_20001.mat`). Not reached with `SpinupYears = "3"` (one spinup cycle).
- [ ] `GLUE_GetUserVar_Inverse`: same string arithmetic in `string(UserVar.Velocity+1)` (only for `Velocity` other than "2000"); `UserVar.DensityInterpolants` (plural) is only used for a file check, the singular `DensityInterpolant` is set in `GLUE_GetUserVar_FirstInverseRun` (TODO in code); the `startAglen=-9999` branch sets `UserVar.Inverse.startAGlen`, which `DefineAGlenDistribution` does not use.
- [ ] `DefineGeometryAndDensities`: the cache file is saved with all of `B,b,S,s,rho`; fields that were not requested are saved empty (TODO in code).
- [ ] `DefineOutputs`: `v2struct(F)` creates variables from the fields of `F` and overwrites the input `GF` with `F.GF`; removed the unreachable plotting block (`plots=''`).
- [ ] `DefineInitialInputs`: `UseParallel=true` in fmincon needs the Parallel Computing Toolbox (otherwise no effect); the walltime timer uses a 60 min buffer.
- [ ] `DefineInputsForInverseRun`: run table column `dhdt_err` is a cap on the dhdt errors (m/yr), not a scaling factor; FixPoint boxes cover all of Antarctica.
- [x] Removed because only needed for removed domains or features: `DefineCalving` (level set method only for `AMUND_v2026_BReed`; copy in /mnt/user-data/removed/inverse_unused), `DefineDesiredEleSize` (adaptive meshing is off: `CtrlVar.AdaptMesh=0`). Restore if the diagnostic stage needs them.
- [x] `DefineStartValues.m` renamed to `DefineStartVelValues.m` (Ua looks for this file name).

`ua_input/diagnostic`
- [ ] `GLUE_GenerateRunTable_Diagnostic`: out of sync with the 24-column table (see section 1); the `BaseMesh` name for AMUND was built as `AMUND_nsmbl_<year>_meshmin...`, which `GLUE_DefineBaseMesh` does not know: changed to `AMUND_<year>_meshmin1500_meshmax100000_refined` (TODO in code); the output file name contains the fixed text `_Weertman_` whatever the sliding law; the comment about "10 diagnostic simulations per inversion" described an older version (now `it=2` only and `pert` selects the perturbations).
- [ ] `GLUE_GetUserVar_Diagnostic`: `elseif UserVar.InverseCycleIS > 1` is also used for `geom="GI"` (same value in the table); needs inversion restart files from `../GLUE_Inverse/cases/...` (path relative to the experiment folder).
- [ ] `DefineGeometryAndDensities` (diagnostic): the message for floating ice prints `GIBaseGeometry` instead of `ISBaseGeometry`; `FieldsToBeDefined` is always `'sbSBrho'` (the input argument is overwritten).
- [ ] `DefineBoundaryConditions` (diagnostic): `persistent AA BB` is declared but not used.
- [ ] `DefineStartVelValues`: current Ua calls `DefineStartVelValues.m` (21 input arguments). The uploaded diagnostic file and function were called `DefineStartValues` and the inverse file `DefineStartValues.m` (function `DefineStartVelValues`), so with a current Ua they would not have been called (Ua's default start values would be used). Both are now `DefineStartVelValues`; if your Ua version expects `DefineStartValues`, rename.
- [x] Removed: `DefineCalving` (diagnostic and inverse; level set method only for the removed domain, copies in /mnt/user-data/removed), level-set code in both `DefineInitialInputs` and in the inverse `DefineMassBalance`, `DistanceToLineSegment2` (already in UaSource `UaUtilities`, not called), `CalcMeshDerivatives_1` (identical to the copy in `ua_core_overrides`, which both master folders need).

`ua_input/run` (`GLUE_UaWrapper`, `GLUE_UaJob`, `GLUE_CleanUp`)
- [ ] **Machine-specific host block** in `GLUE_UaWrapper` (paths `/mnt/md0/Ua/setup_Ua2D_beta.m`, `/home/<user>/Documents/Ua/setup_Ua2D.m` with a personal user name, hostnames, ARCHER2): replace by a generic setup (central config / `setup_paths.m`) before publication. `NumWorkers` is set but not used.
- [ ] `isempty(pgid)` in the config file section is false for a string `""`, so a `pgid` in the config file is not used when none is passed as argument.
- [ ] `nit = 100000` in both branches of `if contains(UserVar.hostname,"ARCHER2")`.
- [ ] `GLUE_UaJob` ends with `cd ..` (one level up, to `cases/<Domain>`), while its first statement uses the relative path `./GLUE_<type>_9999`: check for repeated calls in one session.
- [ ] The wrapper repeats the same logic for existing and new experiments (duplicated code); the global run table is re-read in the "existing" loop but not in the "new" loop.
- [ ] Global run table: `GLUE_UaJob` sets `Running=1` in the global table, but `GLUE_CleanUp` only writes the experiment table (see launcher/sync item above).
- [x] `GLUE_CleanUp`: typo `UsserVar` in the final error message corrected.

`analysis/emulation/prep_EmulatorTrainingData_deltaU.m`
- [ ] `slidinglaw_char(1,1,ii)`: for a string array `char()` returns one row per element, so the index is out of range for `ii>1` (the SVD file name `Wc2_Uc2` suggests it worked; `slidinglaw_char(ii,1)` was probably intended). Check.
- [ ] `add_measurements_to_SVD=1`: `T_hat` has `num_exp-1` rows but `seq=randperm(num_exp)`, so `data=T_hat(seq,:)` fails; missing semicolon after `T = SVD_new.T(2:end,:)`. Not used with the default (0).
- [ ] No random seed for `seq=randperm(num_exp)` (the permutation is saved in the output files).
- [ ] Header text said "95%-99.5% of the variance" but `SVD_targetpercentage=0.5` (minimum 50%, capped by `max_SVD_components` = 25 for AMUND, 10 for SYNTH_PIG).
- [ ] Output folders (`Emulators/<domain>/SVD_files`, `Figures`, `Emulators/<domain>/RNN/mat_files`) must exist. Removed all FNN code (training branch, settings, file names), a no-op loop `for r=[10 50 100]` and commented-out plotting code.

`analysis/emulation/Calc_SVD_basis.m`
- [ ] `add_measurements_to_SVD=1`: `T = [T_meas(:)' T]` concatenates horizontally (a new first row would be `[T_meas(:)'; T]`); the predictors `X` get no row for the measurements (TODO in code). Not used with the default (0).
- [ ] `S` is calculated from `T_meanremoved`, which still contains the floating nodes when `only_grounded_ice=1` (T, T_mean and T_meas are zeroed there); `S` is only used to choose the number of components in `prep_EmulatorTrainingData_deltaU` (TODO in code).
- [ ] Rows with Inf (not only NaN) are not removed; if the data matrix has more rows than columns it is transposed without transposing X (heuristic). Variables named `std` and `v` shadow MATLAB functions (harmless).
- [ ] Needs the EXTRUDED velocity interpolants of the start and target year in `../GLUE_Data/GLUE_Interpolants` (see pipeline step 2) and the postprocessed `DiagnosticData` files. The default settings when called without arguments use `only_grounded_ice = 0` and both sliding laws.

`analysis/emulation/RNN_network_optimisation_JDR_v5.py`
- [ ] **Loss and normalisation**: `prep_EmulatorTrainingData_deltaU.m` normalises the targets (z-score per SVD component) when it writes `T_train`, but `matrix_loss` multiplies the targets and predictions by the basis `B_trunc` without undoing the scaling, so the loss is not the physical speed field. Check that this is intended (the header note says normalisation of the training data in Python was removed).
- [ ] The example file name in the old docstring (`Calv_dh_2014-2018_Weertman_cycle2_N0k995`) did not match the names written by the current prep script (`<domain>_<perturbation>_<start>-<target>_<sliding laws>_cycle..._Basis_...-Comp..-Var..`); the docstring now shows the current pattern. The script must be started from the folder that contains `<folder>/RNN/mat_files` (for the MATLAB output, from `Emulators` with `folder=AMUND`).
- [ ] No random seeds (tensorflow, numpy): the search and training are not reproducible. 120 tuner trials (200 epochs, early stopping) and two retrainings of 2000 epochs without early stopping.
- [ ] Diary: the model trained on the training data only is evaluated on the combined data and labelled "training loss"; the full model is not evaluated on the test data.
- [ ] Machine-specific: environment check for a venv called `tf213_env`, tuner directory `/tmp/v2/rnn_<fname>`, CPU only. Removed unused imports (`keras.backend`, `Huber`, `StandardScaler`, `joblib`, `Normalization`, `mixed_precision`), commented-out code, and added a usage message (the model and training code is unchanged: AST comparison).
- [ ] `n` (number of retained components, from `T_pct`) is passed to the loss, which slices the first `n` columns although the output size equals `n`.

`analysis/bayesian_inference/main_BayesianInference_u.m` and `calc_BayesianInference_u.m`
- [ ] **File name mismatch**: the emulator, data, SVD and MSE files are looked up with `"_cycle"+string(cycle(ii))+"_floatingice..."` (e.g. `cycle2`), but `prep_EmulatorTrainingData_deltaU.m` writes `cycle`+`join(string(cycle),"-")` (e.g. `cycle2-2` for two sliding laws) and `...Basis_<basis>-Comp<N>-Var<V>`. The `_*Comp<N>*` wildcard matches the second part, not the cycle part. Check which naming the shipped files use (and fix one side).
- [ ] The priors of gaA, gaC, gsA, gsC are truncated Gaussians in log10 space (means 0.7 / 4.3, std 0.51; bounds [-1 log10(50)] and [3 6]), while the ensemble was sampled uniformly over [-1 log10(100)] and [3 6]; `dhdt_err` is log-uniform in the prior but was sampled uniformly (linear) in the ensemble; the sliding law is a continuous variable in [1 2] rounded in the likelihood. Comments in `GLUE_GenerateSampleSpace_Inverse` now say that the Gaussians are the Bayesian priors (they were described as "not used").
- [ ] `clear Calc_BayesianInference;` in the main loop named a function that does not exist (the function is `calc_BayesianInference_u`), so the persistent emulators were not cleared between rows of the table; changed to `clear calc_BayesianInference_u`. Only one row is used in the shipped configuration.
- [ ] Persistent variables `M`, `Nem`, `np` in `customLogLikelihood`: with a changed configuration in the same MATLAB session the emulators of the first call are reused (clear the function first).
- [ ] `TF_dir.name` fails with an unclear error if no emulator is found (only `numel>1` is checked); `inv(S)` and `det(S)` of the covariance in the SVD basis are used directly (possible under/overflow for many components).
- [ ] The origin of `std_ua` (40 m/yr) and the range `l` (50 km) of the Ua error covariance is marked `FIXME` in the code: please document (TODO in code).
- [ ] Machine-specific: `cd(getenv("froot_ua")+"cases/GLUE/GLUE_DataProcessing")` in the main script (the working folder must contain `Emulators`, `DiagnosticData`; `BayesianAnalysis` is created).
- [ ] Removed all FNN code (`NN` option, FNN loading and evaluation), the commented-out loops and old code blocks (about 250 lines). The `.keras` (Keras 3 via Python) loading branch is kept; the training script saves SavedModel directories imported with `importNetworkFromTensorFlow`.
- [ ] Requirements for the README: UQLab Rel. 2.0.0; MATLAB Deep Learning Toolbox with the Converter for TensorFlow Models; Statistics and Machine Learning Toolbox (`pdist2`); `tensorprod` (R2022a or later); Python interface (only for `.keras` models).

`analysis/bayesian_inference/loadvelocitydata.m` and `Calc_MarginalsInference.m`
- [ ] `loadvelocitydata`: machine-specific paths (`getenv("froot_ua")+"/cases/GLUE/GLUE_Data/..."` and `.../GLUE_DataProcessing/DiagnosticData/...`), while `calc_BayesianInference_u` reads `./DiagnosticData` relative to its working folder: use one config. The variables `std` and `v` shadow MATLAB functions (harmless). Removed the unused `addpath` of the MEaSUREs annual data (only needed by commented-out code), the ANT domain, and commented-out alternatives (NaN handling, a "DANGER" override of the errors).
- [ ] `Calc_MarginalsInference`: the posterior sample is the last 10% of the steps of all chains (`npct=0.1`; the comment said "final npct%"), at most 25e3 randomly selected points; `discr`, `iOpts` and `MarginalIndex_discrete` are not cleared between files of the loop; the 'bimodalgaussian' parameter bounds are set although the marginal type is 'KS' (leftover); removed the `Melt_Parameterization` branch (another project), commented-out code and the machine-specific ANT start folder of the file selection window (now `./BayesianAnalysis`).

`analysis/postprocessing/main_PerturbationResultsEnsemble.m`
- [ ] Machine-specific folder `UserVar.home = "/mnt/md0/Ua/cases/GLUE/"`; the experiment type is derived from the text of the `Comments` column of the diagnostic run table (keep in sync with `GLUE_GenerateRunTable_Diagnostic`); the variable `year` shadows a MATLAB function. Removed the ANT/all-basins settings and about 80 lines of commented-out code. The mapping of experiment types: Original, Calv, dhIS (= ISthick), dh (= thick), Calv_dh (= Calv_thick), as used by the emulators.
- [ ] `Calc_UaGLFlux_PerBasin` / `Calc_UaOBFlux_PerBasin` (marked "for transparency, not runnable"): removed the ANT-specific breaks of the grounding line (points in the Ross, Filchner-Ronne and Peninsula regions, only inserted if within 100 km of the grounding line, so presumably never active for AMUND) and commented-out plotting code. In `Calc_UaOBFlux_PerBasin` the variable `OB_GF` is computed but not used, the boundary edges are selected by water column thickness (`sum(b-B)<eps`, the commented alternative used the grounded fraction), and fluxes above 1e12 are discarded as anomalous; `GF` and `CtrlVar` are unused inputs there. Units: the fluxes are in kg/yr (`FluxAcrossBoundary`), so the division by 1e12 in `main_PerturbationResultsEnsemble` gives Gt/yr; the anomaly threshold of 1e12 is in kg/yr per edge.

`figures/` (plotting scripts)
- [ ] **Data for the figures**: Figures 3, 4, 6, 7 need the Bayesian analysis files (`BayesianAnalysis/<domain>/*.mat` with `myBayesianAnalysis`, `UserVar`, `myPosteriorDist`; 9 SYNTH_PIG files in `Figure4`, 9 AMUND files in `Figure7`, the two files named in `README_figures.md` for Figures 3 and 6; large `-v7.3` files: sizes? ship as processed data, e.g. on Zenodo) and, for Figure 6, `DiagnosticData/AMUND/*` and the emulators; the posterior files were made with `v4` (AMUND) and `v5` (SYNTH_PIG) emulators (file names), see the emulator version question above.
- [ ] `Figure2` and `Figure5` are marked "for transparency, not runnable": they need results of the synthetic experiments (`/mnt/md0/Ua/cases/SYNTH_PIG/ResultsFiles/{cold,warm}_Weertman/...`) and of diagnostic / inverse experiments (experiment numbers `runID_*` in the script). Observed grounding lines in `Figure5`: MEaSUREs InSAR v2, Milillo et al. (Thwaites 2016-2017), Pope/Smith/Kohler (Dotson, Crosson), Ross et al. COSMO-SkyMed 2020-2022, ESA CCI GL v2: download links for the README; `ll2psxy` (not in UaSource).
- [ ] `Figure5`: in the 2014 block `h2000(Ind) = 0;` modifies `h2000` instead of `h2000_tmp` (copy-paste?), so the ice outside the 2000 boundary is not masked in `dh2000_2014`; not changed. The quick comparison with Bedmap2 (an extra figure that is not part of Figure 5, needs the Bedmap2 tif) was removed; the old calls `loadvelocitydata("AMUND","du","2000-2009",1)` (4 arguments) were replaced by a local helper that calls the current `loadvelocitydata(UserVar)`.
- [ ] `Figure7`: the output file names said `_SYNTH_` (copy-paste); now `_AMUND_`. `Figure4` / `Figure7`: the error message for a missing `myPosteriorDist` used the undefined variable `fname` (now `getfilename(ff)`); machine-specific `froot`.
- [ ] `plot_BayesianAnalysisResults_u` (file was `Plot_myBayesianAnalysis.m`; the function name is the one called by `calc_BayesianInference_u`): removed (i) the FNN / `UserVar.NN` switches (the field no longer exists), (ii) the "MAP" section at the end (two comparison figures of emulator, nearest Ua simulation and measurements at the MAP; the `print` calls were commented out, and it needs the inversion restart files in `../GLUE_Inverse`, so it could not run for others; the original upload is unchanged in your files), (iii) the title block for two analyses (it used `UserVar.fac_su`, which no longer exists), commented-out code. Hard-coded `/mnt/md0` paths in the "selected samples" part are now relative (`./DiagnosticData/AMUND/AMUND_perturbation_grids.mat`, `AMUND_Delta_u_<years>_HPDSample.mat`); the old 4-argument call of `loadvelocitydata` was replaced as in `Figure5`.
- [ ] `plot_BayesianAnalysisResults_u`: the check `exist(fname_HPD,"file")` looks in the current folder, but the HPD file is saved in `./BayesianAnalysis/<domain>/` (so it is always recomputed with 10 random samples, `rng(1)` is set); `gpuDevice([])` at the start needs the Parallel Computing Toolbox; needs Statistics Toolbox (`hist3`, `knnsearch`, `isoutlier`) and interactive dialogs (`uigetfile`, `questdlg`, `inputdlg`).

`analysis/bayesian_inference/calc_HPDsample.m`
- [ ] **Method**: `cum_prob = cumsum(f_sorted)/sum(f_sorted)` weights the Monte Carlo samples by their pdf value, although they are already drawn from the distribution (the comment said "uniform weights"). This selects a smaller region than the 95% HPD region; the 95% HPD would be the first `ceil(p*Nsamples)` sorted samples. Not changed (TODO in code): please check.
- [x] The first column of `HPD(k).sample` (1.25, 1.75): resolved. It is the value of the continuous sliding law variable of the inference, which `calc_BayesianInference_u` rounds to the index (1 = Weertman, 2 = Umbi); header comment corrected ("highest posterior density").

## 4. Findings in the scripts removed from the repository (for your information)

The ANT mesh chain was removed because the project uses only AMUND and SYNTH_PIG (files: `ANT_GenerateBaseMesh`, `ANT_RefineMesh`, `GenerateBoundaryWithVariableResolution`, `Replace_Greene_with_Baumhoer`, `Node_to_face_distance`, `Node_to_node_distance`; cleaned copies in /mnt/user-data/removed/ANT_meshing). Possible bugs found there, in case the ANT mesh is ever published:
- `ANT_GenerateBaseMesh`: intersection loop cases `indL==2` and `indL==4` snap to the first node of the segment (`segind`), probably `segind+1` intended; the segment loop `while kk<numel(...)` never looks at the last vertex of each front; `warning('off','all')` is only undone if the script finishes.
- `ANT_RefineMesh`: `MUAnew` undefined if no element is flagged initially; the loop runs at most `AdaptMeshMaxIterations-1` times; `RefineGL` uses a persistent `Interp` and returns only the last year when `years` has several entries.
- `GenerateBoundaryWithVariableResolution`: `U` only computed if the persistent `Fus` is empty; `effective_strain_rate_gradient` needs `speed` before it; the fallback in `speed` uses undefined `MUA`/`F`; `movmean` smooths along one dimension only.
- `Replace_Greene_with_Baumhoer`: `files` undefined for years other than 2020; `Thwaites2` is a 2021 file in the 2020 list. `Node_to_face_distance`: the last segment wraps from the last point to the first. `Node_to_node_distance`: the function was declared as `Node_to_face_distance` (corrected).
- Input data that is no longer needed in the README: Greene et al. (2022) ice fronts, DLR IceLines shapefiles, `selfintersect` (File Exchange 13351), MESH2D `refine2`/`smooth2`.

## 5. Repository-level tasks (I will do these once all scripts are in)

- [ ] Central config: replace `/mnt/md0/...` paths and the `froot_data` / `froot_tools` / `froot_ua` / `froot_matlabfunctions` environment variables, `../GLUE_HelperFunctions/`, and the `../GLUE_MeshData` / `GLUE_Inverse/EmptyTable.csv` layout.
- [ ] `setup_paths.m` adding UaSource and the folders in this repository.
- [x] Top-level `README.md` drafted (summary, contents, workflow in short, requirements); it links `WORKFLOW.md`. Open: the [TODO] markers in both files (title, citation, DOIs, licence, third-party functions, contact), `LICENSE`, `.gitignore`.
- [ ] README: analysis layout `analysis/emulation`, `analysis/bayesian_inference` (`analysis/figures` planned); working folders created at run time: `DiagnosticData/`, `Emulators/`, `Figures/`.
- [ ] README: master folder of the diagnostic stage `<home>/GLUE_Diagnostic_9999/` = all files of `ua_input/diagnostic` (except the two generators) + `ua_input/ua_core_overrides/CalcMeshDerivatives.m` (and the other overrides) + `RunTable_GLUE_Diagnostic_9999.csv` (= `ua_input/diagnostic/EmptyTable.csv`); `GLUE_GenerateRunTable_Diagnostic` expects `EmptyTable.csv` in its folder.
- [ ] README: folder layout of a run: `<home>/GLUE_Inverse_9999/` (master folder = all files of `ua_input/inverse` + `ua_input/ua_core_overrides` + `RunTable_GLUE_Inverse_9999.csv`, a copy of `ua_input/runtable/EmptyTable.csv`), `<home>/cases/<Domain>/<Domain>_Inverse_<ExpID>/` (created by the wrapper), `<home>/../GLUE_Data/{GLUE_MeshData,GLUE_Interpolants,GLUE_HelperFunctions}`, global run table `RunTable_<host>.csv`; the wrapper, `GLUE_UaJob`, `GLUE_CleanUp`, `GLUE_GetUserVar_*`, `GLUE_ReadWritetable`, `GLUE_DefineBaseMesh`, `GLUE_ApplyMeshModifications` live in `<home>`.
- [ ] README skeleton: run order (above), dependency list (toolboxes: Curve Fitting only if needed, Mapping, Image Processing, Statistics), data sources, reader-function interfaces, "not runnable" scripts.
- [ ] `.gitignore`, LICENSE (check licences of the third-party data and of P. Holland's modified BedMachine), rename folders (`bayesian_inference`, `data/ua_input`).

## 6. Scripts marked "FOR TRANSPARENCY, NOT RUNNABLE"

- `ua_input/meshing/AMUND_GenerateBaseMesh.m` (needs the circum-Antarctic mesh, which is not distributed; the resulting AMUND meshes are on Zenodo)
- the whole diagnostic stage, all files in `ua_input/diagnostic` (marked; they need the inverse run tables and the inversion restart files, which are not distributed)
- `figures/Figure2_Plot_SYNTH_PIG_VelThick.m`, `figures/Figure5_Plot_AMUND_VelThick.m` (marked; need results of the synthetic experiments and of the diagnostic / inverse experiments)
- `analysis/postprocessing/main_PerturbationResultsEnsemble.m`, `Calc_UaGLFlux_PerBasin.m`, `Calc_UaOBFlux_PerBasin.m` (marked; need the diagnostic results and the inversion data of the ensemble)
- `ua_input/runtable/GLUE_GenerateRunTable_Inverse.m`: only the catalogue branch (`UseCatalogue=1`: reads run tables of earlier inversions chosen in a dialog window). The default branch (`Adjoint`, `UseCatalogue=0`, start values 0) runs with `GLUE_ReadWritetable.m` and `EmptyTable.csv` (still needed).
- Not marked, but only runnable with the raw input data downloaded and the user-written reader functions: the scripts in `ua_input/interpolants/` (except `Calc_dh_from_ds`, `ExtrudeField`, which are self-contained apart from helpers).

## 7. Done

- [x] Interpolants: eight scripts incl. `Calc_dh_from_ds` and `Calc_ITSLIVE_CPOM_Paolo2023_Deltas` (cleaned, header, comments; dead code after `return` and commented-out blocks removed); `sB_to_bh` removed from `Create_Geometry_from_reference_and_ds.m` (exact copy of `Calc_dh_from_ds`); sign convention of `ds` checked (`ds = s(referencetime) - s(targettime)`)
- [x] Run table: `GLUE_GenerateSampleSpace_Inverse` (Domain `AMUND_nsmbl`), `GLUE_GenerateRunTable_Inverse` (`ANT_nsmbl` and `AMUND_v2026_BReed` removed, `startC = startAGlen = 0`), `GLUE_ReadWritetable` (cleaned, stale help text corrected, dead code removed)
- [x] Meshing: `AMUND_GenerateBaseMesh`, `GLUE_DefineBaseMesh` (only the ANT input mesh, AMUND and SYNTH_PIG cases left), `GLUE_ApplyMeshModifications`, `Define_Quantity_PerBasin` (cleaned, header, comments)
- [x] Removed everything that is not AMUND or SYNTH_PIG (see section 4)
- [x] Inverse stage: `GLUE_GetUserVar_Inverse`, `DefineInitialInputs`, `DefineInputsForInverseRun`, `DefineMassBalance`, `DefineOutputs`, `DefineGeometryAndDensities`, `DefineBoundaryConditions`, `DefineAGlenDistribution`, `DefineSlipperyDistribution`, `DefineRunStopCriterion`, `DefineStartVelValues` (cleaned, header, comments; `ANT_nsmbl`, `AS_PROPHET_nsmbl`, `AMUND_v2026_BReed_nsmbl` removed)
- [x] Ua core copies placed in `ua_input/ua_core_overrides` and compared with UaSource
- [x] Figures: `Figure1_DiagnosticCalibration.tex`, `Figure2_Plot_SYNTH_PIG_VelThick.m`, `Figure4_SYNTH_MarginalsInference.m`, `Figure5_Plot_AMUND_VelThick.m`, `Figure7_AMUND_MarginalsInference.m`, `plot_BayesianAnalysisResults_u.m` (Figures 3 and 6), `README_figures.md` (commented-out code removed, headers, README rewritten for this repository)
- [x] Analysis: `loadvelocitydata`, `Calc_MarginalsInference`, `main_PerturbationResultsEnsemble` (headers, ANT / other-project code and commented-out code removed)
- [x] Analysis: `main_BayesianInference_u`, `calc_BayesianInference_u` (headers, FNN and commented-out code removed, stale `clear` fixed)
- [x] Analysis: `RNN_network_optimisation_JDR_v5.py` (header, dead code and unused imports removed, usage check added; verified with an AST comparison)
- [x] Analysis: `prep_EmulatorTrainingData_deltaU` (header, dead code removed, all FNN code removed), `Calc_SVD_basis` (header, comments), `calc_HPDsample` (header, comments corrected)
- [x] Diagnostic stage (`ua_input/diagnostic`, all marked "for transparency, not runnable"): `GLUE_GenerateRunTable_Diagnostic`, `GLUE_GetUserVar_Diagnostic`, `DefineAGlenDistribution`, `DefineBoundaryConditions`, `DefineGeometryAndDensities`, `DefineInitialInputs`, `DefineMassBalance`, `DefineOutputs`, `DefineSlipperyDistribution`, `DefineStartVelValues`, `EmptyTable.csv` (24 columns; cleaned, headers, v2026 / ANT removed)
- [x] Run scripts: `GLUE_UaWrapper` (header with config file keys and folder layout), `GLUE_UaJob`, `GLUE_CleanUp` (cleaned, commented-out code removed)
- [x] `EmptyTable.csv` created
- [x] Dependencies located in UaSource (see section 2)
