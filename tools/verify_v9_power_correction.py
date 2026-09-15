"""Independently read V9 MATLAB MAT/CSV evidence and replay source arithmetic."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import platform

import numpy as np
import scipy
from scipy.io import loadmat


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--code-commit", required=True)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--reference-csv", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    source = repo / "analysis/validation_whole_aircraft_trim/data/CR166536_WING_T4II_VIII.csv"
    with source.open(encoding="utf-8-sig", newline="") as f:
        cells = list(csv.DictReader(f))
    with (args.evidence / "V9_RETRIM_POINTS.csv").open(newline="") as f:
        rows = list(csv.DictReader(f))
    summary = json.loads((args.evidence / "V9_SUMMARY.json").read_text())
    assert summary["executionIdentity"] == "MATLAB_NATIVE"
    assert summary["matlabRelease"] == "2021a"
    assert summary["acceptedPoints"] == 3
    assert summary["componentTests"]["sourceCells"] == 205
    assert summary["defaultLegacyStackBitwiseEqual"]
    assert summary["componentTests"]["helicopterLegacyBitwiseEqual"]
    assert len(rows) == 3 and {int(float(r["speed_kt"])) for r in rows} == {110, 120, 130}
    checks = 0

    def close(actual, expected, tol=1e-8):
        nonlocal checks
        a, e = np.asarray(actual, dtype=float), np.asarray(expected, dtype=float)
        assert np.all(np.isfinite(a)) and np.all(np.isfinite(e))
        error = np.max(np.abs(a - e))
        assert error <= tol, (error, tol, a, e)
        checks += 1

    def lookup(table, coefficient, mast, alpha):
        nodes = {}
        for c in cells:
            if (c["table_name"] == table and c["coefficient"] == coefficient
                    and c["mast_angle_deg"] == str(mast) and c["flap_setting"] == "40/25"
                    and c["status"] == "TRANSCRIBED"):
                x, y = float(c["row_value"]), float(c["value"])
                assert x not in nodes or nodes[x] == y
                nodes[x] = y
        xs = sorted(nodes)
        assert xs[0] <= alpha <= xs[-1]
        return np.interp(alpha, xs, [nodes[x] for x in xs])

    results = []
    for row in rows:
        speed = int(float(row["speed_kt"]))
        assert row["accepted"].lower() in {"1", "true"}
        point = args.evidence / f"trim_{speed:03d}kt"
        saved = loadmat(point / "V9_INDEPENDENT_REPLAY.mat", simplify_cells=True)
        r = saved["replay"]
        assert saved["accepted"]
        P, eo, x, u = r["P"], r["eomOut"], r["x"], r["u"]
        info = eo["components"]  # EOM archives the complete componentInfo container.
        components = info["components"]
        L, R = eo["rotorLeft"], eo["rotorRight"]
        mass, inertia, cg = eo["massProperties"]["mass"], eo["massProperties"]["I"], eo["massProperties"]["cgShift"]
        rho, g = P["env"]["rho"], P["env"]["g"]
        beta = np.pi / 3
        close(P["rotor"]["Omega"] * 60 / (2 * np.pi), 589)
        close(P["validation"]["flapDeg"], 40)
        close(P["wing"]["SslipMaxHalf"], 0)
        close(x[3:7], np.zeros(4))
        close(np.linalg.norm(x[:3]), speed * .514444)
        power = (L["torque"] + R["torque"]) * P["rotor"]["Omega"] / 1000
        close(power, float(row["newPower_kW"]))
        close(np.sum([c["F"] for c in components], axis=0), eo["FaeroProp"])
        close(np.sum([c["M"] for c in components], axis=0), eo["Mtotal"])
        gravity = mass * g * np.array([-np.sin(x[7]), 0, np.cos(x[7])])
        close(gravity, eo["Fgravity"])
        close(eo["FaeroProp"] + gravity, eo["Ftotal"])
        xdot = np.r_[eo["Ftotal"] / mass, np.linalg.solve(inertia, eo["Mtotal"]), np.zeros(3)]
        close(xdot, r["xdot"], 1e-10)
        scaled = xdot.copy()
        scaled[:3] /= g
        residual = np.linalg.norm(scaled)
        close(residual, float(row["replayFullScaledResidualNorm"]), 1e-12)
        assert residual < P["trim"]["residualTolerance"]
        assert eo["physicalConverged"] and eo["physicalBranchSupported"]
        assert float(row["minimumBoundMargin"]) > 1e-7
        close(L["alphaClampCount"] + R["alphaClampCount"], float(row["alphaClampCount"]))
        close(L["machClampCount"] + R["machClampCount"], float(row["machClampCount"]))

        # A75/A76 source mast velocity and spinner area, independently in Python.
        vi = (L["inducedVelocity"] + R["inducedVelocity"]) / 2
        thrust_axis = np.array([np.sin(beta), 0, -np.cos(beta)])
        velocity = x[:3] + vi * thrust_axis
        mast = np.array([x[0] * np.cos(beta) + x[2] * np.sin(beta), x[1],
                         -vi - x[0] * np.sin(beta) + x[2] * np.cos(beta)])
        incidence = np.arctan2(np.hypot(mast[0], mast[1]), abs(mast[2]))
        area = 2 * .3048**2 * (1 + 5.5 * np.sin(incidence)**3)
        drag = .5 * rho * np.dot(mast, mast) * area
        force = -drag * velocity / np.linalg.norm(velocity)
        hub = np.array([P["rotor"]["pivotX"], 0, P["rotor"]["pivotZ"]]) + P["rotor"]["RH_hub"] * thrust_axis - cg
        close(force, info["hubSpinner"]["F"])
        close(np.cross(hub, force), info["hubSpinner"]["M"])
        close(mast, info["hubSpinner"]["VlocalMast"])

        # A70 and source cells, independent of the MATLAB helper arrays.
        cf = (np.linalg.norm(L["F"]) + np.linalg.norm(R["F"])) / (rho * np.pi * P["rotor"]["Omega"]**2 * P["rotor"]["R"]**4)
        mu = (L["mu"] + R["mu"]) / 2
        alpha = np.rad2deg(np.arctan2(x[2], x[0])) - .26 * (.0806 + 60*.00003341 + 60**2*.000007386) * cf / max(.15, mu)**2 * 57.3
        close(alpha, info["wing"]["freefield"]["alphaWing_deg"])
        close(alpha, info["horizontalTail"]["wingFreeAlpha_deg"])
        cl = lookup("4-II", "CL_WP", 0, alpha) / 3 + 2 * lookup("4-II", "CL_WP", 90, alpha) / 3
        cd = lookup("4-IV", "CD_WP", 0, alpha) / 3 + 2 * lookup("4-IV", "CD_WP", 90, alpha) / 3
        q = .5 * rho * (x[0]**2 + x[2]**2)
        lift, drag = q * P["wing"]["S"] * cl, q * P["wing"]["S"] * cd
        a = np.deg2rad(alpha)
        fw = np.array([-drag*np.cos(a)+lift*np.sin(a), 0, -drag*np.sin(a)-lift*np.cos(a)])
        close(fw, info["wing"]["F"])
        rw = np.array([P["wing"]["xAC"], 0, P["wing"]["zAC"]]) - cg
        mw = np.cross(rw, fw) + np.array([0, q*P["wing"]["S"]*P["wing"]["c"]*(-.110), 0])
        close(mw, info["wing"]["M"])
        mach = np.linalg.norm(x[:3]) / P["env"]["aSound"]
        epsilon = lookup("4-V(b)", "epsilon_W_HOGE", 60, alpha) / np.sqrt(1 - mach**2)
        close(epsilon, info["horizontalTail"]["wingDownwash_deg"])
        results.append({"speed_kt": speed, "power_kW": power, "fullScaledResidual": residual,
                        "alphaClampCount": int(float(row["alphaClampCount"]))})

    # This comparison occurs only after all native outputs have been checked.
    # Reference power never enters the MATLAB solver or its acceptance test.
    reference = args.reference_csv or repo / "docs/validation/v8_grid_review_20260914/FIG1c_CONDITIONAL_COMPARISON.csv"
    comparison_path = args.output.parent / "V9_FIG1c_CONDITIONAL_COMPARISON.csv"
    ordered = sorted(rows, key=lambda r: float(r["speed_kt"]))
    speeds = [float(r["speed_kt"]) * .514444 for r in ordered]
    channels = {
        "shaft_power_kW": [float(r["newPower_kW"]) for r in ordered],
        "theta_deg": [float(r["theta_deg"]) for r in ordered],
        "stick_percent_9p6in": [float(r["stick_in"]) / 9.6 * 100 for r in ordered],
    }
    comparison = []
    with reference.open(encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            if r["covered"].lower() != "true":
                continue
            speed, value = float(r["reference_x_mps"]), float(r["reference_value"])
            assert min(speeds) <= speed <= max(speeds), "No comparison extrapolation"
            prediction = float(np.interp(speed, speeds, channels[r["channel"]]))
            error = prediction - value
            comparison.append({"channel": r["channel"], "reference_x_mps": speed,
                               "reference_value": value, "old_calculated_value": float(r["calculated_value"]),
                               "new_calculated_value": prediction, "old_error": float(r["error"]), "new_error": error,
                               "new_power_error_percent": 100 * error / value if r["channel"] == "shaft_power_kW" else "",
                               "readout_2pixel_y": float(r["readout_2pixel_y"]),
                               "status": "CONDITIONAL_SOURCE_MODEL_COMPARISON_NOT_FLIGHT_VALIDATION"})
    assert len(comparison) == 3
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with comparison_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(comparison[0]))
        writer.writeheader()
        writer.writerows(comparison)
    hashes = {str(p.relative_to(args.evidence)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(args.evidence.rglob("*")) if p.is_file() and p != args.output}
    report = {"passed": True, "executionIdentity": "PYTHON_READBACK_OF_NATIVE_MATLAB",
              "checksPassed": checks, "codeCommit": args.code_commit, "workflowRun": args.run_id,
              "python": platform.python_version(), "numpy": np.__version__, "scipy": scipy.__version__,
              "points": results, "sha256": hashes,
              "sourceCellsSHA256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "comparisonReferenceSHA256": hashlib.sha256(reference.read_bytes()).hexdigest(),
              "readerSHA256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "comparison": comparison,
              "claim": "INTERNAL_SOURCE_AND_ARTIFACT_CHECK_NOT_FLIGHT_VALIDATION"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "sha256"}, indent=2))


if __name__ == "__main__":
    main()
