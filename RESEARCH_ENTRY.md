# 当前接续：V8 四构型网格与数值修正，文献精度未闭合

2026-09-14：用户已接受公开文献结果对比作为短期验模证据。最新事实见同一 `STEP_LEDGER.md` 的 V8 条目和 `docs/validation/v8_grid_review_20260914/核查与修正结果.md`。建议网格实算 8/16；延拓和零面积翼面逻辑修正恢复 30°110–130 kt，功率相对图1(c)约120 kt的重提取参考仍高约56%。飞机源域/中间角度构型实现仍需完善，不能以缺全机同步数据阻断这项工作。下文 D17 是历史状态，不覆盖最新目标。

## 历史入口：D17

当前事实入口：`docs/research/dynamic_fidelity/STEP_LEDGER.md`，候选稿为 `docs/research/dynamic_fidelity/D16_CANDIDATE_PAPER_CN.md`。D16 的固定桨毂 72 案例、D16 升沉接口和 D15 v4 恢复实现均保存了实际代码、运行输出、manifest 和独立读回。查表（最大 0.1114%）与总距调度解析传播（最大 0.2707%）相对当前直接源通过本次 1% 数值预算；固定 LTI（最大 168.0%）和准定常（100%）保留为失败/负对照。

这些是条件数值结果：V4 静态源在既有 27 个点仍有约 33%–38% 误差，D16 接入了 Woodgate/NUAA 通用旋翼来源并完成数字化复现审计，但时间原点与静态量级尚未闭合，定量 RMSE 已降级为失败诊断；D16 升沉扩展为 PP-only 条件实验。不能称实机精度、全机验证或国内领先。下一精确接续是先补公平的标准 Pitt–Peters/Peters–He 基线和任务级选择指标，再视来源闭合情况恢复 Woodgate 定量比较；同步实际总距/执行器、旋翼载荷和升沉观测用于升级全机声明，不是方法稿投稿前置。不得用 TM89404 的 power-lever 图、D15 重叠窗口或旧开发曲线冒充这条记录。

长期主线：外部证据约束下、面向倾转操稳与控制的低成本动态预测；短期具体完整的《航空学报》贡献，不按状态/检查数认领创新或领先。成熟方法可胜出并替代候选。

分支research/dynamic-fidelity-benchmark-20260910，Draft PR78不合并。先核实际HEAD/工作区、读AGENTS、CODEX_TASK、同一docs/research/dynamic_fidelity/STEP_LEDGER.md及D13_REPORT.md、D13_PARAMETER_PREDICTION_CONTRACT.json。不得凭聊天摘要重建源数据。

D13主cb7a8fed/run34647299470/artifact10283140101：原生MATLAB工作点C81增量+经典查表对照，源报告桨距输入仍假设。两状态不变，粗表在两PP脉冲最大数值NRMSE.01610%，同MATLAB载荷kernel约146倍快于当前直接实现；不是真实飞机精度或整机加速。原常数b保留不通过1%数值预算的结果。源b.1277617852，源静态兼容性和外部形状差异未消失。

科学原始evidence_d13/runs/34647299470已存Git，a51441ec。公共接口model/dynamic_fidelity/d13_load_table_model.m及d13_hover_load_table_rhs.m已执行API run34647962785，原结果evidence_d13/api_runs/34647962785，8112d87b。只查新接口，0新ODE。MAT/CSV/JSON与独立Python读回完成。Python完整补充在离线包，不与Git摘要镜像混称。

D12常数输入比例不足、动态链未识别结论保留；TN3044全开发、不再新盲测。D06-D11旧Python身份不变，旧54MB完整包仍未全量上Git。

下一实质交付是同构型真实输入/执行器或分离载荷-升沉观测约束下的外部预测，并检查源静态兼容性及跨工作点能力；经典查表和导数调度是强基线。不能继续只增加诊断台账、第三种单点补偿或无依据状态。只做依赖相关回归，默认生产/旧PR77/失败/校准支路保留。当前工作包已结束，无回复后后台执行承诺。
