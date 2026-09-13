# CR-166536 数字化批次4：机身攻角表

## 覆盖范围

- `TABLE_3_I`：机身升力面积量 `L_alpha*`，单位 ft²；
- `TABLE_3_III`：机身阻力面积量 `D_alpha`，单位 ft²；
- `TABLE_3_V`：机身俯仰力矩体积量 `M_alpha`，单位 ft³。

来源为 Ferguson 等，NASA CR-166536，附录 B，原始印刷页 B-26 和 B-27（本地 PDF 页 376、377）。表题为 **XV-15 FUSELAGE AERODYNAMICS WITH ANGLE OF ATTACK**。

## 读取方法

采用原始扫描页高分辨率图像逐格人工读取；数值没有插值、拟合或根据模型反算。CSV 使用长表格式，每个表格量一行。`row_value` 是左侧主 α_F 列；`row_value_equiv` 是同一印刷行右侧的等效角度列。右侧角度是报告排版中的配对角度（例如 −24 与 −156、0 与 ±180），不是额外独立的输出记录；因此没有复制成另一组输出。

表中 `--` 未出现在本批次攻角表中；若后续表出现破折号，将保持缺失，不转为零。`read_status=confirmed_visual` 表示该格在原始扫描图上清晰可读。

## 重要注记

- B-26 页脚原文：**For Table 3-I only, L_alpha from ±100 changes sign from that shown for L_alpha between ±90 degrees.** 该规则已写入 `TABLE_3_I` 每行的 `notes`，后续查表实现必须执行符号变换，不能直接把右侧等效角度当作左侧角度。
- `TABLE_3_I`、`TABLE_3_III`、`TABLE_3_V` 的列值是报告中的面积/体积量，尚未换算为无量纲气动导数；换算需要确认 GTRS 内部参考面积、参考弦长和符号约定后再进行。
- 该批次只数字化机身攻角纵向表，不代表机身侧滑表或机翼/短舱完整气动表已经完成。

## 完整性

31 个主 α_F 行 × 3 个表格量 = 93 个数据单元格；所有单元格均来自 B-26/B-27 原图。
