# Visual Figure Audit Report

_Generated: 2026-06-30 — automated perceptual-similarity audit_

**Thesis document:** `final decision/Chimundu_VCC_BEng_Thesis_draft_4.docx`  
**Repository:** `FYP_ML_Self_Healing_Mining_Feeder_Code/outputs/figures/`

## 1. Method

Every image embedded in the thesis `.docx` was extracted and associated with the nearest
following figure caption (reading order from `word/document.xml`). Each thesis figure was then
compared **visually** — not by filename — against every image in the repository using four
independent measures:

- **pHash** (32×32 DCT perceptual hash, Hamming distance, 0 = identical structure)
- **dHash** (gradient/difference hash, Hamming distance)
- **aHash** (average hash, Hamming distance)
- **SSIM** (global structural similarity on 256×256 grayscale, 1.0 = identical) and normalised cross-correlation

Confidence rules (SSIM is required for a positive match, so that mostly-white plots which
collide to pHash 0 are **not** falsely matched):

| Classification | Rule |
|---|---|
| **EXACT MATCH** | identical bytes, or pHash ≤ 4 **and** SSIM ≥ 0.93 |
| **LIKELY MATCH** | pHash ≤ 8 **and** SSIM ≥ 0.75 |
| **POSSIBLE MATCH — manual review** | SSIM ≥ 0.55, or SSIM ≥ 0.45 with pHash ≤ 8 |
| **NO MATCH FOUND** | none of the above |

## 2. Summary

**First pass (repository-only audit):**

- **40 captioned thesis figures** were extracted from the `.docx` (plus 1 uncaptioned cover image = 41 images).
- GitHub figures scanned (first pass): **40**
- **30** thesis figures were already **EXACT matches** in the repository (LIKELY: 0, POSSIBLE: 0).
- **10** thesis figures were **missing from the repository** during the first audit (Fig 3.12, 4.1–4.9).
- GitHub figures USED in thesis: **30**;  DUPLICATE of a used figure: **0**.
- Unused/duplicate figures were **archived** in `outputs/figures_unused/`: **6** high-confidence unused + **4** dataset diagnostics (see §7–§8).

**Second pass (full project-folder recovery — this update):**

- A recursive search of the **whole** project folder scanned **50** candidate images (`.png/.jpg/.jpeg/.tif/.tiff/.bmp`).
- **9 of the 10** missing figures (Fig 4.1–4.9) were **recovered as byte-identical source files** from `Project matlab/simulink/` (manual Simulink/scope/parameter-dialog screenshots).
- **1 of the 10** (Fig 3.12, IDMT TCC benchmark) had **no source file on disk** and was **extracted directly from the thesis `.docx`**.
- All 10 were copied into `outputs/figures/thesis_manual_captures/` with caption-based names (see **§11 Recovered Manual Thesis Figures**).
- The 4 dataset diagnostic plots were moved to `outputs/figures_unused/dataset/`.

**Net result:** all 40 captioned thesis figures now have a corresponding image tracked in the repository (30 script-generated + 10 manual captures).

> **Note on numbering.** The figure numbers were re-organised between figure generation and the
> final thesis, so repository filenames do **not** track thesis figure numbers. The matches below
> are by image content. For example thesis *Fig 5.10 (feature importance)* is the repository's
> `Fig5_7_feature_importance.png`, and thesis *Fig 3.5* is `Fig3_3_parameter_sweep.png`.

## 3. Thesis figures and their matched GitHub files

