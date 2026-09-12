"""Independent Python reconstruction and actual MAT/CSV readback; D16 only."""
from pathlib import Path
import argparse, datetime, hashlib, json, re, sys
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.interpolate import PchipInterpolator,RegularGridInterpolator
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def source(root,n=128):
    text=(root/'analysis/xv15_c81_section_lookup.m').read_text(encoding='utf-8');text=re.sub(r'%[^\n]*','',text).replace('...','');arrays={}
    for key,lit in re.findall(r'(T\.[A-Za-z0-9_.()]+)\s*=\s*\[([^\]]+)\]\s*;',text):
        arrays[key]=np.array([np.fromstring(row.replace(',',' '),sep=' ') for row in lit.split(';') if row.strip()])
    aliases=re.findall(r'(T\.[A-Za-z0-9_.()]+)\s*=\s*(T\.[A-Za-z0-9_.()]+)\s*;',text)
    for _ in aliases:
        for a,b in aliases:
            if b in arrays:arrays[a]=arrays[b]
    tables=[]
    for i in range(1,5):tables.append([RegularGridInterpolator((arrays['T.alphaDeg'].ravel(),arrays[f'T.region({i}).mach{k}'].ravel()),arrays[f'T.region({i}).{k}'],bounds_error=True) for k in ['CL','CD']])
    edges=[.0875,.2,.25,.55,.8,.95,1];r=np.concatenate([a+(np.arange(n)+.5)*(b-a)/n for a,b in zip(edges[:-1],edges[1:])]);w=np.concatenate([np.full(n,(b-a)/n) for a,b in zip(edges[:-1],edges[1:])]);ch=np.where(r<=.25,-18.4615*r+18.6154,14)*.0254
    poly=[289.98,-892.87,987.06,-438.31,15.695,32.057];twist=np.deg2rad(np.polyval(poly,r)-np.polyval(poly,.75));region=np.searchsorted([.55,.8,.95],r,side='right');KL=1.291*(ch/(r*3.81))**.0775
    def evaluate(theta,lam,mode='V4'):
        v=np.hypot(r,lam);a=np.rad2deg(theta+twist-np.arctan2(lam,r));ma=v*(768*.3048)/340;cl=np.empty(len(r));cd=np.empty(len(r))
        for j,(CL,CD) in enumerate(tables):
            m=region==j;q=np.column_stack([a[m],ma[m]]);cl[m],cd[m]=CL(q),CD(q)
        if mode=='V4':cl=np.where(cl>0,KL*cl,cl)
        elif mode!='OFF':raise ValueError(mode)
        return 3/(2*np.pi)*np.sum(w*ch/3.81*v*(cl*r-cd*lam))
    return evaluate

