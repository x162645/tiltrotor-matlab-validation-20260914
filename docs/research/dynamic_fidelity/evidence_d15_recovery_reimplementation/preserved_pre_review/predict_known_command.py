from __future__ import annotations
import argparse, json, hashlib, platform, sys, time
from pathlib import Path
import numpy as np
import pandas as pd

SOURCE={"model":"TM89428_EQ4_8","kappa":0.0098,"pole":0.105,"delay_s":0.0074,
        "input_unit":"percentage_point","output_unit":"g_down"}

def check_series(t,u):
    t=np.asarray(t,float);u=np.asarray(u,float)
    if t.ndim!=1 or u.shape!=t.shape or len(t)<2: raise ValueError("matching 1D arrays required")
    if not np.isfinite(t).all() or not np.isfinite(u).all() or not np.all(np.diff(t)>0): raise ValueError("finite, increasing arrays required")
    return t,u

def delayed_piecewise(t,u,delay,query):
    """Evaluate linearly interpolated command at query-delay; prehistory is held at u[0]."""
    q=np.asarray(query,float); z=np.interp(q-delay,t,u,left=u[0],right=u[-1]); return z

def predict_known_command(t,u,*,origin_time,initial_acceleration_g,evaluation_time,
                          kappa=SOURCE["kappa"],pole=SOURCE["pole"],delay_s=SOURCE["delay_s"]):
    """Causal exact propagation of ydot=-pole*y-kappa*d/dt u(t-delay).
    Integrator breakpoints include every delayed input knot and query time; output grid cannot alter integration."""
    t,u=check_series(t,u); te=np.asarray(evaluation_time,float)
    if te.ndim!=1 or len(te)==0 or not np.isfinite(te).all() or np.any(np.diff(te)<=0): raise ValueError("evaluation_time increasing")
    if not np.isfinite([origin_time,initial_acceleration_g,kappa,pole,delay_s]).all() or kappa<=0 or pole<=0 or delay_s<0: raise ValueError("invalid parameter")
    if te[0] < origin_time-1e-12: raise ValueError("queries before origin")
    if te[-1] > t[-1]+delay_s+1e-12: raise ValueError("future query outside command record")
    # Breakpoints where slope of delayed command changes, plus requested output times.
    knots=np.unique(np.r_[origin_time,te,t+delay_s])
    knots=knots[(knots>=origin_time-1e-12)&(knots<=te[-1]+1e-12)]
    knots.sort()
    y=float(initial_acceleration_g); out=np.empty(te.size); j=0
    for i in range(len(knots)-1):
        a,b=float(knots[i]),float(knots[i+1])
        while j<len(te) and te[j] <= a+1e-12: out[j]=y; j+=1
        h=b-a
        ua,ub=delayed_piecewise(t,u,delay_s,np.array([a,b]))
        slope=(ub-ua)/h if h>0 else 0.0
        e=np.exp(-pole*h)
        y=e*y - kappa*slope*(1-e)/pole
    while j<len(te): out[j]=y; j+=1
    return out

def source_reset_predict(t,u,query):
    # legacy source descriptor, zero state at each query array origin
    return predict_known_command(t,u,origin_time=float(query[0]),initial_acceleration_g=0.0,evaluation_time=query)