| Thesis Fig | Caption | Thesis image | Best GitHub match | Class | SSIM | pHash | Confidence |
|---|---|---|---|---|---|---|---|
| 3.1 | Figure 3.1: Research methodology workflow. | image2.png | `outputs/figures/simulink_model/Figure_3_1_Methodology_Workflow.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.2 | Figure 3.2: Six-layer system architecture. | image3.png | `outputs/figures/simulink_model/Figure_3_2_model_overview.png` | EXACT MATCH | 0.999 | 0 | 0.99 |
| 3.3 | Figure 3.3: Feeder block diagram. | image4.png | `outputs/figures/simulink_model/Figure_3_3_model_detail.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.4 | Figure 3.4: Dataset generation workflow. | image5.png | `outputs/figures/simulink_model/Figure_3_7_Dataset_Generation.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.5 | Figure 3.5: Fault parameter sweep space. | image6.png | `outputs/figures/ch3_methodology/Fig3_3_parameter_sweep.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.6 | Figure 3.6: RMS feature vector structure. | image7.png | `outputs/figures/ch3_methodology/Fig3_4_feature_extraction.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.7 | Figure 3.7: Random Forest classifier structure. | image8.png | `outputs/figures/ch3_methodology/Fig3_5_rf_architecture.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.8 | Figure 3.8: Machine-learning training pipeline. | image9.png | `outputs/figures/simulink_model/Figure_3_8_ML_Training.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.9 | Figure 3.9: Asymmetric misclassification cost ma | image10.png | `outputs/figures/ch4_system_design/Fig4_2_cost_matrix.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.10 | Figure 3.10: Selective isolation logic. | image11.png | `outputs/figures/simulink_model/Figure_3_10_Selective_Isolation.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.11 | Figure 3.11: Self-healing restoration logic. | image13.png | `outputs/figures/simulink_model/Figure_3_11_Self_Healing.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 3.12 | Figure 3.12: IDMT TCC benchmark. | image12.png | `— (none) —` | NO MATCH FOUND | 0.116 | 0 | 0.046 |
| 4.1 | Figure 4.1: Simulink feeder model canvas. | image14.png | `— (none) —` | NO MATCH FOUND | 0.136 | 2 | 0.054 |
| 4.2 | Figure 4.2: Source, transformer and breaker para | image15.png | `— (none) —` | NO MATCH FOUND | 0.094 | 0 | 0.038 |
| 4.3 | Figure 4.3: Load block parameters. | image16.png | `— (none) —` | NO MATCH FOUND | 0.077 | 0 | 0.031 |
| 4.4 | Figure 4.4: Fault block default settings. | image17.png | `— (none) —` | NO MATCH FOUND | 0.211 | 10 | 0.084 |
| 4.5 | Figure 4.5: Switching-device parameter settings. | image18.png | `— (none) —` | NO MATCH FOUND | 0.069 | 10 | 0.027 |
| 4.6 | Figure 4.6: Source and T1 healthy RMS outputs. | image19.png | `— (none) —` | NO MATCH FOUND | 0.151 | 18 | 0.06 |
| 4.7 | Figure 4.7: Bus B4 and Bus B5 healthy RMS output | image20.png | `— (none) —` | NO MATCH FOUND | 0.153 | 16 | 0.061 |
| 4.8 | Figure 4.8: T2 supply-path RMS outputs. | image21.png | `— (none) —` | NO MATCH FOUND | 0.376 | 16 | 0.15 |
| 4.9 | Figure 4.9: Bus B2 and Bus B3 healthy RMS output | image22.png | `— (none) —` | NO MATCH FOUND | 0.152 | 16 | 0.061 |
| 4.10 | Figure 4.10: Dataset class distribution. | image23.png | `outputs/figures/ch5_results/Fig5_1_class_distribution.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 4.11 | Figure 4.11: Random Forest OOB error convergence | image24.png | `outputs/figures/ch5_results/Fig5_5_oob_error_curve.png` | EXACT MATCH | 0.999 | 0 | 0.99 |
| 5.1 | Figure 5.1: Healthy Bus B2 waveforms. | image25.png | `outputs/figures/ch3_methodology/Fig3_7_healthy_waveform.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.2 | Figure 5.2: Phase A voltage signature by fault c | image26.png | `outputs/figures/ch5_results/Fig5_2_voltage_heatmap.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.3 | Figure 5.3: Phase A current signature by fault c | image27.png | `outputs/figures/ch5_results/Fig5_3_current_heatmap.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.4 | Figure 5.4: Bus B4 fault waveform comparison. | image28.png | `outputs/figures/ch3_methodology/Fig3_8_fault_waveforms.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.5 | Figure 5.5: Bus B2 current-voltage class separat | image29.png | `outputs/figures/ch5_results/Fig5_4_scatter_separability.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.6 | Figure 5.6: Test-set confusion matrix. | image30.png | `outputs/figures/ch5_results/Fig5_6_confusion_matrix.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.7 | Figure 5.7: Per-class classification metrics. | image31.png | `outputs/figures/ch5_results/Fig5_8_per_class_metrics.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.8 | Figure 5.8: Five-fold cross-validation results. | image32.png | `outputs/figures/ch5_results/Fig5_9_cv_accuracy_folds.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.9 | Figure 5.9: Random Forest versus majority baseli | image33.png | `outputs/figures/ch5_results/Fig5_10_baseline_comparison.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.10 | Figure 5.10: OOB permutation feature importance. | image34.png | `outputs/figures/ch5_results/Fig5_7_feature_importance.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.11 | Figure 5.11: Feature ablation results. | image35.png | `outputs/figures/ch5_results/Fig5_11_ablation_study.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.12 | Figure 5.12: Per-class F1-score confidence inter | image36.png | `outputs/figures/ch5_results/Fig5_12_f1_bootstrap_ci.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.13 | Figure 5.13: Bus B4 voltage recovery timeline. | image37.png | `outputs/figures/ch5_results/Fig5_13_restoration_waveforms.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 5.14 | Figure 5.14: Post-restoration voltage comparison | image38.png | `outputs/figures/ch5_results/Fig5_14_restoration_rms.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 6.1 | Figure 6.1: Protection scheme comparison. | image39.png | `outputs/figures/ch6_conclusions/Fig6_1_scenario_comparison.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 6.2 | Figure 6.2: Performance radar chart. | image40.png | `outputs/figures/ch6_conclusions/Fig6_2_performance_radar.png` | EXACT MATCH | 1.000 | 0 | 0.99 |
| 6.3 | Figure 6.3: Future work roadmap. | image41.png | `outputs/figures/ch6_conclusions/Fig6_3_future_work_roadmap.png` | EXACT MATCH | 0.999 | 0 | 0.99 |

