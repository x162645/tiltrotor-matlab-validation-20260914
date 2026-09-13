# CR-166536 数字化表总清单

当前有效交付说明：`CR166536_CLOSURE_README_CN.md`。逐表、逐数据文件清单由 `cr166536_tables.py` 生成于 `CR166536_TABLE_CATALOG.json`；统一读取表为 `CR166536_ALL_CELLS.csv`。

本次闭合了机身 Table 3-I–IX、机翼 Table 4-I–XVI、平尾 Table 5-I–VII、垂尾 Table 6-I–VIII 的全部数字化续页，并纳入已有旋翼限制、旋翼—平尾干扰和操纵表。四个机体气动模块共 46 张表/子表。

| 数据文件 | 记录 | 有数值 |
|---|---:|---:|
| CR166536_DIGITIZED_TABLES_BATCH1.csv | 492 | 492 |
| CR166536_DIGITIZED_TABLES_BATCH2.csv | 418 | 418 |
| CR166536_DIGITIZED_TABLES_BATCH3_SIDE_SLIP.csv | 73 | 73 |
| CR166536_DIGITIZED_TABLES_BATCH4_WING_T4I.csv | 140 | 96 |
| CR166536_DIGITIZED_TABLES_BATCH4_FUSELAGE_ALPHA.csv | 93 | 93 |
| CR166536_DIGITIZED_TABLES_BATCH5_FUSELAGE_SIDESLIP_MOMENTS.csv | 57 | 57 |
| CR166536_DIGITIZED_TABLES_BATCH6_WING_PYLON_CONSTANTS.csv | 35 | 35 |
| CR166536_WING_T4II_VIII.csv | 1,021 | 980 |
| CR166536_WING_T4IX_XVI.csv | 81 | 81 |
| CR166536_HTAIL_TABLES.csv | 718 | 541 |
| CR166536_VTAIL_TABLES.csv | 1,194 | 1,025 |
| CR166536_TAIL_CONSTANTS.csv | 35 | 35 |
| 合计 | 4,357 | 3,926 |

其余 431 条为未定义、空白/破折号和引用。重复源节点、合并列和范围标签保持原意，不能按记录数计算实验数量。旧机身共享行网格另 32 处破折号只保存于语义元数据，不扩充 CSV 数量。

关键差异与决定集中在 `CR166536_RESOLVED_SEMANTICS.json`，包括 l_beta 单位修正、Cm_WP 原表与正文单位冲突、短舱阻力参数量纲、源角度定义、尾翼表跨表引用以及源报告几何差异。这里不认领新整机仿真或外部验证结果。

仓库根目录复核命令：

```text
python analysis/validation_whole_aircraft_trim/data/check_cr166536_digitization.py
```

本次检查涵盖全包源页/状态/重复冲突、原图锚点以及读取器的引用、插值和域外行为，替代旧版仅检查数量的脚本。每个批次的原始 provenance 仍保留，其早先的“未全部覆盖”具有历史时间语义；本清单及闭合说明为当前状态。
