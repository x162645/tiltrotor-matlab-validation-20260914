# V4之后：固定外部输入的翼/机身对照

本轮不是重跑配平或增加新物理项。复用已冻结TableC1输入和lambda转换，单独调用现有wing_model/fuselage_model。旋翼的lambda/mu/实际力作为输入，不能当作这项诊断所验证的输出。无旋翼求解、无整机求解、无容差变化。

原GTRS TableC1的Wing条目可能包含pylon等合并范围；本轮显示代码机翼与该条目的差异，不称已闭合外部部件误差预算。四点全部保留，参考冲突见REFERENCE_TABLE_CONFLICTS.md。

同时检查原始CR166536 RevA A44/B26/B27/B28：beta=0时升力/阻力/力矩的侧滑表零值与基准扣除相抵；DLANG=-0.5ft²按原页保留。子系统7的DPOD=1.15ft²在B82，不能自动塞进机身D或根据2007表残差修改为另一值。只诊断原表力，未将本征力矩参考点等价性认领为已闭合。

对照可发现原表差异形状，但不能以约常数差额直接认定其来源。没有拟合、没有采用参考输出反求新机体参数，默认和V4物理均不变。

V4历史产物contract.rotorIdentity误继承旧构造器字段，实际执行由M1_CONTINUOUS_CORRIGAN_V4后端、P.rotor.correctionIdentity及源码确认；不得以旧元数据称V4继承旧M1外部验证。下次运行入口应修正该记录；历史MAT/manifest不改写。