def main(run,out):
    out.mkdir(parents=True,exist_ok=False);root=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file())
    tr=pd.read_csv(run/'TRACES.csv');met=pd.read_csv(run/'METRICS.csv');cases=pd.read_csv(run/'CASES.csv');s=pd.read_csv(root/'docs/research/dynamic_fidelity/evidence_d11/channel/data/OARF_RUN15_EXISTING_STATIC_POINTS.csv');S=PchipInterpolator(np.deg2rad(s.theta75_report_index_deg),s.CT,extrapolate=False)
    mat=loadmat(run/'D16_RESULTS.mat',simplify_cells=True)['results'];outputs=mat['outputs'];checks=[]
    # MATLAB table objects are not used as data by scipy; raw numeric output structs are.
    for i,row in cases.iterrows():
        for j,method in enumerate(['DIRECT','LUT','LTI_EXACT','SCHEDULED_EXACT','QS']):
            g=tr[(tr.case_id==row.case_id)&(tr.method==method)]
            o=outputs[i,j] if outputs.ndim==2 else outputs[j]
            ct=o['CT'] if isinstance(o,dict) else o.CT
            checks.append(['MAT_CSV_'+str(int(row.case_id))+'_'+method,float(np.max(abs(np.asarray(ct)-g.CT.to_numpy()))),1e-13])
    rebuilt=[]
    for case,g in tr.groupby('case_id'):
        ref=g[g.method=='DIRECT'];den=np.sqrt(np.mean(ref.non_eq_CT**2))
        for method,a in g.groupby('method'):
            score=np.sqrt(np.mean((a.CT.to_numpy()-ref.CT.to_numpy())**2))/den;reported=float(met[(met.case_id==case)&(met.method==method)].nonequilibrium_relative_RMSE.iloc[0]);rebuilt.append([case,method,score]);checks.append(['score_'+str(case)+'_'+method,abs(score-reported),1e-10])
    B=source(root);bt=np.linspace(np.deg2rad(6),np.deg2rad(11),41);bv=np.array([-(B(th,np.sqrt(S(th)/2)+1e-5)-B(th,np.sqrt(S(th)/2)-1e-5))/(2e-5) for th in bt]);omega=(768*.3048)/3.81
    # Independent exact aerodynamic-tangent/momentum propagation on all cases.
    for _,row in cases.iterrows():
        g=tr[(tr.case_id==row.case_id)&(tr.method=='SCHEDULED_EXACT')];t=g.time_s.to_numpy();th0=np.deg2rad(row.theta0_deg);amp=np.deg2rad(row.amplitude_deg);on=.2;off=on+row.duration_s;bounds=[0,on,off,row.duration_s+1];ll=np.zeros(len(t));state=np.sqrt(S(th0)/2)
        for j,(a,b) in enumerate(zip(bounds[:-1],bounds[1:])):
            th=th0+(amp if j==1 else 0);ls=np.sqrt(S(th)/2);bvj=np.interp(th,bt,bv);ids=(t>=a-2e-14)&(t<=b+2e-14);h=t[ids]-a;e0=state-ls;z=np.exp(-omega/row.k*(bvj+4*ls)*h);v=ls+e0*z/(1+2*e0/(bvj+4*ls)*(1-z));ll[ids]=v;state=v[-1]
        theta=g.theta_rad.to_numpy();pred=S(theta)-np.interp(theta,bt,bv)*(ll-np.sqrt(S(theta)/2));checks.append(['independent_scheduled_'+str(int(row.case_id)),float(np.max(abs(pred-g.CT))),1e-10])
    hyp=pd.read_csv(run/'SOURCE_HYPOTHESES.csv')
    for _,r in hyp[hyp.source.isin(['OFF','V4'])].iterrows():
        th=np.deg2rad(r.theta_report_deg+r.offset_deg);ls=np.sqrt(r.S/2);b=-(B(th,ls+r.derivative_step,r.source)-B(th,ls-r.derivative_step,r.source))/(2*r.derivative_step);checks.append(['independent_B_'+r.source,float(abs(B(th,ls,r.source)-r.raw_B)),1e-12]);checks.append(['independent_b_'+r.source,float(abs(b-r.b)),1e-9])
    check=pd.DataFrame(checks,columns=['check','error','tolerance']);check['passed']=check.error<=check.tolerance;check.to_csv(out/'READBACK_CHECKS.csv',index=False)
    assert check.passed.all(),check[~check.passed].to_string()
    joined=met.merge(cases,on='case_id');joined['passed_1pct']=joined.nonequilibrium_relative_RMSE<=.01
    summary=joined.groupby('method').agg(cases=('case_id','count'),pass_count=('passed_1pct','sum'),worst_relative_RMSE=('nonequilibrium_relative_RMSE','max'),median_relative_RMSE=('nonequilibrium_relative_RMSE','median')).reset_index();summary.to_csv(out/'METHOD_SUMMARY.csv',index=False)
    domain=joined.groupby(['method','amplitude_deg','duration_s']).agg(worst_relative_RMSE=('nonequilibrium_relative_RMSE','max'),pass_count=('passed_1pct','sum'),cases=('case_id','count')).reset_index();domain.to_csv(out/'DOMAIN_SUMMARY.csv',index=False)
    cost=pd.read_csv(run/'FULL_PREDICTION_COST.csv').groupby('method').seconds.agg(['median','min','max']);cost.to_csv(out/'COST_SUMMARY.csv')
    # Report source sensitivity separately from numerical approximation.
    frf=pd.read_csv(run/'CONDITIONAL_FRF.csv');parts=[]
    for (th,memory),g in frf[frf.source.isin(['OFF','V4'])].groupby(['theta_report_deg','memory']):
        piv=g.assign(G=g.G_real_CT_per_rad+1j*g.G_imag_CT_per_rad).pivot(index='omega_rad_s',columns=['source','offset_deg'],values='G');nom=piv[('V4',0)];spread=np.max(abs(piv.to_numpy()-nom.to_numpy()[:,None]),axis=1)/abs(nom.to_numpy());parts.append(pd.DataFrame({'theta_deg':th,'memory':memory,'omega_rad_s':piv.index,'max_relative_complex_difference_from_V4_zero_offset':spread}))
    spread=pd.concat(parts);spread.to_csv(out/'SOURCE_PREDICTION_SPREAD.csv',index=False)
    plt.rcParams.update({'font.size':10,'figure.dpi':150,'axes.spines.top':False,'axes.spines.right':False})
    fig,ax=plt.subplots(1,2,figsize=(10.6,3.8));show=joined[joined.method.isin(['LUT','LTI_EXACT','SCHEDULED_EXACT'])]
    for i,m in enumerate(['LUT','LTI_EXACT','SCHEDULED_EXACT']):
        vals=show[show.method==m].nonequilibrium_relative_RMSE.to_numpy()*100;ax[0].scatter(np.full(len(vals),i),vals,s=10,alpha=.55)
    ax[0].set_xticks(range(3),['LUT','Fixed LTI','Scheduled exact']);ax[0].axhline(1,color='black',ls='--',lw=1);ax[0].set_yscale('log');ax[0].set_ylabel('Non-equilibrium NRMSE (%)');ax[0].set_title('72 conditional cases; 1% numerical budget')
    for (th,m),g in spread.groupby(['theta_deg','memory']):ax[1].semilogx(g.omega_rad_s,100*g.max_relative_complex_difference_from_V4_zero_offset,label=f'{th:g} deg / {m}')
    ax[1].set_xlabel('Frequency (rad/s)');ax[1].set_ylabel('Conditional source spread (%)');ax[1].set_title('OFF/V4 and -1/0/+1 deg hypotheses');ax[1].legend(fontsize=7,ncol=2);fig.tight_layout();fig.savefig(out/'prediction_domain.png');plt.close(fig)
    c=cases[(cases.theta0_deg==8.5)&(cases.amplitude_deg==.3)&(cases.duration_s==.1)&(cases.memory=='PP')]
    if len(c):
        fig,ax=plt.subplots(figsize=(8,3.5));g=tr[tr.case_id==c.case_id.iloc[0]]
        for method,z in g.groupby('method'):ax.plot(z.time_s,1e4*z.non_eq_CT,label=method)
        ax.set_xlim(.15,.65);ax.set_xlabel('Time (s)');ax.set_ylabel('Non-equilibrium CT (x 1e-4)');ax.legend(fontsize=8,ncol=2);fig.tight_layout();fig.savefig(out/'transient_comparison.png');plt.close(fig)
    manifest={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'identity':'INDEPENDENT_PYTHON_D16_NUMERIC_READBACK','python':sys.version,'run':str(run),'checks':len(check),'max_error':float(check.error.max()),'all_passed':bool(check.passed.all()),'input_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in run.iterdir() if p.is_file()},'new_external_experiments':0};(out/'READBACK_MANIFEST.json').write_text(json.dumps(manifest,indent=2));print(summary.to_string(index=False));print(cost.to_string());print(manifest['checks'])

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();main(a.run,a.out)
