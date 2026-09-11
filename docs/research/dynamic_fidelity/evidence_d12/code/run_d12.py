"""D12: input-gain-independent external response-shape diagnostic.

No fitted gain, delay, pole, physical parameter, or new physical state.
This cannot be called an absolute aircraft validation: the input chain and
same-condition flight parameters are not closed. See the committed plan.
"""
from __future__ import annotations
import argparse, hashlib, json, platform, sys, time
from pathlib import Path
import numpy as np
import pandas as pd
import scipy
from d11_tilt_channel import (Parameters, Channel, reference_b, quasi_ss,
    velocity_bt_with_kinematics, frf, kinematic_contract)

ROOT = Path(__file__).resolve().parents[1]
ANCHOR = 1.0

def source_response(source: dict, omega, include_delay: bool = True):
    w = np.asarray(omega, dtype=float)
    lo, hi = source['frequency_band_rad_s']
    if w.ndim != 1 or not len(w) or np.any(~np.isfinite(w)) or np.any(w < lo) or np.any(w > hi):
        raise ValueError('Source frequency support .1-3 rad/s violated')
    s = 1j*w
    h = np.polyval(source['numerator'], s)/np.polyval(source['denominator'], s)
    return h*np.exp(-s*source['delay_s']) if include_delay else h

def normalize(h, h_anchor):
    h = np.asarray(h, dtype=complex)
    if not np.all(np.isfinite(h)) or not np.isfinite(h_anchor) or abs(h_anchor) < 1e-14:
        raise ValueError('Unresolvable/nonfinite normalization anchor')
    return h/h_anchor

def require_absolute_comparison_ready(source, model_input):
    if not source['absolute_matched_comparison_ready'] or source['input'] != model_input:
        raise ValueError('Absolute input/condition homology is not closed')

def analytic_coefficients(ch: Channel):
    p=ch.p; H=2*p.scale/p.m; Q=p.Omega/ch.k
    d=H*ch.b/p.Vtip; z=4*Q*ch.lambda0
    den=np.array([1., Q*(ch.b+4*ch.lambda0)+d, .5*z*d])
    # Downward g per radian of the REPORT coordinate, not g per power lever %.
    num=(-H*ch.alpha/p.g)*np.array([1., z, 0.])
    return num,den,z,d

def metrics(h, ha, ref, ra, w):
    ratio=normalize(h,ha)/normalize(ref,ra)
    error=np.abs(ratio-1)
    logw=np.log(w); span=logw[-1]-logw[0]
    gain=np.abs(h/ref)
    lower=(gain.max()-gain.min())/(gain.max()+gain.min())
    return {'normalized_complex_max':float(error.max()),
            'normalized_complex_log_rms':float(np.sqrt(np.trapezoid(error**2, logw)/span)),
            'normalized_gain_max_abs_db':float(np.max(np.abs(20*np.log10(np.abs(ratio))))),
            'normalized_phase_max_abs_deg':float(np.max(np.abs(np.angle(ratio,deg=True)))),
            'any_constant_gain_amplitude_lower_bound':float(lower),
            'magnitude_ratio_span':float(gain.max()/gain.min())}

