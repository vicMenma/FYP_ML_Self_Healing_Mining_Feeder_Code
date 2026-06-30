# Appendix: Code and Data Availability

To keep this thesis to a reasonable length, the full MATLAB and Simulink source code is not reproduced here as printed listings. Instead, the complete code base used to generate the results presented in this thesis has been archived in an external public repository to support transparency and reproducibility.

**Repository link:** https://github.com/vicMenma/FYP_ML_Self_Healing_Mining_Feeder_Code
**Release URL:** https://github.com/vicMenma/FYP_ML_Self_Healing_Mining_Feeder_Code/releases/tag/v1.0-thesis-submission
**Release tag:** `v1.0-thesis-submission`
**Software:** MATLAB R2024a, with Simulink and Simscape Electrical (Specialized Power Systems)

The release tagged above corresponds to the version of the code used to produce the figures and numerical results reported in this thesis. The repository contains the Simulink feeder model, the data-generation and training scripts, the self-healing/restoration routine, and the figure-generation scripts (all in `src/`); a lightweight CSV copy of the dataset (`outputs/dataset/fault_dataset_1000.csv`); the result summaries (`outputs/summaries/`); and the 40 figures used in the thesis, grouped by chapter and named after their official captions (`outputs/figures/thesis_final_named/`).

## Scripts Included

| Script | Function |
|--------|----------|
| `MASTER_A_PREFLIGHT_AND_DATASET.m` | Verifies the Simulink model and signals, applies a grounding-resistance correction, and generates the 1000-sample labelled fault dataset (one healthy class and twelve fault classes spanning SLG, LL, and 3PH faults across the main buses and load levels). |
| `MASTER_B_TRAIN_AND_RESTORE.m` | Trains the cost-sensitive random forest classifier (80/20 stratified split, fixed seed), evaluates it (accuracy with confidence interval, per-class precision/recall/F1, cross-validation, McNemar test, ablation), and runs the 36 restoration scenarios with post-restoration voltage checks. |
| `MASTER_C_GENERATE_ALL_FIGURES.m` | Regenerates all thesis figures (Chapters 3–6) at print resolution from the saved dataset, trained model, and restoration results. |
| `RUN_ALL_PIPELINE.m` | Runs the three master scripts in sequence (A → B → C) with skip logic for previously generated data, and writes a combined run log. |
| `gen_fig5_14.m` | Helper script that produces the post-restoration voltage figure (Fig. 5.14) from the restoration results table. |
| `mining_feeder_layer_FINAL_baseline.slx` | The Simulink/Simscape model of the 33/11 kV mining distribution feeder used throughout the study. |

## Reproducing the Results

The scripts are intended to be run in the order A → B → C (or via `RUN_ALL_PIPELINE.m`) from MATLAB R2024a, with the `src/` folder set as the current folder so that the scripts and the Simulink model share a common path. A fixed random seed is used so that the dataset split and model training are repeatable. The large datasets and trained model are regenerable from the scripts and are therefore not stored in the repository; the committed result summaries and figures correspond to the run reported in this thesis.

The scripts and model in the linked repository correspond directly to the methodology, figures, and results presented in this thesis. This work is simulation-based and carried out for academic purposes; it does not constitute certified or field-ready protection software.
