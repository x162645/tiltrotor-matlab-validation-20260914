"""Independent readback and one-case scipy reconstruction for D16 heave_native_v2.
Outputs are deliberately outside the repository.
"""
from pathlib import Path
import sys, json, hashlib
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.interpolate import PchipInterpolator
from scipy.optimize import brentq
from scipy.integrate import solve_ivp

HERE = Path(__file__).resolve()
REPO = next(p for p in HERE.parents if (p / "AGENTS.md").is_file())
EVID = REPO / "docs/research/dynamic_fidelity/evidence_d16"
RUN = EVID / "heave_native_v2"
OUT = HERE.parent
# Reuse the prior independent C81 parser; no MATLAB execution or repo writes.
sys.path.insert(0, str(EVID))
from readback_d16 import source as independent_source


def main():
    metrics = pd.read_csv(RUN / "HEAVE_METRICS.csv")
    traces = pd.read_csv(RUN / "HEAVE_TRACES.csv")
    manifest = json.loads((RUN / "HEAVE_MANIFEST.json").read_text())
    mat = loadmat(RUN / "HEAVE_RESULTS.mat", simplify_cells=True)["results"]
    raw = mat["raw"]

    checks = []
    def check(name, value, tol=None):
        value = float(value) if np.isscalar(value) else value
        passed = bool(np.all(np.isfinite(value)) and (tol is None or np.all(np.abs(value) <= tol)))
        checks.append({"check": name, "value": value if np.isscalar(value) else float(np.max(np.abs(value))), "tolerance": tol, "passed": passed})
        return passed

    # CSV/MAT raw object alignment: six raw records are [amp=.1,.3] x [DIRECT,LUT,SCHEDULED_RHS].
    expected_amp = [0.1, 0.1, 0.1, 0.3, 0.3, 0.3]
    expected_method = ["DIRECT", "LUT", "SCHEDULED_RHS"] * 2
    for i, rec in enumerate(raw):
        amp, method = expected_amp[i], expected_method[i]
        g = traces[(traces.amplitude_deg == amp) & (traces.method == method)].reset_index(drop=True)
        for key, col in [("t", "time_s"), ("a", "acceleration_up_mps2"), ("CT", "CT")]:
            arr = np.asarray(rec[key]).reshape(-1)
            check(f"MAT_CSV_{amp:g}_{method}_{key}", np.max(np.abs(arr - g[col].to_numpy())), 1e-12)
        x = np.asarray(rec["x"])
        check(f"MAT_CSV_{amp:g}_{method}_x", np.max(np.abs(x[:, 0] - g.lambda_induced.to_numpy())), 1e-12)
        check(f"MAT_CSV_{amp:g}_{method}_z", np.max(np.abs(x[:, 1] - g.velocity_up_mps.to_numpy())), 1e-12)

    # Basic trace/command support checks.
    check("trace_rows", len(traces), 0)  # replaced below; records a finite scalar
    checks[-1]["passed"] = len(traces) == 6 * 801
    checks[-1]["value"] = len(traces)
    checks[-1]["tolerance"] = "expected 4806"
    check("trace_time_grid", np.max(np.abs(np.sort(traces.time_s.unique()) - np.arange(801) * .005)), 1e-12)
    for amp in [0.1, 0.3]:
        for method in ["DIRECT", "LUT", "SCHEDULED_RHS"]:
            g = traces[(traces.amplitude_deg == amp) & (traces.method == method)].sort_values("time_s")
            check(f"{amp:g}_{method}_finite", np.max(np.abs(g[["theta_rad","lambda_induced","velocity_up_mps","acceleration_up_mps2","CT"]].to_numpy())), None)
            check(f"{amp:g}_{method}_initial_lambda_trim", g.lambda_induced.iloc[0] - g.lambda_induced.iloc[-1] if False else g.lambda_induced.iloc[0] - np.sqrt(float(g.CT.iloc[0]) / 2), 0.02)
            check(f"{amp:g}_{method}_initial_velocity_zero", g.velocity_up_mps.iloc[0], 1e-12)
            # Input pulse is zero through t=1, reaches amp at t=2, and returns to zero at t=3.
            # theta is not in the CSV's independent input; infer from CT only for finite/edge checks.
            check(f"{amp:g}_{method}_prepulse_accel_zero", np.max(np.abs(g[g.time_s <= 1].acceleration_up_mps2.to_numpy())), 2e-7)
            check(f"{amp:g}_{method}_postpulse_accel_finite", np.max(np.abs(g[g.time_s >= 3].acceleration_up_mps2.to_numpy())), None)

    # Reconstruct one DIRECT case independently with solve_ivp and the parsed C81/V4 source.
    static = pd.read_csv(REPO / "docs/research/dynamic_fidelity/evidence_d11/channel/data/OARF_RUN15_EXISTING_STATIC_POINTS.csv")
    S = PchipInterpolator(np.deg2rad(static.theta75_report_index_deg.to_numpy()), static.CT.to_numpy(), extrapolate=False)
    R, V, rho, mass, grav = 3.81, 768 * .3048, 1.225, 6000., 9.80665
    Omega = V / R
    H = 2 * rho * np.pi * R**2 * V**2 / mass
    ct0 = grav / H
    theta0 = brentq(lambda th: float(S(th) - ct0), np.deg2rad(6), np.deg2rad(11))
    l0 = np.sqrt(ct0 / 2)
    k = 128 / (75 * np.pi)
    B = independent_source(REPO)
    amp = 0.3
    def pulse(time):
        return .5 * (1 - np.cos(np.pi * (time - 1))) if 1 <= time <= 3 else 0.
    check("trim_static_CT", float(S(theta0) - ct0), 1e-12)
    check("trim_initial_lambda", l0 - np.sqrt(ct0 / 2), 1e-12)
    check("pulse_t1_zero", pulse(1.), 1e-14)
    check("pulse_t2_peak", pulse(2.) - 1., 1e-14)
    check("pulse_t3_zero", pulse(3.), 1e-14)
    def rhs(time, state):
        lam, z = state
        th = theta0 + amp * np.pi / 180 * pulse(time)
        s = float(S(th)); ls = np.sqrt(s / 2); nu = z / V
        ct = s + float(B(th, lam + nu, "V4") - B(th, ls, "V4"))
        acc = H * ct - grav
        return [Omega / k * (ct - 2 * lam * (lam + nu)), acc]
    tout = np.arange(801) * .005
    sol = solve_ivp(rhs, (0., 4.), [l0, 0.], t_eval=tout, rtol=1e-8, atol=[1e-11, 1e-9], max_step=.02, method="RK45")
    direct = traces[(traces.amplitude_deg == amp) & (traces.method == "DIRECT")].sort_values("time_s").reset_index(drop=True)
    check("scipy_direct_solver_success", 0 if sol.success else 1, 0)
    check("scipy_direct_time_grid", np.max(np.abs(sol.t - tout)), 1e-12)
    check("scipy_direct_lambda_vs_matlab", np.max(np.abs(sol.y[0] - direct.lambda_induced.to_numpy())), 5e-7)
    check("scipy_direct_velocity_vs_matlab", np.max(np.abs(sol.y[1] - direct.velocity_up_mps.to_numpy())), 5e-6)
    # Independently evaluate acceleration/CT from reconstructed states.
    ct_py, acc_py = [], []
    for ti, (lam, z) in zip(tout, sol.y.T):
        th = theta0 + amp * np.pi / 180 * pulse(ti); s = float(S(th)); ls = np.sqrt(s / 2); nu = z / V
        ct = s + float(B(th, lam + nu, "V4") - B(th, ls, "V4")); ct_py.append(ct); acc_py.append(H * ct - grav)
    check("scipy_direct_CT_vs_matlab", np.max(np.abs(np.asarray(ct_py) - direct.CT.to_numpy())), 3e-7)
    check("scipy_direct_acceleration_vs_matlab", np.max(np.abs(np.asarray(acc_py) - direct.acceleration_up_mps2.to_numpy())), 3e-5)

    # Rebuild metrics from traces and compare reported values.
    rebuilt = []
    for amp in [0.1, 0.3]:
        ref = traces[(traces.amplitude_deg == amp) & (traces.method == "DIRECT")].sort_values("time_s")
        for method in ["DIRECT", "LUT", "SCHEDULED_RHS"]:
            g = traces[(traces.amplitude_deg == amp) & (traces.method == method)].sort_values("time_s")
            v = np.linalg.norm(g.velocity_up_mps.to_numpy() - ref.velocity_up_mps.to_numpy()) / np.linalg.norm(ref.velocity_up_mps.to_numpy())
            a = np.linalg.norm(g.acceleration_up_mps2.to_numpy() - ref.acceleration_up_mps2.to_numpy()) / np.linalg.norm(ref.acceleration_up_mps2.to_numpy())
            row = metrics[(metrics.amplitude_deg == amp) & (metrics.method == method)].iloc[0]
            rebuilt.append({"amplitude_deg": amp, "method": method, "velocity_rebuilt": v, "velocity_reported": row.velocity_relative_RMSE, "accel_rebuilt": a, "accel_reported": row.acceleration_relative_RMSE})
            check(f"metric_rebuild_{amp:g}_{method}_velocity", v - row.velocity_relative_RMSE, 1e-10)
            check(f"metric_rebuild_{amp:g}_{method}_accel", a - row.acceleration_relative_RMSE, 1e-10)

    check_df = pd.DataFrame(checks)
    check_df.to_csv(OUT / "READBACK_CHECKS.csv", index=False)
    pd.DataFrame(rebuilt).to_csv(OUT / "REBUILT_METRICS.csv", index=False)
    summary = {
        "identity": "INDEPENDENT_D16_HEAVE_NATIVE_V2_READBACK",
        "run": str(RUN),
        "mat_csv_checks": int(len(check_df)),
        "failed_checks": int((~check_df.passed.astype(bool)).sum()),
        "max_abs_check_value": float(np.nanmax(pd.to_numeric(check_df.value, errors="coerce"))),
        "scipy_case": "DIRECT_amp_0.3deg",
        "source": "independent readback_d16.py C81 parser + scipy solve_ivp",
        "external_dynamic_records": int(manifest.get("new_external_dynamic_records", -1)),
        "fixed_hub_qualification_inherited": bool(manifest.get("fixed_hub_72_case_qualification_inherited", True)),
        "input_sha256": {name: hashlib.sha256((RUN / name).read_bytes()).hexdigest() for name in ["HEAVE_METRICS.csv", "HEAVE_TRACES.csv", "HEAVE_RESULTS.mat", "HEAVE_MANIFEST.json"]},
    }
    (OUT / "READBACK_MANIFEST.json").write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))
    print(check_df[~check_df.passed.astype(bool)].to_string(index=False))
    if summary["failed_checks"]:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
