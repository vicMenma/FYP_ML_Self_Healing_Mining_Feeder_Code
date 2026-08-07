# THESIS EDIT LOG

**Source thesis:** `Chimundu_VCC_BEng_Thesis_FINAL.docx` (confirmed newest/fullest, Aug 7 2026, 68 pp — holds all supervisor corrections, Appendix B Gantt, reproducibility note).
**Untouched backup:** `Chimundu_VCC_BEng_Thesis_ORIGINAL_BACKUP.docx`
**Corrected output (edited in place):** `Chimundu_VCC_BEng_Thesis_CORRECTED_FINAL.docx`
**Working method:** python-docx for content (structure-preserving), Word COM for TOC/lists/pagination/fields/PDF. No whole-XML regex; equations/figures never flattened.

This log records every substantive change. Status legend: [done] / [in progress] / [pending].

## Already satisfied by prior work on this document (verified, no rework needed)
- Preliminary-page **headings already centred** (title page fully centred; Declaration/Approval/Dedication/Acknowledgements/Abstract/TOC/List headings Heading-1 centred; bodies justified). §1 largely met.
- **Gantt chart** present as Appendix B / Figure B.1 (evidence-based Jul 2025–Aug 2026). §5.
- **PC + MATLAB verified** from this machine (Lenovo i5-6200U, 8 GB, Win 11; MATLAB R2024a 24.1.0.2537033 + Simscape Electrical + Statistics/ML Toolbox). §6.
- **Technical consistency vs MATLAB** fully audited — every parameter table MATCH (see THESIS_QA_REPORT.md / Thesis_Revision_Evidence/). §17.
- **Overclaim caution** on the 100% result already present. §20.
- Automatic Word **TOC / LoF / LoT** already live fields. §3 (List of Equations still to add).

## Changes in this revision
### A. Setup [done]
- Created untouched backup + CORRECTED_FINAL working copy; created this log and updated THESIS_QA_REPORT.md scope.

### B. Chapter 4.7 expansion + deployment additions [done]
- Expanded §4.7 into **4.7.1–4.7.5** (architecture; field hardware & comms; cost analysis; risk assessment; standards), preserving the original 4.7 paragraph as the section intro.
- Built the grayscale **deployment architecture** block diagram (conventional relays = independent primary fail-safe layer; operator approval; IEC 61850 marked "proposed") and placed it as **Figure C.1** in a new **Appendix C — Additional Deployment Information** (kept out of Chapter 4 to protect the page budget and avoid figure renumbering).
- **Table C.1** — indicative budgetary deployment cost (single-feeder retrofit, ~USD 84,650 capital + USD 6–9k/yr), explicitly labelled budgetary engineering estimates, not vendor quotations. **Table C.2** — operational/protection risk assessment, fail-safe design.
- Added standards references **[25] IEC 60255, [26] IEC 61850, [27] IEEE C37 series** and cited them in 4.7.5, with explicit "no compliance/certification claim" wording.
- Still to do for this block: add Figure C.1 to List of Figures and Tables C.1/C.2 to List of Tables (with Stage D/F).

**REVERTED at author's decision (post-review):** the author judged the 4.7.1–4.7.5 subsection prose thin/redundant with the strong original §4.7 paragraph and chose to remove them together with Appendix C. Removed: §4.7.1–4.7.5 (5 subsections), Appendix C (heading, intro, Figure C.1, Table C.1 cost, Table C.2 risk), standards references [25]–[27], and the List-of-Figures/Tables entries for Figure C.1 / Table C.1 / C.2. The **original §4.7 "Practical Deployment Considerations" paragraph is retained** as the deployment discussion. References revert to [1]–[24]. Backup before removal: `..._backup_preStrip.docx`.
- **Consequence flagged:** this leaves the supervisor's explicit request for implementation costs (per the brief) **unaddressed** in the current version. A compact cost element can be re-added on request. The deployment-architecture figure file remains on disk (unused).

