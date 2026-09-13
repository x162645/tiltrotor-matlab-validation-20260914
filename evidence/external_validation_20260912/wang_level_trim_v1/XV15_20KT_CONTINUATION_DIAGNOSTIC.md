# XV-15-like 20 kt 配平诊断（2026-09-12）

## 目的

原始正式结果在 20 kt 的残差为 0.06618，虽然 `fminsearch` 返回 `exitflag=1`，但没有达到项目可信配平门槛 0.005，因此标记为 `RESIDUAL_FAILED`。本诊断不改物理参数、控制分配、参考数据或正式结果，只改变搜索路径：速度细分延拓，并把 `fminsearch` 的初始单纯形放在种子附近的正常尺度上。

## 实验设置

- 速度：0.01、4、8、12、16、18、20 kt；每点使用前一点的可信解和左右旋翼挥舞状态作暖启动。
- 20 kt 多初值：延拓终点、原始基准初值、延拓终点加 `[+2 deg, 0 deg, +0.5 in]`。
- 可信门槛：残差范数 `<0.005`，内层物理收敛、物理解分支支持、控制不触限。
- 参考：Kleinhesselink 2007 的 GTRS 验证性仿真列；它不是原始飞行实测。

## 结果

| 项目 | 结果 |
|---|---:|
| 细速度延拓可信点 | 7/7 |
| 20 kt 延拓残差 | 2.36e-9 |
| 20 kt 多初值残差范围 | 1.92e-9 – 3.71e-9 |
| 20 kt 解（俯仰/总距/纵向杆） | 1.979 deg / 35.836 deg / 5.249 in |
| 20 kt 相对 GTRS 俯仰误差 | +1.569 deg |
| 20 kt 相对 GTRS 纵向杆误差 | -0.131 in |
| 20 kt 相对 GTRS 单旋翼推力误差 | -6.33% |

## 判断

20 kt 不是“模型一定无解”。同一模型和同一输入下，原来的零中心微小单纯形停在局部最小值；正常尺度的初始单纯形和细速度延拓都找到稳定物理解。三组不依赖 GTRS 输出的初值收敛到同一解，说明这次失败主要是求解路径问题。

求解修复只解决“能否得到平衡解”，没有自动解决“与参考模型是否足够接近”。20 kt 新解的俯仰和推力仍有明显参考差异。因此：

- 对内部配平、后续线性化和趋势筛选：新解可接受；
- 对高精度外部相关：仍需解释约 1.57 deg 的俯仰差和 6.33% 的推力差；
- 对实机动态精度或飞行品质结论：当前 GTRS 仿真对照仍不够，不能替代同步全机数据。

## 可复核文件

- `results/xv15_20kt_continuation_diagnostic_20260912/XV15_20KT_CONTINUATION_POINTS.csv`
- `results/xv15_20kt_continuation_diagnostic_20260912/XV15_20KT_MULTISTART.csv`
- `results/xv15_20kt_continuation_diagnostic_20260912/XV15_20KT_CONTINUATION_SUMMARY.csv`
- `analysis/validation_whole_aircraft_trim/run_xv15_20kt_continuation_diagnostic.m`
