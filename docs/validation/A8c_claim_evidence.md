# Claim–evidence matrix / 声明与证据矩阵

| Claim / 声明 | Status / 状态 | Supporting evidence / 证据 | Boundary / 边界 |
|---|---|---|---|
| Original 2RC–EKF baseline retained / 原基线保留 | Supported decision | [A7a candidate decision](A8c_candidate_decision.md) | Not proof that every possible candidate is inferior |
| A8a reproduces the archived A7a baseline / 基线回归复现 | Passed: 40 checks | [A8a checks](../../results/validation/A8c/A8a_regression_checks.csv) | Reproduction, not accuracy acceptance |
| Saved Simulink observer matches MATLAB outputs / 输出逐点一致 | Passed within specified tolerances | [A8b checks](../../results/validation/A8c/A8b_signal_checks.csv), [trace](../../results/validation/A8c/A8b_trace.csv) | One 1 s constant-current record; 0/−20/+15 pp initial offsets |
| Bitwise identity / 逐位完全相等 | Not claimed | Nonzero runtime differences | State numerical tolerance instead |
| SOC RMSE near 2.45 pp / SOC 参考误差约 2.45 pp | Supported for correct initialization on this record | [baseline metrics](../../results/validation/A8c/A8a_baseline_metrics.csv) | Coulomb-counting reference, not independent truth; not an all-condition specification |
| Near-zero final SOC error proves convergence / 末端小误差证明收敛 | Not supported | 34 lower-clamped samples per trajectory | Report full-record errors and clamping together |
| Dynamic 2RC replay and candidate screening / 动态回放与候选筛选 | Archived A7a result tables | [time-domain summary](../../results/validation/A8c/A7a_TD_summary.csv) | Given-coordinate forward-model response; not dynamic EKF SOC truth validation |
| Fixed slow-time-constant candidate improves SOC / 候选改善 SOC | Not supported | [EKF regression](../../results/validation/A8c/A7a_EKF_regression.csv) | Posterior voltage improves while reference-SOC RMSE increases slightly |
| Online parameter updating implemented and validated / 在线参数更新已实现且获验收 | Not claimed | Fixed-candidate workflow only | No recursive parameter estimator is enabled by A8c |
| Variable-current input timing verified / 变电流时序已验证 | Not established | Current is constant throughout A8b | Previous/current-sample input indexing may be indistinguishable |
| All internal states and covariances compared / 全部内部状态与协方差已对照 | Not established | A8b directly logs three outputs and two inputs | RC states and full covariance not directly compared |
| Other cells, temperatures or nonuniform sampling / 跨电芯温度及变采样 | Not established by this archive | No relevant runtime test in the exported parity record | Do not extrapolate the pass |
| Embedded deployment or hardware qualification / 部署代码或硬件验收 | Not established | Normal simulation and archive checks only | `ReleaseDecision=NOT_RELEASED` retained |
| File identities match supplied snapshots / 文件身份与快照对应 | Verified for listed uploaded archive members | [fingerprints](../../results/validation/A8c/A8c_archived_input_fingerprints.csv) | Not a live check of a GitHub repository or unlisted dependencies |

The matrix describes the archived evidence, not current repository state. The overlay does not change model parameters, code or repository history.
