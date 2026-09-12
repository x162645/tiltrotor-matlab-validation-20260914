"""NEW D15 reimplementation from visible equations, never recovered original code.
Command percentage points -> downward acceleration g. No rotor validation.
"""
from pathlib import Path
import argparse, datetime, hashlib, itertools, json, platform, subprocess, sys, time
import numpy as np
import pandas as pd
from scipy.linalg import expm
from scipy.optimize import minimize_scalar

KAPPA, POLE, DELAY = .0098, .105, .0074

def real_vector(x):
    a=np.asarray(x)
    if np.iscomplexobj(a): raise ValueError('Complex input rejected')
    a=np.asarray(a,dtype=float)
    if a.ndim!=1 or not np.isfinite(a).all(): raise ValueError('Finite real vector required')
    return a

def checked(t,u):
    t,u=real_vector(t),real_vector(u)
    if len(t)<2 or t.shape!=u.shape or np.any(np.diff(t)<=0): raise ValueError('Increasing matching input arrays required')
    return t,u

def weights(t,origin,target,kappa=KAPPA,pole=POLE,delay=DELAY):
    """Endpoint y=A*y0+w@u, exact piecewise-linear input, explicit constant prehistory."""
    t=real_vector(t)
    if len(t)<2 or np.any(np.diff(t)<=0): raise ValueError('Increasing time vector required')
    if not np.isrealobj([origin,target,kappa,pole,delay]) or not np.isfinite([origin,target,kappa,pole,delay]).all(): raise ValueError('Finite real scalars required')
    if target<origin or target>t[-1] or origin<t[0] or kappa<=0 or pole<=0 or delay<0: raise ValueError('Outside time/parameter contract')
    knots=np.unique(np.r_[origin,t[(t+delay>origin)&(t+delay<target)]+delay,target])
    w=np.zeros(len(t))
    def basis(q):
        if q<=t[0]: return [(0,1.)]
        if q>=t[-1]: return [(len(t)-1,1.)]
        j=np.searchsorted(t,q,side='right')-1;r=(q-t[j])/(t[j+1]-t[j]);return [(j,1-r),(j+1,r)]
    for a,b in zip(knots[:-1],knots[1:]):
        h=b-a
        c=-kappa*np.exp(-pole*(target-b))*(-np.expm1(-pole*h))/(pole*h)
        for j,v in basis(b-delay): w[j]+=c*v
        for j,v in basis(a-delay): w[j]-=c*v
    return np.exp(-pole*(target-origin)),w

def predict(t,u,origin,y0,queries,kappa=KAPPA,pole=POLE,delay=DELAY,input_unit='percentage_point',output_unit='g_down'):
    if input_unit!='percentage_point' or output_unit!='g_down': raise ValueError('Command/acceleration units only')
    t,u=checked(t,u);q=real_vector(queries)
    if not np.isrealobj(y0) or not np.isfinite(y0) or len(q)==0 or np.any(np.diff(q)<=0): raise ValueError('Invalid initial value or queries')
    return np.array([a*y0+w@u for a,w in [weights(t,origin,z,kappa,pole,delay) for z in q]])

def independent_expm(t,u,origin,y0,target):
    # Independent augmented [y, constant slope] state on each input segment.
    knots=np.unique(np.r_[origin,t[(t+DELAY>origin)&(t+DELAY<target)]+DELAY,target]);y=y0
    for a,b in zip(knots[:-1],knots[1:]):
        slope=(np.interp(b-DELAY,t,u)-np.interp(a-DELAY,t,u))/(b-a)
        y=(expm(np.array([[-POLE,-KAPPA],[0.,0.]])*(b-a))@np.array([y,slope]))[0]
    return y

def loss_box(A,lo,hi):
    # Exact real-arithmetic extrema of (A*y0+f-z)^2-(y0-z)^2 on a box.
    # Singular interior stationary sets attain the same value on a boundary.
    lo,hi=real_vector(lo),real_vector(hi)
    if lo.shape!=(3,) or hi.shape!=(3,) or np.any(lo>hi) or not np.isrealobj(A) or not np.isfinite(A) or not 0<A<=1: raise ValueError('Finite ordered three-dimensional box and 0<A<=1 required')
    a=np.array([A,-1.,1.]);b=np.array([1.,-1.,0.]);Q=np.outer(a,a)-np.outer(b,b);vals=[]
    for status in itertools.product((-1,0,1),repeat=3):
        free=np.array([i for i,s in enumerate(status) if s==0],int);fixed=np.array([i for i,s in enumerate(status) if s!=0],int)
        x=np.zeros(3)
        for i in fixed:x[i]=lo[i] if status[i]==-1 else hi[i]
        if len(free):
            H=Q[np.ix_(free,free)]
            if np.linalg.matrix_rank(H,tol=1e-12)<len(free):continue
            x[free]=np.linalg.solve(H,-Q[np.ix_(free,fixed)]@x[fixed])
            if np.any(x[free]<lo[free]-1e-12) or np.any(x[free]>hi[free]+1e-12):continue
        vals.append(float(x@Q@x))
    return min(vals),max(vals)