## 4. Thesis figures NOT found in the GitHub repository (first pass)

These figures appear in the thesis but had **no corresponding source image in the repository** at the
first pass. They are manually-captured Simulink model / parameter-dialog / scope screenshots that the
committed scripts do not regenerate. (The closest-by-pixels repository image is listed only for
reference; SSIM values are low, confirming they are *not* the same image.)

> ✅ **Resolved in the second pass.** All 10 of these figures have since been recovered and added to
> `outputs/figures/thesis_manual_captures/` — 9 as byte-identical files from `Project matlab/simulink/`,
> and Fig 3.12 by extraction from the thesis `.docx`. See **§11 Recovered Manual Thesis Figures**.

| Thesis Fig | Caption | Thesis image | Closest repo image (ref only) | SSIM |
|---|---|---|---|---|
| 3.12 | Figure 3.12: IDMT TCC benchmark. | image12.png | `outputs/figures/dataset/dataset_scatter_B2.png` | 0.116 |
| 4.1 | Figure 4.1: Simulink feeder model canvas. | image14.png | `outputs/figures/ch6_conclusions/Fig6_2_performance_radar.png` | 0.136 |
| 4.2 | Figure 4.2: Source, transformer and breaker para | image15.png | `outputs/figures/ch3_methodology/Fig3_2_methodology_flowchart.png` | 0.094 |
| 4.3 | Figure 4.3: Load block parameters. | image16.png | `outputs/figures/dataset/dataset_scatter_B2.png` | 0.077 |
| 4.4 | Figure 4.4: Fault block default settings. | image17.png | `outputs/figures/ch4_system_design/Fig4_1_fault_block_config.png` | 0.211 |
| 4.5 | Figure 4.5: Switching-device parameter settings. | image18.png | `outputs/figures/ch4_system_design/Fig4_1_fault_block_config.png` | 0.069 |
| 4.6 | Figure 4.6: Source and T1 healthy RMS outputs. | image19.png | `outputs/figures/ch5_results/Fig5_9_cv_accuracy_folds.png` | 0.151 |
| 4.7 | Figure 4.7: Bus B4 and Bus B5 healthy RMS output | image20.png | `outputs/figures/ch5_results/Fig5_9_cv_accuracy_folds.png` | 0.153 |
| 4.8 | Figure 4.8: T2 supply-path RMS outputs. | image21.png | `outputs/figures/ch5_results/Fig5_1_class_distribution.png` | 0.376 |
| 4.9 | Figure 4.9: Bus B2 and Bus B3 healthy RMS output | image22.png | `outputs/figures/ch5_results/Fig5_9_cv_accuracy_folds.png` | 0.152 |

