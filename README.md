# Basal sliding and ice rheology in West Antarctica constrained by multi-epoch satellite observations
**Author:** Jan De Rydt, <jan.rydt@northumbria.ac.uk>

Code to reproduce and analyze the data and figures of [De Rydt, 2026](https://doi.org/10.1017/jog.2026.10227).

The study provides a new approach to calibrate uncertain paramters in large-scale viscous ice-flow models. The methodology is applied using the ice-sflow model ([Úa](https://github.com/GHilmarG/UaSource)) 
for two domains: a synthetic Pine-Island-like glacier (`SYNTH_PIG`) and the Amundsen Sea sector of West Antarctica (`AMUND`). An ensemble of initial ice-sheet states is created for a 
range of parameter combinations. For each ensemble member, the basal slipperiness and the rate factor are inverted for and
then subjected to a change in geometry (calving front and ice thickness) in a diagnostic experiment, which gives the
instantaneous change in ice speed. Neural network emulators of this change in speed are trained and used in a Bayesian
inference (MCMC), which gives the posterior distribution of the model parameters.

Raw model output (restart and result files) are not provided as part of the repository but can be obtained upon request from the author. The repository contains

* all code of the workflow, so that the method can be checked and re-run with the data (public datasets from their original sources; other data can be obtained upon request from the author) and an Úa installation, and
* the processed data (DOI: see "Data availability" below) with which the emulation,
  the Bayesian inference and the figures can be reproduced.

## Contents

```
ua_input/                    Úa input and run scripts (steps 1 to 5, in the order of the numbers)
    0_synth_pig/             SYNTH_PIG only: Úa user input files of the synthetic glacier experiments (geometry, spinup,
                             cold and warm transient runs, inversion test)
    1_interpolants/          gridded interpolants of geometry, velocities and thickness changes for AMUND.
    2_meshing/               meshes for SYNTH_PIG and AMUND (the meshes themselves are archived on Zenodo, DOI: see "Data availability" below)
    3_runtable/              sample space and run table of the inverse ensemble
    run/                     general scripts for the inverse and the diagnostic stage: wrapper that runs the
                             experiments of a run table, job and clean-up scripts, reading and writing of run tables
        ua_core_overrides/   modified copies of Úa core functions used by the runs (see its README.txt)
        4_inverse/           Úa user input files of the inverse stage
        5_diagnostic/        Úa user input files of diagnostic stage
analysis/                    analysis of the results (steps 6 to 9)
    postprocessing/          processing of the inversion and diagnostic results (for transparency, not runnable without raw output files), the Delta_u files,
                             basin fluxes and plots of the ensembles
    emulation/               SVD, training data and training of the neural network emulators
    bayesian_inference/      Bayesian inference, posterior distribution and sampling of the posterior
figures/                     scripts for the figures of the paper (see figures/README_figures.md)
```

## Workflow in short

| # | Step | Folder |
|---|---|---|
| 1 | gridded interpolants of the input data | `ua_input/1_interpolants` |
| 2 | meshes | `ua_input/2_meshing` |
| 3 | sample space and run table of the inverse ensemble | `ua_input/3_runtable` |
| 4 | inverse stage in Úa (inversion, spin-up, inversion with dh/dt) | `ua_input/run`, `ua_input/run/4_inverse` |
| 5 | diagnostic stage: perturbation experiments with new geometry | `ua_input/run/5_diagnostic` |
| 6 | postprocessing of the results | `analysis/postprocessing` |
| 7 | emulation: singular value decomposition and neural network | `analysis/emulation` |
| 8 | Bayesian inference (MCMC) and fit of the posterior | `analysis/bayesian_inference` |
| 9 | sample of the posterior, new Úa runs | `analysis/bayesian_inference/Calc_HPDsample.m` |
| 10 | figures | `figures` |

Scripts that need raw model output are marked "**FOR TRANSPARENCY, NOT RUNNABLE**" in their header; the data they need
can be obtained upon request from the author.

## Data availability

* Processed data (postprocessed model results, inversion data, Bayesian analysis files) on [Zenodo](https://zenodo.org/records/24321711).
* Meshes (AMUND meshes with their boundary and fixed-boundary files, SYNTH_PIG mesh files) on [Zenodo](https://zenodo.org/records/24321711).
* Raw model output and other data that is not in the repository can be obtained upon
  request from the author.
* Public input datasets (BedMachine, Bedmap2, MEaSUREs, ITS_LIVE,...): to be downloaded from the original sources as detailed in [De Rydt, 2026](https://doi.org/10.1017/jog.2026.10227).

## Requirements

* [Úa](https://github.com/GHilmarG/UaSource/releases/tag/v2025a) for the model runs and plotting functions.
* MATLAB with the Mapping, Image Processing, Statistics and Machine Learning, Optimization and Parallel Computing toolboxes; for
  the emulation and inference also the Deep Learning Toolbox and the Deep Learning Toolbox Converter for TensorFlow Models.
* [UQLab](https://www.uqlab.com) Rel. 2.0.0.
* Python with TensorFlow 2.13 (Keras 2), keras-tuner, numpy and scipy.


## Use of AI

The preparation of this repository for publication was done with the assistance of an AI model under the direction of the author. 
The AI model was used to add a header (purpose, inputs, outputs, requirements) and section comments to each script.
The scientific methods, the model code and the results are the work of the authors.