def fit_prefix(t,u,observations):
    """Select the training window inside the fitting API, before any computation."""
    prefix=observations[(observations.time_s>=.5)&(observations.time_s<18)]
    tp,yp=checked(prefix.time_s,prefix.value);d=np.diff(tp);wt=np.r_[d[0]/2,(d[:-1]+d[1:])/2,d[-1]/2];wt/=wt.sum()
    def fit_at(p):
        q=predict(t,u,.5,0,tp,1,p);kap=(wt*q)@yp/((wt*q)@q);return float(wt@((kap*q-yp)**2)),float(kap)
    grid=np.geomspace(.02,1,161);profile=np.array([[p,*fit_at(p)] for p in grid]);j=profile[:,1].argmin()
    opt=minimize_scalar(lambda p:fit_at(p)[0],bounds=(grid[max(j-1,0)],grid[min(j+1,len(grid)-1)]),method='bounded',options={'xatol':1e-12})
    options=[(profile[j,1],profile[j,0],profile[j,2]),(fit_at(opt.x)[0],float(opt.x),fit_at(opt.x)[1])]
    return min(options),profile

def received_command_hold(t,u,origin,y0,target):
    """Source parameters; retain all received command history and pending delay.

    Future raw-command samples are unavailable. Hold the last received sample
    through target; do not reset the actuator delay to a held delayed value.
    """
    t,u=checked(t,u);m=t<=origin
    if np.count_nonzero(m)<2 or target<=origin: raise ValueError('Insufficient received history or horizon')
    ht=np.r_[t[m],target];hu=np.r_[u[m],u[m][-1]]
    return predict(ht,hu,origin,y0,[target])[0]

