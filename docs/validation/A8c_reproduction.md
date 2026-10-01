# Running the benchmark and checking the evidence

[Project overview](../../README.md) · [Validation report](A8c_validation_report.md)

## MATLAB reference benchmark

From the repository root:

```matlab
addpath(fullfile(pwd, "matlab"), fullfile(pwd, "data"))
run("matlab/run_mj1_ekf_holdout.m")
run("matlab/check_against_python_benchmark.m")
```

The runner uses the model and holdout data in `data/` and the estimator functions in `matlab/`. The documented execution environment is MATLAB R2025b Update 2. Simulink is needed for the `.slx` models in `model/`; see the [implementation guide](../SIMULINK_IMPLEMENTATION_PLAN.md) for their initialization and interfaces.

## Offline verification of published results

With Python 3.9 or later, from the repository root:

```bash
python tools/verify_a8c_evidence.py
```

The standard-library utility reads the published evidence and prints a JSON report. It checks file hashes, 40 baseline-regression checks, 15 signal checks, and the 3495-row three-case comparison trace. It also recomputes SOC and posterior-voltage RMSE, checks lower-bound occupancy, and verifies the arithmetic of the candidate-performance differences.

A successful report contains:

```json
{
  "archive_verification": "PASS_FOR_PACKAGED_EVIDENCE",
  "matlab_or_simulink_executed": false
}
```

The command does not execute MATLAB or Simulink and is not required to run the estimator. It verifies the archived exports rather than reproducing a new physical experiment. Small decimal-export rounding differences are assessed against the original numerical tolerances.

## Repeating the original MATLAB-Simulink parity test

The original runtime test used an isolated copy of the saved Simulink observer, the A8a baseline snapshot, MAT reference data, core MATLAB functions, and the `A8b_matlab_simulink_parity.m` audit runner. The full audit runner and local run-directory layout are not supplied as part of this documentation archive. Re-executing that exact test therefore requires the original audit dependencies or a separately validated repository-layout adaptation.

The repository contains the model and estimator implementations; the [baseline provenance record](A8c_repository_integration.md) documents their correspondence at integration. Exported comparison traces allow numerical review of the reported test without claiming that the offline checker is a replacement for simulation.

## File integrity and documentation revisions

`A8c_package_manifest.json` indexes the current public documentation and evidence. A presentation-only revision updates documentation hashes without modifying the original numerical CSVs, status records, or model-source fingerprints. The original manifest is retained as `A8c_package_manifest_original.json` for provenance; its document paths describe the earlier edition, not files that must exist in the current tree.

The active manifest excludes itself. Hashes check consistency of the listed bytes; the manifest is not an external signature or an independent authentication of experimental provenance. Original full local run directories and simulation outputs remain the source archive for a fresh runtime investigation.
