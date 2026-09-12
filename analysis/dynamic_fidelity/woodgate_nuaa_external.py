"""Woodgate/NUAA figure digitization and appendix-model component check.

This is a component-level external check, not an XV-15 validation. The accepted
manuscript only exposes NUAA measurements as plotted square markers; this script
records the pixel-to-axis transform and preserves that limitation.
"""
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json, platform, sys
import numpy as np
import pandas as pd
from PIL import Image
from scipy import ndimage
from scipy.integrate import solve_ivp, quad

R, R0, NB = .54, .2*.54, 2
C = CE = C1 = C2 = .054
A_LIFT, LOCK, RHO, OMEGA = 5.73, 9., 1.29, 125.66
MB, L, G = 2., .6*.54, 9.8
MA = .637*RHO*4/3*np.pi*R**3
I1 = RHO*A_LIFT*CE*R**4/LOCK

def sha(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def _components(image: Path, box):
    arr=np.asarray(Image.open(image).convert('RGB'))
    x0,y0,x1,y1=box; gray=arr[y0:y1,x0:x1].mean(axis=2)
    labels,n=ndimage.label(gray<60, structure=np.ones((3,3)))
    out=[]
    for k in range(1,n+1):
        ys,xs=np.where(labels==k)
        if not len(xs): continue
        x,y=xs.min()+x0,ys.min()+y0; w=xs.max()-xs.min()+1; h=ys.max()-ys.min()+1
        if 3<=w<=12 and 3<=h<=12 and 8<=len(xs)<=30:
            out.append((x+(w-1)/2,y+(h-1)/2,w,h,len(xs)))
    return np.asarray(out)

def digitize_figure(image: Path, figure: int):
    # Rendered at 2x from the accepted manuscript. Bounds were chosen from the
    # printed axes; only black square experimental markers are retained.
    if figure==8:
        box=(430,100,760,360); xleft,xright=458.,735.; ytop,ybottom=158.,355.; ymax=0.010; ymin=0.; legend=(570,250,735,320)
    elif figure==9:
        box=(430,580,760,820); xleft,xright=458.,735.; ytop,ybottom=594.,793.; ymax=0.012; ymin=.002; legend=(550,680,735,770)
    else: raise ValueError(figure)
    comp=_components(image,box)
    # Remove the in-plot legend marker/text region. Do not cut by y: the
    # pre-step low-thrust markers are part of the external response.
    comp=comp[(comp[:,0]>=458)&(comp[:,0]<=733)]
    comp=comp[~((comp[:,0]>=legend[0])&(comp[:,0]<=legend[2])&
                (comp[:,1]>=legend[1])&(comp[:,1]<=legend[3]))]
    if len(comp)<10: raise RuntimeError(f'only {len(comp)} markers found for figure {figure}')
    # Axis transform; x is time [0,1] s, y is CT. One pixel uncertainty is
    # retained as a conservative digitization scale in the output.
    t=(comp[:,0]-xleft)/(xright-xleft)
    ct=ymax+(comp[:,1]-ytop)*(ymin-ymax)/(ybottom-ytop)
    order=np.argsort(t); comp=comp[order]; t=t[order]; ct=ct[order]
    initial=2. if figure==8 else 4.
    return pd.DataFrame({'figure':figure,'initial_collective_deg':initial,'time_s':t,'CT_digitized':ct,
                         'pixel_x':comp[:,0],'pixel_y':comp[:,1],'pixel_uncertainty_CT':abs(ymax-ymin)/(ybottom-ytop)})

def static_terms(theta):
    def dT(r):
        q=(-1+np.sqrt(1+2*r*theta*16*np.pi/(NB*C*A_LIFT)))
        return 4*np.pi*RHO*r*(NB*C*A_LIFT*OMEGA/(16*np.pi)*q)**2
    def dM(r):
        q=(-1+np.sqrt(1+2*r*theta*16*np.pi/(NB*C*A_LIFT)))
        return 4*np.pi*RHO*r**2*(NB*C*A_LIFT*OMEGA/(16*np.pi)*q)**2
    T=quad(dT,R0,R,epsabs=1e-11,epsrel=1e-11)[0]
    M=quad(dM,R0,R,epsabs=1e-11,epsrel=1e-11)[0]
    va=np.sqrt(T/(2*np.pi*R**2*RHO))
    return T,M,va

def model_ct(theta0_deg, times, dynamic=True):
    theta0=np.deg2rad(theta0_deg); theta1=theta0+np.deg2rad(4.)
    dtheta=np.deg2rad(40.)
    _,_,v0=static_terms(theta0)
    def theta(t): return min(theta1, theta0+dtheta*max(0.,t-.1))
    def rhs(t,y):
        th=theta(t); T,M,va=static_terms(th)
        eta=(th-T/(1/6*RHO*NB*OMEGA**2*A_LIFT*CE*R**3))/(1.5*C1/CE*va/(OMEGA*R)) if th else 1.
        # Appendix A Listing 2 freezes beta and beta-dot in rapid(); this is
        # intentionally reproduced, rather than silently adding flap dynamics.
        # The first term is A1/K = theta - 1.5*eta*v/(Omega R).  Using the
        # static thrust ratio T/K here would incorrectly replace the appendix
        # dynamic-input term by the quasi-steady induced-velocity relation.
        a1_over_k = th - 1.5*eta*y[0]/(OMEGA*R)
        k=1/6*RHO*NB*OMEGA**2*A_LIFT*CE*R**3
        return [(k*a1_over_k-2*np.pi*R**2*RHO*y[0]*(y[0]))/MA] if dynamic else [0.]
    # State is induced velocity only; the appendix output uses beta=beta-dot=0.
    sol=solve_ivp(rhs,(0.,float(np.max(times))),[v0],t_eval=np.asarray(times),
                  rtol=1e-10,atol=1e-12,max_step=.001)
    out=[]
    for t,v in zip(times,sol.y[0]):
        th=theta(float(t));T,M,va=static_terms(th)
        eta=(th-T/(1/6*RHO*NB*OMEGA**2*A_LIFT*CE*R**3))/(1.5*C1/CE*va/(OMEGA*R)) if th else 1.
        # Ct1 in Listing 1: T1 = A1 with beta-dot=0.
        if dynamic: T1=1/6*RHO*NB*OMEGA**2*A_LIFT*CE*R**3*(th-1.5*eta*v/(OMEGA*R))
        else: T1=T
        out.append(T1/(RHO*OMEGA**2*R**4*np.pi))
    return np.asarray(out)

def main(out: Path, pdf: Path, page14: Path, page15: Path):
    out.mkdir(parents=True,exist_ok=False)
    d8=digitize_figure(page15,8); d9=digitize_figure(page15,9)
    data=pd.concat([d8,d9],ignore_index=True); data['CT_model_appendix']=np.nan;data['CT_model_quasisteady']=np.nan
    for init,g in data.groupby('initial_collective_deg'):
        idx=g.index.to_numpy();t=g.time_s.to_numpy();data.loc[idx,'CT_model_appendix']=model_ct(init,t,True);data.loc[idx,'CT_model_quasisteady']=model_ct(init,t,False)
    data.to_csv(out/'WOODGATE_NUAA_DIGITIZED_CT.csv',index=False)
    rows=[]
    for (fig,init),g in data.groupby(['figure','initial_collective_deg']):
        y=g.CT_digitized.to_numpy(); pix=g.pixel_uncertainty_CT.to_numpy();
        for method in ['CT_model_appendix','CT_model_quasisteady']:
            e=g[method].to_numpy()-y
            rows.append({'figure':int(fig),'initial_collective_deg':init,'method':method,'points':len(g),
                         'RMSE_CT':float(np.sqrt(np.mean(e**2))),'MAE_CT':float(np.mean(abs(e))),
                         'max_abs_CT':float(np.max(abs(e))),'mean_digitization_scale_CT':float(np.mean(pix))})
    metrics=pd.DataFrame(rows);metrics.to_csv(out/'WOODGATE_NUAA_METRICS.csv',index=False)
    # The plotted points carry approximately one vertical-pixel uncertainty.
    # Quantify whether the small dynamic-vs-QS ranking survives that reading
    # uncertainty; this is not a statistical measurement uncertainty estimate.
    rng=np.random.default_rng(20260912); urows=[]
    for (fig,init),g in data.groupby(['figure','initial_collective_deg']):
        y=g.CT_digitized.to_numpy(); pix=g.pixel_uncertainty_CT.to_numpy()
        yd=g.CT_model_appendix.to_numpy(); yq=g.CT_model_quasisteady.to_numpy()
        yp=y+rng.uniform(-pix,pix,size=(10000,len(g)))
        rd=np.sqrt(np.mean((yd[None,:]-yp)**2,axis=1)); rq=np.sqrt(np.mean((yq[None,:]-yp)**2,axis=1))
        diff=rd-rq
        urows.append({'figure':int(fig),'initial_collective_deg':init,'draws':10000,
                      'prob_dynamic_lower_rmse':float(np.mean(diff<0)),
                      'rmse_diff_median_dynamic_minus_qs':float(np.median(diff)),
                      'rmse_diff_p05':float(np.quantile(diff,.05)),
                      'rmse_diff_p95':float(np.quantile(diff,.95))})
    pd.DataFrame(urows).to_csv(out/'WOODGATE_NUAA_UNCERTAINTY.csv',index=False)
    manifest={'identity':'WOODGATE_NUAA_COMPONENT_EXTERNAL_FIGURE_REPRODUCTION_ATTEMPT','source':'Woodgate et al., Aerospace Science and Technology 110 (2021) 106425','source_url':'https://eprints.gla.ac.uk/226967/2/226967.pdf','source_pdf_sha256':sha(pdf),'page14_sha256':sha(page14),'page15_sha256':sha(page15),'figures':[7,8,9],'digitized_figures':[8,9],'figure_role':'black square NUAA experimental CT markers from accepted manuscript plots; no raw arrays','rotor':{'R_m':R,'root_cut_m':R0,'blades':NB,'chord_m':C,'airfoil':'NACA23012','rho_kg_m3':RHO,'Omega_rad_s':OMEGA,'rpm':OMEGA*60/(2*np.pi)},'conditions':{'initial_collective_deg':[2,4],'final_increment_deg':4,'rate_deg_s':40,'start_s':.1,'end_s':.2},'model_identity':'Python reimplementation of Appendix A equations with the plotted physical input timing (0.1 s ramp start); not a literal Listing 1/2 execution, which ramps from t=0 in the accepted PDF','digitization':'2x rendering, axes transform recorded in source; approx one pixel vertical uncertainty; plotted points are approximate, not raw measurements','python':sys.version,'platform':platform.platform(),'points':int(len(data)),'external_component_check':True,'quantitative_qualification':False,'status':'NEGATIVE_REPRODUCTION_MISMATCH','reason':'Appendix code time origin differs from plotted test timing and static CT levels do not close at the plotted pre-step points; do not use RMSE as validated prediction evidence','xv15_or_aircraft_validation':False}
    (out/'MANIFEST.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
    print(metrics.to_string(index=False));print(json.dumps(manifest,ensure_ascii=False,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--pdf',type=Path,required=True);p.add_argument('--page14',type=Path,required=True);p.add_argument('--page15',type=Path,required=True);a=p.parse_args();main(a.out,a.pdf,a.page14,a.page15)
