# Model selection: slow-branch time-constant correction

[Project overview](../../README.md) · [Validation report](A8c_validation_report.md)

## Result

The original parameter mapping is retained. A fixed increase in the slow-branch time constant improved selected low-frequency response metrics but did not improve performance across both primary excitation frequencies and the existing SOC-estimation benchmark.

## Candidate definition

The candidate holds `R2` fixed and sets `C2_candidate = s * C2_baseline`, giving `tau2_candidate = s * tau2_baseline`. This changes the branch dynamics without changing its steady-current resistance or the model reference capacity. Other lookup-table parameters remain unchanged.

In the time-domain comparison, the 0.2C+0.3C pair uses the scale fitted on 0.3C+0.7C, and conversely. The secondary 0.4C+0.6C pair uses the pooled-primary scale. Baseline and candidate share the same eligible cycles within each comparison. The separate EKF regression uses pooled-primary scales. Its coordinate labels identify the scale source, not a redefinition of the EKF SOC reference.

Source: [applied scales](../../results/validation/A8c/A7a_candidate_scales.csv).

## Cross-pair dynamic response

The following results use the end-anchored coordinate. The last two columns are complex-response RMSE, not terminal-voltage error.

| Excitation pair | Frequency label | Common cycles | Applied scale | Baseline [mOhm] | Candidate [mOhm] |
|---|---|---:|---:|---:|---:|
| 0.2C + 0.3C | 10tau | 14 | 1.473002 | 5.624399 | 5.105731 |
| 0.2C + 0.3C | 1tau | 155 | 1.473002 | 1.830484 | 2.812176 |
| 0.3C + 0.7C | 10tau | 9 | 1.450606 | 4.329118 | 2.562023 |
| 0.3C + 0.7C | 1tau | 91 | 1.450606 | 0.928536 | 1.725752 |

Both primary pairs improve at 10tau and deteriorate at 1tau under all three SOC-coordinate interpretations. The secondary pair behaves differently and is reported separately rather than pooled with the primary evidence. The end-anchored table is a representative view, not a demonstration that this coordinate is true SOC.

Source: [time-domain results](../../results/validation/A8c/A7a_TD_summary.csv). The original `Screen` field checks only complex-response and raw-voltage changes, not all recorded metrics.

## SOC-estimator regression

For correct initialization and the pooled end-anchored scale of approximately 1.459015:

| Metric | Baseline | Candidate |
|---|---:|---:|
| SOC RMSE [pp] | 2.445155 | 2.495851 |
| Posterior-voltage RMSE [mV] | 10.181881 | 9.091244 |

Across nine candidate-scale/initialization combinations, SOC RMSE increases by approximately 0.0407-0.0507 pp while posterior-voltage RMSE decreases. These combinations replay one reference record; they are not independent experiments or evidence of statistical significance.

Source: [EKF regression results](../../results/validation/A8c/A7a_EKF_regression.csv).

## Selection outcome

The candidate provides a frequency-dependent trade-off rather than a general improvement. No SOC benefit was demonstrated to offset the primary 1tau performance cost. It remains an offline diagnostic result and is not applied to the default estimator. This outcome concerns the tested candidate and data; it is not a general conclusion about adaptive estimation.
