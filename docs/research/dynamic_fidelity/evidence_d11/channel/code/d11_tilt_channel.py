"""Static-anchored concept twin-proprotor axial channel. Not an XV-15 flight model.

Inputs are OARF theta75 REPORT indices (radians), not measured rotating pitch.
Off-equilibrium b is an independently specified reference-model derivative.
The static curve cannot identify b; no TN3044 fitted parameter is imported.
"""
from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.interpolate import PchipInterpolator
from scipy.optimize import brentq
from scipy.integrate import quad
from scipy.linalg import solve_continuous_lyapunov, cholesky, svd, expm

ROOT=Path(__file__).resolve().parents[1]
K_MEMORY={'PP_mean':128/(75*np.pi),'CF_TN3044':.637*4/3}

@dataclass(frozen=True)
class Parameters:
    # m,rho,g are explicit concept assumptions, not same-condition flight data.
    m:float=6000.
    rho:float=1.225
    g:float=9.80665
    R:float=3.81
    Vtip:float=768*.3048
    Nb:int=3
    @property
    def Omega(self):return self.Vtip/self.R
    @property
    def scale(self):return self.rho*np.pi*self.R**2*self.Vtip**2
    def validate(self):
        if not all(np.isfinite(x) and x>0 for x in (self.m,self.rho,self.g,self.R,self.Vtip,self.Nb)):
            raise ValueError('Physical parameters must be finite positive')

class StaticMap:
    def __init__(self,path=None):
        self.df=pd.read_csv(path or ROOT/'data/OARF_RUN15_EXISTING_STATIC_POINTS.csv')
        self.theta=np.deg2rad(self.df.theta75_report_index_deg.to_numpy())
        self.ct=self.df.CT.to_numpy()
        self.f=PchipInterpolator(self.theta,self.ct,extrapolate=False)
    def __call__(self,theta):
        v=self.f(theta)
        if np.any(~np.isfinite(v)) or np.any(v<=0):raise ValueError('Static-map input outside 6-11deg or CT<=0')
        return v
    def derivative(self,theta):
        self(theta)
        return self.f.derivative()(theta)

def reference_b(p:Parameters):
    """Linear small-angle BEMT derivative, independent of OARF response targets.

    C81 columns use published-table representative Mach. Root extension and
    small-angle linearization are explicit assumptions, not measured bounds.
    """
    d=pd.read_csv(ROOT/'data/C81_EXISTING_SMALL_ANGLE_EXCERPT.csv')
    cl=d[['span1','span2','span3','span4']].to_numpy()
    slopes={'central':(cl[2]-cl[0])/np.deg2rad(4),
            'left_secant':(cl[1]-cl[0])/np.deg2rad(2),
            'right_secant':(cl[2]-cl[1])/np.deg2rad(2)}
    rows=[]
    for variant in ['central','left_secant','right_secant','central_no_unknown_root']:
        a=slopes['central' if variant=='central_no_unknown_root' else variant]
        root=.2 if variant=='central_no_unknown_root' else .0875
        edges=[root,.55,.8,.95,1.]
        def chord(x):return .0254*(-18.4615*x+18.6154 if x<=.25 else 14.)
        terms=[a[j]*quad(lambda x:chord(x)/p.R*x,edges[j],edges[j+1],
                       points=[.25] if edges[j]<.25<edges[j+1] else None,epsabs=1e-13)[0]
               for j in range(4)]
        b=p.Nb/(2*np.pi)*sum(terms)
        rows.append({'variant':variant,'b':b,'a_span1_per_rad':a[0], 'a_span2_per_rad':a[1],
                     'a_span3_per_rad':a[2],'a_span4_per_rad':a[3],
                     'root_start_R':root,'role':'REFERENCE_DERIVED_CONDITIONAL_NOT_CONFIDENCE_BOUND'})
    return pd.DataFrame(rows)

class Channel:
    def __init__(self,b:float,law='PP_mean',p=None):
        self.p=p or Parameters();self.p.validate();self.static=StaticMap()
        if law not in K_MEMORY:raise ValueError(law)
        if not np.isfinite(b) or b<=0:raise ValueError('b must be positive for stable heave comparison; b=0 is unobservable/marginal boundary')
        self.b=float(b);self.law=law;self.k=K_MEMORY[law]
        self.ct0=self.p.m*self.p.g/(2*self.p.scale)
        if not(self.static.ct[0]<self.ct0<self.static.ct[-1]):raise ValueError('Hover balance outside static support')
        self.theta0=brentq(lambda t:float(self.static(t))-self.ct0,self.static.theta[0],self.static.theta[-1],xtol=1e-14)
        self.lambda0=np.sqrt(self.ct0/2)
        self.x0=np.array([self.p.Vtip*self.lambda0,0.])
        self.slope=float(self.static.derivative(self.theta0))
        self.alpha=self.slope*(1+self.b/(4*self.lambda0))
    def ct(self,x,theta):
        vi,v=np.asarray(x);S=self.static(theta)
        return S+self.b*(np.sqrt(S/2)-(vi+v)/self.p.Vtip)
    def rhs(self,t,x,theta):
        vi,v=x;ct=float(self.ct(x,theta));p=self.p
        if vi<0 or ct<=0:raise ValueError('Positive-thrust/normal-flow domain left; no silent clipping')
        return np.array([p.Vtip*p.Omega/self.k*(ct-2*vi*(vi+v)/p.Vtip**2),2*p.scale/p.m*ct-p.g])
    def observe(self,x,theta):
        p=self.p;ct=self.ct(x,theta)
        return np.array([x[1],2*p.scale/p.m*ct-p.g]),2*p.scale*ct
    def quasi(self,v,theta):
        p=self.p;z=v/p.Vtip;S=float(self.static(theta));c=S+self.b*np.sqrt(S/2)-self.b*z
        if c<=0:raise ValueError('QS positive-flow domain left')
        B=self.b+2*z
        lam=2*c/(B+np.sqrt(B*B+8*c))
        return p.Vtip*lam,2*lam*(lam+z)
    def ss(self):
        p=self.p;b=self.b;lam=self.lambda0;H=2*p.scale/p.m
        A=np.array([[-p.Omega/self.k*(b+4*lam),-p.Omega/self.k*(b+2*lam)],
                    [-H*b/p.Vtip,-H*b/p.Vtip]])
        B=np.array([[p.Vtip*p.Omega/self.k*self.alpha],[H*self.alpha]])
        C=np.array([[0.,1.],A[1]])
        D=np.array([[0.],[B[1,0]]])
        return A,B,C,D

