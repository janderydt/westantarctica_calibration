# [TODO: project title]

Code to reproduce the figures and analyse the data of **[TODO: citation of the paper, DOI]**.

The study calibrates an ensemble of ice-flow models ([Úa](https://github.com/GHilmarG/UaSource)) against observed changes in
ice speed. Two domains are used: the Amundsen Sea sector of West Antarctica (`AMUND`) and a synthetic
Pine-Island-like glacier (`SYNTH_PIG`). Each ensemble member is inverted for the basal slipperiness and the rate factor and
then subjected to a change in geometry (calving front and ice thickness) in a diagnostic experiment, which gives the
instantaneous change in ice speed. Neural network emulators of this change in speed are trained and used in a Bayesian
inference (MCMC), which gives the posterior distribution of the model parameters.

Raw model output (restart and result files) is not part of the repository but can be obtained upon request from the author. The repository contains

* all code of the workflow, so that the method can be inspected and re-run with the data (public datasets from their original sources; other data can be obtained upon request from the author) and an Úa installation, and
* the processed data (postprocessed model results, emulators, posterior samples; DOI: see "Data availability" below) with which the emulation,
  the Bayesian inference and the figures can be reproduced.

## Contents

```
ua_input/                    Úa input and run scripts (steps 1 to 5, in the order of the numbers)
    0_synth_pig/             SYNTH_PIG only: Úa user input files of the synthetic glacier experiments (geometry, spinup,
                             cold and warm transient runs, inversion test)
    1_interpolants/          gridded interpolants of geometry, velocities and thickness changes
    2_meshing/               meshes (the meshes themselves are archived on Zenodo, DOI: see "Data availability" below)
    3_runtable/              sample space and run table of the inverse ensemble
    run/                     general scripts for the inverse and the diagnostic stage: wrapper that runs the
                             experiments of a run table, job and clean-up scripts, reading and writing of run tables
        ua_core_overrides/   modified copies of Úa core functions used by the runs (see its README.txt)
        4_inverse/           Úa user input files of the inverse stage
        5_diagnostic/        diagnostic stage (for transparency, not runnable)
analysis/                    analysis of the results (steps 6 to 9)
    postprocessing/          collection of the inversion and diagnostic results (for transparency, not runnable), the Delta_u files,
                             basin fluxes and plots of the ensembles
    emulation/               SVD, training data and training of the neural network emulators (MATLAB and Python)
    bayesian_inference/      Bayesian inference, posterior distribution and sampling of the posterior
figures/                     scripts for the figures of the paper (see figures/README_figures.md)
WORKFLOW.md                  description of the workflow, step by step
```

## Workflow in short

| # | Step | Folder |
|---|---|---|
| 1 | gridded interpolants of the input data | `ua_input/1_interpolants` |
| 2 | meshes | `ua_input/2_meshing` |
| 3 | sample space and run table of the inverse ensemble (Sobol sample, 300 members) | `ua_input/3_runtable` |
| 4 | inverse stage in Úa (inversion, spin-up, inversion with dh/dt) | `ua_input/run`, `ua_input/run/4_inverse` |
| 5 | diagnostic stage: perturbation experiments with new geometry | `ua_input/run/5_diagnostic` |
| 6 | postprocessing of the results | `analysis/postprocessing` |
| 7 | emulation: singular value decomposition and neural network | `analysis/emulation` |
| 8 | Bayesian inference (MCMC) and fit of the posterior | `analysis/bayesian_inference` |
| 9 | sample of the posterior, new Úa runs | `analysis/bayesian_inference/Calc_HPDsample.m` |
| 10 | figures | `figures` |

Scripts that need raw model output are marked "**FOR TRANSPARENCY, NOT RUNNABLE**" in their header; the data they need
can be obtained upon request from the author [TODO: contact]. See
[WORKFLOW.md](WORKFLOW.md) for the inputs, outputs and status of every step.

## Reproducing the figures

1. Download the processed data (DOI: see "Data availability" below) and place it in the folders `DiagnosticData`, `InversionData`, `Emulators` and
   `BayesianAnalysis` of the folder from which the scripts are run (see `WORKFLOW.md`).
2. Install the requirements below.
3. Run the scripts in `figures` as described in `figures/README_figures.md`. Figures 2 and 5 need raw model output and
   cannot be reproduced from the data in the repository (the raw model output can be obtained upon request from the author).

To repeat the emulation and the inference: `analysis/emulation` (`prepare_data_for_Delta_u_emulators.m`, then
`RNN_network_optimisation_JDR.py`), then `analysis/bayesian_inference` (`Driver_BayesianInference.m`).

## Data availability

* Processed data (postprocessed model results, inversion data, emulators, Bayesian analysis files): [TODO: DOI].
* Meshes (AMUND meshes with their boundary and fixed-boundary files, SYNTH_PIG mesh files), archived on Zenodo: [TODO: DOI].
* Raw model output and other data that is not in the repository (for example `basins_IMBIE_v2.mat`): can be obtained upon
  request from the author [TODO: contact].
* Public input datasets (BedMachine, Bedmap2, MEaSUREs, ITS_LIVE, CPOM, ...): to be downloaded from the original sources
  [TODO: table with dataset, version, citation and link].

## Requirements

The scripts do not change the MATLAB path (the only exception is the placeholder `addpath("/path/to/ua/source/folder")` in
`ua_input/run/UaWrapper.m`, which you have to adapt). Before running them, add to the path: this repository with its subfolders
(`addpath(genpath('<path to this repository>'))`), Úa, UQLab, the third-party and helper functions listed below and, for
step 1, the reader functions. The Úa user input files (`Define*.m`) in `ua_input/0_synth_pig`, `ua_input/run/4_inverse` and
`ua_input/run/5_diagnostic` have the same names in the different stages: Úa uses the copy in the experiment folder, so do not
put these three folders on the MATLAB path.

* [Úa](https://github.com/GHilmarG/UaSource) (no specific version is tracked) for the model runs and plotting functions.
* MATLAB with the Mapping, Image Processing, Statistics and Machine Learning, Optimization and Parallel Computing toolboxes; for
  the emulation and inference also the Deep Learning Toolbox and the Deep Learning Toolbox Converter for TensorFlow Models.
* [UQLab](https://www.uqlab.com) Rel. 2.0.0 (third party).
* Python with TensorFlow 2.13 (Keras 2), keras-tuner, numpy and scipy (see the header of `analysis/emulation/RNN_network_optimisation_JDR.py`).
* Third-party MATLAB functions: [TODO: list with versions]. Functions that read proprietary or binary data
  (`measures_annual`, `itslive_annual`, `measures_amundsen`, `bedmap2_interp`, `read_Bamber_2004`) are not included.
  The public datasets that they read (BedMachine, Bedmap2, MEaSUREs, ITS_LIVE, CPOM, ...) have to be downloaded from their
  original sources [TODO: table with dataset, version, citation and link]; other input data, for example
  `basins_IMBIE_v2.mat`, can be obtained upon request from the author.

## Notes

* Folders on your computer are written as placeholders that start with `/path/to/`; replace them before running a script
  (search for `/path/to`): `/path/to/ua/source/folder` (Úa source code, `ua_input/run/UaWrapper.m`), `/path/to/data`
  (public input datasets, the scripts in `ua_input/1_interpolants` and `figures/Figure5_Plot_AMUND_VelThick.m`),
  `/path/to/interpolants/` and `/path/to/DiagnosticData/` (`analysis/bayesian_inference/loadvelocitydata.m`),
  `/path/to/analysis/folder` (`analysis/bayesian_inference/Driver_BayesianInference.m`), `/path/to/home/`
  (`analysis/postprocessing/Calc_PerturbationResults_Ensemble.m`), `/path/to/run_tables/`
  (`ua_input/3_runtable/GenerateRunTable_Inverse.m`), and in the figure scripts `/path/to/BayesianAnalysis/<domain>/`,
  `/path/to/SYNTH_PIG/ResultsFiles/`, `/path/to/diagnostic_cases/` and `/path/to/inverse_cases/`.
* Some scripts adapt code from other authors: `analysis/emulation/RNN_network_optimisation_JDR.py` is adapted from
  Rosier et al. (2025, The Cryosphere 19, 2527, https://tc.copernicus.org/articles/19/2527/2025/) [TODO: licence of the original].

## Use of AI

The preparation of this repository for publication was done with the assistance of an AI model (Claude, Anthropic,
November 2026), under the direction of the authors. The AI model was used to

* remove commented-out and unused code from the scripts and add a header (purpose, inputs, outputs, requirements) and
  section comments to each script,
* flag possible bugs and missing dependencies (these are marked as `TODO` in the code and were not silently fixed),
* write this `README.md`, `WORKFLOW.md` and `figures/README_figures.md`.

The scientific methods, the model code and the results are the work of the authors. The AI model could not run MATLAB or
Úa: the edited scripts were checked by comparing their active code with the original scripts, but they were **not
executed** in their cleaned form. Please report any problem as an issue. [TODO: authors to confirm that they have reviewed the
changes.]

## Citation and licence

[TODO: how to cite the paper and the archived code; LICENSE]

## Contact

[TODO]
