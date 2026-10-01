# Reproduction levels / 复现层级

[Validation report](A8c_validation_report.md) · [中文报告](A8c_validation_report_zh.md)

## 1. Check this archived evidence without MATLAB

From the `repo_overlay` directory, or the repository root after adding its folders, run:

```text
python tools/verify_a8c_evidence.py
```

The helper requires Python 3.9 or later and its standard library only. It reads files and reports JSON; it does not modify model files, regenerate experimental data or create a new MATLAB/Simulink execution.

It checks packaged file sizes and SHA-256 hashes, A8a's 40 saved check rows, A8b's 15 saved signal checks, the 3495-row trace and the three summary rows. Recomputed parity comparisons retain time order and the first sample. It also recomputes SOC and posterior-voltage RMSE against the exported original reference, confirms the 34 lower-clamped samples per case, and checks the arithmetic and directions of the candidate tradeoffs in the supplied A7a summaries.

Expected archive result:

```text
"archive_verification": "PASS_FOR_PACKAGED_EVIDENCE"
"matlab_or_simulink_executed": false
"deployment_release": "NOT_RELEASED"
```

Decimal CSV decoding can slightly change the smallest reported differences. Passing uses the original numerical tolerances; it does not require identical last digits of exported runtime maxima. The helper verifies A7a summary arithmetic, not a fresh A7a forward-model or EKF simulation.

The package manifest excludes itself. Hashes detect inconsistent packaged bytes; a manifest supplied alongside files is not an external signature or independent authentication of experimental provenance.

## 2. Repeat the actual MATLAB/Simulink test locally

A fresh runtime test requires the original A8a snapshot, saved SLX, MAT reference, core MATLAB functions and the actual `A8b_matlab_simulink_parity.m` runner. Preserve the original A7a, A8a and A8b result folders. Use the archived source fingerprints to distinguish this baseline from a later working copy; filenames alone are not sufficient.

The source files and binary artifacts are intentionally not duplicated in this documentation overlay. Their exact dependency layout must be retained or explicitly adapted and retested. This package does not certify a reordered repository layout or claim that the repository's present files match the fingerprints; the live repository has not been inspected or changed in this step.

The prior A8b review ZIP omits full `SimulationOutput` MAT files, the runtime test copy and compilation outputs. These remain local audit artifacts. Re-running the optional offline helper is not a prerequisite for ordinary MATLAB use.

## 3. Files intended for GitHub

`docs/validation/` contains public-facing validation, scope, candidate-decision and reproduction documents. `results/validation/A8c/` contains selected numeric outputs, processed reference/trace data, original statuses and path-free provenance. `tools/verify_a8c_evidence.py` allows numerical checks on the archived exports.

No existing root README, source code, LUT or SLX is overwritten by the overlay design. The separate README excerpt is optional. Keep any existing repository license unchanged; this package does not assign a license or make decisions about third-party code/data rights.

## 4. Files to keep in the local archive

Keep the original completed `results/A7a_.../`, `results/A8a_.../` and `results/A8b_.../` directories and their original review ZIPs. Those include full dependency snapshots and richer local runtime evidence. Do not replace them with the smaller public evidence overlay.

Do not bulk-copy compilation caches, working SLX versions, complete raw-data folders, path-containing manifests or previous intermediate review archives into the public repository. The original A8b independent-review bundle is supplementary and is not an input to A8c.

## 中文操作要点

本次 A8c 不需要再运行 MATLAB，也不需要先下载 A8b 补充复核包。最终材料是“文档与证据增量”，不是完整可运行工程替代包。把 `repo_overlay` 里的 `docs`、`results`、`tools` 按相对路径合入 Phase II 仓库；不要直接用它覆盖整个仓库。原始运行目录继续保存在本地。

此步骤没有执行 GitHub 写入、提交或推送。公开证据整理完成不改变 `NOT_RELEASED` 的工程发布边界。
