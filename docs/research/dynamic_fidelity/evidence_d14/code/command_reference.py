"""Evidence-typed empirical power-lever -> downward acceleration reference.
This is NOT a blade-collective, rotor-load, CG-load or complete flight model.
SOURCE coefficients are a published frequency-identified descriptor, not
parameters identified from the Fig4.34 verification target.
"""
from __future__ import annotations
import numpy as np
from scipy.linalg import expm
SOURCE={'model_id':'TM89428_EQ4_8','kappa':.0098,'pole':.105,'delay_s':.0074,
 'input_unit':'percentage_point','output_unit':'g_down',
 'evidence':'published flight-identified command-level description',
 'frequency_support_rad_s':[.1,3.],'mechanistic_component_model':False}

def checked_record(t,u):
 t,u=np.asarray(t,float),np.asarray(u,float)
 if t.ndim!=1 or u.shape!=t.shape or len(t)<2:raise ValueError('Matching one-dimensional time/input arrays required')
 if not np.isfinite(t).all() or not np.isfinite(u).all() or not np.all(np.diff(t)>0):raise ValueError('Finite values and strictly increasing time required')
 return t,u

def first_order_shape(t,u,pole):
 # Unit negative high-pass; exact first-order-held input, zero perturbation IC.
 t,u=checked_record(t,u)
 if not np.isfinite(pole) or pole<=0:raise ValueError('Positive finite pole')
 y=np.empty(len(t));z=0.
 for i in range(len(t)):
  y[i]=z-u[i]
  if i+1<len(t):
   h=t[i+1]-t[i];w=-np.expm1(-pole*h)
   z=(1-w)*z+w*u[i]+(h-w/pole)*(u[i+1]-u[i])/h
 return y

def state_space_foh(t,u,A,B,C,D):
 t,u=checked_record(t,u);A=np.asarray(A,float);B=np.asarray(B,float).reshape(-1);C=np.asarray(C,float).reshape(-1);n=len(B)
 if A.shape!=(n,n) or C.shape!=(n,):raise ValueError('State-space dimensions')
 x=np.zeros(n);out=np.empty(len(t));last_h=None;M=None
 Q=np.zeros((n+2,n+2));Q[:n,:n]=A;Q[:n,n]=B;Q[n,n+1]=1.
 for i in range(len(t)):
  out[i]=C@x+D*u[i]
  if i+1<len(t):
   h=t[i+1]-t[i]
   if last_h is None or abs(h-last_h)>1e-12:M=expm(Q*h);last_h=h
   x=(M@np.r_[x,u[i],(u[i+1]-u[i])/h])[:n]
 return out

def d13_shape(t,u,params):
 # Frozen local shape, NOT a physical input calibration.
 a,b,z=params['den_s'],params['den_const'],params['zero_rate']
 return -state_space_foh(t,u,[[0,1],[-b,-a]],[0,1],[-b,z-a],1.)

def observe_lowpass(t,y,cutoff=3.):
 # Common causal observation operation, not new physical/actuator states.
 return state_space_foh(t,y,[[0,1],[-cutoff**2,-np.sqrt(2)*cutoff]],[0,1],[cutoff**2,0],0.)

def predict_power_record(t,command,*,input_unit='percentage_point',output_unit='g_down',parameters=None,evaluation_time=None):
 if input_unit!='percentage_point' or output_unit!='g_down':raise ValueError('Only power-lever percentage points -> downward g is supported')
 t,u=checked_record(t,command);p=SOURCE if parameters is None else parameters
 te=t if evaluation_time is None else np.asarray(evaluation_time,float);checked_record(te,np.zeros_like(te))
 k,rate,delay=float(p['kappa']),float(p['pole']),float(p['delay_s'])
 if not np.isfinite([k,rate,delay]).all() or k<=0 or rate<=0 or delay<0:raise ValueError('Invalid empirical descriptor')
 ud=np.interp(te-delay,t,u,left=u[0],right=u[-1]);ur=ud-ud[0]
 return k*first_order_shape(te,ur,rate)
