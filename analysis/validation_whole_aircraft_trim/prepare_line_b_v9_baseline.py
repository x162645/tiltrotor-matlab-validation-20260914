"""Materialize renamed, immutable PR1 functions for V9 MATLAB regression."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

BASELINE = "7f672db177256fa6f89b4df5f369ba33a49fc920"
PATHS = [
    "model/gtrs_spinner_steady.m",
    "model/gtrs_wing_heli_coefficients.m",
    "model/gtrs_wing_freefield_angle.m",
    "model/gtrs_heli_tail_tables.m",
    "model/gtrs_horizontal_tail_steady.m",
    "model/horizontal_tail_model.m",
    "model/wing_model_source_family.m",
    "model/wing_model_freefield_consistent.m",
    "analysis/stage2_aircraft/stage2_total_forces_moments.m",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    args.output.mkdir(parents=True, exist_ok=True)
    names = {Path(p).stem for p in PATHS}
    pattern = re.compile(r"\b(" + "|".join(sorted(names)) + r")\b")
    manifest = {"baselineCommit": BASELINE, "files": {}}
    for path in PATHS:
        raw = subprocess.check_output(["git", "show", f"{BASELINE}:{path}"], cwd=root)
        text = pattern.sub(lambda m: "baseline_" + m[0], raw.decode("utf-8-sig"))
        (args.output / ("baseline_" + Path(path).name)).write_text(text, encoding="utf-8")
        manifest["files"][path] = hashlib.sha256(raw).hexdigest()
    (args.output / "BASELINE_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
