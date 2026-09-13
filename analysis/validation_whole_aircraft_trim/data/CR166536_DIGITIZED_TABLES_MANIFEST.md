# CR-166536 数字化表总清单

本目录保存从 Ferguson 等的 NASA CR-166536（TR-1195-2 Rev. A）原始扫描页人工逐格抄录的输入表。数字化结果是“可追溯输入层”，不是外部验证结果，也没有把表格值拟合到当前模型。

| 文件 | 覆盖范围 | 单元格 | 说明 |
|---|---|---:|---|
| `CR166536_DIGITIZED_TABLES_BATCH1.csv` | Table 1-I/1-II/1-III、2-Ia/b/c/d、补充 2-II | 492 | 旋翼推力上限、侧向/并列修正、旋翼尾迹对平尾的诱导速度与 `K_Hβ` |
| `CR166536_DIGITIZED_TABLES_BATCH2.csv` | Table 5-V(a-c)、5-VI、5-VII、8a-I 至 8a-VIII | 418 | 平尾动压比、机身侧滑动压损失、操纵传动与襟翼增益 |
| `CR166536_DIGITIZED_TABLES_BATCH3_SIDE_SLIP.csv` | Table 3-II、3-IV、3-VI（B-28） | 42 | 机身侧滑导数；原表破折号缺失值不写入 |

## 页码与身份表冲突

身份参数表把 `TABLE_023` 的 Table 1-I 登记为 B-16；原始扫描页中该表标题和数值实际位于 PDF 渲染页 368、报告页 B-18，B-16 是旋翼常数页。数字化 CSV 保留原始页码 B-18，并在 provenance 中记录这一差异，避免把常数页误当成数据表页。

CR-166536 B-26 原图给出 `DLANG=-0.5 ft²`，而身份参数 CSV 的 FUSE_005 记录为 `+0.5 ft²`。该符号冲突已保留为待裁决项，不能在模型中静默覆盖。

## 未覆盖的表

CR-166536 的机身（Table 3-I 至 3-IX）、机翼/短舱（Table 4-I 至 4-XVI）、完整平尾/垂尾气动表（Table 5-I 至 5-IV、6-I 至 6-VIII）仍未全部数字化。它们必须逐页抄录并经过第二人抽查后，才可接入整机气动计算；当前模型不得把缺失表格默认为零或由已有表格外推。

## 复核命令

在仓库根目录运行：

```text
python analysis/validation_whole_aircraft_trim/data/check_cr166536_digitization.py
```

该检查只验证 CSV 完整性和单元格数量，不验证物理正确性。
