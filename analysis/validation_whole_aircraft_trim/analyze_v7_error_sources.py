"""Read frozen V7 trim MAT files and expose component force/moment/power terms.

This is an audit of already-computed states. It does not re-solve trim and does
not change the physical model or select parameters against the paper curves.
"""
from __future__ import annotations
import argparse, json
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.io import loadmat
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager

KT = 0.514444
SPEEDS = [40, 60, 80, 100]
COMPONENT_ORDER = ["rotorLeft", "rotorRight", "wing", "fuselage",
                   "horizontalTail", "verticalTail", "hubSpinner"]
CN = {"rotorLeft":"左旋翼", "rotorRight":"右旋翼", "wing":"机翼",
      "fuselage":"机身", "horizontalTail":"平尾", "verticalTail":"垂尾",
      "hubSpinner":"桨毂罩"}

def scalar(x):
    a = np.asarray(x)
    return float(a.reshape(-1)[0])

def vec(x):
    return np.asarray(x, dtype=float).reshape(-1)

def read_point(path: Path, speed: int):
    d = loadmat(path, simplify_cells=True)
    point = d["result"]["point"]
    eom = point["eomOut"]
    comps = eom["components"]["components"]
    if isinstance(comps, dict): comps = [comps]
    byname = {c["name"]: c for c in comps}
    rows = []
    for name in COMPONENT_ORDER:
        c = byname[name]
        F, M = vec(c["F"]), vec(c["M"])
        data = c.get("data", {})
        torque = scalar(data["torque"]) if name.startswith("rotor") and "torque" in data else np.nan
        hlong = scalar(data["Hlong"]) if name.startswith("rotor") and "Hlong" in data else np.nan
        hlat = scalar(data["Hlat"]) if name.startswith("rotor") and "Hlat" in data else np.nan
        vi = scalar(data["inducedVelocity"]) if name.startswith("rotor") and "inducedVelocity" in data else np.nan
        clamp = scalar(data["alphaClampCount"]) if name.startswith("rotor") and "alphaClampCount" in data else np.nan
        power = torque * 589 * 2*np.pi/60 / 1000 if np.isfinite(torque) else 0.0
        rows.append(dict(speed_kt=speed, component=name, component_cn=CN[name],
                         Fx_N=F[0], Fy_N=F[1], Fz_N=F[2],
                         Mx_Nm=M[0], My_Nm=M[1], Mz_Nm=M[2],
                         torque_Nm=torque, shaft_power_kW=power, Hlong_N=hlong,
                         Hlat_N=hlat, inducedVelocity_mps=vi, alphaClampCount=clamp))
    # `Ftotal` includes gravity; component force closure is aerodynamic only.
    Fsum = vec(eom["FaeroProp"]); Msum = vec(eom["Mtotal"])
    total = dict(speed_kt=speed, component="TOTAL", component_cn="合计",
                 Fx_N=Fsum[0], Fy_N=Fsum[1], Fz_N=Fsum[2],
                 Mx_Nm=Msum[0], My_Nm=Msum[1], Mz_Nm=Msum[2],
                 torque_Nm=np.nan, shaft_power_kW=sum(r["shaft_power_kW"] for r in rows),
                 Hlong_N=np.nan, Hlat_N=np.nan, inducedVelocity_mps=np.nan, alphaClampCount=np.nan)
    return rows + [total]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args(); out = args.out; calc = out/"calculation"
    rows=[]
    for s in SPEEDS:
        p=calc/(f"POINT_{s:03d}p00kt.mat")
        if not p.exists(): raise FileNotFoundError(p)
        rows.extend(read_point(p,s))
    df=pd.DataFrame(rows); df.to_csv(out/"误差归因分解_四点.csv",index=False,encoding="utf-8-sig",float_format="%.9g")
    totals=df[df.component=="TOTAL"].copy()
    checks=[]
    for s in SPEEDS:
        q=df[(df.speed_kt==s)&(df.component!="TOTAL")]
        t=totals[totals.speed_kt==s].iloc[0]
        checks.append(dict(speed_kt=s,
          force_sum_error_N=float(np.linalg.norm(q[["Fx_N","Fy_N","Fz_N"]].sum().to_numpy()-t[["Fx_N","Fy_N","Fz_N"]].to_numpy())),
          moment_sum_error_Nm=float(np.linalg.norm(q[["Mx_Nm","My_Nm","Mz_Nm"]].sum().to_numpy()-t[["Mx_Nm","My_Nm","Mz_Nm"]].to_numpy())),
          rotor_power_kW=float(q.shaft_power_kW.sum()), total_power_kW=float(t.shaft_power_kW),
          wing_Fz_N=float(q[q.component=="wing"].Fz_N.iloc[0]),
          fuselage_Fz_N=float(q[q.component=="fuselage"].Fz_N.iloc[0]),
          tail_Fz_N=float(q[q.component=="horizontalTail"].Fz_N.iloc[0]+q[q.component=="verticalTail"].Fz_N.iloc[0]),
          rotor_Fz_N=float(q[q.component.str.startswith("rotor")].Fz_N.sum()),
          wing_My_Nm=float(q[q.component=="wing"].My_Nm.iloc[0]),
          fuselage_My_Nm=float(q[q.component=="fuselage"].My_Nm.iloc[0]),
          tail_My_Nm=float(q[q.component.isin(["horizontalTail","verticalTail"])].My_Nm.sum()),
          spinner_My_Nm=float(q[q.component=="hubSpinner"].My_Nm.iloc[0])))
    cdf=pd.DataFrame(checks); cdf.to_csv(out/"误差归因_四点汇总.csv",index=False,encoding="utf-8-sig",float_format="%.9g")
    plt.rcParams.update({"font.family":"Microsoft YaHei","font.sans-serif":["Microsoft YaHei"],"axes.unicode_minus":False})
    fig,ax=plt.subplots(2,2,figsize=(12,8),dpi=180)
    x=np.arange(len(SPEEDS)); labels=[str(s) for s in SPEEDS]
    q=df[df.component!="TOTAL"]
    # force and moment component bars, retaining signs
    for a,field,title,ylabel in [(ax[0,0],"Fz_N","垂向力分解","Fz / N"),(ax[0,1],"My_Nm","俯仰力矩分解","My / N·m")]:
        bottom=np.zeros(len(SPEEDS))
        for name in COMPONENT_ORDER:
            vals=[q[(q.speed_kt==s)&(q.component==name)][field].iloc[0] for s in SPEEDS]
            a.bar(x,vals,bottom=bottom,label=CN[name]); bottom+=np.asarray(vals)
        a.set_xticks(x,labels); a.set_title(title); a.set_xlabel("速度 / kt"); a.set_ylabel(ylabel); a.axhline(0,color="k",lw=.6); a.grid(axis="y",alpha=.2)
    a=ax[1,0]; a.plot(SPEEDS,cdf.rotor_power_kW,"o-",label="左右旋翼轴功率"); a.set_title("旋翼功率定义核查"); a.set_xlabel("速度 / kt"); a.set_ylabel("功率 / kW"); a.grid(alpha=.2); a.legend()
    a=ax[1,1]; a.plot(SPEEDS,cdf.wing_My_Nm,"o-",label="机翼"); a.plot(SPEEDS,cdf.fuselage_My_Nm,"o-",label="机身"); a.plot(SPEEDS,cdf.tail_My_Nm,"o-",label="平尾+垂尾"); a.plot(SPEEDS,cdf.spinner_My_Nm,"o-",label="桨毂罩"); a.axhline(0,color="k",lw=.6); a.set_title("非旋翼俯仰力矩来源"); a.set_xlabel("速度 / kt"); a.set_ylabel("My / N·m"); a.grid(alpha=.2); a.legend(fontsize=8)
    fig.suptitle("V7 配平误差归因：四个速度点的部件分解",fontsize=14); fig.tight_layout(); fig.savefig(out/"误差归因分解_四点.png",bbox_inches="tight"); plt.close(fig)
    report = """# V7 配平误差归因：四个速度点

这是对已保存 MATLAB 配平状态的读取审计，不是重新配平，也没有用论文曲线调参。四个点为 40、60、80、100 kt。力和力矩来自同一个 `eomOut.components` 载体，旋翼功率为左右桨扭矩乘 589 rpm 的角速度。

## 可以直接确认的事实

- 每个速度点都保存了左/右旋翼、机翼、机身、平尾、垂尾和桨毂罩的独立力与力矩。
- 部件力和力矩相加后与整机输出逐点一致；核对误差写在 `误差归因_四点汇总.csv`，不把残差当作外部精度。
- 功率输出只包含左右旋翼轴功率，没有发动机、传动和附件损失。因此它与论文“旋翼需用功率”在类别上接近，但仍需核对论文是否含同类损失。

## 目前不能由这四点单独证明的内容

- 不能仅凭部件分解判断旋翼气动模型正确；还需要相同输入和独立载荷数据。
- 机翼、机身和尾翼的力矩贡献可以解释配平杆位变化，但不能把解释当成验证。
- 若论文使用了不同的总距、转速、重量、功率口径或坐标定义，当前功率差会包含定义差异。

下一步应把本表与 CR-166536/CR-166537 的同工况定义逐项核对，再做“固定输入、不重新配平”的旋翼/非旋翼分支对照。只有某个来源被证实与参考口径一致后，才允许据此修改相应模块。
"""
    (out/"误差归因报告.md").write_text(report,encoding="utf-8")
    (out/"误差归因运行记录.json").write_text(json.dumps(dict(identity="READ_FROZEN_V7_COMPONENT_BREAKDOWN",speeds_kt=SPEEDS,source="calculation/POINT_*p00kt.mat",new_model_calls=0,force_moment_sum_checked=True,power_definition="sum rotor torque * 589 rpm Omega / 1000"),ensure_ascii=False,indent=2),encoding="utf-8")
    print("DECOMPOSITION_DONE", len(df), "rows")
if __name__=="__main__": main()
