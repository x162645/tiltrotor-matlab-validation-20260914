from pathlib import Path
import csv, json
out=Path('external_validation_coverage'); out.mkdir(exist_ok=True)
rows=[
 {'betaM_deg':90,'evidence':'Wang 2025 Fig.1(a) digitized blue reference','cases':'0.01,20,40,60,80,100 kt','outputs':'theta,stick,power','role':'external source-constrained reference','status':'AVAILABLE_FOR_COMPARISON'},
 {'betaM_deg':60,'evidence':'Yan 2023 Fig.8 digitized flight-test markers','cases':'42,52,62,72 m/s','outputs':'theta0,pitch,stick,power','role':'secondary public figure target with uncertainty','status':'AVAILABLE_FOR_COMPARISON'},
 {'betaM_deg':30,'evidence':'Yan 2023 Fig.8 digitized flight-test markers','cases':'52,62,72,82 m/s','outputs':'theta0,pitch,stick,power','role':'secondary public figure target with uncertainty','status':'AVAILABLE_FOR_COMPARISON'},
 {'betaM_deg':0,'evidence':'Yan 2023 Fig.8 plus CR166537/CR166536 GTRS tables','cases':'75–140 m/s (Yan); 0.01–100 kt (GTRS)','outputs':'theta0,pitch,stick,power; GTRS theta/stick/cyclic/elevator/thrust','role':'mixed secondary flight-test figure and reference simulation','status':'AVAILABLE_FOR_COMPARISON'},
]
with (out/'EXTERNAL_VALIDATION_COVERAGE.csv').open('w',newline='',encoding='utf-8-sig') as f:
 w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
 meta={'identity':'EXTERNAL_VALIDATION_COVERAGE_MATRIX_V2','external_full_aircraft_target_angles_deg':[90,60,30,0],'blocked_angles_deg':[],'independent_component_evidence':'OARF/WADC/Woodgate rotor-level evidence; not full-aircraft angle validation','no_target_fitting':True,'claim_boundary':'All four angles now have public figure targets from Yan 2023 Fig.8; targets are secondary digitizations with stated reading uncertainty, not raw synchronized arrays.'}
(out/'EXTERNAL_VALIDATION_COVERAGE.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
 (out/'EXTERNAL_VALIDATION_COVERAGE.md').write_text('''# 外部验证覆盖矩阵\n\n已找到 Yan、Yuan、Chen（Aerospace 2023）图8，其中空心圆飞行试验点覆盖90°、60°、30°、0°四个短舱状态。90°同时有王梓旭图1(a)目标，0°还有CR166537/CR166536的GTRS参考。\n\nYan图8只有公开图表，没有原始同步数组，因此本项目将其作为带读图不确定度的外部目标，不把计算曲线或插值点当作实测。它可以支持四个角度的配平趋势和定量近似比较，但不能替代原始输入时历、左右旋翼载荷和同步全机动态验证。\n''',encoding='utf-8')
print(out/'EXTERNAL_VALIDATION_COVERAGE.md')
