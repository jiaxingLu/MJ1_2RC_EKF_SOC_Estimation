# EXT2 analysis-source snapshots

This directory contains the **final reviewed MATLAB analysis-source snapshots**
used during EXT2 dynamic-parameter adaptation qualification.

## Important reproducibility boundary

These files are published for:

- methodological inspection;
- equation / threshold review;
- auditability of the EXT2 evidence chain; and
- preservation of the final analysis logic.

They are **not advertised as clone-and-run reproduction scripts**.

The original EXT2 workflow was executed in a dedicated working tree with:

- historical experimental data that are not fully distributed in this repository;
- intermediate MAT bundles generated sequentially by earlier EXT2 stages;
- local provenance/audit assets; and
- stage-specific AUTODOC output directories.

Machine-specific paths in these public copies have therefore been replaced by
placeholders such as:

- `<REPO_ROOT>`
- `<EXT2_WORK_ROOT>`
- `<WORK_PACKAGE_ROOT>`
- `<LOCAL_DATA_ROOT>`
- `<LEGACY_HPPC_SOURCE>`
- `<PYTHON_EXECUTABLE>`

Replacing those placeholders alone does not guarantee full reproduction,
because some upstream raw/provenance inputs are intentionally not distributed.

## Version policy

Only the final reviewed executable version of each public EXT2 MATLAB stage is
included where practical. Failed implementation drafts such as the superseded
C1/C1A first attempts are intentionally excluded.

## B1-2J provenance audit

`EXT2_B1_2J_RUN_v1.m` and `EXT2_B1_2J_model_metadata_v1.m` are preserved as
public orchestration / metadata snapshots.

The full B1-2J provenance workflow also relied on local Python audit stages,
protected-baseline/addendum files, and historical source records that are not
presented here as a standalone reproduction package.

The public scientific result of B1-2J is therefore the reviewed evidence
snapshot under:

`results/extension_track2/B1_2J/`

Its final status remains:

`HPPC_SOC_PROVENANCE_INCONCLUSIVE`

## Scientific claim boundary

EXT2 does not introduce a new released continuous dynamic-parameter updater.

The final qualification is:

- gated Bayesian `R0`: qualified within released v1.0 scope;
- `R1/tau1`: continuous online adaptation not qualified;
- `R2/tau2`: continuous online adaptation not qualified / closed;
- simultaneous dynamic4 adaptation: not qualified;
- HPPC pulse+relaxation: future event-based / batch re-identification candidate.