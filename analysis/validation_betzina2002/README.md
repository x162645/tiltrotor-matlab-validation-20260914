# Betzina 2002 低速前飞旋翼外部检查

此目录恢复了 A25 阶段的验证适配器、运行脚本和两组公开图表数字化输入，作为可复核入口：

- `run_betzina2002_two_cyclic_forward_validation.m`：12 个 Fig.16 运行状态求解；
- `run_betzina2002_fig16_comparison.m`：扭矩外部比较；
- `run_betzina2002_mu017_representative_load_sweep.m`：12 个 Fig.18 再绘图代表性扫描；
- `run_betzina2002_two_cyclic_identity_gate.m`：零横向周期输入退化检查；
- `data/`：公开图表数字化值，含数字化不确定度。

现有定量结果来自归档提交 `f24ffbe55e2c87b7c54177c1c60b1367b1ff0a8e`，位于 `docs/validation/line_b_implementation_20260910/handoff_evidence/A25_FORWARD_REGRESSION/`。2026-09-12 曾在当前 HEAD 尝试重新运行双周期优化，但在本窗口内未完成，未将未完成过程当作新验证结果。归档结果只能作为单旋翼低速前飞部件证据，不能替代整机过渡或飞行品质外部验证。