## 5. GitHub figures used in the thesis

| GitHub file | Maps to Thesis Fig | SSIM |
|---|---|---|
| `outputs/figures/ch3_methodology/Fig3_3_parameter_sweep.png` | 3.5 | 1.000 |
| `outputs/figures/ch3_methodology/Fig3_4_feature_extraction.png` | 3.6 | 1.000 |
| `outputs/figures/ch3_methodology/Fig3_5_rf_architecture.png` | 3.7 | 1.000 |
| `outputs/figures/ch3_methodology/Fig3_7_healthy_waveform.png` | 5.1 | 1.000 |
| `outputs/figures/ch3_methodology/Fig3_8_fault_waveforms.png` | 5.4 | 1.000 |
| `outputs/figures/ch4_system_design/Fig4_2_cost_matrix.png` | 3.9 | 1.000 |
| `outputs/figures/ch5_results/Fig5_10_baseline_comparison.png` | 5.9 | 1.000 |
| `outputs/figures/ch5_results/Fig5_11_ablation_study.png` | 5.11 | 1.000 |
| `outputs/figures/ch5_results/Fig5_12_f1_bootstrap_ci.png` | 5.12 | 1.000 |
| `outputs/figures/ch5_results/Fig5_13_restoration_waveforms.png` | 5.13 | 1.000 |
| `outputs/figures/ch5_results/Fig5_14_restoration_rms.png` | 5.14 | 1.000 |
| `outputs/figures/ch5_results/Fig5_1_class_distribution.png` | 4.10 | 1.000 |
| `outputs/figures/ch5_results/Fig5_2_voltage_heatmap.png` | 5.2 | 1.000 |
| `outputs/figures/ch5_results/Fig5_3_current_heatmap.png` | 5.3 | 1.000 |
| `outputs/figures/ch5_results/Fig5_4_scatter_separability.png` | 5.5 | 1.000 |
| `outputs/figures/ch5_results/Fig5_5_oob_error_curve.png` | 4.11 | 0.999 |
| `outputs/figures/ch5_results/Fig5_6_confusion_matrix.png` | 5.6 | 1.000 |
| `outputs/figures/ch5_results/Fig5_7_feature_importance.png` | 5.10 | 1.000 |
| `outputs/figures/ch5_results/Fig5_8_per_class_metrics.png` | 5.7 | 1.000 |
| `outputs/figures/ch5_results/Fig5_9_cv_accuracy_folds.png` | 5.8 | 1.000 |
| `outputs/figures/ch6_conclusions/Fig6_1_scenario_comparison.png` | 6.1 | 1.000 |
| `outputs/figures/ch6_conclusions/Fig6_2_performance_radar.png` | 6.2 | 1.000 |
| `outputs/figures/ch6_conclusions/Fig6_3_future_work_roadmap.png` | 6.3 | 0.999 |
| `outputs/figures/simulink_model/Figure_3_10_Selective_Isolation.png` | 3.10 | 1.000 |
| `outputs/figures/simulink_model/Figure_3_11_Self_Healing.png` | 3.11 | 1.000 |
| `outputs/figures/simulink_model/Figure_3_1_Methodology_Workflow.png` | 3.1 | 1.000 |
| `outputs/figures/simulink_model/Figure_3_2_model_overview.png` | 3.2 | 0.999 |
| `outputs/figures/simulink_model/Figure_3_3_model_detail.png` | 3.3 | 1.000 |
| `outputs/figures/simulink_model/Figure_3_7_Dataset_Generation.png` | 3.4 | 1.000 |
| `outputs/figures/simulink_model/Figure_3_8_ML_Training.png` | 3.8 | 1.000 |

