# Appendix A — Code, Data and Reproducibility (repository text)

*This file provides ready-to-paste text and the repository map for Appendix A of the thesis.*

The complete workflow supporting this thesis — the Simulink model, the MATLAB pipeline scripts, the
labelled dataset, the trained classifier, the live-simulation waveform data, the final figures, and
the result summaries — is archived in a public GitHub repository:

- **Repository:** https://github.com/vicMenma/FYP_ML_Self_Healing_Mining_Feeder_Code
- **Software environment:** MATLAB R2024a with Simulink and Simscape Electrical Specialized Power Systems
- **Reproducibility:** a fixed random seed, `rng(42)`, makes the train/test split and model training
  repeatable within MATLAB.
- **Author:** Victoire Chinyanta Chimundu, CU-BEE-100-7229

## Repository contents

| Path | Purpose |
|---|---|
| `src/` | MATLAB scripts and the Simulink feeder model (`mining_feeder_layer_FINAL_baseline.slx`). |
| `outputs/dataset/` | The 1000-sample labelled dataset (`.csv`, `.xlsx`, `.mat`), 24 features, 13 classes. |
| `outputs/model/` | The trained Random Forest (`rf_model_v2.mat`) and the confusion, OOB, cross-validation and feature-importance data. |
| `outputs/waveforms/` | Twelve live-simulation fault-and-restoration captures (`wave_{SLG,LL,3PH}_B{2..5}.mat`). |
| `outputs/figures/` | The final thesis figures, organised by chapter, plus `figure_manifest.csv`. |
| `outputs/summaries/` | Block discovery, SLG grounding pre-flight, RF metrics, restoration summary and results, and the pipeline log. |

## Script execution order

| Order | Script | Purpose |
|---|---|---|
| 1 | `MASTER_A_PREFLIGHT_AND_DATASET.m` | Discovers blocks, runs the SLG grounding pre-flight, and generates the labelled dataset (aborts if any zone fails the pre-flight). |
| 2 | `MASTER_B_TRAIN_AND_RESTORE.m` | Trains the cost-sensitive Random Forest and runs the closed-loop restoration and waveform-capture scenarios. |
| 3 | `MASTER_C_GENERATE_ALL_FIGURES.m` | Regenerates the thesis figures from the stored outputs. |
| — | `RUN_ALL_PIPELINE.m` | Runs the complete workflow with automated stage control and a smoke test. |

## Academic and safety notice

This repository is an academic archive for a simulation-based Bachelor of Engineering thesis. It is
not a certified protection-relay package and must not be used for direct control of live mining
electrical infrastructure. Practical implementation would require relay-setting review,
hardware-in-the-loop testing, protection-coordination studies, cybersecurity assessment, site
acceptance testing, and approval by competent protection engineers.
