# Extension Track 1 evidence

This directory contains reviewed evidence for the **K=4 rolling-posterior extension candidate**.

The extension is **closed as a frozen candidate** and is **not an independently validated v1.1 release**.

## Recommended public evidence set

The working closeout manifest hashes the complete evidence set. The most important public files are:

- `EXT1_rolling_K4_shadow_candidate_v1.csv` — K=4 selection snapshot from the finite-memory sweep.
- `EXT1_K4_native_integration_fast_parity_v1.csv` — integrated A/B/C parity.
- `EXT1_K4_native_integration_negative_fallback_v1.csv` — gate-closed fallback equivalence.
- `EXT1_K4_sensor_bias_closed_loop_stress_v1.csv` — predeclared sensor-bias qualification; verdict remains FAIL.
- `EXT1_v1_vs_K4_matched_sensor_bias_v1.csv` — matched v1/K4 current- and voltage-offset comparison.
- `EXT1_v1_vs_K4_current_bias_output_impact_summary_v1.csv` — output-impact interpretation of current-offset sensitivity.
- `EXT1_EXP0037_holdout_salvage_audit_v1.csv` — evidence that the archived candidate is the same physical development run.
- `EXT1_nested_LOCO_K_selection_v1.csv` — internal leave-one-condition-out selection stability.
- `EXT1_K4_fine_SOC_bins_v1.csv` — 5-percentage-point SOC localization.
- `EXT1_conditional_local_alpha_oracle_v1.csv` — fixed-state conditional-alpha oracle.
- `EXT1_shadow_vs_EKF_local_target_divergence_summary_v1.csv` — shadow-to-EKF target divergence.
- `EXT1_alpha_mismatch_voltage_leverage_summary_v1.csv` — voltage-leverage attribution.
- `EXT1_residual_correction_geometry_v1.csv` — exact per-bin SSE cross/quadratic decomposition.
- `EXT1_residual_correction_geometry_summary_v1.csv` — compact high-SOC geometry summary.
- `EXT1_K4_closeout_evidence_manifest_v1.csv` — SHA-256 closeout manifest.
- `EXT1_K4_final_closeout_snapshot_v1.txt` — final evidence-lock snapshot.

## Interpretation

The aggregate K=4 result is positive on A/B and on the Case-C sensitivity range, but Case C contains sustained high-SOC local regression from approximately 55% SOC.

The final mechanism investigation attributes this mainly to excessive realized correction energy relative to the residual-cancellation benefit, especially alpha-layer over-correction over approximately 60–75% SOC.

For the complete claim boundary, see:

`docs/validation/ext1_k4_candidate_closeout.md`
## Public-path sanitization

Repository copies of path-bearing evidence use repository-relative or
archive-relative paths instead of workstation-specific absolute paths.
This changes only path metadata; numerical results, source-data SHA-256
identifiers, model-selection results, and scientific verdicts are unchanged.

The public closeout manifest is regenerated after this sanitization so its
SHA-256 entries refer to the bytes actually published in this repository.
