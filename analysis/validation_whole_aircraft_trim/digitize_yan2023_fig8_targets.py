from pathlib import Path
import csv, json

# Approximate marker-center digitization from Yan et al. (2023), Fig. 8,
# rendered from the CC-BY author manuscript. Values are intentionally stored
# with reading uncertainty; they are not treated as raw arrays.
rows=[]
def add(beta, flap, xs, th0, theta, stick, power):
    for x,a,b,c,d in zip(xs,th0,theta,stick,power):
        rows.append({
            'source':'Yan2023_Aerospace_Fig8', 'source_kind':'SECONDARY_FIGURE_DIGITIZATION',
            'betaM_deg':beta, 'flap_aileron_deg':flap, 'speed_mps':x,
            'theta0_deg':a, 'pitch_deg':b, 'longitudinal_stick_pct':c,
            'power_kW':d, 'speed_uncertainty_mps':1.0,
            'theta0_uncertainty_deg':1.5, 'pitch_uncertainty_deg':1.5,
            'stick_uncertainty_pct':3.0, 'power_uncertainty_kW':80.0,
            'role':'external_flight_test_marker_digitized_from_figure'
        })
add(90,'40/25',[0,10,20,30,40,50],[46,47,44,43,44,46],[0,-1,-3,-5,-8,-11],[52,55,52,55,58,70],[1500,1400,1000,850,950,1350])
add(60,'20/12.5',[42,52,62,72],[43,45,49,53],[10,3,-1,-5],[48,60,72,80],[700,850,1150,1750])
add(30,'20/12.5',[52,62,72,82],[48,53,57,61],[10,3,0,-3],[50,64,70,73],[750,850,1050,1300])
add(0,'0/0',[75,90,100,110,120,130,140],[60,65,69,73,77,80,83],[7,4,2,1,0,-1,-1],[49,52,54,55,57,58,59],[650,780,950,1100,1300,1650,2100])
out=Path('external_targets');out.mkdir(exist_ok=True)
with (out/'YAN2023_FIG8_DIGITIZED_FLIGHT_TEST.csv').open('w',newline='',encoding='utf-8-sig') as f:
    w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
meta={'identity':'YAN2023_FIG8_DIGITIZED_FLIGHT_TEST_V1','paper':'Yan, X.; Yuan, Y.; Chen, R. Aerospace 2023, 10(9), 742','doi':'10.3390/aerospace10090742','figure':'Fig. 8','angles_deg':[90,60,30,0],'point_count':len(rows),'digitization':'manual marker-center read from rendered figure','uncertainty':'speed ±1 m/s; theta0/pitch ±1.5 deg; stick ±3 percentage points; power ±80 kW','status':'SECONDARY_PUBLIC_FIGURE_TARGET_NOT_RAW_ARRAY','use':'external trim comparison after model runner execution','do_not_use':'do not treat calculated lines or interpolated values as measurements'}
(out/'YAN2023_FIG8_DIGITIZED_FLIGHT_TEST.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
(out/'YAN2023_FIG8_README.md').write_text('''# Yan 2023 Figure 8 外部目标\n\n该文件从 Yan、Yuan、Chen（Aerospace 2023, 10(9), 742）图8中空心圆飞行试验点读取，覆盖90°、60°、30°、0°四个短舱状态。\n\n数值是公开图表数字化结果，不是原始飞行数组。已给出读图不确定度：速度±1 m/s、姿态±1.5°、杆位±3个百分点、功率±80 kW。黑色计算曲线没有写入CSV。\n''',encoding='utf-8')
print(out/'YAN2023_FIG8_DIGITIZED_FLIGHT_TEST.csv')
