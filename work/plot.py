import pandas as pd, matplotlib.pyplot as plt
p='results/xv15_wang_closure_v1/XV15_WANG_STYLE_TRIM_POINTS.csv'
d=pd.read_csv(p)
fig,ax=plt.subplots(figsize=(7,4))
for k,g in d.groupby('i_n_deg'):
 ax.plot(g.speed_mps,g.residualNorm,'o-',label=f'i_n={k}°')
ax.axhline(1e-5,color='k',ls='--',lw=.8,label='credible threshold')
ax.set(xlabel='速度 V (m/s)',ylabel='配平残差范数',yscale='log',title='XV-15-like 四构型配平闭合检查')
ax.grid(True,which='both',alpha=.25); ax.legend(ncol=2,fontsize=8); fig.tight_layout(); fig.savefig(r'C:/Users/86173/Documents/Codex/2026-09-11/yue/outputs/XV15_WANG_STYLE_TRIM_RESIDUALS.png',dpi=180)
