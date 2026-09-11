"""D14 new flight-record prediction only; no historical suite execution.
See D14_PLAN_BEFORE_PREDICTION.md committed before fitting or scoring.
"""
from __future__ import annotations
import argparse,hashlib,json,time,sys,platform
from pathlib import Path
import numpy as np
import pandas as pd
import scipy
from scipy.interpolate import PchipInterpolator
from scipy.optimize import minimize_scalar
from command_reference import SOURCE,first_order_shape,d13_shape,observe_lowpass,predict_power_record,state_space_foh
NAMES=['SOURCE_FROZEN_1STATE','PREFIX_IDENTIFIED_1STATE','STATIC_GAIN_NEGCONTROL','D13_SHAPE_PREFIX_GAIN_DIAGNOSTIC']

def weights(t):
 d=np.diff(t);w=np.r_[d[0]/2,(d[:-1]+d[1:])/2,d[-1]/2];return w/w.sum()

def input_grid(df,t,scenario='central'):
 s=df.time_s.to_numpy();v=df.value.to_numpy()
 if scenario=='read_lower':v=df.read_lower.to_numpy()
 if scenario=='read_upper':v=df.read_upper.to_numpy()
 if scenario=='input_time_plus_0.03s':s=s+.03
 if scenario=='input_time_minus_0.03s':s=s-.03
 td=t-SOURCE['delay_s']
 if td.min()<s.min() or td.max()>s.max():raise ValueError('Input outside digitized support')
 z=PchipInterpolator(s,v,extrapolate=False)(td) if scenario=='PCHIP' else np.interp(td,s,v)
 return z-z[0]

def frozen_plant(static_csv,manifest):
 raw=pd.read_csv(static_csv);S=PchipInterpolator(np.deg2rad(raw.theta75_report_index_deg),raw.CT)
 V=768*.3048;R=3.81;rho=1.225;g=9.80665;mass=6000;scale=rho*np.pi*R*R*V*V
 CT0=mass*g/(2*scale);lam=np.sqrt(CT0/2);H=2*scale/mass;Q=(V/R)/(128/(75*np.pi));b=manifest['b_operating'];d=H*b/V
 th=np.deg2rad(manifest['theta0_deg']);alpha=float(S.derivative()(th))*(1+b/(4*lam))
 return dict(den_s=Q*(b+4*lam)+d,den_const=2*Q*lam*d,zero_rate=4*Q*lam,b=b,H=H,alpha=alpha,g=g,theta0_deg=manifest['theta0_deg'])

def fit_prefix(t,u,flight,plant):
 # Only prefix targets are supplied to this function.
 tt=flight.time_s.to_numpy();yy=flight.value.to_numpy();w=weights(tt)
 def at(rate):
  q=np.interp(tt,t,first_order_shape(t,u,rate));kap=np.dot(w*q,yy)/np.dot(w*q,q)
  loss=np.dot(w,(kap*q-yy)**2) if kap>0 else np.inf
  return float(loss),float(kap)
 grid=np.geomspace(.02,1.,161);prof=np.array([[p,*at(p)] for p in grid]);j=np.argmin(prof[:,1])
 opt=minimize_scalar(lambda p:at(p)[0],bounds=(grid[max(0,j-1)],grid[min(len(grid)-1,j+1)]),method='bounded',options={'xatol':1e-12})
 options=[(prof[j,1],prof[j,0],prof[j,2]),(at(opt.x)[0],float(opt.x),at(opt.x)[1])];loss,rate,kap=min(options)
 q=np.interp(tt,t,d13_shape(t,u,plant));plant_gain=float(np.dot(w*q,yy)/np.dot(w*q,q))
 if plant_gain<=0:raise ValueError('D13 diagnostic negative fitted gain; preserve and investigate')
 return dict(prefix_pole=rate,prefix_kappa=kap,diagnostic_gain=plant_gain,delay_s=SOURCE['delay_s'],train_time_s=[.5,18.],prefix_loss=loss,role='empirical command-level parameters and separate non-installable D13 gain diagnostic',physical_rotor_parameter_fits=0),prof

def responses(t,u,fit,plant):
 return np.column_stack([.0098*first_order_shape(t,u,.105),fit['prefix_kappa']*first_order_shape(t,u,fit['prefix_pole']),-.0098*u,fit['diagnostic_gain']*d13_shape(t,u,plant)])

