# Woodgate et al. (2021) source review

核查日期：2026-09-12。本文以格拉斯哥大学 Enlighten 官方记录及其开放的作者接受稿为主；没有把图中曲线数字化，也没有把图像点当作原始数组。

## 官方记录与可下载材料

- 官方记录：[Enlighten eprint 226967](https://eprints.gla.ac.uk/226967/)。记录给出作者 Mark A. Woodgate、Yongjie Shi、Thomas A. Fitzgibbon、George N. Barakos、Pan Li，题名 *Simulation of step input in collective pitch for hovering rotor*，*Aerospace Science and Technology* 110, 106425，DOI [10.1016/j.ast.2020.106425](https://doi.org/10.1016/j.ast.2020.106425)。记录状态为 Published、Refereed=Yes，在线首发 2020-12-28；论文卷期标为 2021, 110, 106425。
- 官方可下载文件仅见 `226967.pdf - Accepted Version`（CC BY-NC-ND，约 4 MB）：[PDF](https://eprints.gla.ac.uk/226967/2/226967.pdf)。该 PDF 含论文正文和 Appendix A 的 MATLAB 代码清单。 文件 SHA-256（本地下载核验）：`7AA10D15E6B4C7FDFD4470ADB9D7F87B77A910ADD7AD657005ABDC96C66D53D9`。
- eprint HTML 的 `Data Availability Statement` 字段显示 `Yes`，但记录页面没有列出独立数据集、数据 DOI、附件、CSV/MAT 文件或代码仓库链接。检查该记录的文件列表与 PDF 后，能够确认的可下载材料是接受稿 PDF；不能据此声称存在可下载的实验原始数组。

## 数据来源的分离：NUAA 与 NACA

论文明确分析两种模型旋翼（PDF 印刷页 9–10，§3.1）：

1. **NUAA 旋翼/实验**：两叶片、跷跷板式（teetering），矩形无扭转平面形；半径 `R=0.54 m`，`R/c=10`，实度 `σ=0.0637`，全叶采用 NACA23012。实验在南京航空航天大学（NUAA）的 whirling-beam rotor maneuvering flight test rig 上进行（印刷页 11–12，§3.4，Fig. 6）。论文说该实验结果此前未公开，来源为 Pan (2010) 中文博士论文（参考文献 [35]：Li, P., *Rotor unsteady free-vortex wake model and investigation on high-fidelity modeling of helicopter flight dynamics*, NUAA, 2010）。这不是把 NACA 历史数据重新命名为 NUAA。

NUAA 学位论文目录中可检索到 Li Pan（李攀）题为“旋翼非定常自由尾迹及高置信度直升机飞行动力学建模研究”的博士论文记录（公开、中文，NUAA，完成日期 2011-01-16；目录链接：[NUAA 学位论文记录](https://diss.nuaa.edu.cn/docinfo.action?id1=d92c6a0b6a3ec3034e8b4e5596742929&id2=Y%252FodkfkvfoU%253D)）。当前网络访问该记录返回 483，未能取得论文文件；Woodgate 文中只把它作为实验/模型来源引用，不能据目录记录推断原始动态数组已公开。 目录摘要本身称论文通过旋臂机试验获取悬停/低速飞行中 collective/cyclic/轴角速度突增后的旋翼载荷瞬态，并与计算比较；这支持“实验来源确有动态载荷测试”的 provenance，但不提供可下载数组。
2. **NACA/Carpenter 旋翼/历史数据**：三叶常规旋翼，半径 `5.8 m (19 ft)`，NACA23015，无扭转木质叶片，实度 `σ=0.042`，挥舞铰在转轴中心，阻力铰偏置 `0.2286 m (9 in)`（印刷页 9–10）。数据来自 Carpenter & Fridovich, NACA TN-3044 (1953)，论文称这是当时唯一可用的带集体桨距渐变验证数据。作者特别指出 NACA 文献没有完整叶尖形状，仿真叶片依据另一篇相关文献构造，因此该基准几何不完整（印刷页 10–11，§3.3）。它是复用的历史 NACA 数据，不是 NUAA 测试。

NUAA CFD 的 Table 1（印刷页 10）还列出：background mesh 19.6 million cells、blade mesh 3.1 million、overall mesh 22.7 million、spanwise points 171、airfoil points 250、720 steps/rev、unsteady residual reduction 3 orders。悬停计算使用单叶片周期域；论文称该假设用于周期稳态尾流。

## NUAA 阶跃/斜坡试验参数与图中响应

论文 Table 2（印刷页 12）给出 NUAA 试验条件：

| 参数 | 论文值 |
|---|---:|
| 转速 | 1200 RPM |
| 输入开始时间 | 0.1 s |
| 输入持续时间 | 0.1 s |
| 初始 collective pitch | 0°, 2°, 4° |
| collective pitch 变化率 | 40°/s |

正文说明输入从 0.1 s 开始、0.2 s 结束；三种初始总距各有一条响应（印刷页 13–14）。Figures 7–9（印刷页 13–15）绘制 `C_T`—time 和 pitch—time：黑色方点为实验数据，蓝色虚线为 dynamic-inflow 模型，红色实线为 free-wake 模型。文中描述：推力在输入期间近似线性上升，约 0.2 s 达到峰值，随后振荡并在约 0.5 s 内趋于稳定；初始 collective 较大时振荡幅度较小。该描述和图仅提供有限采样点/曲线，没有表格化原始采样数组、测量不确定度、传感器标定或独立数据文件。

论文还给出 CFD 复现的 4°→8° 工况（印刷页 16–19，§3.5）：实验 collective 与 thrust 的时间轨迹由曲线拟合；Fig. 13 比较实验与不同 CFD 配置，Fig. 14 给出 4°→8° 的瞬态尾迹，Fig. 15 改变 collective pitch rate。正文报告最快速率时 thrust overshoot 约 20%，但没有在表格中给出每个采样点或 overshoot 的数值数组。Fig. 15 图例明确比较 40°/s、80°/s、160°/s（实验方点仅为 40°/s，CFD 曲线为三种速率）；Fig. 13 的实验点仍以图中曲线/点存在。

## NACA 阶跃/斜坡信息

Figures 3–5（印刷页 11–13，§3.3）显示 NACA 历史数据与简单 dynamic-inflow 计算，输出包括 `C_T`、`Flap/rad`、`V/v_s`，下图为 `Pitch/deg`；图中红色方点为数据、黑线为模型。三幅图对应 collective pitch 变化率 200°/s、48°/s、20°/s；正文只明确指出 200°/s 工况与模型符合最差。论文没有为这三幅图提供可下载数组或逐点表格。NACA 叶尖几何不完整，论文明确把它作为额外不确定性来源。

## 论文中明确给出的方程和模型参数

正文 §2.1（印刷页 5–7）给出简单动态入流/挥舞方程：

- Eq. (1)：`T = m_a * d(v_ind)/dt + 2πR²ρ v_ind [v_ind + (2/3) R dβ/dt] = (1/6) N_b ρ Ω² c_e R² [θ_r − (3/2)(c_1/c_e) η v_ind/(ΩR) − dβ/(Ω dt)]`。
- Eq. (2)：`c_e`, `c_1` 为径向弦长加权量，`m_a = 0.637 ρ (4/3 πR³)`。
- Eq. (3)：`d²β/dt² + Ω²β = [1/(2γΩ²)] [ (c_2/c_e)θ − (4/3)τ v_ind/(ΩR) − (c_2/c_e) dβ/(Ωdt) ] ≡ M_β`。
- Eq. (5)：将 Eq. (3) 写成 `[β, dβ/dt]` 的一阶状态方程。
- Eq. (6)：`T = m_a d(v_ind)/dt + 2πR²ρ v_ind [v_ind + (2/3)R dβ/dt] − m_b l d²β/dt²`。

Appendix A 的 MATLAB 清单（PDF 印刷页 29–31）给出用于简单动态入流模型的一组 NUAA 量级参数：`R=0.54 m`, `R0=0.2R`, `N_b=2`, `c=ce=c1=c2=0.054 m`, lift-curve slope `a=5.73`, Lock number `γ=9`, `ρ=1.29 kg/m³`, `m_a=0.637ρ(4/3πR³)`, blade mass `m_b=2 kg`, `l=0.6R`, `Ω=125.66 rad/s`（1200 RPM），`θ0=4°`, `θ1=8°`, `dθ/dt=0.698 rad/s`（约 40°/s）。代码用 `ode45` 时间向量 `0:0.01:2`，初始状态 `[β, dβ/dt, v_ind]=[0,0,v_a]`，并以 `C_T=T/(ρΩ²R⁴π)` 归一化。清单是可复核的模型实现，不是实验测量数组；代码没有随 eprint 作为独立 `.m` 文件发布，而是嵌在 PDF 中。

## 对当前 D16 的可用性判定

- **可作为独立的通用旋翼部件动态验证（有限强度）**：NUAA 数据由另一实验平台/旋翼获得，输入为 collective pitch、输出为旋翼 `C_T`/推力瞬态，且含 0°、2°、4°三个初始点；它可用于检查模型是否能重现“0.1–0.2 s 输入、推力峰值/滞后、约 0.5 s 稳定、超调/振荡”的一般动态现象。NACA 数据也可作为第二个历史旋翼部件对照，但叶尖几何不完整、数据为图中点，独立复核能力更弱。
- **不能作为当前 XV-15/D16 的实机动态资格**：NUAA 是孤立小型 teetering rotor，未给倾转机体升沉、桨毂六分量载荷、实际执行器位置—受载总距标定或同构型边界；NACA 同样不是 XV-15。两者都不能闭合 D16 所需的“实际总距/执行器→旋翼载荷→升沉”链，也不能验证 D16 的 XV-15 OARF/V4 静态源。
- **可复核性等级**：论文和官方 eprint 足以复核旋翼几何、输入时序、RPM、初始总距和方程；但公开页面未提供原始数组/CSV/MAT/数据 DOI。图中实验点可人工数字化，却会引入读图误差，不能称作原始时历或盲测数据。若需要将其作为外部验证集，应向作者/NUAA 申请原始时历和测量不确定度，并保留原始数据 provenance。

## 官方来源

1. [University of Glasgow Enlighten record 226967](https://eprints.gla.ac.uk/226967/)
2. [Author accepted manuscript PDF](https://eprints.gla.ac.uk/226967/2/226967.pdf)
3. [ScienceDirect article record/DOI](https://doi.org/10.1016/j.ast.2020.106425)

本文件只记录官方页面/PDF中可核查的事实；未从图像反推逐点数组，也未把“Data Availability Statement: Yes”解释为已有公开原始数据下载链接。




代码清单的可执行性还需人工核对：Listing 1 的全局变量使用 `nb`，而 Listing 2 `rapid` 的 `global` 行写成 `b`，但函数体仍使用 `nb`；按 MATLAB 全局变量规则，这一处可能使代码直接运行时报未定义变量。因此不能把“附录有代码”当作已验证可执行的软件发布。



