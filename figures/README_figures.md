# How the figures of the paper are made

Unzip the data archive into the top folder of the repository first. The scripts have no `addpath`: put the
folders `figures`, `analysis/bayesian_inference`, `analysis/emulation`, `analysis/postprocessing` and `ua_input/2_meshing` on the MATLAB path
(not the folders with the Úa user files `ua_input/0_synth_pig`, `ua_input/run/4_inverse` and `ua_input/run/5_diagnostic`, whose files have the
same names); the Úa source code, UQLab, `cmocean`, `fig`, `othercolor` and `crameri` also have to be on the path.

Where to run the scripts:

* Figures 2, 4 and 7: from the folder `figures` (they read `../analysis/...` and write `Figure*.png` in the current folder).
* Figures 3 and 6 (`plot_myBayesianAnalysis.m`) and Figures A1 to A3: from the folder `analysis` (they read `./diagnosticdata`, `./emulators`,
  `./bayesiananalysis` and write `.png` files in `./Figures`, which has to exist).

| Figure | Script | Notes |
|---|---|---|
| 1 | `Figure1_DiagnosticCalibration.tex` | LaTeX (standalone, tikz, pgfplots): schematic of the diagnostic calibration |
| 2 | `Figure2_Plot_SYNTH_PIG_VelThick.m` | needs five result files of the synthetic experiments (data archive) in `../analysis/ua_resultsfiles/synth_pig/`: `ResultsFile-cold_Weertman-00500k000yr.mat` and `ResultsFile-warm_Weertman-000{30,35,50,75}k000yr.mat` |
| 3 | `plot_myBayesianAnalysis.m` | select the file `bayesiananalysis/synth_pig/SYNTH_PIG_BayesianAnalysis__EM_v5_tuned_model_full-du-dh-Weertman-Umbi-cycle2-floating0-SVDcomponents10__EM1_Weertmanyr30-Weertmanyr50__UaERR_l0-stdua0__MCMC_a2-steps100000-nchains25_v1.mat` in the file window |
| 4 | `Figure4_SYNTH_MarginalsInference.m` | uses the 9 SYNTH_PIG Bayesian analysis files in `../analysis/bayesiananalysis/synth_pig/` listed in `getfilename` at the end of the script |
| 5 | `Figure5_Plot_AMUND_VelThick.m` | **for transparency, not runnable** (needs diagnostic and inverse results of the ensemble, which can be obtained upon request from the author) |
| 6 | `plot_myBayesianAnalysis.m` | select the file `bayesiananalysis/amund/AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2009__EM2_2000-2014__EM3_2000-2020__UaERR_l0-stdua0__MCMC_a2-steps200000-nchains50_v1.mat` in the file window, and plot the sample of the high-density region for the inset (answer "High-density sample") |
| 7 | `Figure7_AMUND_MarginalsInference.m` | uses the 9 AMUND Bayesian analysis files in `../analysis/bayesiananalysis/amund/` listed in `getfilename` at the end of the script |
| A1, A2 | `analysis/emulation/prepare_data_for_Delta_u_emulators.m` | settings at the top of the script (as supplied: AMUND, `Calv_dh`, 2000 to 2009, both sliding laws, cycle 2, at most 25 components; change `targetyear` for 2014 and 2020); writes `Figures/<domain>_DeltaU_Measured_vs_Truncated.png` and `..._Modelled_vs_Truncated.png`; the SVD basis files are in `emulators/<domain>` |
| A3 | `analysis/emulation/plot_Emulator_MSE.m` | with the settings below; also writes the `MSE_RNN` files |

Settings for Figure A3 (`plot_Emulator_MSE.m`):

```matlab
modelversion = "v4_tuned_model_full"; % v4 (AMUND) or v5 (SYNTH_PIG)
domain="AMUND"; % AMUND or SYNTH_PIG
perturbation="Calv_dh"; % Calv_dh or dh
trainingdataformat="u"; % u or LOGu
startyear="2000"; % 2000 for AMUND, e.g. Weertmanyr30 for SYNTH_PIG
targetyear="2020"; % 2009, 2014, 2020 for AMUND, e.g. Weertmanyr75 for SYNTH_PIG. this can be an empty string to plot results for the u emulator, rather than the du emulator
slidinglaw=["Weertman" "Umbi"];
cycle=2;
SVDcomponents=25; % 25 for AMUND, 10 for SYNTH_PIG
```

Requirements: the Úa source code (Figures 2, 5 and A1 to A3), UQLab 2.0 (Figures 3, 4, 6, 7), `cmocean` and `fig` (C. Greene),
`othercolor`, `crameri` and `PlotNodalBasedQuantities_JDR` (modified Úa plotting function).

## Use of AI

This README file was produced with the help of an AI model. The scientific methods, the model code and the results are the work of the author.