"""Actual MAT/CSV/JSON readback, not a green-workflow proxy."""
from pathlib import Path
import argparse,json,hashlib
import numpy as np
import pandas as pd
from scipy.io import loadmat
from run_d14 import NAMES

def main(root):
 p,n=root/'python',root/'native';mat=loadmat(n/'D14_NATIVE_RESULTS.mat',simplify_cells=True)['result']
 py=pd.read_csv(p/'ORIGINAL_TARGET_PREDICTIONS.csv');native=pd.read_csv(n/'NATIVE_PREDICTIONS.csv');pf=json.loads((p/'FROZEN_PREFIX_PARAMETERS.json').read_text());nf=json.loads((n/'NATIVE_PREFIX_PARAMETERS.json').read_text());checks=[]
 for name,arr,ref,tol in [('native_mat_to_csv',mat['predictions'],native[NAMES].to_numpy(),1e-13),('time_points',mat['time'],py.time_s.to_numpy(),1e-12),('native_vs_python_predictions',native[NAMES].to_numpy(),py[NAMES].to_numpy(),2e-8)]:
  err=float(np.max(abs(arr-ref)));checks.append(dict(check=name,max_difference=err,tolerance=tol,passed=err<=tol))
 for name,tol in [('prefix_pole',2e-6),('prefix_kappa',1e-7),('diagnostic_gain',1e-10)]:
  e=abs(nf[name]-pf[name]);checks.append(dict(check=name,max_difference=e,tolerance=tol,passed=e<=tol))
 df=pd.DataFrame(checks);df.to_csv(root/'NATIVE_CROSSCHECK.csv',index=False)
 if not df.passed.all():raise AssertionError('Native mismatch; retain original outputs')
 report={'status':'ACTUAL_NATIVE_MAT_CSV_JSON_DECODED_AND_COMPARED','matched_original_points':len(native),'checks':checks,'native':json.loads((n/'NATIVE_MANIFEST.json').read_text()),'python':json.loads((p/'EXECUTION_MANIFEST.json').read_text()),'new_external_flight_experiments':0,'native_mat_sha256':hashlib.sha256((n/'D14_NATIVE_RESULTS.mat').read_bytes()).hexdigest()}
 (root/'READBACK_MANIFEST.json').write_text(json.dumps(report,indent=2));print(df.to_string(index=False))
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('root',type=Path);main(a.parse_args().root)
