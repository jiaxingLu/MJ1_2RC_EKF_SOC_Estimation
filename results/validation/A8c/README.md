# A8c numeric evidence

These files support the [public validation report](../../../docs/validation/A8c_validation_report.md). Source CSVs named `A7a_*`, `A8a_*` and `A8b_*` are copied byte-for-byte except that host-path manifests are deliberately excluded.

| File group | Role |
|---|---|
| `A7a_EKF_regression.csv`, `A7a_TD_summary.csv`, `A7a_candidate_scales.csv` | Fixed-candidate performance tradeoffs and applied scale provenance |
| `A7a_execution_status.csv` | Original A7a completion status |
| `A8a_baseline_metrics.csv`, `A8a_regression_checks.csv`, `A8a_status.csv` | Original baseline metrics and reproduction audit |
| `A8b_signal_checks.csv`, `A8b_summary.csv`, `A8b_trace.csv`, `A8b_status.csv` | Original runtime parity evidence |
| `A8c_holdout_reference.csv` | Original A8a reference arrays exported to CSV without changing samples |
| `A8c_scope_and_settings.json` | Archived test definitions; no new parameter fit |
| `A8c_archived_input_fingerprints.csv` | Original input hashes with archive-relative identities, not host paths |
| `A8c_provenance.json` | Source fingerprints, copy/export operations and exclusions |
| `A8c_package_manifest.json` | Sizes and hashes of packaged overlay files, excluding the manifest itself |

`pp` means percentage points. `mOhm` or mΩ is not interchangeable with mV. The original statuses describe successive stages: A8a is a pre-runtime baseline/static audit; A8b is the later limited-scope runtime check. Neither status is rewritten as deployment approval.
