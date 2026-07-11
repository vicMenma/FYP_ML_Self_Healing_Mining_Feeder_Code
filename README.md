# ML-Assisted Self-Healing Protection of a 33/11 kV Mining Distribution Feeder

MATLAB/Simulink code and result archive for the BEng (Electrical Engineering) final-year
thesis:

> **Simulation-Based Design and Evaluation of a Machine Learning-Assisted Self-Healing
> Protection Scheme for a 33/11 kV Mining Distribution Feeder**
> Victoire Chinyanta Chimundu (CU-BEE-100-7229) — Copperstone University, 2026
> Supervisor: Mr Charles Kasonde

This repository is the reproducibility archive cited in **Appendix A** of the thesis. It contains
the Simulink model, the MATLAB pipeline scripts, the labelled dataset, the trained classifier, the
live-simulation waveform data, and every final thesis figure and result summary.

> **Academic and safety notice.** This is an academic archive for a *simulation-based*
> proof-of-concept. It is **not** a certified protection-relay package and must not be used to
> control live electrical infrastructure. Practical use would require relay-setting review,
> hardware-in-the-loop testing, protection-coordination studies, cybersecurity assessment, site
> acceptance testing, and approval by competent protection engineers.

---

## What the project does

A five-bus 33/11 kV radial mining feeder is modelled in MATLAB R2024a Simulink (Simscape Electrical
Specialized Power Systems). A cost-sensitive Random Forest is trained on three-phase RMS voltage and
current features to identify **fault type and location** (13 classes: Healthy + SLG/LL/3PH at buses
B2–B5). The prediction then drives a deterministic, auditable **selective-isolation and tie-switch
restoration** policy. Every switching decision in the evaluation is driven by the classifier
prediction computed from the pre-switch measurements — a genuine closed detection→isolation→
restoration loop.

### Headline results (controlled simulation)

| Result | Value |
|---|---|
| Test-set classification accuracy | 100.00 % (200/200) |
| Out-of-bag error @ 500 trees | 0.00 % |
| Five-fold cross-validation | 100.00 % ± 0.00 % |
| Correct fault-zone prediction (restoration suite) | 12 / 12 |
| Faulted zone isolated | 12 / 12 |
| Tie held open for terminal (B4/B5) faults | 6 / 6 |
| Restoration-eligible cases restored | 6 / 12 (B2, B3) |
| Post-restoration voltage (eligible cases) | 0.963 – 0.981 pu (within 0.95–1.05) |

The 100 % figure is a **controlled-simulation feasibility result** under near-bolted fault
assumptions and ideal sensors — not field-validated performance. See the thesis for the full
limitations (NER-limited earth faults, discrete parameter grid, ideal sensors, no hardware/field
validation).

---

## Repository structure

```
src/                                   MATLAB scripts and the Simulink model
  mining_feeder_layer_FINAL_baseline.slx
  MASTER_A_PREFLIGHT_AND_DATASET.m     SLG grounding pre-flight + 1000-sample dataset
  MASTER_B_TRAIN_AND_RESTORE.m         cost-sensitive RF training + closed-loop restoration
  MASTER_C_GENERATE_ALL_FIGURES.m      regenerates all thesis figures from stored outputs
  RUN_ALL_PIPELINE.m                   full pipeline with stage control + smoke test
outputs/
  dataset/    fault_dataset_v2.{csv,xlsx,mat}   1000 samples x 24 features, 13 classes
  model/      rf_model_v2.mat + confusion/oob/cv/feature-importance mats
  waveforms/  wave_{SLG,LL,3PH}_B{2..5}.mat      12 live-sim fault+restoration captures
  figures/    chapter_3 .. chapter_6              final thesis figures + figure_manifest.csv
  summaries/  block discovery, SLG pre-flight, RF metrics, restoration summary/results, pipeline log
```

## Key model parameters

| Item | Value |
|---|---|
| Source | 33 kV, 50 Hz, 500 MVA SC, X/R = 10 |
| Transformer T1 | 20 MVA, 33/11 kV, Dyn11, ≈8 % Z |
| Transformer T2 (auxiliary) | 15 MVA, 33/11 kV, Dyn11, ≈8 % Z |
| Loads (B2/B3/B4/B5) | 1.95 / 2.60 / 3.25 / 2.145 MW (unity pf) |
| Faults | SLG (A-g), LL (A-B), 3PH; R_on 0.001–5.0 Ω; R_g 0.001 Ω |
| Solver | powergui Discrete, 5 µs (200 kHz), 2.0 s/run |
| Classifier | Random Forest, 500 trees, √24 = 4 features/split, cost(fault→Healthy) = 12.5×, rng(42) |

## How to reproduce

Requires **MATLAB R2024a** with **Simulink** and **Simscape Electrical Specialized Power Systems**.
A fixed seed `rng(42)` makes the split and training repeatable.

```matlab
% from the src/ folder, in order:
MASTER_A_PREFLIGHT_AND_DATASET     % aborts if the SLG grounding pre-flight fails
MASTER_B_TRAIN_AND_RESTORE         % trains the RF, runs the closed-loop restoration
MASTER_C_GENERATE_ALL_FIGURES      % regenerates the figures
% or, end to end:
RUN_ALL_PIPELINE                   % smoke test / full pipeline with prompts
```

## License

Released under the MIT License — see [LICENSE](LICENSE).
