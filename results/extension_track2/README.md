# EXT2 curated public evidence snapshot

This directory contains a **curated human-readable subset** of the final EXT2
evidence.

The public snapshot prioritizes:

- CSV summaries;
- TXT reports;
- diagnostic figures; and
- final closeout tables.

Large/internal MAT bundles, private raw experimental records, protected-asset
audit internals, and development handoff files are intentionally excluded.

## Path redaction

Machine-specific local paths in public text evidence were replaced by aliases
such as:

- `<LOCAL_DATA_ROOT>`
- `<REPO_ROOT>`
- `<EXT2_WORK_ROOT>`
- `<LEGACY_HPPC_SOURCE>`

This redaction changes only machine-location strings.

It does **not** intentionally change:

- numerical measurements;
- SHA-256 source identities;
- SOC labels;
- current / voltage values;
- Ah integrals;
- pass/fail classifications; or
- scientific conclusions.

## Evidence groups

- `B1_2H/` — independent low-rate charging-baseline correction validation
- `B1_2I/` — confounder-controlled `R2/tau2` target-consistency re-audit
- `B1_2J/` — HPPC SOC-label provenance audit
- `C1/` — full 1C trajectory charging-baseline transfer
- `C1A/` — SOC-axis sensitivity audit
- `CLOSEOUT/` — final adaptation qualification and claim-boundary tables

See:

`docs/validation/ext2_dynamic_parameter_adaptation_closeout.md`

for the public technical narrative and final claim boundaries.