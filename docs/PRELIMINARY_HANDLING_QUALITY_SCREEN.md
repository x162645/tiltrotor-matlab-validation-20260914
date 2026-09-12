# 初步操稳品质筛查

`analysis/control_stability/preliminary_handling_quality_screen.m` 将一个线性化
工作点的特征值、状态参与度和控制矩阵整理成可复核的筛查表。它识别短周期、荷兰滚、
滚转沉降和螺旋运动候选模态，并给出阻尼比、自然频率、衰减率以及每弧度控制输入引起的
初始角加速度。

筛查阈值写在函数的 `default_options` 中，也可由调用者覆盖：短周期阻尼比 0.30、
荷兰滚阻尼比 0.08、滚转沉降衰减率 0.10/s，频率下限分别为 1.0 和 0.4 rad/s。
这些数值是本项目的透明筛查门槛，不是 MIL-F-8785、MIL-HDBK-1797 或适航等级标准。

运行已生成的三点结果：

```matlab
addpath(genpath(pwd));
result = run_preliminary_handling_quality_screen();
```

结果文件位于 `docs/tiltrotor_control_stability_technical_report/`：

- `PRELIMINARY_HANDLING_QUALITY_SCREEN.csv`
- `PRELIMINARY_CONTROL_ACCELERATION_SCREEN.csv`
- `PRELIMINARY_HANDLING_QUALITY_SCREEN.mat`

当前三个代表点的特征向量条件审计均触发 `SCREEN_UNCERTAIN`，因此表中不把数值门槛通过
解释成操稳品质合格。该不确定性来自线性化矩阵的模态可辨识性与状态缩放问题，不能由
软件运行成功或内部配平残差替代。要形成正式飞行品质结论，还需同构的质量、惯量、控制
输入和飞行试验响应数据，并完成适用标准的任务等级映射。
