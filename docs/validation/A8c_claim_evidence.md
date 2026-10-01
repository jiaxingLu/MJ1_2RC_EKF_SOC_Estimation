# Validation coverage

[Project overview](../../README.md) · [Validation report](A8c_validation_report.md)

| Capability or result | Evidence | Demonstrated scope |
|---|---|---|
| Baseline reproducibility | [40 regression checks](../../results/validation/A8c/A8a_regression_checks.csv) | Reproduction of the archived MATLAB baseline |
| MATLAB-Simulink output agreement | [15 signal checks](../../results/validation/A8c/A8b_signal_checks.csv), [comparison traces](../../results/validation/A8c/A8b_trace.csv) | One 1 s constant-current record with 0/-20/+15 pp initial SOC offsets |
| Reference-SOC RMSE of 2.445 pp with correct initialization | [Baseline metrics](../../results/validation/A8c/A8a_baseline_metrics.csv) | Error relative to the Coulomb-counting reference on that record |
| Dynamic-response candidate evaluation | [Time-domain comparisons](../../results/validation/A8c/A7a_TD_summary.csv) | Given-coordinate forward-model response at the recorded excitation frequencies |
| Original parameter mapping retained | [Model-selection analysis](A8c_candidate_decision.md) | The tested slow-time-constant candidate did not provide a general performance improvement |
| File identity | [Source fingerprints](../../results/validation/A8c/A8c_archived_input_fingerprints.csv), [baseline provenance](A8c_repository_integration.md) | Listed source artifacts and snapshots only |

## Interpretation

Numerical agreement between implementations is distinct from physical SOC accuracy. The results are tolerance-based rather than bitwise identical. A near-zero endpoint error is not used as a convergence claim because the estimator reaches its lower SOC bound.

## Not evaluated by the archived runtime comparison

| Area | Boundary |
|---|---|
| Variable-current timing | A constant-current record cannot distinguish every previous/current-input indexing error |
| Complete internal-state agreement | Both RC states and the full covariance matrix were not directly compared |
| Independent SOC accuracy | The reference uses the existing Coulomb-counting definition |
| Dynamic DC-AC SOC estimation | Forward-model response checks do not establish EKF SOC accuracy under those conditions |
| Online parameter adaptation | No recursive parameter estimator is enabled |
| Generalization and deployment | Other cells, temperatures, aging states, nonuniform sampling, and hardware execution require separate tests |

The coverage table describes the supplied evidence, not a performance specification for untested operating conditions.