def main(out):
    out.mkdir(parents=True,exist_ok=False);start=time.perf_counter();repo=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file())
    root=repo/'docs/research/dynamic_fidelity';data=root/'evidence_d14_recovery/recovered_data'
    inp=pd.read_csv(data/'FIG434_POWER_INPUT.csv');obs=pd.read_csv(data/'FIG434_FLIGHT_AZ.csv');obs=obs[(obs.time_s>=.5)&(obs.time_s<=29)].copy()
    t,u=checked(inp.time_s,inp.value);tf,y=checked(obs.time_s,obs.value)
    (loss,fitp,fitk),profile=fit_prefix(t,u,obs)
    fit={'role':'NEW_PREFIX_ONLY_EXACT_PROPAGATOR_EMPIRICAL_FIT','pole':fitp,'kappa':fitk,'delay':DELAY,'prefix_loss':loss,'training_window':'[0.5,18)','physical_parameter_fits':0}
    (out/'FROZEN_PREFIX.json').write_text(json.dumps(fit,indent=2));pd.DataFrame(profile,columns=['pole','loss','kappa']).to_csv(out/'PREFIX_PROFILE.csv',index=False)
    rows=[];boxes=[];checks=[];origins=np.where((tf>=18)&(tf<=24)&(tf+5<=tf[-1]))[0]
    for i in origins:
        origin=tf[i];y0=y[i]
        for h in [.5,2.,5.]:
            j=np.searchsorted(tf,origin+h)
            if j==len(tf):continue
            target=tf[j];A,w=weights(t,origin,target);pred=A*y0+w@u
            fp=predict(t,u,origin,y0,[target],fitk,fitp)[0]
            # Only input samples available by origin; then explicitly hold last received command.
            unknown=received_command_hold(t,u,origin,y0,target)
            static=y0-KAPPA*(np.interp(target-DELAY,t,u)-np.interp(origin-DELAY,t,u))
            rows.append([origin,h,target,y0,y[j],pred,fp,y0,static,unknown])
            for shift in [-.03,0,.03]:
                aa,ww=weights(t+shift,origin,target);fmin=np.minimum(ww*inp.read_lower.to_numpy(),ww*inp.read_upper.to_numpy()).sum();fmax=np.maximum(ww*inp.read_lower.to_numpy(),ww*inp.read_upper.to_numpy()).sum()
                lower=np.array([obs.iloc[i].read_lower,obs.iloc[j].read_lower,fmin]);upper=np.array([obs.iloc[i].read_upper,obs.iloc[j].read_upper,fmax]);l,r=loss_box(aa,lower,upper)
                boxes.append([origin,h,target,shift,fmin,fmax,l,r])
    columns=['origin_s','requested_horizon_s','target_s','initial_g','target_g','source_known','prefix_known','hold','static_increment','unknown_received_command_hold']
    forecasts=pd.DataFrame(rows,columns=columns);forecasts.to_csv(out/'ALL_FORECASTS.csv',index=False)
    metrics=[]
    for h,g in forecasts.groupby('requested_horizon_s'):
        for m in columns[5:]:metrics.append([h,m,len(g),np.sqrt(np.mean((g[m]-g.target_g)**2)),(g.target_s-g.origin_s).min(),(g.target_s-g.origin_s).max()])
    pd.DataFrame(metrics,columns=['horizon_s','method','overlapping_forecasts','RMSE_g','actual_horizon_min_s','actual_horizon_max_s']).to_csv(out/'METRICS.csv',index=False)
    box=pd.DataFrame(boxes,columns=['origin_s','horizon_s','target_s','input_shift_s','forcing_lower_g','forcing_upper_g','MSE_difference_lower_g2','MSE_difference_upper_g2']);box.to_csv(out/'INPUT_READING_BOXES.csv',index=False)
    box.groupby(['horizon_s','input_shift_s'])[['MSE_difference_lower_g2','MSE_difference_upper_g2']].mean().to_csv(out/'BOX_MEAN_LOSS_DIFFERENCE.csv')
    origin=18.;y0=float(np.interp(origin,tf,y));q=[18.,18.37,19.,20.]
    a=predict(t,u,origin,y0,q);b=predict(t,u,origin,y0,np.unique(np.r_[q,np.linspace(18,20,401)]));checks.append(['query_grid_final',abs(a[-1]-b[-1]),1e-12])
    checks.append(['independent_augmented_expm',abs(a[-1]-independent_expm(t,u,origin,y0,20)),1e-12])
    checks.append(['initial_value',abs(a[0]-y0),1e-12])
    # Refit through the public training API after poisoning every held-out target.
    poisoned=obs.copy();poisoned.loc[poisoned.time_s>=18,'value']=999.
    poison_fit,poison_profile=fit_prefix(t,u,poisoned)
    checks.append(['prefix_target_poison_refit',float(np.max(abs(np.asarray(poison_fit)-np.array([loss,fitp,fitk])))),0])
    checks.append(['prefix_target_poison_profile',float(np.max(abs(poison_profile-profile))),0])
    future_poison=u.copy();future_poison[t>origin]=999.
    checks.append(['unknown_future_command_poison',abs(received_command_hold(t,future_poison,origin,y0,20)-received_command_hold(t,u,origin,y0,20)),0])
    ht=np.r_[t[t<=origin],20.];hu=np.r_[u[t<=origin],u[t<=origin][-1]]
    checks.append(['unknown_retained_delay_expm',abs(received_command_hold(t,u,origin,y0,20)-independent_expm(ht,hu,origin,y0,20)),1e-12])
    for name,kwargs in [('complex',{'y0':1j}),('wrong_unit',{'input_unit':'rad'}),('outside',{'queries':[100.]})]:
        args=dict(t=t,u=u,origin=18.,y0=y0,queries=[20.]);args.update(kwargs)
        try:predict(**args);failure=1
        except ValueError:failure=0
        checks.append(['reject_'+name,failure,0])
    for name,operation in [('unordered_weights',lambda:weights(t[::-1],18,20)),('beyond_input_support',lambda:weights(t,18,t[-1]+DELAY/2)),('reversed_box',lambda:loss_box(.8,[1,0,0],[0,1,1]))]:
        try:operation();failure=1
        except ValueError:failure=0
        checks.append(['reject_'+name,failure,0])
    chk=pd.DataFrame(checks,columns=['check','error','tolerance']);chk['passed']=chk.error<=chk.tolerance;assert chk.passed.all();chk.to_csv(out/'CHECKS.csv',index=False)
    # Actual readback of all pointwise metrics before manifest.
    fr=pd.read_csv(out/'ALL_FORECASTS.csv');mr=pd.read_csv(out/'METRICS.csv');readerr=max(abs(np.sqrt(np.mean((g[m]-g.target_g)**2))-float(mr[(mr.horizon_s==h)&(mr.method==m)].RMSE_g.iloc[0])) for h,g in fr.groupby('requested_horizon_s') for m in columns[5:]);assert readerr<1e-12
    inputs=[Path(__file__),data/'FIG434_POWER_INPUT.csv',data/'FIG434_FLIGHT_AZ.csv']
    manifest={'identity':'D15_RECOVERY_REIMPLEMENTATION_NEW_CODE_NEW_RUN','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'command':sys.argv,'python':sys.version,'numpy':np.__version__,'platform':platform.platform(),'elapsed_s':time.perf_counter()-start,'input_sha256':{str(p.relative_to(repo)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},'origins':len(origins),'overlapping_forecasts':len(fr),'new_independent_records':0,'readback_metric_max_difference':readerr,'claim':'finite reading boxes, three discrete shifts; not confidence intervals or continuous full uncertainty; not original D15 artifacts'}
    (out/'MANIFEST.json').write_text(json.dumps(manifest,indent=2));print(mr.to_string(index=False));print(manifest)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True);main(ap.parse_args().out)
