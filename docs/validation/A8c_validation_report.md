# MJ1 2RC–EKF: validation scope and archived evidence

[中文报告](A8c_validation_report_zh.md) · [Candidate decision](A8c_candidate_decision.md) · [Reproduction guide](A8c_reproduction.md) · [Claim–evidence matrix](A8c_claim_evidence.md)

## Outcome

The original SOC-dependent two-RC EKF remains the default baseline. The archived A8b test passed output-parity tolerances between the MATLAB implementation and the saved Simulink observer for **one 1 s, −3.4 A constant-current discharge record and three initial-SOC conditions**. The fixed `Tau2FixedR2` candidate was not adopted as the default; online parameter updating was not enabled. The archived deployment status remains `NOT_RELEASED`.

Publishing this validation record is not a production-release decision. This directory is an evidence addition to `MJ1_2RC_EKF_SOC_Estimation`, not a replacement implementation or a new model version. Source status files are retained unchanged: A8a's static-only status precedes A8b's runtime test.

Sources: [A8a status](../../results/validation/A8c/A8a_status.csv), [A8b status](../../results/validation/A8c/A8b_status.csv), [A7a candidate evidence](A8c_candidate_decision.md).

## Test specification

| Item | Archived definition |
|---|---|
| State order | `[v1, v2, SOC]`; voltages in V and SOC as a fraction |
| Current sign | Positive charge, negative discharge |
| Reference capacity | 3.335 Ah |
| Frozen LUT SOC interval | 17–85% |
| Input record | 1165 points, 0–1164 s, fixed 1 s spacing, −3.4 A |
| Reference SOC | Approximately 49.988339% → 17.024821%; Coulomb-counting based |
| Initial offsets | 0, −20 and +15 percentage points relative to the same initial reference |
| Outputs compared | SOC, posterior terminal voltage and voltage innovation |
| Inputs compared | Logged current and measured terminal voltage |
| First sample | Initialized output, not a measurement correction; retained in the comparison |
| Scope of runtime | Normal Simulink simulation; no output interpolation, time shift or first-sample removal |

The three initializations reuse one record. They are not independent experiments. The MATLAB environment archived with A8a is `25.2.0.3055257 (R2025b) Update 2` on `PCWIN64`. Cross-platform numerical identity is not established. Exact settings and provenance are recorded in [scope and settings](../../results/validation/A8c/A8c_scope_and_settings.json) and [provenance](../../results/validation/A8c/A8c_provenance.json).

## Numerical implementation parity

The preceding A8a audit recorded **40/40 passed baseline-reproduction checks**. A8b recorded **15/15 passed signal checks**: five signals for each initial condition. Runtime maxima are shown below; re-reading decimal CSV exports may change only their last reported digits.

| Initial case | Max SOC difference [pp] | Max posterior-voltage difference [mV] | Max innovation difference [mV] |
|---|---|---|---|
| correct_init | 7.616e-12 | 1.625e-10 | 1.563e-10 |
| minus20pp | 6.043e-10 | 5.422e-09 | 5.315e-09 |
| plus15pp | 7.250e-11 | 1.230e-10 | 1.208e-10 |

The prespecified output-parity tolerances were `1e-6 pp` for SOC and `1e-5 mV` for posterior voltage and innovation; the time-alignment tolerance was `1e-9 s`. These are numerical reproduction tolerances, not measurement uncertainty or battery accuracy targets. All recorded time differences and both input-signal differences were zero. The outputs agree within tolerance, not bit-for-bit.

Sources: [A8a checks](../../results/validation/A8c/A8a_regression_checks.csv), [A8b signal checks](../../results/validation/A8c/A8b_signal_checks.csv), [A8b summary](../../results/validation/A8c/A8b_summary.csv). The [comparison trace](../../results/validation/A8c/A8b_trace.csv) contains both implementations at every archived sample.

## Estimation error is a different quantity

Implementation difference compares `SOC_Simulink − SOC_MATLAB`. Estimation error here compares `SOC_estimated − SOC_reference`, where the reference is the existing Coulomb-counting definition. Very small implementation differences do not reduce the latter error.

| Initial case | Initial SOC [%] | SOC RMSE vs reference [pp] | Posterior voltage RMSE [mV] |
|---|---|---|---|
| correct_init | 49.988339 | 2.445155 | 10.181881 |
| minus20pp | 29.988339 | 2.508752 | 10.925093 |
| plus15pp | 64.988339 | 2.455045 | 11.186954 |

Each trajectory contains **34 samples at the 17% SOC lower bound**. A final error near −0.024821 pp therefore cannot serve as independent evidence of unconstrained convergence. First-sample initialization error remains included in full-record SOC metrics.

Sources: [baseline metrics](../../results/validation/A8c/A8a_baseline_metrics.csv), [Simulink summary](../../results/validation/A8c/A8b_summary.csv), [exported original reference](../../results/validation/A8c/A8c_holdout_reference.csv).

## Candidate-parameter decision

A7a examined a fixed increase of the slow-branch time constant, keeping `R2` fixed and scaling `C2`. The archived replay improved 10τ complex-response error on both primary pairs but worsened their 1τ response. In the original EKF regression, all nine candidate/initialization combinations increased SOC RMSE slightly while reducing posterior-voltage RMSE.

The candidate is retained as an offline diagnostic, not applied to the default baseline. This is a finding for this candidate, objective and dataset; it is not evidence that every adaptive estimator fails. See the [decision record](A8c_candidate_decision.md) for paired numbers and the distinction between time-domain scales and pooled EKF scales.

## Coverage limits

**Input timing:** constant current gives `I[k−1] = I[k]`. This test cannot distinguish certain previous/current-input indexing errors; a saved use of `IPrev` is not a variable-current runtime test.

**Internal variables:** A8b directly compared three outputs and two inputs. The complete covariance matrix and both RC state traces were not directly logged and compared between implementations.

**Physical validity and deployment:** no independent SOC ground truth, nonuniform sampling, cross-cell/temperature generalization, DC–AC EKF SOC-accuracy validation, deployment-code validation or hardware qualification is established by this runtime test. Forward-model DC–AC checks and EKF output parity are separate evidence categories.

**Archive scope:** the public addition includes processed outputs, selected reference arrays and documentation. Full model/SLX snapshots, original raw experiment files, path-containing manifests and compilation artifacts remain in the original local audit folders. Their absence here does not authorize broader claims about unarchived runs.

## Reproduction and status

Run `python tools/verify_a8c_evidence.py` from the overlay or merged repository root to verify packaged hashes, recorded check results, exported parity traces, baseline metrics and candidate-tradeoff arithmetic. This uses the Python standard library and **does not run MATLAB/Simulink**. Detailed instructions and the distinction from a fresh runtime test are in the [reproduction guide](A8c_reproduction.md).

Archive status: `DOCUMENTATION_AND_EVIDENCE_PACKAGED`. Limited runtime-parity status: `PASS_FOR_TESTED_1S_HOLDOUT_CASES`. Default candidate adoption: `NOT_ADOPTED`. Deployment release: `NOT_RELEASED`.
