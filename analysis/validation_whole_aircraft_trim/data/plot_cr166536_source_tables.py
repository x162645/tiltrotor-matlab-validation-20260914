"""Plot source lookup nodes for inspection, not model validation results."""
import argparse
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from cr166536_tables import TableDatabase, ROOT


def main(output):
    for name in ('Microsoft YaHei', 'SimHei', 'Noto Sans CJK SC', 'WenQuanYi Zen Hei'):
        if name in {f.name for f in font_manager.fontManager.ttflist}:
            plt.rcParams['font.sans-serif'] = [name]
            break
    else:
        raise RuntimeError('No Chinese font found; install a CJK font before plotting.')
    plt.rcParams['axes.unicode_minus'] = False
    db=TableDatabase()
    fig,axes=plt.subplots(2,2,figsize=(12,8.5),layout='constrained')
    def draw(ax,table,axis,label,limits=None,**selectors):
        cells=db.select(table,**selectors)
        xy=sorted({(float(c['coordinates'][axis]),c['value']) for c in cells if c['value'] is not None})
        if limits:
            xy=[(x,y) for x,y in xy if limits[0]<=x<=limits[1]]
        ax.plot([p[0] for p in xy],[p[1] for p in xy],'.--',lw=1,ms=5,label=label)
    ax=axes[0,0]
    draw(ax,'4-I','row_value','襟翼 0/0°',(-40,40),col_value='MN_0_0.2')
    for flap in ['20/12.5','40/25','75/47']:
        draw(ax,'4-II','row_value','襟翼 '+flap+'°',(-40,40),mast_angle_deg=90,mach_label='0..0.2',flap_setting=flap)
    ax.set(title='机翼升力：飞机构型，低马赫数',xlabel='机翼迎角（°）',ylabel='升力系数（无量纲）')
    ax=axes[0,1]
    for elevator in [0,-20,20]:
        draw(ax,'5-I','alpha_deg',f'升降舵 {elevator}°',(-40,40),elevator_deg=elevator)
    ax.set(title='平尾升力：低马赫数',xlabel='平尾迎角（°）',ylabel='升力系数（无量纲）')
    ax=axes[1,0]
    for rudder in [0,-20,20]:
        draw(ax,'6-I','row_key',f'方向舵 {rudder}°',(-40,40),col_key=rudder)
    ax.set(title='垂尾侧向力：低马赫数',xlabel='垂尾局部侧滑角（°）',ylabel='侧向力系数（无量纲）')
    ax=axes[1,1]
    draw(ax,'4-XV','row_value','原表节点')
    ax.set(title='短舱干扰阻力参数',xlabel='源报告桨轴角 βm（°，0°为直升机构型）',ylabel='等效阻力面积（ft²）')
    for ax in axes.flat:
        ax.grid(alpha=.25)
        ax.legend(fontsize=9)
    fig.suptitle('CR-166536 原始查表数据预览（不是验模结果）',fontsize=16)
    fig.supxlabel('点为原表数值，虚线仅连接相邻节点；画面范围用于阅读，完整数据另存 CSV。',fontsize=10)
    fig.savefig(output,dpi=170)
    plt.close(fig)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=ROOT/'CR166536_SOURCE_TABLE_PREVIEW.png')
    main(parser.parse_args().output)
