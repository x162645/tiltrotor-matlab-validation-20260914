from pathlib import Path
import csv, json
out=Path('external_validation_coverage'); out.mkdir(exist_ok=True)
rows=[
 {'betaM_deg':90,'evidence':'Wang 2025 Fig.1(a) digitized blue reference','cases':'0.01,20,40,60,80,100 kt','outputs':'theta,stick,power','role':'external source-constrained reference','status':'AVAILABLE_FOR_COMPARISON'},
 {'betaM_deg':60,'evidence':'No matched public full-aircraft target in repository','cases':'','outputs':'','role':'coverage gap','status':'BLOCKED_EXTERNAL_TARGET'},
 {'betaM_deg':30,'evidence':'No matched public full-aircraft target in repository','cases':'','outputs':'','role':'coverage gap','status':'BLOCKED_EXTERNAL_TARGET'},
 {'betaM_deg':0,'evidence':'CR166537/CR166536 GTRS helicopter tables','cases':'0.01,20,40,60,80,100 kt','outputs':'theta,stick,cyclic,elevator,thrust','role':'GTRS reference simulation, not raw flight','status':'AVAILABLE_FOR_COMPARISON'},
]
with (out/'EXTERNAL_VALIDATION_COVERAGE.csv').open('w',newline='',encoding='utf-8-sig') as f:
 w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
meta={'identity':'EXTERNAL_VALIDATION_COVERAGE_MATRIX_V1','external_full_aircraft_target_angles_deg':[90,0],'blocked_angles_deg':[60,30],'independent_component_evidence':'OARF/WADC/Woodgate rotor-level evidence; not full-aircraft angle validation','no_target_fitting':True,'claim_boundary':'Only 90 and 0 degree external comparisons are currently supportable; 60 and 30 degree results remain model performance screens until matched targets are acquired.'}
(out/'EXTERNAL_VALIDATION_COVERAGE.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
(out/'EXTERNAL_VALIDATION_COVERAGE.md').write_text('''# 外部验证覆盖矩阵\n\n当前可直接对比的整机级公开目标只有90°王梓旭图1(a)数据和0° CR166537/CR166536 GTRS直升机配平参考。60°和30°没有同任务、同输入、同输出的公开整机目标，因此只能做模型性能筛查，不能计算外部误差。\n\n这不阻断角度配平和趋势研究，但阻断60°/30°的外部精度声明。部件级旋翼证据可以继续用于旋翼模块验证，不能替代整机验证。\n''',encoding='utf-8')
print(out/'EXTERNAL_VALIDATION_COVERAGE.md')
