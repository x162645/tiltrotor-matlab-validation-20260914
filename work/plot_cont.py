import pandas as pd, matplotlib.pyplot as plt
from matplotlib import font_manager
fonts=['C:/Windows/Fonts/msyh.ttc','C:/Windows/Fonts/simhei.ttf','C:/Windows/Fonts/simsun.ttc']
for f in fonts:
 try:
  prop=font_manager.FontProperties(fname=f); plt.rcParams['font.family']=prop.get_name(); break
 except Exception: pass
plt.rcParams['axes.unicode_minus']=False
p='results/xv15_20kt_continuation_diagnostic_20260913/XV15_20KT_CONTINUATION_POINTS.csv'; d=pd.read_csv(p)
fig,axs=plt.subplots(1,3,figsize=(11,3.6))
axs[0].plot(d.speed_kts,d.theta_deg,'o-',color='#1565c0'); axs[0].set(xlabel='速度（kt）',ylabel='俯仰角（度）',title='连续速度延拓：俯仰角')
axs[1].plot(d.speed_kts,d.stick_in,'o-',color='#2e7d32'); axs[1].set(xlabel='速度（kt）',ylabel='纵向杆位（in）',title='连续速度延拓：杆位')
axs[2].semilogy(d.speed_kts,d.residualNorm,'o-',color='#c62828'); axs[2].axhline(1e-5,color='k',ls='--',lw=.8); axs[2].set(xlabel='速度（kt）',ylabel='配平残差范数',title='残差（虚线为阈值）')
for ax in axs: ax.grid(alpha=.25)
fig.tight_layout(); fig.savefig(r'C:/Users/86173/Documents/Codex/2026-09-11/yue/outputs/XV15_连续速度延拓_中文.png',dpi=200)
