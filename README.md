# [TODO: project title]

Code to reproduce the figures and analyse the data of **[TODO: citation of the paper, DOI]**.

The study calibrates an ensemble of ice-flow models ([Úa](https://github.com/GHilmarG/UaSource)) against observed changes in
ice speed. Two domains are used: the Amundsen Sea sector of West Antarctica (`AMUND`) and a synthetic
Pine-Island-like glacier (`SYNTH_PIG`). Each ensemble member is inverted for the basal slipperiness and the rate factor and
then subjected to a change in geometry (calving front and ice thickness) in a diagnostic experiment, which gives the
instantaneous change in ice speed. Neural network emulators of this change in speed are trained and used in a Bayesian
inference (MCMC), which gives the posterior distribution of the model parameters.

Raw model output (restart and result files) is **not** distributed. The repository contains

* all code of the workflow, so that the method can be inspected and re-run with your own data and an Úa installation, and
* the processed data (postprocessed model results, emulators, posterior samples; [TODO: DOI]) with which the emulation,
  the Bayesian inference and the figures can be reproduced.

## Contents

```
ua_input/                    Úa input and run scripts (steps 1 to 5)
    interpolants/            gridded interpolants of geometry, velocities and thickness changes
    meshing/                 meshes (the meshes themselves are archived on Zenodo, DOI: TODO)
    runtable/                sample space and run table of the inverse ensemble
    inverse/                 Úa user input files of the inverse stage
    ua_core_overrides/       modified copies of Úa core functions used by the runs (see its README.txt)
    run/                     wrapper that runs the experiments of a run table
    diagnostic/              diagnostic stage (for transparency, not runnable)
analysis/                    analysis of the results (steps 6 to 9)
    postprocessing/          collection of the diagnostic results and basin fluxes (for transparency, not runnable)
    emulation/               SVD, training data and training of the neural network emulators (MATLAB and Python)
    bayesian_inference/      Bayesian inference, posterior distribution and sampling of the posterior
figures/                     scripts for the figures of the paper (see figures/README_figures.md)
WORKFLOW.md                  description of the workflow, step by step
```

## Workflow in short

| # | Step | Folder |
|---|---|---|
| 1 | gridded interpolants of the input data | `ua_input/interpolants` |
| 2 | meshes | `ua_input/meshing` |
| 3 | sample space and run table of the inverse ensemble (Sobol sample, 300 members) | `ua_input/runtable` |
| 4 | inverse stage in Úa (inversion, spin-up, inversion with dh/dt) | `ua_input/run`, `ua_input/inverse` |
| 5 | diagnostic stage: perturbation experiments with new geometry | `ua_input/diagnostic` |
| 6 | postprocessing of the results | `analysis/postprocessing` |
| 7 | emulation: singular value decomposition and neural network | `analysis/emulation` |
| 8 | Bayesian inference (MCMC) and fit of the posterior | `analysis/bayesian_inference` |
| 9 | sample of the posterior, new Úa runs | `analysis/bayesian_inference/calc_HPDsample.m` |
| 10 | figures | `figures` |

Scripts that need raw model output are marked "**FOR TRANSPARENCY, NOT RUNNABLE**" in their header. See
[WORKFLOW.md](WORKFLOW.md) for the inputs, outputs and status of every step.

## Reproducing the figures

1. Download the processed data [TODO: DOI] and place it in the folders `DiagnosticData`, `InversionData`, `Emulators` and
   `BayesianAnalysis` of the folder from which the scripts are run (see `WORKFLOW.md`).
2. Install the requirements below.
3. Run the scripts in `figures` as described in `figures/README_figures.md`. Figures 2 and 5 need raw model output and
   cannot be reproduced from the distributed data.

To repeat the emulation and the inference: `analysis/emulation` (`prep_EmulatorTrainingData_deltaU.m`, then
`RNN_network_optimisation_JDR_v5.py`), then `analysis/bayesian_inference` (`main_BayesianInference_u.m`).

## Requirements

* [Úa](https://github.com/GHilmarG/UaSource) (no specific version is tracked) for the model runs and plotting functions.
* MATLAB with the Mapping, Image Processing, Statistics and Machine Learning, Optimization and Parallel Computing toolboxes; for
  the emulation and inference also the Deep Learning Toolbox and the Deep Learning Toolbox Converter for TensorFlow Models.
* [UQLab](https://www.uqlab.com) Rel. 2.0.0 (third party).
* Python with TensorFlow 2.13 (Keras 2), keras-tuner, numpy and scipy (`analysis/emulation/requirements_RNN.txt`).
* Third-party MATLAB functions: [TODO: list with versions]. Functions that read proprietary or binary data
  (`measures_annual`, `itslive_annual`, `measures_amundsen`, `bedmap2_interp`, `read_Bamber_2004`) are not included.

## Notes

* Many scripts contain machine-specific folders (for example `/mnt/md0/...` and environment variables such as `froot_ua`), marked
  with `TODO` in the code. Replace them with your own folders.
* Some scripts adapt code from other authors: `analysis/emulation/RNN_network_optimisation_JDR_v5.py` is adapted from
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