def main(args):
 out=args.out
 if out.exists():raise FileExistsError('New output directory required')
 out.mkdir(parents=True);started=time.perf_counter()
 inp=pd.read_csv(args.data/'FIG434_POWER_INPUT.csv');fl=pd.read_csv(args.data/'FIG434_FLIGHT_AZ.csv')
 fl=fl[(fl.time_s>=.5)&(fl.time_s<=29)].copy();prefix=fl[fl.time_s<18].copy()
 if len(prefix)<20 or len(fl)==len(prefix):raise ValueError('Incomplete frozen intervals')
 t=np.linspace(.5,29.,1426);u=input_grid(inp,t);plant=frozen_plant(args.static,json.loads(args.plant_manifest.read_text()))
 fit,prof=fit_prefix(t,u,prefix,plant)
 # Store frozen parameters before evaluating later targets.
 (out/'FROZEN_PREFIX_PARAMETERS.json').write_text(json.dumps(fit,indent=2))
 pd.DataFrame(prof,columns=['pole','prefix_weighted_MSE','kappa']).to_csv(out/'PREFIX_PROFILE.csv',index=False)
 (out/'FROZEN_D13_SHAPE.json').write_text(json.dumps(plant,indent=2))
 pred=responses(t,u,fit,plant);records=[];times=fl.time_s.to_numpy();truth=fl.value.to_numpy()
 def calc(pr,sc,obs):
  for j,name in enumerate(NAMES):
   for window,mask in [('prefix',times<18),('later',times>=18),('full',np.ones(len(times),bool))]:
    w=weights(times[mask]);err=pr[mask,j]-obs[mask];den=np.dot(w,obs[mask]**2)
    records.append([sc,window,name,int(mask.sum()),np.sqrt(np.dot(w,err**2)),np.sqrt(np.dot(w,err**2)/den),np.max(abs(err))])
 pp=np.column_stack([np.interp(times,t,pred[:,j]) for j in range(4)]);calc(pp,'central_raw',truth)
 for sc in ['read_lower','read_upper','input_time_plus_0.03s','input_time_minus_0.03s','PCHIP']:
  us=input_grid(inp,t,sc);ps=responses(t,us,fit,plant)
  calc(np.column_stack([np.interp(times,t,ps[:,j]) for j in range(4)]),sc,truth)
 yp=np.interp(t,times,truth,left=truth[0],right=truth[-1]);low_y=observe_lowpass(t,yp);low_p=np.column_stack([observe_lowpass(t,pred[:,j]) for j in range(4)])
 calc(np.column_stack([np.interp(times,t,low_p[:,j]) for j in range(4)]),'common_causal_lowpass_3rads',np.interp(times,t,low_y))
 met=pd.DataFrame(records,columns=['scenario','window','model','original_target_points','RMSE_g','NRMSE','max_abs_error_g']);met.to_csv(out/'PREDICTION_METRICS.csv',index=False)
 trace=fl.copy()
 for j,n in enumerate(NAMES):trace[n]=pp[:,j]
 trace.to_csv(out/'ORIGINAL_TARGET_PREDICTIONS.csv',index=False)
 pd.DataFrame(np.c_[t,u,pred,low_y,low_p],columns=['time_s','delayed_power_perturbation_pct']+NAMES+['observed_lowpass_g']+['LP_'+n for n in NAMES]).to_csv(out/'SIMULATED_TRACES.csv',index=False)
 pairs=[];L=fl.read_lower.to_numpy();U=fl.read_upper.to_numpy();mask=times>=18;w=weights(times[mask])
 for j in range(4):
  for k in range(j+1,4):
   dj=(pp[:,j]-L)**2-(pp[:,k]-L)**2;dk=(pp[:,j]-U)**2-(pp[:,k]-U)**2
   lo=float(w@np.minimum(dj,dk)[mask]);hi=float(w@np.maximum(dj,dk)[mask])
   pairs.append([NAMES[j],NAMES[k],lo,hi,'first_lower_loss' if hi<0 else 'second_lower_loss' if lo>0 else 'not_ordered_by_read_envelope'])
 pd.DataFrame(pairs,columns=['first','second','loss_difference_min_g2','loss_difference_max_g2','read_envelope_order']).to_csv(out/'LATE_SHARED_READ_ENVELOPE.csv',index=False)
 poison=fl.copy();poison.loc[poison.time_s>=18,'value']=999.;checkfit,_=fit_prefix(t,u,poison[poison.time_s<18],plant)
 checks=[['later_target_poison_does_not_change_fit',float(max(abs(checkfit[k]-fit[k]) for k in ['prefix_pole','prefix_kappa','diagnostic_gain'])),1e-13]]
 th=np.linspace(.5,29,2851);uh=input_grid(inp,th);half=responses(th,uh,fit,plant)
 for j,n in enumerate(NAMES):checks.append(['half_dt_'+n,float(np.max(abs(pred[:,j]-half[::2,j]))),5e-5])
 q=first_order_shape(t,u,.105);q2=-state_space_foh(t,u,[[-.105]],[1],[-.105],1)
 checks.append(['first_order_against_independent_state_space',float(np.max(abs(q-q2))),1e-10])
 for iu,ou in [('rad','g_down'),('fraction','g_down'),('percentage_point','newtons')]:
  try:predict_power_record(t,u,input_unit=iu,output_unit=ou);ok=False
  except ValueError:ok=True
  checks.append([f'reject_{iu}_{ou}',0. if ok else 1.,0.])
 api=predict_power_record(inp.time_s.to_numpy(),inp.value.to_numpy(),evaluation_time=t)
 checks.append(['public_API_replays_source_prediction',float(np.max(abs(api-pred[:,0]))),1e-13])
 const=predict_power_record(t,np.ones(len(t))*6);checks.append(['constant_initial_control_zero_perturbation',float(np.max(abs(const))),1e-14])
 bad=pd.DataFrame(checks,columns=['check','absolute_difference','tolerance']);bad['passed']=bad.absolute_difference<=bad.tolerance;bad.to_csv(out/'TARGETED_CHECKS.csv',index=False)
 if not bad.passed.all():raise AssertionError('D14 targeted check failed; preserve outputs')
 ratio=fit['diagnostic_gain']/(plant['H']*plant['alpha']/plant['g']);implied=plant['theta0_deg']+np.rad2deg(ratio*u)
 mapping={'role':'NON_INSTALLABLE_PREFIX_GAIN_DIAGNOSTIC_NOT_MEASURED_ACTUATOR','inferred_constant_rad_per_percent':ratio,'implied_report_coordinate_min_deg':float(implied.min()),'implied_report_coordinate_max_deg':float(implied.max()),'D13_report_coordinate_support_deg':[6.,11.],'implied_theta_outside_D13_support':bool(np.any((implied<6)|(implied>11))),'nonlinear_plant_prediction_released':False,'true_collective_chain_and_matched_case_known':False}
 (out/'PHYSICAL_INTERFACE_GATE.json').write_text(json.dumps(mapping,indent=2))
 costs=[]
 for j,n in enumerate(NAMES):
  for rep in range(5):
   ts=time.perf_counter()
   if j==0:r=.0098*first_order_shape(t,u,.105)
   elif j==1:r=fit['prefix_kappa']*first_order_shape(t,u,fit['prefix_pole'])
   elif j==2:r=-.0098*u
   else:r=fit['diagnostic_gain']*d13_shape(t,u,plant)
   costs.append([n,rep+1,len(t),time.perf_counter()-ts,float(np.sum(r))])
 pd.DataFrame(costs,columns=['model','repeat','samples','elapsed_s','checksum']).to_csv(out/'MATCHED_PROPAGATION_COST.csv',index=False)
 hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [args.data/'FIG434_POWER_INPUT.csv',args.data/'FIG434_FLIGHT_AZ.csv',args.static,args.plant_manifest,Path(__file__),Path(__file__).with_name('command_reference.py')]}
 manifest={'status':'PYTHON_EXECUTED_READBACK_REQUIRED','python':sys.version,'numpy':np.__version__,'scipy':scipy.__version__,'pandas':pd.__version__,'platform':platform.platform(),'elapsed_seconds':time.perf_counter()-started,'original_target_points':len(fl),'prefix_points':len(prefix),'later_points':len(fl)-len(prefix),'input_time_origin_s':.5,'input_prehistory':'constant; subtract initial delayed control','initial_state':'equilibrium; not optimized','physical_rotor_parameter_fits':0,'empirical_command_parameter_fits':2,'D13_noninstallable_diagnostic_gain_fits':1,'new_flight_experiments':0,'new_blind_holdout':False,'historical_scientific_reruns':0,'hashes':hashes}
 (out/'EXECUTION_MANIFEST.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(fit,indent=2));print(met.query("scenario=='central_raw'").to_string(index=False));print(json.dumps(mapping,indent=2))

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--data',type=Path,required=True);a.add_argument('--static',type=Path,required=True);a.add_argument('--plant-manifest',type=Path,required=True);a.add_argument('--out',type=Path,required=True);main(a.parse_args())
