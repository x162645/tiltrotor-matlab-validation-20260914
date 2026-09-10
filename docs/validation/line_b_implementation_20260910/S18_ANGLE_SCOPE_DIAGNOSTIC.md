# S18：有效角、单位面积升力与输出范围的有限判别

## 来源与方法

- 原始输入和 17 行分项载荷：NASA CR-166537，PDF 100/101、103/104、106/107、109/110（印刷 A-10/A-11、A-13/A-14、A-16/A-17、A-19/A-20），沿用 S15 已归档 CSV。
- 自由流有效角和系数：NASA CR-166536 Sep1988 RevA，A70/PDF138、B33/PDF383、B36–B37/PDF386–387、B41–B42/PDF391–392、B51/PDF401；使用现有 `gtrs_wing_freefield_angle` 与 `gtrs_wing_heli_coefficients`，不修改函数。
- 方法：对四个已归档状态分别计算机体角 `alphaBody`、V6 `alpha_WFS`、源表 `CL/CD`，并从原始 `WING_FREESTREAM` 力反算两种角定义下的等效系数。`alphaRequiredFromCLV6` 只是在单调的 -16° 到 12° 源表分支上给出诊断角标签，不写回参数或目标函数。另列出原始合计中独立的发动机短舱/喷流和桨毂罩载荷。

MATLAB R2021a 实际执行命令：

```text
cd('C:\lb'); run('startup.m');
addpath('analysis/validation_whole_aircraft_trim');
addpath('analysis/stage2_aircraft');
run_line_b_s18_angle_scope_diagnostic('docs/validation/line_b_implementation_20260910/handoff_evidence/A39_S18_ANGLE_SCOPE');
```

执行结果：`checksPassed=43`，旋翼求解 0 次，整机配平 0 次，`productionPhysicsChanged=false`，`targetFit=false`，`externalAccuracyPass=false`。输出在 `handoff_evidence/A39_S18_ANGLE_SCOPE/`，由 CSV、JSON 和 MAT 组成。

## 结果

|速度|V6 有效角相对机体角的偏移|V6 源表 `ΔCL=CL_eq−CL_source`|机体角源表 `ΔCL`|机体角相对 V6 的升力 Z 变化|V6 诊断面积比 `CL_eq/CL_source`|
|---:|---:|---:|---:|---:|---:|
|40 kt|−0.939°|+0.2041|+0.1447|−53.2 lbf|1.372|
|60 kt|−0.914°|+0.1349|+0.0784|−114.5 lbf|1.364|
|80 kt|−0.717°|+0.0481|+0.0039|−160.5 lbf|1.278|
|100 kt|−0.524°|≈0|−0.0321|−182.8 lbf|0.962|

把有效角退回机体角会增加源表升力，能缩小 40/60/80 kt 的一部分差距，但 100 kt 会使源表升力超过原始等效值；四点都不能由单一角定义变化解释。即使只把覆盖面积作为诊断比例，40/60/80 kt 仍需约 1.37/1.36/1.28 倍当前自由流系数载荷，不能把该比例写回面积参数。

原始输出的 `WING_FREESTREAM` 与 `ENGINE_PYLONS`、`JET_THRUST_TOTAL` 分列；40/60/80/100 kt 的后两项合计分别为 X = −97.5/−180.8/−305.5/−466.5 lbf，Z = −16.3/+12.8/+50.6/+99.4 lbf。当前源系数函数元数据标明 `containsPylonEffects=true`，而当前装配没有独立发动机短舱/喷流模型。两种载荷范围之间没有足够的原始字段对应关系，不能直接相加而宣称修复，也不能把其全部差额归因于有效角。

## 结论与限制

S18 关闭了“密度舍入或单一有效角即可解释单位面积升力差”的假设：角定义是低速敏感因素，但不是四点共同的充分解释。S15 记录的 `CR166537` 输出版本与 `CR166536 RevA` 系数修订版本仍未被原始文件元数据证明为同一版本；该项保持 **OPEN**。部件包含范围同样保持 **OPEN**，在得到明确的源输出版本/字段定义前不实施新的翼系数、面积、发动机短舱或喷流模型，也不重跑既有 27+24 点回归。

