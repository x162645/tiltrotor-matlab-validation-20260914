# 本轮实际计算与复算

## 已执行结果

MATLAB R2021a 实际求解并接受 22 个正向速度点：0.01 kt、5–105 kt 每 5 kt。0 kt 因现有机翼、机身、平尾和桨毂罩接口明确要求 `x(1)>0` 而跳过；0.01 kt 是单独标注的近悬停正向点。

40–85 kt 的 10 点使用原 V7 的 `fminsearch` 数值协议。其后改用阻尼 Newton 延拓：中央差分、至多 10 次迭代、回溯保持原边界和物理分支、目标残差小于 1e-8；失败才回退原 `fminsearch`。改变原因是每点原本需要约 300–400 次完整机理求值，与参考曲线误差无关。

切换前，用已接受的 65 kt 完整状态作为初值，重新求解 70 kt，并与旧 70 kt 解核对。俯仰角、总距、杆位和总轴功率的最大相对差为 1.494e-8，小于预设 1e-5。新方法用了 17 次完整求值，旧方法用了 342 次；这次核对是数值求解一致性检查，不是外部验证。

余下 12 点全部由 Newton 接受，没有用到回退求解器，总耗时约 37.58 s。22 点独立 MAT/CSV 读回通过。仍有攻角表裁剪计数（最高 20），应保留为模型限制。

冻结物理设置始终是源表 V7、`P.wing.SslipMaxHalf=0`、同一 M1 旋翼、同一控制分配、同一质量/转速/几何和原接受条件。零浸入来自 40–100 kt 参考载荷的工况口径；范围外是同一配置的诊断延拓，不声称那里已验证了真实尾迹覆盖。

## 重绘（不重算模型）

在仓库根目录运行。此命令需要当前交付根目录中的 `calculation/` 与 `reference/`：

```powershell
& 'C:/Users/86173/AppData/Local/Programs/Python/Python38/python.exe' analysis/validation_whole_aircraft_trim/plot_v7_wang_speed_sweep.py --out 'C:/Users/86173/Documents/Codex/2026-09-11/yue/outputs/V7_加密速度_王梓旭对比_20260913'
```

## 已有结果的缓存恢复

V2 不是独立冷启动入口。它需要 V1 的冻结参数和已接受 65/70 kt MAT，先完成或读取数值交叉核对，再复用逐点 MAT。

```powershell
& 'F:/matlab/R2021a/bin/matlab.exe' -batch "addpath(genpath(pwd)); run_line_b_v7_speed_sweep_v2('C:/Users/86173/Documents/Codex/2026-09-11/yue/outputs/V7_加密速度_王梓旭对比_20260913/calculation');"
```

全部点与交叉核对载体存在时，不进行新模型求值。此次已在独立临时副本上实际验证缓存恢复：45 个逐点/尝试 MAT 的 SHA256 不变，重新汇总的 CSV 与原 CSV 字节一致，见 `CACHE_RECOVERY_CHECK.json`。

## 从空目录全新重算

先运行 V1 完整网格，再运行 V2。该路径较慢；本轮没有为了交付重复执行整套冷启动。

```powershell
& 'F:/matlab/R2021a/bin/matlab.exe' -batch "addpath(genpath(pwd)); run_line_b_v7_speed_sweep('C:/Users/86173/Documents/Codex/2026-09-11/yue/work/v7_fresh_recalculation'); run_line_b_v7_speed_sweep_v2('C:/Users/86173/Documents/Codex/2026-09-11/yue/work/v7_fresh_recalculation');"
```

使用真正的新目录。已有逐点 MAT 不会被覆盖；配置或物理源码不一致时拒绝恢复。图表所需参考数据不由计算器生成，应复用交付包的可追溯 `reference/` 数据。

## 元数据修订

初次冻结记录继承了参数构造函数中的 `contract.productionPhysicsModified=false`，没有正确反映本轮零浸入配置。代码现已改为 `true`，原始冻结文件和数值 MAT 保留原样；应结合 `METADATA_CORRECTION.json` 读取该字段。此修订没有改变任何已计算数值。另修复了“仅 attempt 落盘后中断”的恢复路径，使其读取既有尝试而不覆盖。

本轮是同一部件模型在密集速度网格上的真实求解，不能把数值收敛、求解器一致或源模型相关性称为实机精度或全机构型外部验证。
