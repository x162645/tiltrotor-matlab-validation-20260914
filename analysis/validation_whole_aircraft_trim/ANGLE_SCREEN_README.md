# V7 角度域筛查

`run_line_b_v7_angle_screen` 用于检查同一套 V7 参数在不同论文短舱角 `i_n` 下是否能够稳定配平。输入角度采用论文/王梓旭约定：`i_n=90°` 为直升机模式、`i_n=0°` 为飞机模式；模型内部约定为 `betaM=0°` 和 `90°`，代码在入口明确执行 `betaM_internal=90-i_n`。默认速度只是诊断点，不代表完整过渡走廊；应按外部目标的有效速度范围显式传入。

```matlab
run_line_b_v7_angle_screen('outputs/V7_ANGLE_SCREEN_20260913')
```

也可以显式指定角度和速度：

```matlab
run_line_b_v7_angle_screen(outDir,[90 60 30 0],[40 60 80 100])
```

输出包括：

* `ANGLE_SCREEN_POINTS.csv`：每个组合的配平状态、推力、功率、残差、物理分支状态和边界状态；
* `ANGLE_SCREEN_SUMMARY.json`：接受/拒绝计数及声明边界；
* `ANGLE_SCREEN_MANIFEST.json`：参数栈和运行身份；
* 每个组合的独立 MAT 文件及汇总 `ANGLE_SCREEN_RESULTS.mat`。

该筛查不读取 Wang 等文献目标值，不进行目标拟合，也不覆盖冻结的 V7 速度扫描。`NUMERICALLY_ACCEPTED_SOURCE_SUBSET` 只表示数值和物理接口通过，不能解释为外部验证或全机飞行品质验证。只有角度筛查完成后，才允许对候选气动修正开展跨角度比较。