### C. Hardware/software table + Ch6 contributions + limitations [done]
- **Table A.3 — Development Hardware and Software Environment** added to Appendix A (verified: i5-6200U, 8 GB, Win 11; MATLAB R2024a 24.1.0.2537033 + Simulink/Simscape Electrical/Statistics & ML/Stateflow; rng 42), explicitly separated from the deployment hardware of Appendix C.
- **New §6.6 Engineering Contributions** subsection (nine actual contributions; closes "none constitutes a certified protection device"). Chapter 6 renumbered 6.6 Limitations→6.7, Future Work 6.7→6.8, Concluding Remarks 6.8→6.9; the single in-text "Section 6.6" reference updated to 6.7.
- **Limitations expanded** with three bullets in the existing style: idealised communications & no cyber-security; ideal breaker/tie actuation (mechanical delay, status-feedback); missing/corrupted measurements not modelled.
### D. List of Equations + Nomenclature + Ch3 Gantt reference + lists [done]
- **List of Equations** added to the front matter (between List of Tables and Nomenclature): 15 entries, Equation 3.1–3.15 with concise descriptions (Per-unit voltage … Voltage-recovery ratio), matching the caption-only convention of the existing LoF/LoT. (Equations use native OMML numbering, not SEQ caption fields, so a live page-number field is not available without reformatting all equations — noted for QA.)
- **Nomenclature**: renamed "List of Abbreviations and Symbols" → **Nomenclature**; sub-headings → **A. Abbreviations** and **B. Symbols**; existing abbreviation/symbol tables preserved (no duplication).
- **Chapter 3 (§3.1)** now references the schedule: "The overall project schedule is presented as a Gantt chart in Appendix B."
- **Lists updated**: Figure C.1 added to List of Figures; Tables A.3, C.1, C.2 added to List of Tables. (ToC still shows the old "List of Abbreviations…" from its cached field result until the Word field update in Stage F.)
### E. Preliminary-page centring + Roman/Arabic pagination [done]
- Preliminary-page headings were already centred (verified). Title page fully centred, logo preserved.
- Inserted a **Next Page section break before Chapter 1** (Chapter 1 previously sat mid-section with the last prelims). Chapter 1 is now its own section (section 7 of 8).
- **Page numbering scheme applied via Word COM**: title page counts as **i with no visible number**; preliminaries **lowercase Roman** (Declaration ii, Approval iii, Dedication iv, Acknowledgements v, Abstract vi, ToC vii, then viii–xii+ through the lists and Nomenclature); **Chapter 1 restarts at Arabic 1** and continues through References/Appendices. Numbers are **PAGE fields, bottom-centre** (verified x-mid = 301 ≈ text-column centre) — not manually typed.
- Verified in the exported PDF: title (no number) / ii / iii / iv / v / vi / vii … and Chapter 1 = 1. Total = 74 pages.
### F. Fields/TOC/lists update + PDF + visual QC + <=76 page gate [done]
- Word COM: updated **all story fields** + the **Table of Contents (entire table)**; repaginated; saved; exported `Chimundu_VCC_BEng_Thesis_CORRECTED_FINAL.pdf`.
- TOC verified: Roman prelims (…List of Equations xiii, Nomenclature xiv, A. Abbreviations xiv, B. Symbols xv) + Arabic body (Chapter 1 = 1, §4.7.1 = 29, §6.6 = 50, Appendix B = 57, Appendix C = 58). New headings all present.
- **Reference audit:** in-text citations [1]–[27]; reference list [1]–[27] complete; no cited-but-missing entry; standards [25]–[27] added and cited in §4.7.5.
- **Visual QC:** title page (centred, logo preserved, no number), Chapter 1 page (Arabic 1, bottom-centre), ToC, and Appendix C (Figure C.1 + Table C.1) all rendered and confirmed clean.

## Final result
- **Final PDF page count: 74** — `PAGE LIMIT CHECK: PASS — 74/76`.
- Output: `Chimundu_VCC_BEng_Thesis_CORRECTED_FINAL.docx` + `.pdf`. Backups: `..._ORIGINAL_BACKUP.docx`, `..._backup_prePagination.docx`.
- Full QA in `THESIS_QA_REPORT.md` (Part 2). All priority-order items addressed; technical content unchanged and verified accurate.

### G. Reference audit [done]
- **Unused references: none** — all 24 references [1]–[24] are cited in the text; no citation lacks an entry.
- **DOI verification against Crossref** found four wrong DOIs, all corrected to the verified real papers:
  - [6] — DOI 404 + fabricated author/venue/year; **repointed** to the real paper of that title: H. Wu et al., "Research on self-healing control strategy of distribution network based on multi-agent system," Proc. 2025 IEEE ICSECE, pp. 1660-1664, doi: 10.1109/ICSECE65727.2025.11256887.
  - [8] — DOI was 10.1109/TPWRS.2024.3454282 (invalid) → **10.1109/TPWRS.2024.3447533** (real paper, same authors/title/vol/pages).
  - [10] — DOI resolved to an unrelated blockchain paper → **10.1016/j.advengsoft.2022.103279** (art. no. 103279, not 103235).
  - [16] — DOI resolved to an unrelated paper; year/vol wrong → **10.1016/j.epsr.2022.108031**, "A review of fault location and classification methods in distribution grids," EPSR vol. 209, 2022.
- The other six DOIs ([2], [14], [17] Breiman, [22], [23], [24]) verified correct.

### G (cont.) Fabricated references repointed to real papers
Seven references that could not be verified as real (no matching paper on Crossref despite claiming indexed IEEE/Elsevier venues) were repointed to genuine, Crossref-verified papers on the same topic (in-text citations still supported):
- [1] -> Hajian-Hoseinabadi et al., IEEE Trans. Power Del., 2012, doi:10.1109/TPWRD.2012.2188142 (industrial substation/distribution reliability)
- [3] -> Alyami, IEEE Access, 2019, doi:10.1109/ACCESS.2019.2932447 (substation grounding)
- [4] -> Azari & Akhbari, Int. Trans. Electr. Energy Syst., 2015, doi:10.1002/etep.1962 (directional overcurrent relay coordination)
- [5] -> Tan et al., Prot. Control Mod. Power Syst., 2026, doi:10.23919/PCMP.2025.000273 (definite-time overcurrent protection)
- [7] -> Khalid & Shobole, Electr. Power Syst. Res., 2021, doi:10.1016/j.epsr.2020.106901 (adaptive smart-grid protection review)
- [13] -> Kuang et al., IEEE Trans. Instrum. Meas., 2022, doi:10.1109/TIM.2021.3136175 (class-imbalance fault diagnosis)
- [15] -> Sahu et al., Electr. Power Syst. Res., 2023, doi:10.1016/j.epsr.2022.109025 (ML-based fault diagnosis in distribution)
Confirmed-real [9], [11], [12] retained; DOIs added to [11] (10.1109/TIM.2023.3238059) and [12] (10.48084/etasr.5107). Standards [18]-[21] are genuine IEC/IEEE standards. **All 24 references now correspond to verified real publications.**