## 6. Duplicated figures

No exact duplicate of a *used* figure was found in the repository (no two repository files
both resolve to the same thesis figure at EXACT/LIKELY confidence).

## 7. Unused GitHub figures — archived

Confirmed not used in the thesis (maximum SSIM against **every** thesis figure < 0.30 — i.e. no
thesis figure resembles them). The thesis instead uses different images for these concepts
(Simulink screenshots or text tables). These were moved to `outputs/figures_unused/` (same
sub-folder structure; nothing deleted).

| GitHub file (archived) | Concept | Max SSIM to any thesis fig |
|---|---|---|
| `outputs/figures/ch3_methodology/Fig3_1_feeder_topology.png` | Matplotlib feeder topology (thesis uses Simulink Fig 3.3) | 0.175 |
| `outputs/figures/ch3_methodology/Fig3_2_methodology_flowchart.png` | Matplotlib methodology flowchart (thesis uses Fig 3.1) | 0.150 |
| `outputs/figures/ch3_methodology/Fig3_6_selfhealing_logic.png` | Matplotlib self-healing logic (thesis uses Simulink Fig 3.11) | 0.168 |
| `outputs/figures/ch4_system_design/Fig4_1_fault_block_config.png` | Fault-block config table (thesis uses Simulink dialog Fig 4.4) | 0.211 |
| `outputs/figures/ch4_system_design/Fig4_3_class_label_map.png` | Class-label map table (not used as a figure) | 0.175 |
| `outputs/figures/ch4_system_design/Fig4_4_rf_hyperparameters.png` | RF hyperparameter table (not used as a figure) | 0.193 |

## 8. Manual review required (held — NOT moved)

These repository images are **not** used in the thesis as-is, but they are early *diagnostic*
renderings of data that the thesis **does** present through re-styled figures. They were held for
human confirmation at the first pass and have now been **archived** to `outputs/figures_unused/dataset/`
(moved, not deleted) since the thesis uses the final styled Chapter 5 versions instead.

| GitHub file (now archived) | Closest used concept (Thesis Fig) | SSIM | Note |
|---|---|---|---|
| `outputs/figures_unused/dataset/dataset_class_dist.png` | 4.10 | 0.492 | alt rendering of class distribution (used: Fig 4.10) |
| `outputs/figures_unused/dataset/dataset_current_heatmap.png` | 5.3 | 0.752 | alt rendering of current heatmap (used: Fig 5.3) |
| `outputs/figures_unused/dataset/dataset_scatter_B2.png` | 3.12 | 0.116 | B2-specific diagnostic scatter (used: Fig 5.5 separability) |
| `outputs/figures_unused/dataset/dataset_voltage_heatmap.png` | 5.2 | 0.387 | alt rendering of voltage heatmap (used: Fig 5.2) |

## 9. Cover / non-figure image

- `image1.jpeg` — uncaptioned cover/identity image in the thesis front matter; not a figure, no repository counterpart (closest `outputs/figures/dataset/dataset_current_heatmap.png`, SSIM 0.517).

## 10. Contact sheets

- `docs/figure_audit_contact_sheets/sheet1_thesis_vs_match.png` — every thesis figure beside its best GitHub match
- `docs/figure_audit_contact_sheets/sheet2_unused.png` — GitHub figures with no thesis match (archived)
- `docs/figure_audit_contact_sheets/sheet3_manual_review.png` — uncertain diagnostic plots vs their closest thesis figure
- `docs/figure_audit_contact_sheets/sheet4_recovered_manual_figures.png` — each recovered figure (Fig 3.12, 4.1–4.9) beside its matched project-folder source

## 11. Recovered Manual Thesis Figures

Second-pass recovery. A recursive search of the **entire** project folder
(`Project matlab/`, **50** images scanned: `.png/.jpg/.jpeg/.tif/.tiff/.bmp`) located the source
images for the 10 figures that were missing at the first pass. Each was compared **visually** (pHash,
dHash, aHash, SSIM, NCC) against every candidate — not by filename.

- **9 of 10** (Fig 4.1–4.9) were found as **byte-identical** files in `Project matlab/simulink/`
  (mean absolute pixel difference = 0.000, identical dimensions) and copied into the repository.
