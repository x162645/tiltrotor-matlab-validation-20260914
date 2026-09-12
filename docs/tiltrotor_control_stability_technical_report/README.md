# 开环操纵稳定特性技术研究报告复现说明

本目录保存通用低阶部件级倾转旋翼机模型的开环操纵稳定特性后处理、原始 CSV、图件、技术报告源文件与构建记录。既有学位论文目录保持不变。

## MATLAB 复现

在仓库根目录执行：

```powershell
& 'F:\matlab\R2021a\bin\matlab.exe' -batch "cd('E:\tiltrotor-control-stability-technical-report-20260726'); run('analysis/control_stability/run_full_assessment_batch.m');"
```

入口会重新计算九点显式配平模式数据库，并对三个代表点完成直接导数、A/B 矩阵交叉核查、九状态和十三状态模态分析、小扰动控制阶跃与图表输出。

## 报告构建

报告主源位于 `xelatex_project/main.tex`，Markdown 报告为 `TECHNICAL_REPORT.md`，可编辑 Word 报告为 `TECHNICAL_REPORT_EDITABLE.docx`。精确构建命令和当前环境限制记录在 `BUILD_BLOCKED.md` 或 `REPORT_BUILD_AND_QA.md`。

## 研究边界

结果用于通用低阶模型的机理、开环稳定性、操纵效能和模型形式敏感性研究，不用于 XV-15 定量性能复现、型号性能预测、飞行安全包线认证或正式操纵品质评级。

`run_preliminary_handling_quality_screen` 可在上述冻结线性化结果上生成初步操稳筛查表。
该表中的阈值是项目筛查门槛，不是适航标准；当前矩阵条件审计触发不确定状态，不能把
`SCREEN_PASS` 或模态指标解读为正式飞行品质等级。
