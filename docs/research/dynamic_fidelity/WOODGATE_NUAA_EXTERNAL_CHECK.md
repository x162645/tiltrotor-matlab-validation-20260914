# Woodgate/NUAA 外部部件动态复现尝试（负结果）

核查日期：2026-09-12。该复现尝试用于检验通用旋翼的 `collective pitch -> C_T` 动态响应，当前结论是定量复现未闭合，不能替代 XV-15 或全机操稳验证。

## 来源与数据角色

来源为 Woodgate 等，*Simulation of step input in collective pitch for hovering rotor*，*Aerospace Science and Technology* 110 (2021) 106425，DOI [10.1016/j.ast.2020.106425](https://doi.org/10.1016/j.ast.2020.106425)。采用格拉斯哥大学 Enlighten 的官方记录和作者接受稿 [PDF](https://eprints.gla.ac.uk/226967/2/226967.pdf)。接受稿中 NUAA 旋翼为两叶跷跷板式旋翼，`R=0.54 m`、NACA23012、约 1200 rpm；输入从 `0.1 s` 开始，以约 `40 deg/s` 由初始总距斜坡增加 `4 deg`。论文将 NUAA 实验与 NACA/Carpenter 历史资料分开，不能把后者重新命名为 NUAA 实测数据。

官方材料没有提供可下载的原始数组、CSV/MAT 文件或独立数据 DOI。本次只数字化接受稿第 8、9 图中的黑色实验方点，共 57 个近似图点（初始总距 2° 和 4°）。图点不是原始采样，也不计作盲测原始数据。

## 可复核实现

脚本 [woodgate_nuaa_external.py](../../../analysis/dynamic_fidelity/woodgate_nuaa_external.py) 完成像素连通域提取、坐标变换和 Appendix A 方程的 Python 重实现。模型只积分诱导速度，按论文 Listing 2 冻结挥舞角及其导数；未用数字化点拟合参数。每个图点保留约一个纵向像素的 `C_T` 读图尺度。该实现按论文图示的 `0.1 s` 输入开始时间计算，不是接受稿 Listing 1/2 的字面执行；清单明确记录了这一身份差异。

复算入口：

```text
python analysis/dynamic_fidelity/woodgate_nuaa_external.py \
  --out docs/research/dynamic_fidelity/evidence_woodgate_nuaa/run_v6 \
  --pdf <accepted-manuscript.pdf> \
  --page14 <rendered-page-14.png> --page15 <rendered-page-15.png>
```

运行环境为项目 Python 3.12.14；这一步是 Python 重实现，不是 MATLAB 原附录代码的运行结果。

## 复现结果与失败判定

`run_v6` 生成了逐点 RMSE 诊断，但这些数值不能作为有效外部预测指标。接受稿 Appendix A 的 `rapid` 函数从 `t=0` 开始斜坡，而论文图示实验输入从约 `0.1 s` 开始；当前脚本为便于与图对齐采用了后者，因此不是原附录的字面复算。其次，按附录参数计算的初始静态 `C_T` 约为 2° 时 `0.00060`、4° 时 `0.00169`，而图 8、9 的实验方点在阶跃前约为 `0.002` 和 `0.004`，存在明显的静态量级错配。该差异远大于单像素读图尺度，说明附录参数、归一化、输入时间原点或图中数据角色至少有一项尚未闭合。

因此 `run_v6` 中的 RMSE 和读图扰动概率只作为失败复现的诊断产物，manifest 将 `quantitative_qualification=false`。不能据此说动态入流优于准稳态，也不能把该来源计作 D16 的定量外部验证。当前可保留的外部信息只有：论文确实提供了独立旋翼的集体桨距阶跃/斜坡、推力峰值和滞后现象；若要形成定量部件证据，必须先逐项核对附录实现、图轴归一化和原始数据角色，或取得作者/NUAA 原始时历。

## 证据边界

该来源仍有研究价值：它支持把 `collective pitch -> C_T` 的动态峰值、滞后和稳定过程作为后续部件模型改进目标，并暴露当前重实现不能直接支撑定量外推的失败机制。它不闭合 XV-15 的实际执行器位置—受载总距—旋翼载荷—机体升沉链，也没有六分量桨毂载荷、机体质量/惯量、倾转过渡或真实飞行记录。

原始产物、源文件哈希、逐点结果和失败原因见 [evidence_woodgate_nuaa/run_v6](evidence_woodgate_nuaa/run_v6)。
