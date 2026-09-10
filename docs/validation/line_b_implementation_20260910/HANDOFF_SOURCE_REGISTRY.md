# 交接来源注册表：身份、位置、用途与限制

2026-09-10。目录中的 `handoff_evidence` 是原始字节永久副本；每个文件的SHA256、来源run/artifact及代码提交见ARCHIVE_INDEX.json。以下页码采用PDF一基页码，并明确另列印刷页。历史原页检查沿既有证据复用；本次交接没有重审全部文献。

## SRC-01：Kleinhesselink 2007

题名：Stability and control modeling of tiltrotor aircraft。
原址：https://drum.lib.umd.edu/bitstreams/6dcf466c-961a-4384-aae7-287ab7e7fd7d/download
SHA256：`9f3c1cddf517b6bffca24e9afeae324383678d94338716d0ffa7742075db0bc4`。
永久副本：`handoff_evidence/A03_SOURCE_GTRS/Kleinhesselink_2007.pdf`。

角色分开：Appendix B为低阶参数/控制来源；Appendix C Table C-1的GTRS列为参考仿真输出，Math Model列是另一模型，Figure14飞行趋势不能冒充数字化精度表。
参数主要印刷149–152/PDF165–168、印刷171/PDF187；控制印刷164–165/PDF180–181；Table C-1状态印刷175–176/PDF191–192、部件印刷179–182/PDF195–198。
第3.1节印刷70/PDF86和文献表印刷235/PDF251把原GTRS输出指向SRC-03。保留旧转引错误，使用SRC-03闭合总量；不把旧数据悄悄改成新值。

## SRC-02：Ferguson NASA CR-166536，Sep1988 RevA

原址：https://rotorcraft.arc.nasa.gov/Publications/files/CR-166536_882.pdf
SHA256：`a2013a314af5beb0c5e9bc5bbeb26f99be9a8aa63f2ebe07deaaf11d0d44d67d`。
永久副本：`handoff_evidence/A03_SOURCE_GTRS/NASA_CR_166536.pdf`，538页。
角色：GTRS方程和源系数；被用于模型形式/参数，不作为独立飞行试验。

|内容|印刷位置|PDF页|具体用途|
|---|---|---|---|
|旋翼到尾部|A38–A40，B22/B25|106–108，372/375|带符号比例、左右平均诱导、零侧滑、稳态输运|
|尾部完整局部流/动压/系数|A85–A88，B49/B56–58/B62–65|153–156及对应B页|V3分开升力角、阻力角、力方向、动压；不重复旧incidence/tanh|
|机翼自由流/本征矩|A69–A71/A74/A181，B33|137–139/142/249，383|V5/V6系数适用、统一alpha_WFS、q_free*S_total*c*Cm|
|机翼系数族|B36/B37/B41/B42/B51|386/387/391/392/401|低Mach、直升机、flap40/25的CL/CD/Cm；不再重复旧诱导阻力|
|桨毂罩|A75/A76，B33，A232|143/144，383，300|V7独立阻力面积与速度、力臂，单个基准面积1和5.5ft²|
|升降舵传动|B88|438|4.167deg/in与4.8in中立；不解释所有旧输出映射差异|
|旋翼入流坐标|A18/A20/A24/A25，B31|86/88/92/93，381|早期lambda转纯诱导；后续优先用SRC-03直接记录Wi|

同一报告的源系数和输出版本未被证明完全一致。B36的-12deg CL=+0.0628已在原页核查及S15代码节点测试中记录，不能为追残差改符号。机身DLANG与输出差额不授权加拟合阻力；短舱/喷流必须明确包含范围后再建模。

## SRC-03：NASA CR-166537 原始GTRS输出

原址：https://rotorcraft.arc.nasa.gov/Publications/files/CR-166537_883.pdf
SHA256：`9a0888d19929747d079e79582c5172f5ea0ac526e14de87a0547b5ee2ae6340a`。
永久副本：`handoff_evidence/A32_ORIGINAL_SOURCE/NASA_CR_166537.pdf`，278页。
角色：原始参考仿真打印输出，不是飞行数据。

40/60/80/100kt状态PDF100/103/106/109；载荷PDF101/104/107/110，分别印刷A-11/A-14/A-17/A-20。读取方法为原页目视转录，保留印刷精度，非OCR推断。
机器载体：`analysis/validation_whole_aircraft_trim/data/CR166537_HELI_4POINT_INPUTS.csv`、`CR166537_HELI_4POINT_LOADS.csv`、`CR166537_REFERENCE_PROVENANCE.json`。
机体合计含engine pylons/jet等，旋翼合计含hub spinner；不能只加选定部件就宣布原始总量有错。原qdot并非严格为零；舍入区间不是实验置信区间。
原始Wi直接作为条件回放输入；输入的旋翼载荷/速度不再认领为该次验证的输出。浸没区载荷为0不证明真实浸没面积为0。

