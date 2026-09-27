# MJ1 v0.2 — Simulink implementation plan

The project should move to Simulink **after** the MATLAB reference implementation
passes `check_against_python_benchmark.m`.

## Model boundary

Use only the validated v0.2 range:

- SOC: **17–85%**
- temperature: approximately the experimental room-temperature condition
- current sign: **I > 0 charge, I < 0 discharge**
- model: second-order Thevenin ECM with SOC-dependent lookup tables

Do not add PyBaMM to this block-level implementation.

## Top-level Simulink architecture

```text
Measured current I[k] ─────────────┐
                                   │
Measured voltage V[k] ───────┐     │
                             ▼     ▼
                       ┌─────────────────┐
                       │  MJ1 2RC EKF    │
                       │                 │
                       │ prediction      │
                       │ voltage model   │
                       │ innovation      │
                       │ Kalman update   │
                       └─────────────────┘
                           │   │   │
                           │   │   └── innovation
                           │   └────── V_hat
                           └────────── SOC_hat
```

## Internal functional blocks

1. **SOC-dependent parameter lookup**
   - OCV(SOC)
   - R0(SOC), R1(SOC), C1(SOC), R2(SOC), C2(SOC)
   - 1-D Lookup Table blocks, linear interpolation
   - clamp/bound SOC to [0.17, 0.85]

2. **Exact-discrete 2RC prediction**
   - `a_i = exp(-dt/(R_i*C_i))`
   - `b_i = R_i*(1-a_i)`
   - `v_i[k+1] = a_i*v_i[k] + b_i*I[k]`
   - `SOC[k+1] = SOC[k] + I[k]dt/(3600 Qref)`

3. **Terminal-voltage measurement**
   - `V_hat = OCV + v1 + v2 + R0*I`

4. **EKF covariance / innovation subsystem**
   - state vector `[v1; v2; SOC]`
   - numerical or scheduled Jacobians
   - fixed baseline `Q = diag([1e-7 1e-7 1e-9])`
   - fixed baseline `R = (0.020 V)^2`
   - do **not** tune Q/R on the holdout data

## Recommended Simulink implementation sequence

### Phase S1 — plant only
Reproduce the MATLAB open-loop 2RC voltage prediction in Simulink.

Acceptance:
- Simulink and MATLAB voltage traces should agree to numerical precision.

### Phase S2 — estimator
Add the EKF update.

Acceptance:
- correct-initial-SOC case agrees with MATLAB reference.
- -20 percentage-point initial SOC case recovers with the same qualitative behavior.

### Phase S3 — instrumentation
Log:
- SOC_hat
- v1_hat, v2_hat
- V_hat
- innovation
- Kalman gains
- diagonal of P

### Phase S4 — test harness
Use the frozen 50→17% holdout `.mat` dataset as the first test harness.

Only after S1–S4 pass should the model be extended to:
- current / voltage sensor perturbation test cases
- capacity/SOH parameter estimation
- Dual EKF
