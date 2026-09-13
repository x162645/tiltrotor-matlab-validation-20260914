"""Independent Python readback of actual MATLAB point carriers and plot tables."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.io import loadmat


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', type=Path, required=True)
    args = p.parse_args()
    out = args.out
    data = pd.read_csv(out/'calculation'/'V7_SPEED_SWEEP_POINTS.csv')
    expected = set(np.r_[np.arange(5,106,5), 0.01, 0.0].tolist())
    assert set(data.speed_kt) == expected, 'Incomplete requested speed inventory'
    assert len(data.speed_kt.unique()) == len(data)
    reads = []
    for _, row in data.iterrows():
        tag = ('%06.2f' % row.speed_kt).replace('.', 'p')
        path = out/'calculation'/('POINT_'+tag+'kt.mat')
        record = loadmat(path, squeeze_me=True, struct_as_record=False)['result']
        assert bool(record.row.numericallyAccepted) == bool(row.numericallyAccepted)
        if row.numericallyAccepted:
            left = record.point.eomOut.rotorLeft
            right = record.point.eomOut.rotorRight
            native = np.asarray(record.z).ravel()
            assert abs(left.theta75Deg-row.theta75Deg) < 1e-8
            assert abs(native[0]*180/np.pi-row.theta_deg) < 1e-8
            assert abs(native[2]-row.stick_in) < 1e-8
            assert abs(row.totalRotorPower_kW-row.shaftPowerLeft_kW-row.shaftPowerRight_kW) < 1e-8
            assert abs(left.thrust-row.thrustLeft_N) < 1e-6
            assert abs(right.thrust-row.thrustRight_N) < 1e-6
            assert abs(row.speed_mps-row.speed_kt*.514444) < 1e-8
        reads.append({'speed_kt': row.speed_kt, 'status': str(record.row.status), 'MAT_CSV_agree': True})
    plotting = pd.read_csv(out/'加密计算_绘图数据.csv')
    assert set(plotting.speed_kt) == expected
    pairs = pd.read_csv(out/'论文图示点_逐点对照.csv')
    valid = pairs[np.isfinite(pairs.calculated_value)]
    assert (valid.low_bracket_speed_kt <= valid.speed_mps/.514444+1e-7).all()
    assert (valid.high_bracket_speed_kt >= valid.speed_mps/.514444-1e-7).all()
    assert ((valid.high_bracket_speed_kt-valid.low_bracket_speed_kt) <= 5.01).all()
    assert set(pairs.reference_role) <= {'red_flight', 'blue_literature'}
    assert not (pairs.variable == 'theta0').any(), 'Unresolved pitch datum was scored'
    result = {'execution': 'INDEPENDENT_PYTHON_READBACK_OF_NATIVE_MATLAB_OUTPUT',
              'requested_rows': len(data), 'accepted': int(data.numericallyAccepted.sum()),
              'MAT_points_checked': len(reads), 'comparison_pairs_with_valid_bracket': len(valid),
              'all_checks_passed': True, 'points': reads}
    (out/'独立读回检查.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k != 'points'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
