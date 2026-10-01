# Experimental validation and implementation verification

[Project overview](../../README.md) · [Model-selection analysis](A8c_candidate_decision.md) · [Reproduction guide](A8c_reproduction.md)

## Summary

The SOC-dependent 2RC-EKF was evaluated on an experimental LG INR18650 MJ1 discharge record and implemented in both MATLAB and Simulink. The archived runtime comparison confirms agreement of the specified outputs across three initial-SOC conditions. The baseline model is retained after evaluating a fixed slow-time-constant correction against dynamic-response and SOC-estimation metrics.

## Test configuration

| Item | Specification |
|---|---|
| States | `[v1, v2, SOC]`; voltage in V, SOC as a fraction |
| Current sign | Positive charge, negative discharge |
| Reference capacity | 3.335 Ah |
| Lookup-table range | 17-85% SOC |
| Input | 1165 samples over 0-1164 s; 1 s sampling; -3.4 A |
| Reference SOC | Approximately 49.988339% to 17.024821%; Coulomb-counting based |
| Initial SOC offsets | 0, -20 and +15 percentage points |
| Outputs compared | SOC, posterior terminal voltage, voltage innovation |
| Inputs compared | Logged current and measured terminal voltage |
| Initial sample | Initialized output, retained without a measurement correction |
| Runtime | Normal Simulink simulation; no output resampling or time alignment |

The initializations reuse one experimental record. The documented runtime environment is MATLAB R2025b Update 2 on Windows 64-bit. Full settings are available in [test configuration](../../results/validation/A8c/A8c_scope_and_settings.json).

## State-estimation results

| Initial condition | Initial SOC [%] | SOC RMSE [pp] | Posterior-voltage RMSE [mV] |
|---|---:|---:|---:|
| Correct initialization | 49.988339 | 2.445155 | 10.181881 |
| -20 pp offset | 29.988339 | 2.508752 | 10.925093 |
| +15 pp offset | 64.988339 | 2.455045 | 11.186954 |

These SOC errors are relative to the existing Coulomb-counting reference. Full-record metrics include the initial error. Each trajectory contains 34 samples at the 17% lower SOC bound, so the final error of approximately -0.024821 pp is not an unconstrained convergence measure.

Sources: [baseline metrics](../../results/validation/A8c/A8a_baseline_metrics.csv), [reference arrays](../../results/validation/A8c/A8c_holdout_reference.csv).

## Implementation agreement

The baseline regression passed 40 checks. The MATLAB-Simulink comparison passed 15 signal checks: three estimator outputs and two inputs for each initial condition.

| Initial condition | Maximum SOC difference [pp] | Maximum posterior-voltage difference [mV] | Maximum innovation difference [mV] |
|---|---:|---:|---:|
| Correct initialization | 7.616e-12 | 1.625e-10 | 1.563e-10 |
| -20 pp offset | 6.043e-10 | 5.422e-09 | 5.315e-09 |
| +15 pp offset | 7.250e-11 | 1.230e-10 | 1.208e-10 |

The specified tolerances were `1e-6 pp` for SOC, `1e-5 mV` for posterior voltage and innovation, and `1e-9 s` for sample timing. Input and timestamp differences were zero. These thresholds evaluate numerical implementation agreement, not sensor uncertainty or battery-state accuracy. Decimal CSV decoding can affect the smallest reported differences without changing the pass result.

Sources: [regression checks](../../results/validation/A8c/A8a_regression_checks.csv), [signal checks](../../results/validation/A8c/A8b_signal_checks.csv), [comparison traces](../../results/validation/A8c/A8b_trace.csv).

## Parameter-selection study

A fixed candidate increased the slow-branch time constant while holding `R2` constant. In cross-pair time-domain evaluation, it reduced the primary 10-tau complex-response error but increased the primary 1-tau error. In the existing EKF benchmark, posterior-voltage error decreased while reference-SOC RMSE increased slightly across all nine candidate-scale/initialization combinations.

The original parameter mapping is therefore retained. The [model-selection analysis](A8c_candidate_decision.md) reports the applied scales, separate frequency results, and estimator trade-off. The candidate study is offline; it does not implement recursive parameter estimation.

## Coverage

The constant-current input cannot distinguish every previous/current-input indexing error because `I[k-1] = I[k]`. The runtime comparison directly checks the three outputs and two inputs, not the complete covariance matrix or both internal RC states.

The tests do not establish independent SOC ground truth, variable-step operation, temperature or aging generalization, or hardware performance. Forward-model DC-AC response tests and EKF SOC accuracy are separate evaluations. See [validation coverage](A8c_claim_evidence.md) for the evidence available for each claim.

## Data and reproduction

The [evidence directory](../../results/validation/A8c/README.md) contains original numerical exports, trace comparisons, and processed reference arrays. The archived machine-readable deployment state remains `NOT_RELEASED`; it records the scope of the original tests, not whether documentation is publicly available.

The offline checker verifies file hashes and metric arithmetic. Re-running the original MATLAB-Simulink parity test additionally requires its audit runner and full snapshot dependencies. Instructions are in the [reproduction guide](A8c_reproduction.md), with source correspondence documented in [baseline provenance](A8c_repository_integration.md).
