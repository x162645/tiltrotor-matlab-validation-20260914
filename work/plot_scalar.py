import pandas as pd, matplotlib.pyplot as plt
from matplotlib import font_manager
for f in ['C:/Windows/Fonts/msyh.ttc','C:/Windows/Fonts/simhei.ttf','C:/Windows/Fonts/simsun.ttc']:
 try: plt.rcParams['font.family']=font_manager.FontProperties(fname=f).get_name(); break
 except: pass
plt.rcParams['axes.unicode_minus']=False
p=r'C:/Users/86173/Documents/Codex/2026-09-11/yue/work/tiltrotor-matlab/results/xv15_gtrs_cr166537_trim/CR166537_GTRS_SCALAR_TRIM_COMPARISON.csv'; d=pd.read_csv(p); ref=pd.read_csv(r'C:/Users/86173/Documents/Codex/2026-09-11/yue/work/tiltrotor-matlab/analysis/validation_whole_aircraft_trim/reference_gtrs_helicopter_trim_kleinhesselink2007.csv')
fig,axs=plt.subplots(1,3,figsize=(11,3.6))
for ax,a,b,yl,t in [(axs[0],'theta_deg','theta_gtrs_deg','俯仰角（度）','俯仰角'),(axs[1],'stick_in','stick_gtrs_in','纵向杆位（英寸）','纵向杆位'),(axs[2],'thrust_lb','thrust_per_rotor_gtrs_lb','单旋翼推力（磅）','单旋翼推力')]:
 ax.plot(d.speed_kts,d[a],'o-',label='标量替换模型'); ax.plot(ref.speed_kts,ref[b],'s--',label='GTRS参考'); ax.set(xlabel='速度（节）',ylabel=yl,title=t); ax.grid(alpha=.25); ax.legend(fontsize=7)
fig.suptitle('CR-166536 标量参数替换后的逐点文献对比'); fig.tight_layout(); out=r'C:/Users/86173/Documents/Codex/2026-09-11/yue/outputs/CR166537_GTRS标量替换_中文图.png'; fig.savefig(out,dpi=220); print(out)
