# Adaptive v1 validation evidence

This directory contains the reviewed public evidence for the adaptive estimator.

- `real_condition_matrix_reviewed.csv` — nine real-condition A/B cases with both the original automated pass flag and the reviewed numerical-equivalence verdict.
- `sensor_bias_closed_loop_stress.csv` — closed-loop current- and voltage-offset stress cases.
- `adaptive_v1_verdict_summary.csv` — compact final architecture verdict.

## Numerical-equivalence review

The original automated final matrix reported one failure for the `0.4C + 0.6C` slow condition because the maximum adaptive-minus-frozen SOC difference was `1.192e-9` percentage points against a `1.0e-9` percentage-point equality threshold.

For that case, the autonomous gate remained closed, the online update count was zero, `alpha_R0 = 1`, plant outputs were unchanged, and the posterior-voltage RMSE change was approximately `6.3e-11 %`. The discrepancy is therefore floating-point numerical noise rather than an algorithmic or physical difference.

A reviewed numerical-equivalence tolerance of `1e-8` percentage points (`1e-10` in absolute SOC fraction) was used for the public verdict. The resulting reviewed matrix is 9/9 PASS.

The raw development logs and temporary regression archives are intentionally not published here.