- **1 of 10** (Fig 3.12) had **no source on disk** and was extracted directly from the thesis `.docx`.

All recovered images were copied (originals untouched) into `outputs/figures/thesis_manual_captures/`
with caption-based filenames:

| Thesis Fig | Caption | Source found (in `Project matlab/`) | Destination in repo | SSIM | pHash | Match basis | Status |
|---|---|---|---|---|---|---|---|
| 3.12 | 3.12: IDMT TCC benchmark. | _thesis `.docx` (no file on disk)_ | `outputs/figures/thesis_manual_captures/Fig3_12_idmt_tcc_benchmark.png` | 0.116 | 0 | extracted from `.docx` | NO MATCH FOUND (no external source) |
| 4.1 | 4.1: Simulink feeder model canvas. | `Project matlab/simulink/Screenshot 2026-03-07 051205.png` | `outputs/figures/thesis_manual_captures/Fig4_1_simulink_feeder_model_canvas.png` | 1.000 | 0 | identical bytes | EXACT MATCH |
| 4.2 | 4.2: Source, transformer and breaker parameters | `Project matlab/simulink/Screenshot 2026-02-05 214308.png` | `outputs/figures/thesis_manual_captures/Fig4_2_source_transformer_breaker_parameters.png` | 1.000 | 0 | identical bytes | EXACT MATCH |
| 4.3 | 4.3: Load block parameters. | `Project matlab/simulink/Screenshot 2026-02-05 214041.png` | `outputs/figures/thesis_manual_captures/Fig4_3_load_block_parameters.png` | 1.000 | 0 | identical bytes | EXACT MATCH |
| 4.4 | 4.4: Fault block default settings. | `Project matlab/simulink/Screenshot 2026-02-05 213245.png` | `outputs/figures/thesis_manual_captures/Fig4_4_fault_block_default_settings.png` | 1.000 | 0 | identical bytes | EXACT MATCH |
| 4.5 | 4.5: Switching-device parameter settings. | `Project matlab/simulink/Screenshot 2026-02-05 214425.png` | `outputs/figures/thesis_manual_captures/Fig4_5_switching_device_parameter_settings.png` | 1.000 | 0 | identical bytes | EXACT MATCH |
| 4.6 | 4.6: Source and T1 healthy RMS outputs. | `Project matlab/simulink/Screenshot 2026-02-05 213355.png` | `outputs/figures/thesis_manual_captures/Fig4_6_source_and_T1_healthy_rms_outputs.png` | 1.000 | 0 | identical bytes | EXACT MATCH |
| 4.7 | 4.7: Bus B4 and Bus B5 healthy RMS outputs. | `Project matlab/simulink/Screenshot 2026-02-05 213751.png` | `outputs/figures/thesis_manual_captures/Fig4_7_busB4_B5_healthy_rms_outputs.png` | 1.000 | 0 | identical bytes | EXACT MATCH |
| 4.8 | 4.8: T2 supply-path RMS outputs. | `Project matlab/simulink/Screenshot 2026-02-05 213932.png` | `outputs/figures/thesis_manual_captures/Fig4_8_T2_supply_path_rms_outputs.png` | 1.000 | 0 | identical bytes | EXACT MATCH |
| 4.9 | 4.9: Bus B2 and Bus B3 healthy RMS outputs. | `Project matlab/simulink/Screenshot 2026-02-05 213541.png` | `outputs/figures/thesis_manual_captures/Fig4_9_busB2_B3_healthy_rms_outputs.png` | 1.000 | 0 | identical bytes | EXACT MATCH |

The four scope captures (Fig 4.6–4.9) are visually similar to one another, so each assignment was
additionally confirmed to be **byte-identical** to its thesis image and to strictly out-score the
nearest runner-up before being accepted. See `sheet4_recovered_manual_figures.png`.

---

_All similarity scores are reproducible by re-running the audit script. No image was deleted; unused
figures were moved (not removed) under `outputs/figures_unused/`, and recovered figures were **copied**
from the project folder (originals untouched) into `outputs/figures/thesis_manual_captures/`._