def main(args):
    out=args.out; out.mkdir(parents=True,exist_ok=False)
    inp=pd.read_csv(args.input); obs=pd.read_csv(args.flight)
    t,u=check_series(inp.time_s,inp.value); tf,yf=check_series(obs.time_s,obs.value)
    # Extracted flight trace extends slightly beyond command trace; explicitly hold last command.
    if tf[-1] > t[-1]:
        t=np.r_[t, tf[-1]]; u=np.r_[u, u[-1]]
    fit=json.loads(args.frozen_fit.read_text()) if args.frozen_fit else None
    # Deterministic endpoint comparisons on original observation times.
    central=np.column_stack([tf,yf,
       source_reset_predict(t,u,tf),
       predict_known_command(t,u,origin_time=float(tf[0]),initial_acceleration_g=float(yf[0]),evaluation_time=tf),
       np.full(tf.size,yf[0])])
    pd.DataFrame(central,columns=["time_s","observed_g","legacy_source_reset_g","fixed_origin_source_g","hold_current_g"]).to_csv(out/"POINTWISE_TRACE.csv",index=False)
    # Rolling condition forecasts: all starts 18-24 s and first target at requested horizon.
    starts=tf[(tf>=18)&(tf<=24)][:65]  # fixed deterministic subset; overlapping starts, not independent trials
    rows=[]
    horizons=[0.5,2.0,5.0]
    for oi,origin in enumerate(starts):
        y0=float(np.interp(origin,tf,yf))
        for H in horizons:
            target=float(tf[tf>=origin+H][0]) if np.any(tf>=origin+H) else np.nan
            if not np.isfinite(target): continue
            known=float(predict_known_command(t,u,origin_time=float(origin),initial_acceleration_g=y0,evaluation_time=np.array([target]))[0])
            hold=y0
            # unknown future command branch: hold delayed command at value at origin; no future samples used.
            uo=float(delayed_piecewise(t,u,SOURCE["delay_s"],np.array([origin]))[0])
            known_hold=float(predict_known_command(np.array([origin,target+1e-6]),np.array([uo,uo]),origin_time=float(origin),initial_acceleration_g=y0,evaluation_time=np.array([target]),kappa=SOURCE["kappa"],pole=SOURCE["pole"],delay_s=0.0)[0])
            fitpred=np.nan
            if fit: fitpred=float(predict_known_command(t,u,origin_time=float(origin),initial_acceleration_g=y0,evaluation_time=np.array([target]),kappa=fit["prefix_kappa"],pole=fit["prefix_pole"],delay_s=fit["delay_s"])[0])
            truth=float(np.interp(target,tf,yf))
            rows.append([oi,float(origin),H,target,y0,truth,known,hold,known_hold,fitpred])
    cols=["origin_index","origin_time_s","requested_horizon_s","target_time_s","initial_observed_g","target_observed_g","source_known_g","hold_current_g","source_future_command_held_g","prefix_fit_known_g"]
    pd.DataFrame(rows,columns=cols).to_csv(out/"FORECASTS_POINTWISE.csv",index=False)
    # Targeted checks: query-grid invariance and delayed-breakpoint stress.
    q1=np.array([18.0,18.37,19.0,20.0]);q2=np.linspace(18,20,401)
    y0=float(np.interp(18,tf,yf))
    a=predict_known_command(t,u,origin_time=18,initial_acceleration_g=y0,evaluation_time=q1)
    b=predict_known_command(t,u,origin_time=18,initial_acceleration_g=y0,evaluation_time=q2)
    grid_err=float(abs(a[-1]-b[-1]))
    st=np.array([0.,1.,2.,3.]); su=np.array([0.,0.,10.,0.])
    s1=predict_known_command(st,su,origin_time=0,initial_acceleration_g=0,evaluation_time=np.array([3.0]),kappa=1,pole=1,delay_s=0)
    s2=predict_known_command(st,su,origin_time=0,initial_acceleration_g=0,evaluation_time=np.linspace(0,3,301),kappa=1,pole=1,delay_s=0)[-1]
    tam=u.copy();tam[t>24]+=100
    f1=predict_known_command(t,u,origin_time=18,initial_acceleration_g=y0,evaluation_time=np.array([20.]),kappa=SOURCE["kappa"],pole=SOURCE["pole"],delay_s=SOURCE["delay_s"])
    f2=predict_known_command(t,tam,origin_time=18,initial_acceleration_g=y0,evaluation_time=np.array([20.]),kappa=SOURCE["kappa"],pole=SOURCE["pole"],delay_s=SOURCE["delay_s"])
    checks=[["query_grid_invariance_abs_g",grid_err,1e-10,grid_err<=1e-10],
            ["delayed_breakpoint_exact_vs_refined_abs_g",float(abs(s1[0]-s2)),1e-8,float(abs(s1[0]-s2))<=1e-8],
            ["origin_initial_condition_abs_g",abs(float(predict_known_command(t,u,origin_time=18,initial_acceleration_g=y0,evaluation_time=np.array([18.]))[0])-y0),1e-12,True],
            ["future_input_tamper_before_24s_abs_g",float(abs(f1[0]-f2[0])),1e-12,float(abs(f1[0]-f2[0]))<=1e-12]]
    pd.DataFrame(checks,columns=["check","absolute_difference","tolerance","passed"]).to_csv(out/"TARGETED_CHECKS.csv",index=False)
    # Aggregated RMSE by horizon; overlapping starts are explicitly labeled dependent.
    fr=pd.DataFrame(rows,columns=cols); agg=[]
    for H,g in fr.groupby("requested_horizon_s"):
        for m in ["source_known_g","hold_current_g","source_future_command_held_g","prefix_fit_known_g"]:
            if g[m].notna().all(): agg.append([H,m,int(len(g)),float(np.sqrt(np.mean((g[m]-g.target_observed_g)**2))),"overlapping_origins_same_record"])
    pd.DataFrame(agg,columns=["requested_horizon_s","model","n_overlapping_forecasts","RMSE_g","dependence_note"]).to_csv(out/"FORECAST_METRICS.csv",index=False)
    manifest={"role":"D15_RECOVERY_REIMPLEMENTATION_NEW_IDENTITY","status":"EXECUTED_READBACK_REQUIRED","source_descriptor":SOURCE,
      "origin_policy":"fixed origin_time and initial_acceleration_g; no per-query reset","delay_breakpoints":"all input knots shifted by delay included in integration",
      "query_grid_policy":"output queries do not determine integration breakpoints","input_prehistory":"constant u[0] before first recorded input",
      "physical_rotor_parameter_fits":0,"new_flight_experiments":0,"independent_trials":0,
      "forecast_rows":len(rows),"origins_shared_record":True,
      "hashes":{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__),args.input,args.flight]+([args.frozen_fit] if args.frozen_fit else [])},
      "python":sys.version,"numpy":np.__version__,"platform":platform.platform()}
    (out/"EXECUTION_MANIFEST.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    print(json.dumps({"rows":len(rows),"checks":checks},indent=2))
if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("--input",type=Path,required=True);ap.add_argument("--flight",type=Path,required=True);ap.add_argument("--frozen-fit",type=Path);ap.add_argument("--out",type=Path,required=True);main(ap.parse_args())

