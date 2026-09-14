from pathlib import Path
import json, hashlib, math
import numpy as np
import pandas as pd
from scipy.io import loadmat

root=Path(r'C:/Users/86173/Documents/Codex/2026-09-11/yue/outputs/V7_加密速度_王梓旭对比_20260913/calculation')
df=pd.read_csv(root/'V7_SPEED_SWEEP_POINTS.csv')
ok=df[df.numericallyAccepted==1]
expected=np.array([0.01,*range(5,106,5)],dtype=float)
assert np.array_equal(ok.speed_kt.to_numpy(),expected)
checks=[]
for _,row in ok.iterrows():
    tag=f'{row.speed_kt:06.2f}'.replace('.','p')
    path=root/f'POINT_{tag}kt.mat'
    result=loadmat(path,squeeze_me=True,struct_as_record=False)['result']
    rotor=result.point.eomOut.rotorLeft
    assert abs(rotor.theta75Deg-row.theta75Deg)<1e-10
    assert abs(row.shaftPowerLeft_kW+row.shaftPowerRight_kW-row.totalRotorPower_kW)<1e-8
    assert abs(row.thrustLeft_N-row.thrustRight_N)<1e-7
    assert abs(row.shaftPowerLeft_kW-row.shaftPowerRight_kW)<1e-7
    assert row.wingImmersedHalf_m2==0
    assert row.atBound==0 and row.controlsClamped==0 and row.withinLimits==1
    assert row.physicalConverged==1 and row.physicalBranchSupported==1
    assert row.residualNorm<5e-3
    assert row.repeatEvaluationDifference==0
    for col in ['theta_deg','collectiveControl_deg','theta75Deg','stick_in','totalRotorPower_kW','residualNorm']:
        assert math.isfinite(row[col])
        assert abs(getattr(result.row,col)-row[col])<1e-8
    checks.append({'speed_kt':float(row.speed_kt),'pointFile':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
summary={
 'executionIdentity':'Independent Python readback of MATLAB MAT/CSV; no new model solve',
 'acceptedPointCount':len(ok),'allExpectedTrueCalculatedPointsPresent':True,
 'zeroSpeed':'explicitly skipped because forward-flow source APIs require x(1)>0',
 'nearHoverSpeed_kt':0.01,'pointFilesVerified':len(checks),
 'maxResidualNorm':float(ok.residualNorm.max()),
 'maxAlphaClampCount':int(ok.alphaClampCount.max()),
 'maxMachClampCount':int(ok.machClampCount.max()),
 'controlClampedCount':int(ok.controlsClamped.sum()),
 'solverCounts':ok.solverRevision.value_counts().to_dict(),
 'newtonTime_s':float(ok.loc[ok.solverRevision=='NEWTON_V2','elapsed_s'].sum()),
 'fminsearchTime_s':float(ok.loc[ok.solverRevision=='FMINSEARCH_V1','elapsed_s'].sum()),
 'pointRecords':checks,
}
(root/'INDEPENDENT_READBACK.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
errata={
 'kind':'metadata correction only; no numerical arrays or per-point MAT files modified',
 'field':'contract.productionPhysicsModified',
 'recordedValue':False,'correctedValue':True,
 'appliesTo':['V7_SWEEP_FROZEN.json','V7_SWEEP_FROZEN.mat','V7_SWEEP_FROZEN_V2.json','V7_SWEEP_FROZEN_V2.mat','V7_SPEED_SWEEP_RESULTS.mat'],
 'reason':'Inherited builder default was not updated. The evaluated source V7 variant explicitly sets P.wing.SslipMaxHalf from 4.0 m2 to 0; the source-based fuselage/wing/tail/spinner identities are also explicitly configured. This is a changed model configuration relative to the original builder.',
 'codeCorrection':'Both sweep runners now set contract.productionPhysicsModified=true; per-attempt recovery reads immutable saved attempts.',
 'numericalEffect':'none; existing numeric points and frozen originals are retained',
}
(root/'METADATA_CORRECTION.json').write_text(json.dumps(errata,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='pointRecords'},ensure_ascii=False,indent=2))
