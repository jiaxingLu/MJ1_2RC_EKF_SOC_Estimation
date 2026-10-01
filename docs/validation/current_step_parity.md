# Variable-Current MATLAB-Simulink Implementation Check

This test extends the constant-current implementation comparison with a controlled variable-current input. Its purpose is to check sample timing and numerical parity between the MATLAB EKF reference and the saved Simulink observer. It is a **software implementation test**, not a new battery experiment and not an independent SOC-accuracy validation.

## Input schedule

The synthetic test uses a 1 s sample interval and 271 samples from 0 to 270 s. The current profile contains eight transitions:

| Time interval [s] | Current [A] | Test condition |
|---|---:|---|
| 0-30 | 0.0 | rest |
| 30-60 | -1.7 | discharge |
| 60-90 | -3.4 | deeper discharge |
| 90-120 | 0.0 | rest |
| 120-150 | +1.7 | charge |
| 150-180 | 0.0 | rest |
| 180-210 | -1.7 | discharge |
| 210-240 | +1.7 | direct discharge-to-charge reversal |
| 240-270 | 0.0 | final rest |

The voltage input is generated from an independently coded frozen-LUT 2RC forward fixture plus two deterministic sinusoidal perturbations. The perturbations are used only to prevent a trivially zero innovation sequence; they are not measured sensor noise and are not a calibrated noise model.

## Cases and comparison signals

The forward fixture starts from 55% SOC. Both EKF implementations receive the same current and voltage inputs and are evaluated with three initial SOC conditions:

- correct initialization: 55%
- -20 percentage-point offset: 35%
- +15 percentage-point offset: 70%

The comparison checks the following signals sample by sample:

- SOC estimate
- posterior voltage estimate
- voltage innovation
- applied current
- applied voltage input

The same numerical parity tolerances used in the archived constant-current comparison are retained:

- SOC: `1e-6 pp`
- posterior voltage: `1e-5 mV`
- innovation: `1e-5 mV`
- time: exact 1 s alignment within `1e-9 s`

These are implementation-reproduction tolerances, not physical estimation-accuracy targets.

## Results

All three initial-SOC cases passed.

| Initial condition | Max SOC difference [pp] | Max posterior-voltage difference [mV] | Max innovation difference [mV] |
|---|---:|---:|---:|
| correct initialization | 1.692e-11 | 7.949e-11 | 8.216e-11 |
| -20 pp offset | 7.078e-10 | 7.773e-09 | 7.739e-09 |
| +15 pp offset | 3.961e-10 | 4.291e-09 | 4.275e-09 |

The full test therefore satisfies the specified MATLAB-Simulink numerical parity tolerances for the synthetic 1 s step schedule.

### Transition-window checks

Each of the eight current changes is checked over a dedicated window spanning one sample before the step through five samples after it. Across the three initialization cases, all **24/24 transition windows passed**.

This includes the direct current reversal from `-1.7 A` to `+1.7 A`.

## Negative controls

Two deliberate MATLAB-only timing faults were injected at the test-call level without editing the production EKF functions or Simulink observer:

1. use the current sample `I[k]` for state prediction instead of `I[k-1]`;
2. use the previous sample `I[k-1]` in the measurement equation instead of `I[k]`.

Under the step schedule, both faults were detected at all eight transitions:

| Deliberate timing fault | Max SOC difference [pp] | Max posterior-voltage difference [mV] | Max innovation difference [mV] | Detected transitions |
|---|---:|---:|---:|---:|
| prediction uses current sample | 0.111 | 4.782 | 4.913 | 8/8 |
| measurement uses previous sample | 0.776 | 133.096 | 136.132 | 8/8 |

The same deliberate faults produce zero difference under a constant-current control, confirming why the earlier constant-current parity test could not by itself expose this class of timing error.

## Interpretation

The test supports the following implementation-level statement:

> For the tested fixed-step 1 s synthetic current schedule, the MATLAB EKF reference and the saved Simulink observer remain numerically consistent across rest, discharge, charge, and direct current reversal. The test is sensitive to the two selected current-sample timing faults.

The test does **not** establish physical SOC accuracy for a measured variable-current drive cycle, hardware timing, irregular sampling support, temperature or aging robustness, or embedded deployment readiness. Internal RC-state and full covariance-matrix parity are not logged in this check.

## Evidence files

- [`current_schedule.csv`](../../results/validation/current_step/current_schedule.csv)
- [`summary.csv`](../../results/validation/current_step/summary.csv)
- [`signal_checks.csv`](../../results/validation/current_step/signal_checks.csv)
- [`step_window_checks.csv`](../../results/validation/current_step/step_window_checks.csv)
- [`negative_control_summary.csv`](../../results/validation/current_step/negative_control_summary.csv)
- [`parity_trace.csv`](../../results/validation/current_step/parity_trace.csv)
- [`negative_control_trace.csv`](../../results/validation/current_step/negative_control_trace.csv)
- [`synthetic_input.csv`](../../results/validation/current_step/synthetic_input.csv)
- [`current schedule figure`](../../results/validation/current_step/step_current.png)
- [`innovation parity figure`](../../results/validation/current_step/innovation_parity_error.png)

The executable MATLAB test is provided in [`scripts/test_mj1_current_step_parity.m`](../../scripts/test_mj1_current_step_parity.m).
