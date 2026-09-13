# CR-166536 数字化批次5：机身侧滑滚偏航力矩表

覆盖 CR-166536 附录 B 印刷页 B-30（本地 PDF 页 380）“XV-15 FUSELAGE AERODYNAMICS WITH SIDESLIP (Concluded)”中的：

- Table 3-VII：Y_beta（单位 ft²）；
- Table 3-VIII：l_beta（单位 ft³）；
- Table 3-IX：N_beta（单位 ft³）。

## 读取方法

原始扫描页高分辨率人工逐格读取；共 19 个 |β_F| 行、3 个表格量，即 57 个单元格。表中角度写为“±β_F”，CSV 的 `row_value` 保存正的绝对角度值；`value` 保存报告对正 β_F 给出的数值。

页脚给出符号规则：当 β_F 为正时取表中符号；当 β_F 为负时，Y_beta、l_beta、N_beta 均取表中数值的相反号。因此 CSV 没有伪造负角度行，后续查表接口应根据输入 β_F 的符号应用该规则。

破折号不适用于本三张表（所有单元格均为可读数值）；未做插值或拟合。`read_status=confirmed_visual` 表示对应数字在原始扫描图上清晰可读。

## 本次单位更正

旧版 CSV 的 l_beta 单位 ft² 是转录标注错误；已更正为 ft³，19 个数字均未变化。依据为 A-43/PDF111 直接列出的 ft³，以及 A-44/PDF112 方程 l_F=q_F*l_beta：动压 lb/ft² 乘 ft³ 才得到 ft·lb。源 B-30 本身没有重新标单位。
