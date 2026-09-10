# 动态研发逐步台账

本台账接续S00–S18，不是重做它们。分支research/dynamic-fidelity-benchmark-20260910，继承4cd7d4c。

## D00 自主接管与资产选择

来源：本次用户授权；实际PR77 HEAD 4cd7d4c；AGENTS、CODEX_TASK、WORK_HANDOFF及Stage6/Stage8动态证据记录。
方法：只检查与启动有关的现成资料、文件/版本，不重新执行历史审计。保留旧物理与证据，新建动态基准分支。
完成：新分支已建立；原PR77和旧分支不变；没有删除、合并或外部发布。资产选择见RESEARCH_ENTRY。
重开条件：实际基础分支新增相关变化，或输入/代码依赖发生变更。保留他人S18结果。

## D01 原文动态参照与频响比较器

来源：NASA TM89428（1987，NTRS19870013257）PDF哈希252f7df0c0e05bd8dece0a923d337df2231c0148f897f0376f930f6102b90ba2，原下载run34534917058/artifact10175006778/source提交8f6fa857；同次保存TM86009（NTRS19840026374），不将两报告算成两份独立动态试验。
方法：原文因式缩写转为多项式；在jw轴保留纯延迟、右半平面极点/零点。输入/输出/单位/观测位置/工况不一致或超出来源频段即拒绝。使用log频率积分权重报告增益、圆周相位和复数相对误差，不优化符号、增益或时间对齐。
实现：df_reference、df_eval_tf、df_state_space_response、df_compare_frf；数据tm89428_reference_cases.json；测试run_dynamic_reference_tests。
参数角色：全部为来源识别响应描述，不是当前飞机输入参数。没有将参数辨识结果写入旋翼或机体以追结果。
证据级别：参照重建与合成单元测试，不是原始时历，不是新飞机动态外部验证。旧同工况缺口保留。每条频响网格129点只是数值离散，不是129个独立试验。
运行状态：EXECUTED_AND_READ_BACK；实际运行与边界见下节。不能把检查通过写成飞机验证通过。
重开条件：相关系数/输入/观测点/频段/实现变化或字节哈希异常。单位/符号合成测试必须随比较器变化回归；不因此重跑旋翼。

### D01 参照逐条定位

|ID|来源位置|输入→输出|采用频段rad/s|必须保留的限制|
|---|---|---|---|---|
|HOVER_Q_ELEVATOR|PDF113–114/124，印刷90–91/101，Eq4.9–4.10/Table4.1|实测升降舵坐标deg→抬头俯仰角速度deg/s|0.2–5|悬停控制混合索引非孤立舵面；不稳定模态与低频非线性限制|
|HOVER_AZ_POWER|PDF110/124，印刷87/101，Eq4.8|功率杆百分数→向下加速度g|0.1–3|百分数不是总距rad或0–1比例|
|CRUISE_Q_ELEVATOR|PDF147，印刷124，Eq5.10；频段PDF144|实测升降舵deg→俯仰角速度deg/s|0.3–7|170KIAS/180KCAS，不等于170KTAS；低频长周期未包含|
|CRUISE_AZCG_ELEVATOR|PDF147–148，印刷124–125，Eq5.12；频段PDF144|实测升降舵deg→CG向下加速度g|0.3–10|CG不是ICR；保留+6.70零点；等效拟合不作时域真值|

缩写因式解释PDF93/印刷70脚注；输入符号PDF19/21，工况与SCAS PDF43–45。使用原报告SCAS说明：纵向扫频pitch SCAS engaged，横侧向部分off，不能把其他数据库二手描述套成全报告全部SCAS-off。直接曲线中为便于显示绘制q/-delta_e，不改变代码保存的q/delta_e负增益。

PDF124/147及因式脚注PDF93和Eq4.8/PDF110已查看渲染原页；其余元数据同时核对解析原文。Web端PDF403、截图不可用；原PDF由真实Actions下载后本地渲染，未做OCR。所有原PDF保留，不用网页失败制造已经看过的假记录。

### D01 实际执行与读回（已完成）

