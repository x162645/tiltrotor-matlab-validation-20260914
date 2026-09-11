"""Read actual Python and MATLAB output tables; no model re-execution."""
from pathlib import Path
import argparse,json
import numpy as np
import pandas as pd
from scipy.io import loadmat

def main(python_dir, matlab_dir, out):
    p=pd.read_csv(python_dir/'SOURCE_SHAPE_METRICS.csv')
    m=pd.read_csv(matlab_dir/'NATIVE_SOURCE_SHAPE_METRICS.csv')
    keys=['law','b_variant','method','source_delay_included']
    for t in [p,m]:
        t['source_delay_included']=t.source_delay_included.astype(str).str.lower().isin(['true','1'])
    joined=p.merge(m,on=keys,suffixes=('_python','_matlab'),validate='one_to_one')
    assert len(joined)==len(p)==len(m)==48, 'Missing/duplicated native results'
    metrics=['normalized_complex_max','normalized_complex_log_rms','normalized_gain_max_abs_db','normalized_phase_max_abs_deg','any_constant_gain_amplitude_lower_bound','magnitude_ratio_span']
    checks=[]
    for name in metrics:
        a=joined[name+'_python'].to_numpy();b=joined[name+'_matlab'].to_numpy()
        err=float(np.max(abs(a-b)/np.maximum(1,abs(a))))
        checks.append({'metric':name,'max_scaled_difference':err,'tolerance':2e-9,'passed':err<2e-9})
    pb=pd.read_csv(python_dir/'REFERENCE_B.csv')[['variant','b']]
    mb=pd.read_csv(matlab_dir/'NATIVE_REFERENCE_B.csv')
    bj=pb.merge(mb,on='variant',suffixes=('_python','_matlab'),validate='one_to_one')
    err=float(np.max(abs(bj.b_python-bj.b_matlab)))
    checks.append({'metric':'source_derived_b','max_scaled_difference':err,'tolerance':1e-12,'passed':err<1e-12})
    native=loadmat(matlab_dir/'D12_NATIVE_RESULTS.mat',simplify_cells=True)
    assert 'result' in native and np.isfinite(native['result']['ct0'])
    nativechecks=pd.read_csv(matlab_dir/'NATIVE_CHECKS.csv')
    assert nativechecks.passed.astype(str).str.lower().isin(['true','1']).all()
    out.mkdir(parents=True,exist_ok=False)
    pd.DataFrame(checks).to_csv(out/'PYTHON_MATLAB_CROSSCHECK.csv',index=False)
    manifest={'status':'ACTUAL_MAT_CSV_JSON_READ_BACK','matlab':json.loads((matlab_dir/'NATIVE_MANIFEST.json').read_text()),'python':json.loads((python_dir/'EXECUTION_MANIFEST.json').read_text()),'matched_rows':len(joined),'passed':all(c['passed'] for c in checks),'native_mat_ct0':float(native['result']['ct0']),'max_comparison_difference':max(c['max_scaled_difference'] for c in checks)}
    (out/'READBACK_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
    assert manifest['passed'], 'Native/Python agreement failed; preserve outputs'
    print(json.dumps({'status':manifest['status'],'matched_rows':len(joined),'max_difference':manifest['max_comparison_difference']}))
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--python',type=Path,required=True);a.add_argument('--matlab',type=Path,required=True);a.add_argument('--out',type=Path,required=True);args=a.parse_args();main(args.python,args.matlab,args.out)
