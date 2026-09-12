# 当前代码真实外部验证记录（2026-09-12）

## 运行对象

- 证据包提交链最新：`3fa9607`（模型身份基线：`d0b1a47`）
- MATLAB：R2021a，`F:\matlab\R2021a\bin\matlab.exe`
- 外部来源：NASA CR-2017-219486，Appendix A Table A-2，XV-15 OARF 原始金属桨 Run 15 / Run 14。
- 评价窗：总距 6–11°；每个窗口固定，按物理收敛点统计 MAPE。
- 运行前冻结模型和参数；未用外部目标数据调参。

## Run 15：纯 M0 直接旋翼路径（主证据）

脚本：`analysis/run_xv15_v1_baseline_correlation.m`；旋翼入口：`model/rotor_model_bemt.m`。

|量|物理收敛点|MAPE|平均有符号误差|
|---|---:|---:|---:|
|CT|6/6|56.4224%|-56.4224%|
|CP|6/6|62.6130%|-62.6130%|
|FM|6/6|23.0180%|-23.0180%|

0°、2°、4°未达到耦合求解收敛，逐点结果保留为失败状态，没有从统计中删除后改称成功。

## Run 14：同一 OARF 系列的运行级外部检验

脚本：`analysis/run_xv15_v1_run14_external_validation.m`；同样使用直接 M0 路径。Run 14 在先前模型诊断链中未使用，但与 Run 15 属同一 OARF 试验系列，不能冒充独立实验或盲测。

|量|物理收敛点|MAPE|平均有符号误差|
|---|---:|---:|---:|
|CT|6/6|56.1864%|-56.1864%|
|CP|6/6|64.0809%|-64.0809%|
|FM|6/6|19.1169%|-19.1169%|

1°、3°耦合解未收敛；负推力点标记为不支持。Run 14 与 Run 15 的 CT/CP 低估方向和量级相近，说明误差不是某一组曲线偶然造成，但只能支持同一试验系列内的重复性证据。

## WADC：冻结 M1 的跨设施部件比较

脚本：`analysis/run_m1_stage5_wadc_holdout.m`。该比较在模型冻结后执行，保留 M0 作为未经修正的基线，并报告冻结 M1 的相对变化。15/15 个点物理收敛；汇总 MAPE 为 M0 的 CT/CP/FM = 59.1465%/66.0974%/23.0497%，M1 为 37.8956%/51.1078%/9.2559%。数据已经进入此前诊断链，因此不能称作盲测；它支持“有外部数据约束的相对改进”，不能单独支持普适精度或整机动态精度。

## 结论

这次是真正的外部数据比较，不是代码自洽测试。结果显示当前低阶 M0 模型在 XV-15 OARF 条件下系统性低估绝对 CT/CP，FM 误差较小但不能抵消载荷误差。因此当前模型可以支持“已执行、可追溯的 XV-15 部件级外部相关，并定位出模型形式误差”的结论，不能支持“XV-15 精确预测”或“整机动态精度”声明。

## 可复核文件

- [Run 15 指标](../evidence/external_validation_20260912/run15_direct_m0/XV15_V1_M0_BASELINE_METRICS.csv)
- [Run 15 逐点结果](../evidence/external_validation_20260912/run15_direct_m0/XV15_V1_M0_BASELINE_POINTS.csv)
- [Run 15 MATLAB 日志](../evidence/external_validation_20260912/run15_direct_m0/run15_matlab.log)
- [Run 14 指标](../evidence/external_validation_20260912/run14_direct_m0/XV15_V1_RUN14_M0_METRICS.csv)
- [Run 14 逐点结果](../evidence/external_validation_20260912/run14_direct_m0/XV15_V1_RUN14_M0_POINTS.csv)
- [Run 14 MATLAB 日志](../evidence/external_validation_20260912/run14_direct_m0/run14_matlab.log)
- [另一路径对照：section-aero wrapper 结果](../evidence/external_validation_20260912/section_aero_wrapper/XV15_FROZEN_LOW_ORDER_METRICS.csv)



- [WADC M0/M1 指标](../evidence/external_validation_20260912/wadc_m1_holdout/M1_STAGE5_WADC_METRICS.csv)
- [WADC 来源审计](../evidence/external_validation_20260912/wadc_m1_holdout/M1_STAGE5_WADC_SOURCE_DATA_AUDIT.csv)

