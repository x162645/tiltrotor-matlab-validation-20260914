# 本轮复算入口

模型执行环境为完整 MATLAB R2021a（`F:\matlab\R2021a\bin\matlab.exe`）。Python 只做图像提取、MAT 读回和表格，不代替模型运行。工作目录为本分支仓库；运行前先执行：

```matlab
run('startup.m');
addpath(genpath('analysis'));
```

实际执行的顺序与保留目录：

1. `V7_ANGLE_SCREEN_ADAPTIVE_20260914`：调用已有 `run_line_b_v7_angle_screen_source_modes`，逐角度使用 `[20 40 60 80]`、`[80 100 120 140]`、`[110 130 150 170]`、`[130 150 170 185]`。8/16 接受。此时源代码基线为 `7cd2a72`，未修正飞机机翼 MachGap 或零面积区域。
2. `V8_CONTINUATION_IN030_20260914`：从第 1 步 `IN030/IN030_V110.00.mat` 起始，调用新 `run_line_b_v8_continuation(out,30,[115 120 125 130],seed)`。3/4 接受；130 失败保留。此时尚未修复 `wing_model_source_family` 的零面积逻辑。
3. `V8_AIRPLANE_MACH_INTERPOLATION_20260914`：飞机机翼 Mach 内插修正后，调用 `run_line_b_v8_continuation(out,0,170)`。机翼 MachGap 消失，实际机身源域错误保留。
4. `V8_EMPTY_AREA_FIX_20260914`：零面积逻辑修正后，从第 2 步 125 kt 载体起始，调用 `run_line_b_v8_continuation(out,30,130,seed)`，实际接受。

当前代码复算新结果（输出到新的目录，避免覆盖原记录）：

```matlab
test_gtrs_wing_airplane_source_coefficients;
test_gtrs_tail_equivalent_angle;
test_wing_empty_patch_domain;
run_line_b_v8_continuation('outputs/recomputed_v8_in30',30,[110 115 120 125 130]);
```

上面 5 点冷启动整链命令是组合复算入口，尚未作为一个单独批次运行；实际执行的是上述 1→2→4 的载体接续。当前代码不应重现旧零面积错误；重现修正前失败需使用基线 `7cd2a72` 的 `model/wing_model_source_family.m` 和本次延拓 runner，在独立工作区运行，不能覆盖当前工作区。

固定解回代：`audit_line_b_v8_replay(pointFile,outputDir)`，对 120、130 kt 均已实际执行。它固定状态、控制和物理参数，只切换默认/追踪挥舞初值。`MATLAB_CHECKS.mat`、`MATLAB_CHECKS.log`、`REPLAY130/` 保存最后一次检查。

读回与条件性文献比较：

```powershell
python analysis/validation_whole_aircraft_trim/summarize_v8_grid_review.py --output-base 'C:\Users\86173\Documents\Codex\2026-09-11\yue\outputs'
```

`ALL_ATTEMPTS.csv` 保存固定 12 点、建议 16 点、延拓 4 点、零面积修正 1 点及飞机 Mach 修正 1 点，共 34 条实际尝试，不合并重复工况成新实验。`SOURCE_AND_READBACK.json` 保存所有逐点 MAT 的 SHA256。主要数值读取同时核对了 MAT 内状态导数重算的残差，不能替代模型外部验证。

原图第三列蓝色点提取只使用图片颜色、标记边界和固定坐标轴，不读取模型输出来定位标记。`FIG1c_SOURCE_POINTS_REVISED.csv` 替代旧表第三列的坐标值；旧表保留。总距定义未匹配，不评分。已使用参考不能重新称盲测。

启动回代脚本时曾出现 MATLAB 分析目录未加入路径及空结构数组赋值错误，均已修复；未产生模型成功结果的失败启动不计入 34 条模型尝试。尾翼源表读取的表头自动识别错误也已修复，最终定向测试实际通过。

尾翼系数 helper 的测试不表示已接入整机。飞机状态仍采用明确标记的旧尾翼混合分支，170 kt 未接受。不得把准备好的函数、未执行的组合复算入口或失败点报告为运行成功。
