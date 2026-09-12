# 论文候选稿复算入口（2026-09-12）

本文档给出候选稿中每一类结果的最短复算路径。命令默认在仓库根目录执行，使用
MATLAB R2021a（或兼容版本）。运行前先记录 `git rev-parse HEAD`；结果应与该提交
对应，避免把不同版本的缓存混在一起。

## 1. 初始化和内部检查

```matlab
cd('仓库根目录');
startup;
summary = run_all_checks;
controlReport = check_control_architecture;
inertiaReport = check_berger13_variable_inertia;
hqReport = check_handling_quality_screen;
assert(summary.allPassed);
assert(controlReport.allPassed);
assert(inertiaReport.allPassed);
assert(hqReport.allPassed);
```

这些检查只证明接口、有限性、数值闭合和筛查程序可运行，不是外部预测验证，也不
构成飞行品质认证。变惯量检查应报告 `dI/dt*omega` 闭合和执行器反力矩残差；操稳
筛查的真实研究点仍可能返回 `SCREEN_UNCERTAIN`，不能把单元测试的 PASS 改写成
正式等级结论。

## 2. Berger13 整机研究路径

先使用已有缓存复核论文图表：

```matlab
outDir = fullfile(pwd,'repro_outputs','berger13');
results = run_berger13_complete_research(outDir,false);
```

若要从头重建缓存，将第二个参数改为 `true`。主要输出包括：

- `13X10_RESEARCH_RESULTS.mat` 和 `13X10_SENSITIVITY_RESULTS.csv`；
- `13X10_TRIM_POINT_DATABASE.csv`、`13X10_LINEAR_MODEL_DATABASE.mat`；
- `13X10_DERIVATIVE_DATABASE.csv`、`13X10_EIGENVALUE_DATABASE.csv`；
- `13X10_MODE_TRACKING_DATABASE.csv` 及 `figures/` 下的重画图。

该路径输出的是公开资料约束下的研究模型。短舱惯量、执行器带宽和部分高阶传动
耦合仍有占位或未知项，因此这些图只能支持条件性整机分析。

## 3. 外部部件比较

三个入口均接受显式输出目录，不修改生产参数：

```matlab
oarf15 = run_xv15_v1_baseline_correlation( ...
    fullfile(pwd,'repro_outputs','oarf_run15_m0'));
oarf14 = run_xv15_v1_run14_external_validation( ...
    fullfile(pwd,'repro_outputs','oarf_run14_m0'));
wadc = run_m1_stage5_wadc_holdout( ...
    fullfile(pwd,'repro_outputs','wadc_m1'));
```

候选稿报告的核对值为：

|数据集|模型|点数/窗口|CT MAPE|CP MAPE|FM MAPE|
|---|---|---:|---:|---:|---:|
|OARF Run 15|冻结 M0，6–11°报告窗|6/6 物理收敛|56.42%|62.61%|23.02%|
|OARF Run 14|冻结 M0，6–11°报告窗|6/6 物理收敛|56.19%|64.08%|19.12%|
|WADC Runs 1–3|M0|15/15 物理收敛|59.15%|66.10%|23.05%|
|WADC Runs 1–3|冻结 M1|15/15 物理收敛|37.90%|51.11%|9.26%|

运行后应直接读取生成的 `*_METRICS.csv` 和 `*_POINTS.csv`，并保留低总距未收敛
点。Run 14 与 Run 15 属同一 OARF 系列；WADC 数据在此前诊断链中已可见。三者
都不能标为独立盲测。M1 的结果表示冻结模型的相对改善，不能解释为绝对 CT/CP
高精度。

## 4. Betzina 低速前飞检查

当前版本可直接复核验证适配器身份闸门：

```matlab
cd(fullfile(pwd,'analysis','validation_betzina2002'));
gate = run_betzina2002_two_cyclic_identity_gate;
assert(gate.pass);
```

旧 Fig.16/Fig.18 双周期数值结果来自归档提交
`f24ffbe55e2c87b7c54177c1c60b1367b1ff0a8e`，保存在
`docs/validation/line_b_implementation_20260910/handoff_evidence/A25_FORWARD_REGRESSION/`。
它们是图表数字化的单旋翼低速前飞趋势证据，未在当前 HEAD 重新执行。当前 HEAD
的 `alpha=0` 两控制快速检查虽然 4/4 物理解算收敛，但固定 `CT/σ=0.075` 合同
为 0/4；该失败必须保留，不能把“有正推力”当成运行状态匹配。

## 5. 操稳筛查和证据角色

已有控制稳定性结果位于
`docs/tiltrotor_control_stability_technical_report/`。如需重新生成筛查表：

```matlab
inputMat = fullfile(pwd,'docs','tiltrotor_control_stability_technical_report', ...
    'CONTROL_STABILITY_RESULTS.mat');
screen = run_preliminary_handling_quality_screen(inputMat, ...
    fullfile(pwd,'repro_outputs','handling_quality'));
```

输出的 `PRELIMINARY_HANDLING_QUALITY_SCREEN.csv` 仅是方法筛查。当前真实研究点
包含 `SCREEN_UNCERTAIN`，因此论文只能报告筛查和不确定性，不能声称满足 MIL 或
实机飞行品质等级。

## 6. 复算后的主张边界

可以复核的主张是：通用低成本整机接口可运行；旋翼、翼面和刚体方程能够闭合；
冻结 M1 在 WADC 跨设施数据上相对 M0 有改善；公开单旋翼数据提供有限的低速前飞
趋势检查。缺少同步全机总距/执行器、旋翼载荷、质量—重心—惯量、转速和统一时间
基准，因此不能由这些命令推出 XV-15 全机过渡动态精度、实机飞行品质或国内领先。

