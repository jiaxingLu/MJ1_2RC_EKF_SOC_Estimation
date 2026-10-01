# MJ1 2RC–EKF：验证范围与交付归档

[English report（英文报告）](A8c_validation_report.md) · [Candidate decision（候选采用决定）](A8c_candidate_decision.md) · [Reproduction guide（复现说明）](A8c_reproduction.md)

## 最终采用决定

**保留原有 SOC-dependent 2RC–EKF（SOC 相关双 RC 扩展卡尔曼估计器）基线。约 1.45 倍慢时间常数的固定候选不替换默认模型，不启用对应在线参数更新。**

A8b 已验证：在一条 1 s 采样、−3.4 A 恒流放电记录，以及正确初始化、−20 pp、+15 pp 三种初始 SOC 条件下，MATLAB 与已保存 Simulink 观察器的 SOC、后验电压、电压新息，在预设容差内逐点一致。三个初始化场景复用同一条数据，不是三次独立电池实验。

这份材料用于公开展示验证证据，不代表量产发布。原文件中的 `ReleaseDecision=NOT_RELEASED` 保留不变；A8a 的静态检查状态和后续 A8b 的运行时状态也分别保留，不改写历史记录。[原始状态](../../results/validation/A8c/A8b_status.csv)

## 测试对象与数值口径

状态顺序为 `[v1, v2, SOC]`，电压单位 V，SOC 采用 0–1 分数。充电电流为正；冻结参考容量为 3.335 Ah，查表有效区间为 17–85% SOC。

每个场景包含 1165 个时刻，时间为 0–1164 s。第一点是初始化输出，不进行测量校正；逐点比较保留第一点，没有插值、时间平移或删点。Q、R、P0 和环境记录见[运行设置](../../results/validation/A8c/A8c_scope_and_settings.json)。

## Implementation parity（实现数值一致性）

A8a 的 40 条基线复现检查全部通过；A8b 的 15 条信号检查全部通过。每个场景比较 3 个估计器输出和 2 个实际输入。

| Initial case | Max SOC difference [pp] | Max posterior-voltage difference [mV] | Max innovation difference [mV] |
|---|---|---|---|
| correct_init | 7.616e-12 | 1.625e-10 | 1.563e-10 |
| minus20pp | 6.043e-10 | 5.422e-09 | 5.315e-09 |
| plus15pp | 7.250e-11 | 1.230e-10 | 1.208e-10 |

表中为运行时保存的差异。SOC 容差为 `1e-6 pp`；后验电压与新息容差为 `1e-5 mV`；时间容差为 `1e-9 s`。它们是数值复现标准，不是测量不确定度或电池 SOC 精度目标。两个输入的差异和时间轴差异均为零；输出不宣称逐位完全相等。[逐信号检查](../../results/validation/A8c/A8b_signal_checks.csv)

## Estimation error（估计误差）没有因实现一致而消失

实现差异比较的是 `SOC_Simulink − SOC_MATLAB`；这里的 SOC 估计误差比较的是 `SOC_estimated − SOC_reference`。参考值来自原有 Coulomb counting（库仑计数）定义，不是独立真实 SOC 测量。

| Initial case | Initial SOC [%] | SOC RMSE vs reference [pp] | Posterior voltage RMSE [mV] |
|---|---|---|---|
| correct_init | 49.988339 | 2.445155 | 10.181881 |
| minus20pp | 29.988339 | 2.508752 | 10.925093 |
| plus15pp | 64.988339 | 2.455045 | 11.186954 |

三条轨迹各有 34 个时刻处于 17% 的 SOC 下限。因此末端约 −0.024821 pp 的小误差受到限幅影响，不能单独证明准确收敛。全记录指标保留初始化误差。[基线指标](../../results/validation/A8c/A8a_baseline_metrics.csv)

## Candidate acceptance（候选验收）结论

`Tau2FixedR2` 仅缩放 C2，保持 R2 不变。A7a 的时域回放继续使用跨配对拟合尺度：A 使用 B 上拟合的尺度，B 使用 A 上拟合的尺度；次级配对使用主要配对合并尺度。原有 EKF 回归测试使用主要配对合并尺度，且不改变 EKF 的参考 SOC、Q、R、P0 或 Qref。

该候选改善了两个主要配对的 10τ 基波误差，却恶化了它们的 1τ 误差。九种候选尺度／初始状态组合中，后验电压 RMSE 都下降，但 SOC RMSE 都略有增大。**电压重构改善不等于 SOC 估计改善。** 因此保留候选研究结果，不采用默认替换。[完整采用记录](A8c_candidate_decision.md)

## 未覆盖范围

恒流条件下 `I[k−1]=I[k]`，所以这次执行测试无法区分部分上一拍／当前拍电流的使用错误。A8b 没有直接对照全部 RC 内部状态和完整协方差矩阵。

本轮也不证明变电流时序一致性、不等间隔采样、其他电芯／温度、动态 DC–AC 工况下独立 SOC 精度、部署代码或硬件验证。此前给定 SOC 坐标下的动态前向模型检查，与 EKF 的 SOC 精度验证必须分开表述。

## 本地证据与公开材料

本目录仅提供公开用的验证说明、结果表、参考数组和输出轨迹；完整原始日志、模型 MAT／SLX 快照、包含个人绝对路径的清单、仿真缓存保留在原本地审计目录。这里只发布相对归档标识和文件哈希，不上传整套工作目录。

附带的 `verify_a8c_evidence.py` 是离线证据检查脚本，重新核对打包文件指纹、15 条输出对照及指标运算；它不运行 MATLAB 或 Simulink，也不是继续使用估计器的前置依赖。[复现说明](A8c_reproduction.md)

**归档状态：公开文档与证据已整理；默认基线保留；在线更新未启用；工程部署状态仍为未发布。**
