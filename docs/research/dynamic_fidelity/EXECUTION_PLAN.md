# 连续执行断点（D17，2026-09-12）

Woodgate/NUAA 接受稿已完成部件级外部检查：54 个图示 `collective pitch -> C_T` 点，附录等价动态入流与准稳态的 RMSE 已保存于 `evidence_woodgate_nuaa/run_v2/`。该结果只部分闭合通用旋翼 G1，不闭合 XV-15 系统级动态记录；候选稿已增加结果、引用和边界。

当前：D14/D15必要恢复与D16新预测实验已完成；候选稿已写入，PR78保持Draft。普通编码、定向读回和正常push均已获授权。

1. 接手与原件身份记录已保存evidence_takeover_20260912。两包校验已运行，远端1cf2419核对通过。
2. 冻结D16_PLAN_BEFORE_RUN.md，实现固定桨毂非线性/查表/切线预测，并作代表→跨工作点运行。
3. 读回MAT/CSV/JSON并独立算指标，保留失败；恢复包另列新身份。
4. 完整候选中文稿 `D16_CANDIDATE_PAPER_CN.md`、来源核验、图表/对标和局限已写入。
5. 终稿需完成一次 diff 检查、`git fetch` 后正常 push，并用远端 HEAD、关键文件哈希和 PR78 Draft 状态读回。

已排除：TM2013-217976附录B仅150 kn airplane/pilot-inch模型，不用于本次 hover 同任务验证。TM89404 Fig.13 只有 power-lever—垂向加速度背景，未闭合实际总距—载荷—升沉链。既有 M1 strict-hover Eq12 集成载荷差异已闭合，不重做。关键阻断为同步独立动态记录，不再用新增单点补偿或无依据状态替代。