执行run34535689673，计算提交962dee6cd288aed7024b9c6499734808e18ef741；真实MATLAB 9.10.0.2198249(R2021a)Update8，GLNXA64。
91项断言通过，4条参照各129个计算频点；不调用旋翼/飞机模型，不进行新配平。91是实现测试数量，516是参照离散点数量，都不是新增外部试验数量。

测试包含原始因式对多项式重建、同一传递函数的独立状态空间求值、合成2倍增益/反号/延迟响应，以及错误单位、工况、观测位置、超频段、重复频点、NaN和零响应的拒绝。

|通道|因式/多项式最大复数差|状态空间/多项式最大复数差|
|---|---:|---:|
|HOVER_Q_ELEVATOR|1.2561e-15|1.4895e-15|
|HOVER_AZ_POWER|3.4699e-18|1.9395e-18|
|CRUISE_Q_ELEVATOR|9.1551e-16|1.3369e-15|
|CRUISE_AZCG_ELEVATOR|1.6883e-16|1.6711e-16|

这些是同一已给定数学表达式的实现一致性，不是模型对飞行测量的误差；各通道单位不同，不能合成一个飞机精度指标。测试脚本记录0.433651s只是本次小规模软件测试时间，不代表后续整机实时性能。

结果artifact10175337764，原ZIP SHA256 c862c17d348abb6bec4da0992e062102914a01563ccac088dae4e24493c55cca。下载ZIP后已核对哈希并读取RUN_MANIFEST.json、REFERENCE_RECONSTRUCTION_SUMMARY.csv和DYNAMIC_REFERENCE_TEST_RESULTS.mat，三者状态一致；不是仅看workflow绿色。
原始MAT/CSV/JSON、输入载体快照和两份来源PDF已由提交7788c2e000168b9d64eb0fe3291e4bc2fc8a8273永久入Git，位于本目录evidence/。EXECUTION_INDEX.json给出原run/提交和各文件哈希。不必依赖临时下载地址或重跑已有模型。

离线复现程序（不需要Control System Toolbox）：

```matlab
addpath(fullfile(pwd,'tests','dynamic_fidelity'));
run_dynamic_reference_tests(fullfile(pwd,'results','dynamic_reference_reproduction'));
```

这会执行参照与比较器的软件测试，不是飞机动态验证。当前四条参照first_principles_comparison_ready均为false，原试验质量/CG/惯量、环境/RPM及输入链缺口没有消失。不得复制这些已识别传递函数作为新的部件模型，再与自身比较宣布通过。

## 下一步D02（未实施）

显式动态部件接口与首个可计算纵向—升沉原型；先稳态极限、局部线性/非线性一致性，再决定有资格的外部通道。继承旧动态同工况限制，不把D01来源响应直接复制成新的飞机模型。不声称国内领先；公平基线与独立数据仍需后续建立。

D02应首先确定一个有明确输入含义、可重复计算的工作点及控制接口，再选择最小必要的动态气动状态。不得把任意一阶滤波器套在静态载荷外就称为有依据的动态模型；不得直接把巡航参照用于现有40–100kt直升机算例。若新增参数需要辨识，单列校准数据和保留检验，不能覆盖原无目标拟合基线。模型改动完成后必须执行对应数值一致性与必要回归，而非再次普查所有历史来源。

## D02 implemented

The opt-in service `services/run_d02_longitudinal_heave.m` now provides a fixed-nacelle longitudinal/heave prototype. The production nine-state nonlinear EOM is reused; induced velocity is promoted to one state per rotor, actuator commands are explicit collective/cyclic/elevator states, and `hUp` is inertial altitude positive upward. Current inflow is passed into the rotor blade/flap/load calculation, while each rotor momentum relation supplies the target for the inflow derivative.

Verification gates executed in MATLAB: production trim residual closes (rigid-body 9.193e-05, inflow 3.794e-03); local Jacobian is finite with dimensions 15x15 and 15x3; nonlinear 0.2-degree elevator perturbation remains finite; every sample exposes Fx/Fz/My, rotor thrust/inflow, and rotor/wing/fuselage/tail snapshots. These are implementation and consistency checks, not flight-test validation. The new time constants are assumed research parameters and remain subject to qualified external comparison.