## SRC-04：Koning NASA/CR-2016-219086

原址：https://rotorcraft.arc.nasa.gov/Publications/files/Koning%20CR-2016-219086_FINAL.pdf
SHA256：`225e8ba7ff647dfd396a6287e592f9b4b44f94ad05199c9e937ff1b4ca857adf`。
永久副本：`handoff_evidence/A12_ROTOR_DISCONTINUITY/Koning_CR2016_219086.pdf`。
印刷20–21/PDF36–37，式17–20：旋转修正的正升力条件与高迎角渐退。V4从近似alpha>0改到CL_base>0，是有来源动机的新修订，不声称逐字原式或全导数光滑。n=1为固定模型选择，不是唯一通用常数；不采用为XV15相关调过的n=1.8作为独立验证。

## SRC-05：既有OARF/WADC实验载体与C81/几何输入

原实验数值继承NASA CR-2017-219486 Appendix A Table A-2(OARF)、A-3(WADC)对应的现有载体；回归不重新数字化。
路径：`analysis/run_m1_stage3_corrigan_stall_delay.m`中的Run15六点、`analysis/run_xv15_v1_run14_external_validation.m`中的Run14数组、`analysis/data/xv15_wadc_metal_table_a3.csv`。
原始载体与运行环境的来源限制保留：密度/声速/桨叶质量等是继承约定，不是本次重新确认的试验事实。需要原实验页时沿上述已记录来源查具体表，不重新广泛检索。
回归脚本：`run_line_b_independent_rotor_regression.m`；标准CT=T/(rho*A*Vtip²)，CP=Q*Omega/(rho*A*Vtip³)。6–11deg窗口只保留真实存在数据，WADC各Run为6/8/9/10/11，无插入7deg。
正式旋翼依赖由`stage2_matched_rotor_parameters.m`、`analysis/xv15_c81*`和`analysis/stage2_aircraft/m1_evidence_v1_forward_rotor.m`固定；不要换另一个实现继承验证标签。

## SRC-06：既有Betzina 2002前飞试验验证分支

固定提交：`1c4ebc307717bbd74ad22da66ed8dfbdc3001395`，分支`diagnostic/betzina-80x120-forward-validation-20260907`；没有合并到当前分支。
源代码/数据永久副本：`handoff_evidence/A25_FORWARD_REGRESSION/source/analysis/validation_betzina2002/`。
原图Fig16十二点与Fig18二次转绘十二点必须分开；CSV均标FIGURE_DIGITIZATION，不等于原始机器可读试验数据。mu、轴角、CT/sigma及挥舞操作条件见原CSV与代码，重复性单位不能作为事后PASS门槛。
方法：原两周期适配器只换helper/函数名，零横向周期做与正式后端的一致性门；只求推力和一阶挥舞约束，扭矩是预测，不进残差。生成后的适配器已一并归档。delta3装置差异和翼型截断不被回归消除。

## SRC-07：继承主线与静态参数身份表

既有主线：`docs/VALIDATION_MAINLINE_SYNTHESIS.md`、`docs/PARAMETER_GAP_REGISTER.md`、`results/m1_stage5_wadc_holdout/`。M0冻结27f4088；M1_HOLDOUT冻结d313296a。只作为继承项目资产定位，不在交接中重新认证全部历史。
另从用户已保存文件恢复`PARAMETER_IDENTITY_FIELDS_AUDITED.csv`，原73行/22列，审计提交9d0c2ab，SHA256=`4f3cc72898600c6f87caa8cd8f30254111e26343837b5a10ceb4ba75ba0ddd07`。
仓库可读摘录见`handoff/HISTORICAL_PARAMETER_AUDIT_EXTRACT.csv`与配套说明：保留全部73个字段的值、单位、来源页、转换、分类和限制，删去重复URL列以降低接手阅读量。原完整CSV同时永久存于handoff/PARAMETER_IDENTITY_FIELDS_AUDITED.csv，随交接下载包保留。它是历史静态审计，54条STATIC_CODE_VERIFIED、19条STATIC_CODE_READ，全部NO_MATLAB_RUN；不得作为V7全参数已验证的证明。

## 通用单位与来源使用规则

机体系x前/y右/z下，betaM=0为直升机模式；长度m、力N、矩N*m、角rad。ft→m为0.3048，in→m为0.0254，lbf→N为4.4482216152605，ft*lbf→N*m为1.3558179483314。位置先按同源轴向转换再减CG一次。源站位名称相同不自动证明跨文献基准相同。
输入源、输出对照、模型形式源分别标记；同源模型相关性不能升级为独立飞行验证。后处理反算的CL/CD只是诊断输出，不得写回参数。历史图像PENDING标志与后续具体原页核查分开留档，不回写旧运行清单。
