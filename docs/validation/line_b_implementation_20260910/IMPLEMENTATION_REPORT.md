# 线B：首轮实现与真实MATLAB外部复评

日期：2026-09-10
状态：IMPLEMENTED_TESTED_NOT_PROMOTED。
总体任务状态：整机外部验证尚未完成，未宣布模型通过。

## 1. 已实施内容与版本

本轮已完成固定输入部件外部对照、原始GTRS模型关系核查、可选旋翼—平尾局部流动接口实现、真实MATLAB测试，以及四个规定速度点的整机复评和两次有界初始化复查。结果不是全面改善，新增方案保留为诊断候选，不替换原基线。

基线：9d0c2abce6a3367ec8c46ca7aeb534b45b8ed728。
任务分支：implementation/line-b-external-validation-20260910。
Draft PR77，未合并：https://github.com/x162645/tiltrotor-matlab/pull/77 。
物理改动提交：e76ed614f83eeea842caca4a109034997dbd510f。
最后计算提交：811765fe07b495e8cec111c1a37ce8c49f520ac0；相对上一提交只恢复历史初值，不改变物理或容差。
历史基线产物的实际源提交是1d99311d33753c0006ac08fb3e374b99123c48dc，不能改记成后续快照9d0c2ab。

本报告所在归档提交只追加证据和任务状态，不改变计算版本。候选仅在analysis/stage2调用链显式启用；生产默认参数和默认四参数平尾调用保持原行为。

## 2. 已核原始来源

Kleinhesselink (2007), Stability and control modeling of tiltrotor aircraft，Appendix C, Table C-1：GTRS状态/操纵为印刷175–176页、PDF191–192页；40/60/80/100 kt部件载荷为印刷179–182页、PDF195–198页。上述表页已逐页查看图像，没有把Math Model列混入GTRS列。
原文：https://drum.lib.umd.edu/bitstreams/6dcf466c-961a-4384-aae7-287ab7e7fd7d/download 。
PDF SHA256：9f3c1cddf517b6bffca24e9afeae324383678d94338716d0ffa7742075db0bc4。

GTRS是参考仿真，不是原始飞行试验。部分分项与汇总不闭合，差额保留，没有修改参考数值或把差额认领为遗漏物理项。部件表支持描述性对照，不构成闭合的外部误差预算。

新增模型关系实际来自Ferguson, NASA CR-166536, September1988 Rev.A，而不是将CR-114614自动当成同一版本。
原文：https://rotorcraft.arc.nasa.gov/Publications/files/CR-166536_882.pdf 。
PDF SHA256：a2013a314af5beb0c5e9bc5bbeb26f99be9a8aa63f2ebe07deaaf11d0d44d67d。
已查看Table2-Ia B-22/PDF372，Table2-II B-25/PDF375，A-39/A-40 PDF107/108。采用原表带符号比例、左右旋翼平均诱导速度、零侧滑修正和稳态传输极限，没有拟合TableC-1输出。

本关系与GTRS比较对象共享模型信息，因此属于参考引导的诊断与相关性复评，不是独立盲验或飞行验证。

## 3. 固定输入诊断

首轮MATLAB运行34467434707，artifact10148128888，源0fdf4bd3。24条主要部件评估记录，另有24次整体基准平移不变性复算，共48次部件函数调用；97项断言通过。没有旋翼求解或整机配平搜索。manifest的componentEvaluations=24仅指主要记录。

使用参考速度、迎角、姿态及零侧滑/角速度；两套圆整状态分别为速度+迎角与表列U/W。平尾比较直接输入参考实际舵角以及当前杆位映射两种情况。

以下为速度+迎角、参考实际升降舵输入；M单位lbf*ft，绕重心：

|kt|机身M代码|机身M参考|平尾M代码|平尾M参考|
|---:|---:|---:|---:|---:|
|40|-600.302|-598.520|1716.530|-1619.000|
|60|-2112.428|-2107.490|4442.424|-1665.800|
|80|-5311.028|-5308.990|8034.374|689.590|
|100|-10470.380|-10466.280|8201.108|6856.200|

60kt平尾Z代码+206.227lbf，参考-78.060lbf；M差+6108.224lbf*ft。改用当前杆位映射后M约4588.076，只较实际舵角评估改变145.651，不能解释其余差异。

机身M接近不等于机身整体已验证。60kt机身X代码-21.948、参考-42.620lbf；80kt代码-29.953、参考-104.000lbf。力和力矩必须分别评价。

成立：相同参考状态下原平尾载荷仍有明显差异，不能仅归因于配平姿态或杆位映射不同。
不成立：全部差异必然来自缺少旋翼尾流；四个点等于连续区间验证。

## 4. 代码与内部测试

horizontal_tail_model增加可选第五参数flow，明确输入机体系附加相对气流；旧四参数调用保持。现有机翼下洗和有效安装角未改。
rotor_tail_interference_heli采用原表；stage2_total_forces_moments仅在P.interference.rotorToTailModel显式设为FERGUSON_1988_TABLE_2IA_STEADY_HELI时启用。
原表相关区域比例为负，betaM=0时W_add=-Wi_tail，因此产生正的相对垂向气流。不能截除负比例或笼统当成额外正下洗。

