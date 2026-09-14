import pandas as pd, matplotlib.pyplot as plt
from matplotlib import font_manager
for f in ['C:/Windows/Fonts/msyh.ttc','C:/Windows/Fonts/simhei.ttf','C:/Windows/Fonts/simsun.ttc']:
 try: plt.rcParams['font.family']=font_manager.FontProperties(fname=f).get_name(); break
 except: pass
plt.rcParams['axes.unicode_minus']=False
cur=pd.read_csv(r'C:/Users/86173/Documents/Codex/2026-09-11/yue/work/tiltrotor-matlab/results/xv15_40_100_continuation_full/XV15_40_100KT_CONTINUATION_POINTS.csv')
ref=pd.read_csv(r'C:/Users/86173/Documents/Codex/2026-09-11/yue/work/tiltrotor-matlab/analysis/validation_whole_aircraft_trim/reference_gtrs_helicopter_trim_kleinhesselink2007.csv')
fig,axs=plt.subplots(1,3,figsize=(11,3.6))
for ax,c1,c2,ylabel,title in [(axs[0],'theta_deg','theta_gtrs_deg','俯仰角（度）','俯仰角'),(axs[1],'stick_in','stick_gtrs_in','纵向杆位（英寸）','纵向杆位'),(axs[2],'meanThrustPerRotor_lb','thrust_per_rotor_gtrs_lb','单旋翼推力（磅）','单旋翼推力')]:
 m=cur.credible.astype(bool); ax.plot(cur.speed_kts[m],cur[c1][m],'o-',label='本模型（可信点）'); ax.plot(ref.speed_kts,ref[c2],'s--',label='GTRS参考'); ax.plot(cur.speed_kts[~m],cur[c1][~m],'x',color='gray',label='残差未达标点'); ax.set_xlabel('速度（节）'); ax.set_ylabel(ylabel); ax.set_title(title); ax.grid(alpha=.25); ax.legend(fontsize=7)
fig.suptitle('XV-15直升机构型：统一机体系下的文献对比'); fig.tight_layout(); out=r'C:/Users/86173/Documents/Codex/2026-09-11/yue/outputs/XV15_GTRS_连续延拓_完整中文.png'; fig.savefig(out,dpi=220); print(out)