def main(out: Path):
    if out.exists(): raise FileExistsError('Use a new output directory; do not overwrite prior results')
    out.mkdir(parents=True)
    start=time.perf_counter(); checks=[]; rows=[]; curves=[]; models=[]; maps=[]
    source=json.loads((ROOT/'data/TM89428_HOVER_AZ_POWER.json').read_text())
    p=Parameters(); btable=reference_b(p)
    btable.to_csv(out/'REFERENCE_B.csv',index=False)
    def check(name, condition, value=None):
        row={'check':name,'passed':bool(condition),'value':value}; checks.append(row)
        if not condition:
            pd.DataFrame(checks).to_csv(out/'CHECKS.csv',index=False)
            raise AssertionError(name)
    def rejects(name, fn):
        try: fn()
        except ValueError: check(name,True); return
        check(name,False)
    rejects('reject_source_extrapolation',lambda:source_response(source,[.1,3.01]))
    rejects('reject_zero_anchor',lambda:normalize([1+0j],0))
    rejects('reject_absolute_mismatched_input',lambda:require_absolute_comparison_ready(source,'theta75_report_index_rad'))
    checks_base=[ROOT/'code/d11_tilt_channel.py',ROOT/'data/OARF_RUN15_EXISTING_STATIC_POINTS.csv',ROOT/'data/C81_EXISTING_SMALL_ANGLE_EXCERPT.csv']
    hashes_before={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in checks_base}
    for law in ['PP_mean','CF_TN3044']:
        for br in btable.to_dict('records'):
            ch=Channel(br['b'],law,p); ss=ch.ss()
            bt,_=velocity_bt_with_kinematics(ss)
            contenders={'FULL_2':ss,'PHYSICAL_QS_1':quasi_ss(ss),'BT_V_KINEMATIC_1':bt}
            num,den,z,d=analytic_coefficients(ch)
            required_den=np.polymul(source['denominator'],[1.,z])
            required_num=(-source['numerator'][0]*p.g/(2*p.scale/p.m*ch.alpha))*den
            maps.append({'law':law,'b_variant':br['variant'],'numerator_descending':required_num.tolist(),
                         'denominator_descending':required_den.tolist(),'delay_s':source['delay_s'],
                         'poles':np.roots(required_den).tolist(),'zeros':np.roots(required_num).tolist(),
                         'stable':bool(np.all(np.real(np.roots(required_den))<0)),
                         'proper':bool(len(required_num)<=len(required_den)),
                         'use':'ALGEBRAIC_NONIDENTIFIABILITY_WITNESS_ONLY_NOT_AN_ACTUATOR_MODEL'})
            check(f'{law}/{br["variant"]}/required_map_stable_proper',maps[-1]['stable'] and maps[-1]['proper'])
            models.append({'law':law,'b_variant':br['variant'],'b':ch.b,'k':ch.k,
                           'theta0_deg':float(np.rad2deg(ch.theta0)),'ct0':ch.ct0,'lambda0':ch.lambda0,
                           'static_slope_per_rad':ch.slope,'alpha':ch.alpha,
                           'model_poles':np.linalg.eigvals(ss[0]).tolist(),
                           'downward_accel_num':num.tolist(),'den':den.tolist(),
                           'input':'theta75_report_index_rad','source_input':source['input']})
            for n in [129,257,513]:
                w=np.unique(np.r_[np.geomspace(.1,3.,n),ANCHOR]); w[0]=.1; w[-1]=3.
                s=1j*w
                full=-frf(ss,w)[:,1]/p.g
                direct=np.polyval(num,s)/np.polyval(den,s)
                err=float(np.max(np.abs(full-direct)/np.abs(direct)))
                check(f'{law}/{br["variant"]}/{n}/analytic_ss',err<5e-12,err)
                req=np.polyval(required_num,s)/np.polyval(required_den,s)*np.exp(-s*source['delay_s'])
                ref=source_response(source,w,True)
                err=float(np.max(np.abs(req*full/ref-1)))
                check(f'{law}/{br["variant"]}/{n}/map_identity_not_calibration',err<5e-12,err)
                for method, system in contenders.items():
                    physical=kinematic_contract(system)
                    check(f'{law}/{br["variant"]}/{n}/{method}/kinematics',max(physical.values())<1e-10)
                    resp=frf(system,w); h=-resp[:,1]/p.g
                    ha=-frf(system,[ANCHOR])[0,1]/p.g
                    kinetic_error=float(np.max(np.abs(resp[:,1]-s*resp[:,0])/np.abs(resp[:,1])))
                    check(f'{law}/{br["variant"]}/{n}/{method}/a_equals_sv',kinetic_error<5e-12,kinetic_error)
                    base=normalize(h,ha)
                    # Unit/sign changes and arbitrary constant gain must cancel.
                    scale=-2.7*np.pi/180*p.g
                    diff=float(np.max(np.abs(normalize(h*scale,ha*scale)-base)))
                    check(f'{law}/{br["variant"]}/{n}/{method}/unit_gain_invariant',diff<1e-12,diff)
                    for delay in [True,False]:
                        ref=source_response(source,w,delay); ra=source_response(source,[ANCHOR],delay)[0]
                        stat=metrics(h,ha,ref,ra,w)
                        row={'law':law,'b_variant':br['variant'],'method':method,
                             'base_grid_n':n,'actual_grid_n':len(w),'source_delay_included':delay,
                             'frequency_lo':.1,'frequency_hi':3.,'anchor_rad_s':ANCHOR,**stat}
                        rows.append(row)
                        if n==513:
                            model_shape=normalize(h,ha); ref_shape=normalize(ref,ra)
                            curves.append(pd.DataFrame({'law':law,'b_variant':br['variant'],'method':method,
                                'source_delay_included':delay,'omega_rad_s':w,
                                'model_shape_re':model_shape.real,'model_shape_im':model_shape.imag,
                                'source_shape_re':ref_shape.real,'source_shape_im':ref_shape.imag,
                                'normalized_complex_error':np.abs(model_shape/ref_shape-1),
                                'required_map_shape_re':(ref_shape/model_shape).real,
                                'required_map_shape_im':(ref_shape/model_shape).imag}))
    tab=pd.DataFrame(rows)
    tab.to_csv(out/'SOURCE_SHAPE_METRICS_ALL_GRIDS.csv',index=False)
    final=tab[tab.base_grid_n==513].copy(); final.to_csv(out/'SOURCE_SHAPE_METRICS.csv',index=False)
    pd.concat(curves,ignore_index=True).to_csv(out/'SOURCE_SHAPE_FREQUENCY_POINTS.csv',index=False)
    # Differences between the specified nested numerical grids, not a proof of a continuous upper bound.
    conv=[]
    for key,g in tab.groupby(['law','b_variant','method','source_delay_included']):
        for name in ['normalized_complex_max','any_constant_gain_amplitude_lower_bound']:
            spread=float(g[name].max()-g[name].min())
            conv.append(dict(zip(['law','b_variant','method','source_delay_included'],key))|{'metric':name,'grid_spread':spread})
            check('/'.join(map(str,key))+'/'+name+'/grid_consistency',spread<5e-5,spread)
    pd.DataFrame(conv).to_csv(out/'GRID_CONSISTENCY.csv',index=False)
    hashes_after={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in checks_base}
    check('frozen_D11_dependencies_unchanged',hashes_before==hashes_after)
    pd.DataFrame(checks).to_csv(out/'CHECKS.csv',index=False)
    (out/'MODEL_AND_MAP_WITNESSES.json').write_text(json.dumps({'models':models,'required_maps':maps},indent=2)+'\n')
    elapsed=time.perf_counter()-start
    manifest={'status':'EXECUTED_AND_READ_BACK_REQUIRED','execution':'Python, not MATLAB',
              'python':sys.version,'numpy':np.__version__,'scipy':scipy.__version__,'pandas':pd.__version__,
              'platform':platform.platform(),'elapsed_seconds':elapsed,'source':source,
              'fixed_dependency_sha256':hashes_before,
              'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'checks_passed':len(checks),'new_observations':0,'physical_parameters_fitted':0,
              'absolute_flight_validation':False,'new_holdout':False,
              'restriction':'Normalized mismatch is conditional on an unknown constant input map; an unconstrained dynamic map cannot be excluded.'}
    (out/'EXECUTION_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(final[(final.b_variant=='central') & final.source_delay_included][['law','method','normalized_complex_max','normalized_phase_max_abs_deg','any_constant_gain_amplitude_lower_bound']].to_string(index=False))
    print('New D12 calculation complete; seconds=',elapsed,'checks=',len(checks))

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--out',type=Path,required=True)
    main(a.parse_args().out)
