# 动态研发入口：D13已完成

长期主线：外部证据约束下、面向倾转操稳与控制的低成本动态预测；短期具体完整的《航空学报》贡献，不按状态/检查数认领创新或领先。成熟方法可胜出并替代候选。

分支research/dynamic-fidelity-benchmark-20260910，Draft PR78不合并。先核实际HEAD/工作区、读AGENTS、CODEX_TASK、同一docs/research/dynamic_fidelity/STEP_LEDGER.md及D13_REPORT.md、D13_PARAMETER_PREDICTION_CONTRACT.json。不得凭聊天摘要重建源数据。

D13主cb7a8fed/run34647299470/artifact10283140101：原生MATLAB工作点C81增量+经典查表对照，源报告桨距输入仍假设。两状态不变，粗表在两PP脉冲最大数值NRMSE.01610%，同MATLAB载荷kernel约146倍快于当前直接实现；不是真实飞机精度或整机加速。原常数b保留不通过1%数值预算的结果。源b.1277617852，源静态兼容性和外部形状差异未消失。

科学原始evidence_d13/runs/34647299470已存Git，a51441ec。公共接口model/dynamic_fidelity/d13_load_table_model.m及d13_hover_load_table_rhs.m已执行API run34647962785，原结果evidence_d13/api_runs/34647962785，8112d87b。只查新接口，0新ODE。MAT/CSV/JSON与独立Python读回完成。Python完整补充在离线包，不与Git摘要镜像混称。

D12常数输入比例不足、动态链未识别结论保留；TN3044全开发、不再新盲测。D06-D11旧Python身份不变，旧54MB完整包仍未全量上Git。

下一实质交付是同构型真实输入/执行器或分离载荷-升沉观测约束下的外部预测，并检查源静态兼容性及跨工作点能力；经典查表和导数调度是强基线。不能继续只增加诊断台账、第三种单点补偿或无依据状态。只做依赖相关回归，默认生产/旧PR77/失败/校准支路保留。当前工作包已结束，无回复后后台执行承诺。
