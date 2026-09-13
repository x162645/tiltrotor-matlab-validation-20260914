# CR-166536 机翼/短舱 Table 4-IX 至 4-XVI 数字化

本批次逐格读取原扫描 PDF 401-405 页（B-51 至 B-55），共 **81 个数值单元**。Table 4-IX、4-X 的续页均已包含；4-XIII 和 4-XIV 虽共用一张印刷表，CSV 保留两个独立表号。数据为公开报告中的源模型参数，不是本项目新取得的实验数据。

|表号|PDF页|原页|数值数|
|---|---|---|---:|
|4-IX|401-402|B-51 至 B-52|12|
|4-X|402-403|B-52 至 B-53|12|
|4-XI|403|B-53|8|
|4-XII|404|B-54|4|
|4-XIII|404|B-54|12|
|4-XIV|404|B-54|12|
|4-XV|405|B-55|14|
|4-XVI|405|B-55|7|

CSV 保留每个子表、行列轴、桅杆角、襟翼设置代码、Mach 条件、原表单位文本、上下文解析单位、参考量及坐标解释。未插值、拟合、换算或添加缺失构型节点。低 Mach 表头 `M_N < 0.2` 保留为区间条件；高 Mach 子表仅定义 `beta_m=90 deg, X_FL1`。`All` 桅杆角按原文保留，未扩展为人为离散点。源图这八张表没有印刷 `Not Defined` 单元；未提供的其他构型仍视为 `NOT_DEFINED`，不能当零。

完整字段解释、公式、表下注释、常数、源 PDF SHA-256 和单位审计在同名 `_PROVENANCE.json` 中。

## 关键单位与坐标核对

- 本报告 `beta_m=0 deg` 为 Helicopter，`beta_m=90 deg` 为 Airplane，由 B-34/PDF384 原表明确给出；未沿用其他文献相反的短舱角定义。
- 4-IX 表头没有印单位。B-51 的差商公式和 A-70/PDF138 的 degree 迎角定义支持 `1/deg`。CSV 明确这是上下文解析单位，没有乘以 57.3。
- 4-X、4-XI、4-XIV、4-XVI 为无量纲；4-XII 原表明确写 `1/deg`；4-XIII 的 `1/deg` 来自 A-71/A-74 和 B-32 的副翼导数定义。
- 4-XV 标题称“Drag Coefficient”，表头未列单位。A-75/PDF143 明确 `D_PYLN=D_PYINT*(q_iwL+q_iwR)/2`，因此 `D_PYINT` 是 `ft^2`，不能再乘机翼面积。
- 4-XVI 横轴是桅杆轴的 `alpha_bar_PYL`，不是机体侧滑角。A-76/PDF144 和 A-77/PDF145 给出 `alpha_bar_PYL=alpha_bar_SPN=atan(sqrt(U_MSP^2+V^2)/abs(W_MSP))*57.3`。
- 4-XI 原表标题使用 `|alpha_W| <= 8 deg`；脚注明确 `8 < alpha_W <= 25 deg` 线性插值、`alpha_W > 25 deg` 时 K=0。等号端点经 360 dpi 扫描复核确认。`alpha_W < -8 deg` 的扩展未给出，读取接口应拒绝该域。

## 附带单位审计（未改旧文件）

- Table 3-VIII 的 `l_beta` 应为 `ft^3`：A-43/PDF111 直接印出 `ft^3`；A-44/PDF112 给出 `l'_F=q_F*l_beta`。
- Table 4-VIII 的 `C_mWP` 表头印 `1/rad`，但 A-70/PDF138 给出 `M'_WP=q_WFS*S_W*c_W*C_mWP`，故物理量为无量纲；A-71/PDF139 还说明其在 `C_LWP approximately 0` 处选取。应同时保留原单位文本与 `SOURCE_UNIT_CONFLICT`，不可将数值乘以 57.3。

## 执行身份

Poppler 渲染后逐格视觉读取；Python 只负责 CSV/JSON 写入和读回。读回检查：81/81 值有限、81/81 来源键唯一、8 张表与两个续页齐全。未运行 MATLAB，未修改模型、manifest 或检查脚本，未提交。主任务根代理已独立以 360 dpi 重渲染 PDF403 复核 4-XI 边界符号。
