"""Read native MAT outputs and compare them to source Figure 1(c); no plots.

The original four-panel CSV is retained. Only panel c is re-read here after
inspection found its old axes were displaced. Reference coordinates are
fixed from the image, independently of the computed trim outputs.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image
from scipy.io import loadmat


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--output-base", type=Path, required=True)
    args = ap.parse_args()
    base = args.output_base.resolve()
    out = base / "V8_GRID_REVIEW_20260914"
    out.mkdir(exist_ok=True)
    repo = Path(__file__).resolve().parents[2]
    runs = [
        ("fixed12", "V7_ANGLE_SCREEN_AIRPLANE_SOURCE_20260914_FULL"),
        ("adaptive16", "V7_ANGLE_SCREEN_ADAPTIVE_20260914"),
        ("continuation", "V8_CONTINUATION_IN030_20260914"),
        ("empty_area_fix", "V8_EMPTY_AREA_FIX_20260914"),
        ("airplane_mach_fix", "V8_AIRPLANE_MACH_INTERPOLATION_20260914"),
    ]
    rows, hashes = [], []
    for run, folder in runs:
        files = sorted((base / folder).rglob("IN*_V*.mat"))
        assert files, folder
        for path in files:
            data = loadmat(str(path), simplify_cells=True)
            r = data["rec"]["row"].copy()
            r.update(run=run, carrier=str(path.relative_to(base)))
            r["shaft_power_kW"] = np.nan
            r["stick_percent_9p6in"] = r["stick_in"] / 9.6 * 100
            rec = data["rec"]
            if "point" in rec:
                p, state = data["P"], rec["point"]
                r["rpm"] = p["rotor"]["Omega"] * 60 / (2 * np.pi)
                eo = state["eomOut"]
                r["shaft_power_kW"] = sum(
                    eo[k]["torque"] * p["rotor"]["Omega"]
                    for k in ("rotorLeft", "rotorRight")
                ) / 1000
                residual = state["xdot"][[0, 2, 4]].copy()
                residual[:2] /= p["env"]["g"]
                assert abs(np.linalg.norm(residual) - r["residualNorm"]) < 1e-10
            rows.append(r)
            hashes.append(dict(path=str(path.relative_to(base)),
                               sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    all_points = pd.DataFrame(rows)
    all_points.to_csv(out / "ALL_ATTEMPTS.csv", index=False, encoding="utf-8-sig")
    counts = all_points.groupby("run").numericallyAccepted.agg(["count", "sum"])
    counts.to_csv(out / "RUN_COUNTS.csv", encoding="utf-8-sig")

    source = repo / "docs/validation/wang2025_digitization/source_images/F001.jpg"
    pixels = np.asarray(Image.open(source)).astype(int)
    blue = ((pixels[:, :, 2] > pixels[:, :, 0] + 25) &
            (pixels[:, :, 2] > pixels[:, :, 1] + 5) &
            (pixels[:, :, 0] < 120) & (pixels[:, :, 1] < 170))
    # Pixel axes are midpoint of the two dark spine pixels, visually checked.
    # [left,right,top,bottom,ymin,ymax], all four x axes are 40..90 m/s.
    axes = [[1044.5, 1384.5, 25.5, 199.5, 20, 80],
            [1046.5, 1384.5, 308.5, 483.5, 0, 100],
            [1044.5, 1384.5, 601.5, 775.5, -40, 40],
            [1044.5, 1384.5, 895.5, 1070.5, 0, 2500]]
    refs = []
    for row, (left, right, top, bottom, ymin, ymax) in enumerate(axes):
        for approximate_x in [1123, 1193, 1264, 1332]:
            x0, x1 = approximate_x - 10, approximate_x + 11
            y0, y1 = int(top + 5), int(bottom - 5)
            yy, xx = np.where(blue[y0:y1, x0:x1])
            assert len(xx) > 60
            # Merge both blue halves when the black curve occludes a marker.
            xmin, xmax = int(xx.min()+x0), int(xx.max()+x0)
            ymin_px, ymax_px = int(yy.min()+y0), int(yy.max()+y0)
            assert 8 <= xmax-xmin <= 16 and 7 <= ymax_px-ymin_px <= 16
            xc, yc = (xmin+xmax)/2, (ymin_px+ymax_px)/2
            refs.append(dict(row=row, x_pixel=xc, y_pixel=yc,
                x_mps=40 + (xc-left)/(right-left)*50,
                value=ymax-(yc-top)/(bottom-top)*(ymax-ymin),
                readout_2pixel_x_mps=2/(right-left)*50,
                readout_2pixel_y_native=2/(bottom-top)*(ymax-ymin),
                role="WANG_FIG1C_BLUE_CR166537_MODEL_REFERENCE",
                pixel_bbox=json.dumps([xmin,xmax,ymin_px,ymax_px])))
    refs = pd.DataFrame(refs)
    refs.to_csv(out / "FIG1c_SOURCE_POINTS_REVISED.csv", index=False, encoding="utf-8-sig")

    selected = all_points[(all_points.nacelle_deg == 30) &
                          (all_points.numericallyAccepted == 1) &
                          all_points.run.isin(["adaptive16", "continuation", "empty_area_fix"])]
    selected = selected.sort_values("speed_mps")
    selected.to_csv(out / "IN030_ACCEPTED_CHAIN.csv", index=False, encoding="utf-8-sig")
    comparisons = []
    channels = {1: "stick_percent_9p6in", 2: "theta_deg", 3: "shaft_power_kW"}
    for _, ref in refs.iterrows():
        if ref.row not in channels:
            continue  # Collective radial/pitch convention is not yet matched.
        valid = selected.speed_mps.min() <= ref.x_mps <= selected.speed_mps.max()
        value = (np.interp(ref.x_mps, selected.speed_mps, selected[channels[ref.row]])
                 if valid else np.nan)
        comparisons.append(dict(channel=channels[ref.row], reference_x_mps=ref.x_mps,
            reference_value=ref.value, calculated_value=value, error=value-ref.value,
            covered=valid, readout_2pixel_y=ref.readout_2pixel_y_native,
            status="CONDITIONAL_CONVENTION_AND_CONFIGURATION_NOT_FULLY_MATCHED" if valid else "NOT_COVERED_NO_EXTRAPOLATION"))
    comparisons = pd.DataFrame(comparisons)
    comparisons.to_csv(out / "FIG1c_CONDITIONAL_COMPARISON.csv", index=False, encoding="utf-8-sig")
    (out / "SOURCE_AND_READBACK.json").write_text(json.dumps(dict(
        source=str(source.relative_to(repo)), sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        axes_pixel=axes, marker_method="blue bounding box center, split halves merged",
        readout_allowance="2 pixels; extraction allowance, not a statistical confidence interval",
        old_panel_c_csv="retained; displaced-axis calibration superseded by this extraction",
        collective_comparison="omitted: root/radial convention unresolved",
        execution="MATLAB R2021a model results, Python readback and image extraction",
        model_config="589rpm all angles; XFL3 and helicopter field retained at i_n30; conditional source-family comparison",
        carriers=hashes), ensure_ascii=False, indent=2), encoding="utf-8")
    print(counts.to_string())
    print(comparisons[comparisons.covered].to_string(index=False))


if __name__ == "__main__":
    main()
