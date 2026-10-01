# A7a fixed-candidate decision / 固定候选采用决定

[Main validation report](A8c_validation_report.md) · [中文报告](A8c_validation_report_zh.md)

## Decision

**Do not adopt `Tau2FixedR2` as the default. Retain the original baseline and preserve the candidate as an offline diagnostic. No online adaptation is enabled by this archive.**

The decision concerns a fixed candidate in the existing data and estimator configuration. It does not establish that all adaptive algorithms are ineffective.

## Parameter meaning and comparison design

`R2` is held fixed; `C2_candidate = s × C2_baseline`, so `tau2_candidate = s × tau2_baseline`. This does not increase charge capacity. All other lookup-table parameters remain unchanged.

For time-domain checks, the 0.2C+0.3C pair receives the scale trained on the 0.3C+0.7C pair, and conversely. The secondary 0.4C+0.6C pair receives the pooled-primary scale. Within each record, baseline and candidate are compared using the same eligible cycles. In the separate EKF regression, pooled-primary scales are used; coordinate names in EKF version labels denote the **scale source**, not a new SOC-reference definition. See [applied scales](../../results/validation/A8c/A7a_candidate_scales.csv).

## End-anchored primary time-domain evidence

| Pair | Frequency label | Common cycles | Applied scale | Baseline [mΩ] | Candidate [mΩ] |
|---|---|---|---|---|---|
| 0.2C + 0.3C | 10tau | 14 | 1.473002 | 5.624399 | 5.105731 |
| 0.2C + 0.3C | 1tau | 155 | 1.473002 | 1.830484 | 2.812176 |
| 0.3C + 0.7C | 10tau | 9 | 1.450606 | 4.329118 | 2.562023 |
| 0.3C + 0.7C | 1tau | 91 | 1.450606 | 0.928536 | 1.725752 |

Units in the last two columns are complex-response RMSE, not terminal-voltage RMSE or SOC error. The two primary pairs improve at 10τ and deteriorate at 1τ in all three coordinate interpretations. The secondary case does not have identical behavior and remains separately labelled in the original summary.

Source: [all 18 time-domain summary rows](../../results/validation/A8c/A7a_TD_summary.csv). The original `Screen` field checks only complex-response and raw-voltage changes; it is not an all-metric acceptance certificate.

## Existing EKF regression

For correct initialization and the pooled end-anchored scale near 1.459015, SOC RMSE changes from **2.445155 to 2.495851 pp**, while posterior-voltage RMSE changes from **10.181881 to 9.091244 mV**. Across nine candidate-scale/initialization combinations, SOC RMSE increases approximately **0.0407–0.0507 pp**, while posterior-voltage RMSE decreases.

These are small SOC changes on deterministic replays of one reference record, not nine independent experiments or a statistical-significance claim. They provide no demonstrated SOC benefit to offset the primary 1τ performance cost. No post-hoc loosening of a tolerance is used to convert the result into adoption.

Source: [A7a EKF regression](../../results/validation/A8c/A7a_EKF_regression.csv).

## 中文结论

慢时间常数修正具有跨配对的低频／差分指标收益，但没有保持两个主要配对的 1τ 表现，也没有改善原有 EKF 留出段的 SOC 指标。故不替换默认参数，不为了增加“在线自适应”标签继续放宽标准。终点锚定表仅用于展示，不代表它已被证明为真实 SOC 坐标。