限制：仅betaM=0、零侧滑、零角速度、M<0.2、alpha在-30..20deg、V<=140kt；越界报错。没有动态滞后或全转换实现，不能直接用于非零角速度扰动。
未改变旋翼/C81/挥舞物理、翼身尾系数、质量/力臂、控制传动、残差门限或求解设置。这是隔离机制，不是确认其他部分全部正确。

MATLAB环境：9.10.0.2198249(R2021a)Update8，GLNXA64。
17项接口、原表节点、符号与越界检查通过；零附加速度精确复现旧平尾输出。这是内部核验而非外部精度通过。
运行34468711757/artifact10148645767重新执行固定输入诊断；三份CSV与修改前逐字节相同，默认路径回归通过。
原始manifest中的IMAGE_PENDING是运行时状态；后续图像核查见SOURCE_IMAGE_REVIEW.json，不改写历史产物。

## 5. 整机复评与失败保留

第一轮运行34468711818，40/60/80/100kt，初值取历史模型的圆整结果，不取GTRS目标。
40/80kt闭合；60kt残差不合格；100kt全部79次评估挥舞失败。exitflag=1不能代替残差验收。
随后只对60/100kt恢复原MAT完整精度外层状态和左右旋翼挥舞初值，使用已有stage2Numerics接口，运行34469617587。物理、容差和迭代上限不变。
两个点仍未达到原门限0.005：60kt为0.334525200388945；100kt为0.454928255180449。本次恢复初值不足以获得合格解，不能因此排除所有数值因素或断言不存在物理解。没有继续升级求解器。

|kt|原姿态deg|新增姿态deg|GTRS姿态deg|新增数值状态|
|---:|---:|---:|---:|---|
|40|0.998448|-0.243158|-2.52|闭合，残差1.17e-10|
|60|-0.652820|不评分|-5.69|复查后残差失败|
|80|-2.716217|-4.737844|-9.35|闭合，残差1.28e-10|
|100|-4.696805|不评分|-12.61|复查后残差失败|

姿态改善不是整体改善：40kt升降舵原+3.391deg、新-1.804deg、参考+1.270deg；80kt原+6.484deg、新-4.275deg、参考+4.710deg。

仅在共同闭合40/80kt子集同口径汇总：

|指标|原|新|
|---|---:|---:|
|姿态MAE deg|5.076116|3.444499|
|杆位MAE in|0.549076|1.363888|
|升降舵MAE deg|1.947599|6.029461|
|单旋翼推力MAPE %|4.694803|7.210370|

这是两点子集，不是四点通过，也不能与含近悬停的五点平均数混比。TRIM_COMPARISON_4POINT.csv对不合格新配平值留空，全部候选和失败保存在ALL_TRIM_ATTEMPTS.csv及原MAT。
40/80kt成功点的全部九个导数也已回代检查。重复评估差0仅证明同一返回状态的确定性回代，不是独立外层初值搜索。原产物字段coldReplayDifference及字符串converged outer state不能在失败点按字面认领；状态以numericallyAccepted和残差为准。

## 6. 处置与仍需完成的工作

结论：新增接口保留，单独追加原表旋翼—平尾耦合的整机候选不晋升默认。原基线不会因候选失败自动获得外部验证。

本轮支持尾部载荷需要更完整的一致性处理，不支持补这一条通道足以解决线B。

下一项并非重新普查文献：原GTRS尾部的动压损失/非均匀流/机翼下洗见A-85..A-88、B-49、B-56..B-58，已定位但尚未与现有有效安装角、下洗、饱和组合完整对应。应整套核清，不逐个调增益追目标。
机身迎角相关阻力面积表见A-44、B-26..B-28；参考版本、起落架增量及载荷包含范围还需闭合，不能根据本轮差额补拟合阻力。
60/100kt大量内部挥舞失败保留为可计算性限制，不能直接计算并解释这些点的A/B矩阵。
已完成旋翼外部验证的可执行版本一致性应复用并链接，不重开OARF/WADC/Betzina诊断；不得仅根据后端名称或过期注释认领验证身份。

整机动态、转换模式及真实飞行定量验证尚未完成；没有通过把目标降成定性趋势来宣布任务结束。

## 7. 重复运行

在现有完整仓库对应分支中使用MATLAB R2021a；补丁本身不包含完整旋翼数据依赖。

```matlab
startup;
addpath(fullfile(pwd,'analysis','stage2_aircraft'));
addpath(fullfile(pwd,'analysis','validation_whole_aircraft_trim'));
outdir=fullfile(pwd,'results','line_b_reproduction');
if ~exist(outdir,'dir'),mkdir(outdir);end
run_line_b_fixed_input_audit(outdir);
run_line_b_tail_replay(outdir);
% 需要复现配平时显式运行，不默认全扫描。
run_line_b_tail_trim_case(40,fullfile(outdir,'trim40'),false);
run_line_b_tail_trim_case(80,fullfile(outdir,'trim80'),false);
run_line_b_tail_trim_case(60,fullfile(outdir,'retry60'),true);
run_line_b_tail_trim_case(100,fullfile(outdir,'retry100'),true);
```

各次运行均已结束。执行成功不等于外部精度通过。报告及CSV为后处理；实际MATLAB计算证据以相应run、artifact及固定源提交为准。
