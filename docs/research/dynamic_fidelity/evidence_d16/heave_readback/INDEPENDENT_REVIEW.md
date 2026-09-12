# D16 heave_native_v2 independent readback

Run: `docs/research/dynamic_fidelity/evidence_d16/heave_native_v2`  
Script: `readback_heave.py` (workspace only)  
Generated: 2026-09-12

The script read `HEAVE_METRICS.csv`, `HEAVE_TRACES.csv`, `HEAVE_RESULTS.mat`, and `HEAVE_MANIFEST.json` with SciPy/Pandas, rebuilt all six metrics, and independently integrated the 0.3-degree DIRECT case with `scipy.integrate.solve_ivp` using the existing independent C81/V4 parser.

Checks passed: 85/85. MAT-to-CSV raw vectors match to 5.0e-16; rebuilt velocity/acceleration metrics match reported values to 1e-10; all trace values are finite; each trace has 801 samples on the 0.005 s grid; initial velocity is zero and induced inflow starts at the trimmed equilibrium; pre-pulse acceleration is below 1.0e-7 m/s^2; no fixed-hub qualification is inherited.

Independent 0.3-degree DIRECT solve used the runner's equations and constants (`R=3.81 m`, `V=768 ft/s`, `rho=1.225`, `m=6000 kg`, `k=128/(75*pi)`, cosine pulse over 1--3 s). Maximum differences versus MATLAB raw traces were:

- induced inflow: 6.02e-10 (dimensionless);
- heave velocity: 8.05e-9 m/s (check tolerance 5e-6);
- CT: 8.63e-11 (check tolerance 3e-7);
- acceleration: 8.81e-8 m/s^2 (check tolerance 3e-5).

Reported v2 metrics are therefore internally reproducible:

| amplitude | method | velocity relative RMSE | acceleration relative RMSE |
|---:|---|---:|---:|
| 0.1 deg | LUT | 1.4986e-4 | 1.4958e-4 |
| 0.1 deg | SCHEDULED_RHS | 8.3583e-5 | 1.0332e-4 |
| 0.3 deg | LUT | 8.6865e-5 | 9.4879e-5 |
| 0.3 deg | SCHEDULED_RHS | 1.0372e-4 | 1.4232e-4 |

Limitations: this is a conditional model-to-model check. The manifest reports `new_external_dynamic_records=0` and `memory=PP_only`; no independent dynamic measurement is used. The SciPy reconstruction reuses the existing parsed C81/V4 source and independently checks one DIRECT case, so it is a numerical reproduction rather than physical validation. The runner's acceleration tolerance allows approximately 1e-7 m/s^2 pre-pulse numerical drift, so “zero acceleration” should be stated as near-zero within solver tolerance.
