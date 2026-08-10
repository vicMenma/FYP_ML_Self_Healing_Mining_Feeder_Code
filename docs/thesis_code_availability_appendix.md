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
| `src/` | MATLAB scripts and the two Simulink feeder models (`mining_feeder_layer_FINAL_baseline.slx` and the autonomous `mining_feeder_layer_FDIR.slx`). |
| `outputs/dataset/` | The 1000-sample labelled dataset (`.csv`, `.xlsx`, `.mat`): 24 features, 13 classes. |
| `outputs/model/` | The trained Random Forest (`rf_model_v2.mat`) with the confusion, out-of-bag, cross-validation and feature-importance data. |
| `outputs/waveforms/` | Twelve live-simulation fault-and-restoration captures (`wave_{SLG,LL,3PH}_B{2-5}.mat`). |
| `outputs/figures/` | The generated thesis figures, the curated set named after the official captions, and `figure_manifest.csv`. |
| `outputs/summaries/` | Block discovery, SLG grounding pre-flight, RF metrics, restoration results, the rule-based-baseline comparison, and the pipeline log. |
| `tools/` | Python generators for the two document-only artefacts: the Appendix B plan workbook and the Appendix C architecture figure. |
| `docs/` | The thesis, the bibliography, the figure map, and `Project_Gantt_Chart.xlsx`, the project plan behind Table B.1. |

## Script execution order

This mirrors Table A.2 of the thesis. Only the scripts that produce a reported
result are listed. Scripts 1 to 3 must be run in order; 4 to 8 reuse the stored
dataset and trained model and may be run independently, except the interpolation
test, which simulates its own 72 cases.

| No. | Script | Purpose |
|---|---|---|
| 1 | `MASTER_A_PREFLIGHT_AND_DATASET.m` | Discovers the blocks, runs the SLG grounding pre-flight of Section 4.4 and generates the labelled dataset of Table 3.3. Aborts if any zone fails the pre-flight. |
| 2 | `MASTER_B_TRAIN_AND_RESTORE.m` | Trains the cost-sensitive Random Forest of Section 4.6 and runs the twelve closed-loop restoration scenarios of Table 5.4. |
| 3 | `MASTER_C_GENERATE_ALL_FIGURES.m` | Regenerates the thesis figures from the stored outputs. |
| 4 | `BUILD_FDIR_CONTROLLER.m` | Builds the autonomous in-model FDIR controller of Section 4.8, giving Figures 4.5 and 5.15. |
| 5 | `ABLATION_COST_SENSITIVITY.m` | Retrains a standard Random Forest without the cost matrix on the identical split: Table 5.7. |
| 6 | `NOISE_ROBUSTNESS.m` | Evaluates classifier accuracy against measurement noise: Table 5.8 and Figure 5.14. |
| 7 | `INTERPOLATION_TEST.m` | Tests generalisation at off-grid fault resistances, load levels and onset times: Table 5.9. |
| 8 | `BASELINE_RULE_VS_RF.m` | Compares the forest with a max current-ratio zone rule and a single decision tree: Table 5.10. |

### Also in the archive, but not tabulated

These generate nothing quoted in the thesis and are therefore left out of
Table A.2, but they are kept because they are part of the working code:
`RUN_ALL_PIPELINE.m` (chains the whole workflow with stage control and a smoke
test), `LIVE_FDIR_DEMO.m` (interactive single-fault demonstration), and
`getRF.m`, `classifyRF.m`, `reportFDIR.m`, `PATCH_FDIR_IDLE.m` (helpers used by
the in-model controller).

Three further scripts regenerate or audit material that reaches the document by
other means: `REGEN_BW.m` redraws the per-class signatures and the fault
waveforms (Figures 5.1-5.6) in print-safe black and white, using distinct line
styles so the four buses stay distinguishable in monochrome;
`CAPTURE_FDIR_RUN_BW.m` does the same for the autonomous run of Figure 5.15,
re-running the simulation to do so; and `SIMULINK_AUDIT.m` performs a read-only
inventory of the model's blocks and parameters for traceability.

## Academic and safety notice

This repository is an academic archive for a simulation-based Bachelor of Engineering thesis. It is
not a certified protection-relay package and must not be used for direct control of live mining
electrical infrastructure. Practical implementation would require relay-setting review,
hardware-in-the-loop testing, protection-coordination studies, cybersecurity assessment, site
acceptance testing, and approval by competent protection engineers.
