# Woodgate/NUAA 外部部件动态检查

核查日期：2026-09-12。该检查用于检验通用旋翼的 `collective pitch -> C_T` 动态响应，不能替代 XV-15 或全机操稳验证。

## 来源与数据角色

来源为 Woodgate 等，*Simulation of step input in collective pitch for hovering rotor*，*Aerospace Science and Technology* 110 (2021) 106425，DOI [10.1016/j.ast.2020.106425](https://doi.org/10.1016/j.ast.2020.106425)。采用格拉斯哥大学 Enlighten 的官方记录和作者接受稿 [PDF](https://eprints.gla.ac.uk/226967/2/226967.pdf)。接受稿中 NUAA 旋翼为两叶跷跷板式旋翼，`R=0.54 m`、NACA23012、约 1200 rpm；输入从 `0.1 s` 开始，以约 `40 deg/s` 由初始总距斜坡增加 `4 deg`。论文将 NUAA 实验与 NACA/Carpenter 历史资料分开，不能把后者重新命名为 NUAA 实测数据。

官方材料没有提供可下载的原始数组、CSV/MAT 文件或独立数据 DOI。本次只数字化接受稿第 8、9 图中的黑色实验方点，共 54 个近似图点（初始总距 2° 和 4°），并记录了 PDF、渲染页的 SHA-256。图点不是原始采样，也不计作盲测原始数据。

## 可复核实现

脚本 [woodgate_nuaa_external.py](../../../analysis/dynamic_fidelity/woodgate_nuaa_external.py) 完成像素连通域提取、坐标变换和 Appendix A 等价的诱导入流计算。模型只积分诱导速度，按论文 Listing 2 冻结挥舞角及其导数；未用数字化点拟合参数。每个图点保留约一个纵向像素的 `C_T` 读图尺度。

复算入口：

```text
python analysis/dynamic_fidelity/woodgate_nuaa_external.py \
  --out docs/research/dynamic_fidelity/evidence_woodgate_nuaa/run_v2 \
  --pdf <accepted-manuscript.pdf> \
  --page14 <rendered-page-14.png> --page15 <rendered-page-15.png>
```

运行环境为项目 Python 3.12.14；这一步是 Python 重实现，不是 MATLAB 原附录代码的运行结果。原附录清单还存在全局变量拼写疑点，因此这里明确标记为 appendix-equivalent reimplementation。

## 结果

| 图 | 初始总距 | 点数 | 方法 | RMSE(C_T) | MAE(C_T) | 最大绝对误差 |
|---|---:|---:|---|---:|---:|---:|
| 8 | 2° | 28 | 附录等价动态入流 | 0.003532 | 0.003464 | 0.006027 |
| 8 | 2° | 28 | 准稳态对照 | 0.003607 | 0.003528 | 0.006387 |
| 9 | 4° | 26 | 附录等价动态入流 | 0.004572 | 0.004549 | 0.006696 |
| 9 | 4° | 26 | 准稳态对照 | 0.004612 | 0.004588 | 0.006696 |

数字化纵向尺度约为 `5.0e-5--5.1e-5 C_T/像素`，小于模型与图点之间的主要差异。动态入流相对于准稳态在两组图点上均有小幅改善，但仍存在约 `4.6e-3 C_T` 的 RMSE；这不支持把该低阶模型表述为高精度外部预测器。结果更适合说明：输入时序和诱导速度记忆对推力瞬态有可观测影响，但冻结挥舞、简化气动和图点读数限制了定量精度。

## 证据边界

该结果把项目的 G1 外部证据从“无独立动态来源”推进到“通用旋翼部件动态证据部分闭合”：输入是 collective pitch，输出是旋翼 `C_T`，来源独立于 D16/OARF/V4。它仍不闭合 XV-15 的实际执行器位置—受载总距—旋翼载荷—机体升沉链，也没有六分量桨毂载荷、机体质量/惯量、倾转过渡或真实飞行记录。因此 `xv15_or_aircraft_validation=false`，不能据此声称 D16 已通过外部实机验证或实现国内领先。

原始产物、源文件哈希和逐点结果见 [evidence_woodgate_nuaa/run_v2](evidence_woodgate_nuaa/run_v2)。
