import pandas as pd,glob,os,matplotlib.pyplot as plt
plt.rcParams['font.sans-serif']=['Microsoft YaHei','SimHei']; plt.rcParams['axes.unicode_minus']=False
new=pd.concat([pd.read_csv(f) for f in glob.glob(r'C:/Users/86173/Documents/Codex/2026-09-11/yue/work/tiltrotor-matlab/outputs/gtrs_v7_no_immersed_*kt/V7_TRIM_POINT.csv')]).sort_values('speed_kt')
old=pd.DataFrame({'speed_kt':[40,60,80],'thetaDifference_deg':[1.0648,1.9993,3.0322],'stickDifference_in':[-0.2366,-0.6403,-0.7219],'elevatorDifference_deg':[-1.1308,-2.9669,-3.5503],'thrustDifference_pct':[5.0255,5.3107,-0.6741]})
cols=[('thetaDifference_deg','俯仰角误差 (°)'),('stickDifference_in','纵向杆位误差 (in)'),('elevatorDifference_deg','升降舵误差 (°)'),('thrustDifference_pct','单旋翼推力误差 (%)')]
fig,axs=plt.subplots(2,2,figsize=(11,7),dpi=180); axs=axs.ravel()
for ax,(c,label) in zip(axs,cols):
 ax.plot(old.speed_kt,old[c],'-o',label='原V7（含浸入机翼）'); ax.plot(new.speed_kt,new[c],'-s',label='临时V7（无浸入机翼）'); ax.axhline(0,color='0.3',lw=.7); ax.set_xlabel('速度 (kt)'); ax.set_ylabel(label); ax.grid(alpha=.25); ax.legend(fontsize=8)
fig.suptitle('机翼浸入开关对 GTRS 参考误差的影响（固定其他设置）'); fig.tight_layout(rect=[0,0,1,.95]); out=r'C:/Users/86173/Documents/Codex/2026-09-11/yue/outputs/整机验模_CR166536_V7_20260913/机翼浸入开关误差对比.png'; fig.savefig(out,bbox_inches='tight'); print(out)
