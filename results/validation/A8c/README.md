# Validation data

Numerical results and supporting records for the [validation report](../../../docs/validation/A8c_validation_report.md).

| File group | Contents |
|---|---|
| `A7a_EKF_regression.csv`, `A7a_TD_summary.csv`, `A7a_candidate_scales.csv` | Candidate-performance comparisons and applied parameter scales |
| `A7a_execution_status.csv` | Candidate-test execution status |
| `A8a_baseline_metrics.csv`, `A8a_regression_checks.csv`, `A8a_status.csv` | Baseline metrics and reproducibility checks |
| `A8b_signal_checks.csv`, `A8b_summary.csv`, `A8b_trace.csv`, `A8b_status.csv` | MATLAB-Simulink output comparisons |
| `A8c_holdout_reference.csv` | Reference time, current, voltage, and SOC arrays |
| `A8c_scope_and_settings.json` | Test definitions and numerical tolerances |
| `A8c_archived_input_fingerprints.csv`, `A8c_provenance.json` | Source identities and archive provenance |
| `A8c_package_manifest.json` | Current documentation and evidence file hashes |
| `A8c_package_manifest_original.json` | Original manifest retained for the earlier documentation edition |

The original numerical CSVs and machine-readable statuses are unchanged by the documentation revision. `pp` denotes percentage points; `mOhm` denotes milliohms. Implementation differences, voltage errors, and SOC errors are separate quantities.

To verify the current archive, run `python tools/verify_a8c_evidence.py` from the repository root. The original manifest is a historical provenance record; use the active manifest for current file verification.
