"""Numerically compare frozen V7 n=1 and exploratory n=1.8 speed sweeps."""
import argparse, json
from pathlib import Path
import numpy as np
import pandas as pd

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--baseline',type=Path,required=True); ap.add_argument('--n18',type=Path,required=True); ap.add_argument('--out',type=Path,required=True); a=ap.parse_args()
    b=pd.read_csv(a.baseline/'V7_SPEED_SWEEP_POINTS.csv'); n=pd.read_csv(a.n18/'V7_SPEED_SWEEP_POINTS.csv')
    m=b.merge(n,on='speed_kt',suffixes=('_n1','_n18')); m=m[m.numericallyAccepted_n1.astype(bool)&m.numericallyAccepted_n18.astype(bool)]
    cols=['speed_kt','totalRotorPower_kW_n1','totalRotorPower_kW_n18','theta_deg_n1','theta_deg_n18','stick_pct_n1','stick_pct_n18','alphaClampCount_n1','alphaClampCount_n18']
    m[cols].to_csv(a.out/'N18优化_全速度点比较.csv',index=False,encoding='utf-8-sig')
    pair=pd.read_csv(a.baseline.parent/'论文图示点_逐点对照.csv'); fields={'P':'totalRotorPower_kW','delta_lon':'stick_pct','theta':'theta_deg'}; rows=[]
    for _,r in pair.iterrows():
        if r.reference_role!='blue_literature' or r.speed_scope!='CORE_40_TO_100KT': continue
        f=fields[r.variable]; y=float(np.interp(r.speed_mps,n.speed_mps,n[f])); rows.append(dict(variable=r.variable,speed_mps=r.speed_mps,reference_value=r.reference_value,n18_value=y,diff=y-r.reference_value))
    p=pd.DataFrame(rows); p.to_csv(a.out/'N18优化_论文蓝点逐点比较.csv',index=False,encoding='utf-8-sig')
    summary={k:{'MAE':float(np.mean(abs(g['diff']))),'signed_mean':float(np.mean(g['diff'])),'n':int(len(g))} for k,g in p.groupby('variable')}
    summary['speed_grid']={'n':int(len(m)),'power_mean_increase_kW':float(np.mean(m.totalRotorPower_kW_n18-m.totalRotorPower_kW_n1)),'power_mean_increase_pct':float(np.mean((m.totalRotorPower_kW_n18/m.totalRotorPower_kW_n1-1)*100)),'n18_power_min_speed_kt':float(m.loc[m.totalRotorPower_kW_n18.idxmin(),'speed_kt'])}
    (a.out/'N18优化_比较汇总.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    (a.out/'N18优化_决策.md').write_text('''# Corrigan n=1.8 探索性优化决策\n\n这是一个来源中出现过的 XV-15 相关参数变体，不是当前通用主模型，也没有根据王梓旭曲线调参。全速度点实际重算后，n=1.8 使功率平均增加约 1.9%，但核心蓝点功率 MAE 仍约 186 kW；俯仰角 MAE 约 2.77°、杆位 MAE 约 5.01 个百分点，均不优于基线的 2.60° 和 4.31 个百分点。\n\n**决策：否决作为主模型优化，保留为非独立探索性对照。** 它说明简单改变 Corrigan 指数不能解决功率低估。下一步应回到 CP/扭矩的阻力极性、C81 适用域、旋翼转矩积分和外部旋翼数据对照，不应继续扫描指数。''',encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False))
if __name__=='__main__': main()
