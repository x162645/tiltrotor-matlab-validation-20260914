# CR-166536 表格数字化批次 1

- **来源**：Ferguson et al., *Generic Tilt-Rotor Simulation (GTRS)*, NASA CR-166536, Appendix B, TR-1195-2 (Rev. A)。本地PDF：`outputs/Ferguson_1988_CR-166536_XV15_generic_model.pdf`。
- **页码对应**：PDF渲染页 368–374 对应报告打印页 B-18–B-24。CSV字段 `source_pdf_page` 为PDF渲染页，`printed_page` 为报告页码。
- **方法**：从原始扫描页以180 dpi渲染后人工逐格抄录；未进行曲线拟合、平滑或插值。负号、有效数字和 `>140 kt` 区间按原表保留。
- **单位**：Table 1-I/II/III、Table 2-Ia/b/c/d的表内量均为无量纲；`V_T`列为kt，`alpha_F`/`beta_m`为deg。`gt140`表示原文的`> 140`。
- **数字化表**：
  - TABLE_023：Table 1-I，最大可用旋翼推力系数 `C_Tmax/σ=f(μ,β_m)`（本页仅列μ曲线，β_m依模型调用）。
  - TABLE_001：Table 1-II上半，`C_T/σ`耐久限制表；该表是限值标记，不参与主计算。
  - TABLE_024：Table 1-II下半，侧向飞行修正因子 `X_SF=f(|V̄|)`。
  - TABLE_025：Table 1-III，并列旋翼修正因子 `X_SS=f(|μ̄|)`。
  - TABLE_002/003/004：Table 2-Ia/Ib/Ic，旋翼尾迹对平尾诱导速度比 `W_i|_{R/H}/W_i`，分别 `β_m=0°,15°,30°`；Table 2-Id（同B-24页）给出 `β_m=60°,90°` 时常数0.0。
- **校核**：Table 1-I的`c_b=14.0 in`等旋翼常数与CSV身份表及B-16原图一致；本批不覆盖B-25以后表格。
- **不确定性**：当前批次各单元在原图中均可辨认；`Table 2-Ia`中的`−.0945`、`−.623`、`−.0314`等非两位小数按原文保留。使用前应由第二名复核者逐格抽查。
