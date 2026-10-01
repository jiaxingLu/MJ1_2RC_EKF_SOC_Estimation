# Baseline source correspondence

[Project overview](../../README.md) · [Reproduction guide](A8c_reproduction.md)

## Artifacts checked at validation-archive integration

Before the archive was committed, nine repository artifacts were compared with the A8a baseline snapshot:

| Artifact | Comparison |
|---|---|
| `matlab/mj1_ekf_step.m` | Text identity after UTF-8 BOM and line-ending normalization |
| `matlab/mj1_interp_params.m` | Same text comparison |
| `matlab/mj1_state_transition.m` | Same text comparison |
| `matlab/mj1_F_jacobian.m` | Same text comparison |
| `matlab/mj1_H_jacobian.m` | Same text comparison |
| `matlab/mj1_measurement.m` | Same text comparison |
| `data/mj1_v02_model.mat` | Byte-exact SHA-256 match |
| `data/mj1_holdout_50to17.mat` | Byte-exact SHA-256 match |
| `model/MJ1_2RC_EKF_v02_S2_Final.slx` | Byte-exact SHA-256 match |

All nine checks matched. The published validation archive was committed as `4ba259484332fa8de65b2a21557297f4758c2a79`. This records the correspondence at that revision, not a guarantee about later modified working copies.

## Documentation-only revision

The English presentation revision changes the README, explanatory documents, and their manifest entries. It does not alter the estimator, lookup tables, saved Simulink model, numerical result CSVs, or original machine-readable test statuses.

The original package manifest remains available alongside the current manifest. The original bilingual document edition remains in Git history; the current public documentation is in English. Archival filenames retain their test identifiers so that existing evidence can be traced without renaming the result files.
