# How the figures of the paper are made

| Figure | Script | Notes |
|---|---|---|
| 1 | `Figure1_DiagnosticCalibration.tex` | LaTeX (standalone, tikz, pgfplots): schematic of the diagnostic calibration |
| 2 | `Figure2_Plot_SYNTH_PIG_VelThick.m` | **for transparency, not runnable** (needs the results of the synthetic Ua experiments, which can be obtained upon request from the author) |
| 3 | `plot_BayesianAnalysisResults_u.m` | (was `Plot_myBayesianAnalysis.m`) select the file `SYNTH_PIG_BayesianAnalysis__EM_v5_tuned_model_full-du-dh-Weertman-Umbi-cycle2-floating0-SVDcomponents10__EM1_Weertmanyr30-Weertmanyr50__UaERR_l0-stdua0__MCMC_a2-steps100000-nchains25_v1.mat` |
| 4 | `Figure4_SYNTH_MarginalsInference.m` | uses the 9 SYNTH_PIG Bayesian analysis files listed in `getfilename` at the end of the script |
| 5 | `Figure5_Plot_AMUND_VelThick.m` | **for transparency, not runnable** (needs diagnostic and inverse results of the ensemble, which can be obtained upon request from the author) |
| 6 | `plot_BayesianAnalysisResults_u.m` | select the file `AMUND_BayesianAnalysis__EM_v4_tuned_model_full-du-Calv_dh-Weertman-Umbi-cycle2-floating0-SVDcomponents25__EM1_2000-2009__EM2_2000-2014__EM3_2000-2020__UaERR_l0-stdua0__MCMC_a2-steps200000-nchains50_v1.mat`, and plot the sample of the high-density region for the inset (answer "High-density sample" in the dialog) |
| 7 | `Figure7_AMUND_MarginalsInference.m` | uses the 9 AMUND Bayesian analysis files listed in `getfilename` at the end of the script |
| A1, A2 | `analysis/emulation/prep_EmulatorTrainingData_deltaU.m` | (was `prepare_data_for_Delta_u_emulators.m` in GLUE/GLUE_DataProcessing) |
| A3 | `FigureA3_Emulator_MSE.m` | not yet in this repository, with the settings below |

Settings for Figure A3 (`FigureA3_Emulator_MSE.m`):

```matlab
modelversion = "v4_tuned_model_full";
domain="AMUND"; % AMUND or SYNTH_PIG
perturbation="Calv_dh"; % Calv_dh or dh
trainingdataformat="u"; % u or LOGu
startyear="2000"; % 2000 for AMUND, e.g. Weertmanyr30 for SYNTH_PIG
targetyear="2020"; % 2009, 2014, 2020 for AMUND, 35 for SYNTH_PIG. this can be an empty string to plot results for the u emulator, rather than the du emulator
slidinglaw=["Weertman" "Umbi"];
```

The scripts need UQLab (Figures 3, 4, 6, 7), `cmocean` and `fig` (C. Greene) and `PlotNodalBasedQuantities_JDR`
(modified Ua plotting function). Machine-specific folders (`/mnt/md0/...`) have to be replaced by your own.