def residualize(A,B,C,D,r=1):
    A11,A12,A21,A22=A[:r,:r],A[:r,r:],A[r:,:r],A[r:,r:]
    X=np.linalg.solve(A22,A21);Z=np.linalg.solve(A22,B[r:])
    return A11-A12@X,B[:r]-A12@Z,C[:,:r]-C[:,r:]@X,D-C[:,r:]@Z

def quasi_ss(ss):
    A,B,C,D=ss
    # Retain physical heave state; eliminate vi, independently of balancing.
    perm=[1,0]
    return residualize(A[np.ix_(perm,perm)],B[perm],C[:,perm],D)

def mature(ss):
    A,B,C,D=ss
    if np.max(np.real(np.linalg.eigvals(A)))>=0:raise ValueError('BT/BSPA require a stable system')
    P=solve_continuous_lyapunov(A,-B@B.T)
    Q=solve_continuous_lyapunov(A.T,-C.T@C)
    S=cholesky((P+P.T)/2,lower=True);R=cholesky((Q+Q.T)/2,lower=True)
    U,s,Vh=svd(R.T@S)
    T=S@Vh.T@np.diag(1/np.sqrt(s));Ti=np.diag(1/np.sqrt(s))@U.T@R.T
    Ab,Bb,Cb=Ti@A@T,Ti@B,C@T
    bt=Ab[:1,:1],Bb[:1],Cb[:,:1],D.copy()
    bspa=residualize(Ab,Bb,Cb,D)
    return bt,bspa,{'hankel_singular_values':s.tolist(),'balancing_inverse_error':float(np.max(abs(Ti@T-np.eye(2)))),
                    'P_balanced_residual':float(np.max(abs(Ti@P@Ti.T-np.diag(s)))),
                    'Q_balanced_residual':float(np.max(abs(T.T@Q@T-np.diag(s))))}

def frf(ss,omega):
    A,B,C,D=ss;eye=np.eye(len(A))
    return np.array([(C@np.linalg.solve(1j*w*eye-A,B)+D)[:,0] for w in omega])

def simulate_foh(ss,t,u):
    """Identical exact first-order-hold discretization for all LTI contenders."""
    A,B,C,D=ss;t=np.asarray(t);u=np.asarray(u);dt=t[1]-t[0];n=len(A)
    if not np.allclose(np.diff(t),dt,rtol=1e-10,atol=1e-12):raise ValueError('Uniform time grid required')
    M=np.zeros((n+2,n+2));M[:n,:n]=A;M[:n,n:n+1]=B;M[n,n+1]=1.
    E=expm(M*dt);Ad=E[:n,:n];G0=E[:n,n];G1=E[:n,n+1]/dt
    x=np.zeros(n);y=np.empty((len(t),C.shape[0]));y[0]=(C@x+D[:,0]*u[0])
    for j in range(len(t)-1):
        x=Ad@x+G0*u[j]+G1*(u[j+1]-u[j]);y[j+1]=C@x+D[:,0]*u[j+1]
    return y

def pulse(t,amp):
    a=np.asarray(t);return np.where((a>=1)&(a<=3),amp*.5*(1-np.cos(np.pi*(a-1))),0.)

def velocity_bt_with_kinematics(ss):
    """Classical SISO velocity BT; reconstruct acceleration by differentiation.

    Input-to-velocity remains strictly proper, and acceleration is C_v*(A z+B u).
    This is a different, explicit projection objective from raw multi-output BT;
    it is not a new aerodynamic state/model or an external-data fit.
    """
    A,B,C,D=ss
    bt,_,meta=mature((A,B,C[:1],D[:1]))
    Ar,Br,Cv,Dv=bt
    if np.max(abs(Dv))>1e-14:raise ValueError('Velocity direct feedthrough incompatible with physical-state derivative output')
    return (Ar,Br,np.vstack((Cv,Cv@Ar)),np.vstack((Dv,Cv@Br))),meta

def kinematic_contract(ss):
    A,B,C,D=ss
    return {'velocity_direct_input':float(np.max(abs(D[:1]))),
            'acceleration_state_defect':float(np.max(abs(C[1:2]-C[:1]@A))),
            'acceleration_input_defect':float(np.max(abs(D[1:2]-C[:1]@B)))}
