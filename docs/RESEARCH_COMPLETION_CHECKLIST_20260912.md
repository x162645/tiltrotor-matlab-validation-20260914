# 倾转旋翼整机研究闭环清单（2026-09-12）

本清单把“代码完成”“内部数值完成”“外部证据完成”和“可发表主张”分开。`DONE` 只表示有文件和实际运行证据；`BLOCKED` 表示依赖当前公开资料中不存在的关键记录，不能用假设值填充。

|阶段|内容|状态|证据或断点|
|---|---|---|---|
|S0|仓库、分支、HEAD、规则和历史成果冻结|DONE|当前分支 `research/dynamic-fidelity-benchmark-20260910`；本地与 `research-origin/main` 已同步到合并提交 `b3965e8`，GitHub 公开交付已核对|
|S1|状态、控制量、坐标、单位和左右旋翼符号合同|DONE|`docs/CONTROL_CONVENTIONS.md`，`tests/check_control_architecture.m`|
|S2|公开 XV-15 参数来源、单位换算和角色台账|PARTIAL|公开 NASA 几何、旋翼和试验表已接入；专用受载桨距、C81 参考弦偏置和部分质量属性仍 UNKNOWN|
|S3|旋翼 BEMT、挥舞、诱导、短舱角和力矩接口|DONE_WITH_LIMITS|`model/rotor_model_bemt.m`、`model/berger13/rotor_model_bemt_berger13.m`；低总距负推力分支尚未建立|
|S4|机翼、机身、平尾、垂尾和统一 CG 力矩合成|DONE|`model/berger13/total_forces_moments_13x10.m`；旋翼和翼面按实际 CG 重算|
|S5|六自由度整机状态方程|DONE_WITH_LIMITS|`model/berger13/tiltrotor_eom_13x10.m`；变惯量 `dI/dt*omega` 已加入并通过闭合测试，移动质量加速度和高阶传动耦合仍未实现|
|S6|短舱执行器、角度/力矩命令和限制|DONE_WITH_PLACEHOLDER_PARAMETERS|接口、限幅、延迟和反力矩已实现；数值参数仍为 `RESEARCH_PLACEHOLDER`|
|S7|多初值配平、邻域延拓和回代|DONE|`analysis/berger13/trim_berger13_symmetric.m`、`tests/check_berger13_formal_trim.m`|
|S8|数值线性化、模态跟踪、控制导数和时域响应|DONE_FOR_INTERNAL_MODEL|`analysis/berger13/*`、`analysis/control_stability/*`；不是实机飞行品质认证|
|S8b|成熟动态入流强基线和适用域门禁|DONE_WITH_INTEGRATION_BOUNDARY|`model/inflow/pitt_peters_dynamic_inflow.m` 三状态 Pitt–Peters 方程与 5/5 MATLAB 检查通过；当前 Berger13 仍为标量诱导速度接口，未冒称已集成整机|
|S8c|速度—短舱角过渡配平包络入口|DONE_FOR_NUMERICAL_SCOPE|`analysis/berger13/run_berger13_transition_envelope.m` 及 6/6 合同检查；保留失败点，不等同飞行走廊或外部验证|
|S9|NASA OARF Run 15 部件外部比较|DONE_NEGATIVE|当前 M0：CT/CP/FM MAPE = 56.42/62.61/23.02%|
|S10|NASA OARF Run 14 运行级外部比较|DONE_NEGATIVE|当前 M0：56.19/64.08/19.12%；同一 OARF 系列，非盲测|
|S10b|Betzina 低速前飞单旋翼证据与运行状态合同|ARCHIVED_PLUS_CURRENT_DIAGNOSTIC|旧提交归档 Fig.16/Fig.18 共 24 个图表数字化工况；当前 HEAD 身份闸门 PASS，但两控制 alpha=0 快速检查固定 CT 合同 0/4，不能把物理解算收敛误称为运行状态匹配|
|S11|NASA WADC 跨设施冻结比较和强基线|DONE_WITH_CAVEAT|15/15 点收敛；冻结 M1 相对 M0 改善，但绝对 CT/CP 仍偏大|
|S12|同步全机过渡时历、整机动态误差和实机飞行品质|BLOCKED|缺少匹配的实际总距/执行器、旋翼载荷、质量 CG 惯量、转速和统一时间基准|
|S13|中文完整候选稿、图表、复算入口和限制|DONE_FOR_SUPPORTED_SCOPE|可支持“低成本方法+部件外部检查+条件性整机分析”；不能写成全机动态精度或国内领先|
|S14|可复核发布包|DONE_WITH_WEB_UPLOAD|完整源码包、关键入口和新增增量已通过普通 Git 合并推送至 `https://github.com/x162645/tiltrotor-general-validation` 的 `main`；远端最新提交为 `b3965e8`|

## 本轮实际执行

- MATLAB R2021a：整机内部检查、Berger13 配平/线性化/模态/时域流程、OARF Run 14/15 外部比较、WADC 跨设施比较。
- 独立 Python：从逐点 CSV 重算 OARF MAPE，结果与 MATLAB 一致。
- 未修改原始 NASA PDF，也未根据外部目标反调参数。

## 必须保留的阻断

1. `params_berger13.m` 中短舱 I/D/K、角速度限制和执行器带宽是研究占位值，不能冒充 XV-15 实测值。
2. 旋翼外部误差不是单一参数缺失；它是受载桨距映射、C81 参考弦、低阶截面气动和尾迹/旋转效应共同造成的未闭合问题。
3. 没有同步全机记录时，不能完成可复核的 XV-15 整机动态精度和实机飞行品质验证。

这些阻断不妨碍提交限定范围的候选稿，但会阻止更强的全机和“国内领先”表述。

## 模型身份决策

主模型采用 `TILTROTOR_GENERIC_CORE` 身份：方程、状态、部件接口和数值方法面向可换构型的通用倾转旋翼机。XV-15 只通过独立的 `XV15_VALIDATION_ADAPTER` 参数包进入验证，不把 XV-15 的不完整参数、试验总距偏置或外部误差反写进通用核心。

因此：

- 没有完整 XV-15 参数时，仍可完成通用模型、方法比较、部件外部验证和限定任务的操稳研究；
- 只有在 XV-15 参数和同步记录达到同构要求时，才增加 XV-15 整机定量验证；
- 论文不得把通用核心写成 XV-15 完全复现，也不得把某一 XV-15 调参结果称为通用模型领先；
- “国内领先”必须在预先定义的通用任务、输入、输出、基线、计算预算和独立测试集上比较得出。

## 目标成功率（当前证据下的条件估计）

这些是资源和证据条件下的工程判断，不是结果承诺：

|目标|当前估计|主要决定因素|
|---|---:|---|
|可运行的通用整机过渡模型和操稳计算|80%–90%|现有 13 状态接口、配平、线性化和控制链已存在；主要风险是补齐真实短舱/传动参数|
|有外部部件证据的《航空学报》候选稿|60%–75%|需要至少一个独立部件数据集、成熟强基线和清楚的误差—成本贡献|
|有同步数据支撑的 XV‑15 整机动态精度|15%–25%|取决于能否取得匹配质量、CG、惯量、实际输入、转速和全机时历|
|限定通用任务内的国内领先证据|25%–40%|取决于同任务强对手、独立测试集和优势是否跨工况稳定|

目标修改后的主交付是第一、第二项；第三项只在外部记录达到高同构性后启动，第四项只能在比较完成后决定。

