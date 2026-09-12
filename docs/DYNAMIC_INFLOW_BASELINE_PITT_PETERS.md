# Pitt–Peters 三状态动态入流基线

## 审计结论

仓库原有 `model/mean_inflow_88327.m` 是 NASA TM-88327 的轴向平均入流方程。它只有一个平均诱导速度状态，不能代表包含均匀、纵向一阶和横向一阶分量的 Pitt–Peters 三状态动态入流。此前 D03/D16 记录中的 `pp_mean` 也只是平均源方程，不能称为完整 Pitt–Peters。

本次新增 `model/inflow/pitt_peters_dynamic_inflow.m`，作为通用方法基线和公平对照。它目前是显式调用的三状态 RHS，尚未写入现有 Berger13 生产旋翼接口；因此不会把独立基线误报为已经完成的全机动态入流集成。

## 方程与约定

状态定义为

\[
\lambda(\bar r,\psi)=\lambda_0+\bar r\lambda_c\cos\psi+\bar r\lambda_s\sin\psi .
\]

代码采用旋翼盘坐标系，并将载荷输入写为

\[
\boldsymbol C=[C_T, C_{Mx}, C_{My}]^T,
\qquad \boldsymbol f=[C_T,-C_{My},C_{Mx}]^T .
\]

动态方程为

\[
\frac{1}{\Omega}M\dot{\boldsymbol\lambda}+K\boldsymbol\lambda=\boldsymbol f,
\qquad
K=\operatorname{diag}(V_T,V,V)L_0^{-1},
\]

其中

\[
M=\operatorname{diag}\left(\frac{128}{75\pi},\frac{64}{45\pi},\frac{64}{45\pi}\right),
\]

\[
L_0=\begin{bmatrix}
1/2&0&-15\pi X/64\\
0&2(1+X^2)&0\\
15\pi X/64&0&2(1-X^2)
\end{bmatrix},\quad X=\tan(\chi/2).
\]

令诱导分量为 `lambda0`，自由来流轴向分量为 `mu_z`，则

\[
\lambda_T=\mu_z+\lambda_0,
\quad V_T=\sqrt{\mu^2+\lambda_T^2},
\quad V=\frac{\mu^2+\lambda_T(\lambda_T+\lambda_0)}{V_T}.
\]

严格悬停时 `mu=mu_z=0`，因此 `K(1,1)=2*lambda0`，稳态关系退化为

\[
C_T=2\lambda_0^2,
\]

与仓库 `mean_inflow_88327` 的正推力动量约定一致。

## 输入、范围与禁止事项

- `kinematics.mu`：非负盘内来流比；`kinematics.mu_z`：有符号盘法向自由来流比（正值表示流入盘面）；`kinematics.Omega`：rad/s。
- `loads` 的量纲是 `CT, CMx, CMy`，分别按 `rho*A*(Omega*R)^2` 和其乘以 `R` 归一化。
- 默认均匀模态表观质量 `128/(75*pi)` 对应扭转桨叶 Pitt–Peters 约定；一阶模态默认 `64/(45*pi)`，可通过显式 `options.m1` 选择其他文献约定，但不应在比较中逐工况调节。
- 仅接受正诱导速度和正总通流；涡环、风车、自转和反向通流会显式报错。影响矩阵接近奇异时也报错，不用绝对值、截断或假造延拓。
- 该实现没有 XV-15 参数、经验调参或外部准确度声明；它只证明方法方程可运行并可作为同输入、同输出定义的成熟基线。

## 可复核检查

运行：

```matlab
addpath('model/inflow');
addpath('tests');
report = check_pitt_peters_dynamic_inflow();
```

检查包括：悬停动量恒等式、三状态分布合同、推力阶跃的连续尾迹记忆、前飞偏斜与力矩通道，以及反向通流的 fail-closed 行为。测试是方程和数值契约检查，不是外部实验验证。

## 来源

1. Pitt D M, Peters D A. *Theoretical Prediction of Dynamic-Inflow Derivatives*. Vertica, 1981, 5(1):21–34（项目文献表中的 `pitt1981`）。
2. NASA TM-88327, *A Comparison of Two Methods for Predicting the Dynamic Response of a Helicopter to Collective Pitch Inputs*, 1986，PDF pp. 20–22（原文 pp. 10–12），Eqs. (119)–(135)。项目内转录：`docs/research/dynamic_fidelity/evidence_d04/run_34591743296/sources/NASA_TM_88327/pdf_020.txt` 至 `pdf_022`。
3. BladeAD, “Pitt–Peters dynamic inflow model”，其公开矩阵转录与状态/载荷定义用于交叉核对：<https://bladead.readthedocs.io/en/latest/src/background/pitt_peters.html>。

这些来源支持方程形式，不等于对本项目通用倾转旋翼或 XV-15 的定量验证。

## 下一集成边界

若要把该基线接入 Berger13，需要同时扩展每个旋翼的状态向量、在盘面坐标中计算三分量载荷、把动态诱导场传入 BEM 截面速度，并重新做配平、线性化、双旋翼对称性和外部部件比较。现有单标量 `inducedVelocity` 接口不足以宣称已经完成上述集成；本文件将该缺口保留为可追踪的后续工程项。
