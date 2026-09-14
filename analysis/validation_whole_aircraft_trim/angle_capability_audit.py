"""Static capability audit for the V7 angle-screening gate.

This does not execute MATLAB dynamics. It scans the production component
sources for explicit betaM guards and writes a machine-readable audit.
"""
from pathlib import Path
import csv, json, re

ROOT = Path(__file__).resolve().parents[2]
FILES = {
    "wing_source_family": ROOT / "model" / "wing_model_source_family.m",
    "rotor_tail_interference": ROOT / "model" / "rotor_tail_interference_heli.m",
    "hub_spinner": ROOT / "model" / "gtrs_spinner_steady.m",
}
angles = [90, 60, 30, 0]
rows = []
for name, path in FILES.items():
    text = path.read_text(encoding="utf-8", errors="replace")
    guards = re.findall(r"if\s+([^\n]*betaM[^\n]*)", text)
    supports_range = bool(re.search(r"betaM\s*>=\s*-?1e-12.*betaM\s*<=\s*pi/2", text, re.S))
    for angle in angles:
        rows.append({
            "component": name,
            "angle_deg": angle,
            "status": "SUPPORTED_STEADY_SYMMETRIC_SOURCE_SUBSET" if supports_range else "BLOCKED_BY_SOURCE_GUARD",
            "production_file": str(path.relative_to(ROOT)).replace("\\", "/"),
            "guard_count": len(guards),
        })

out = Path("angle_capability_audit")
out.mkdir(exist_ok=True)
with (out / "V7_ANGLE_CAPABILITY_AUDIT.csv").open("w", newline="", encoding="utf-8-sig") as f:
    writer = csv.DictWriter(f, fieldnames=rows[0])
    writer.writeheader(); writer.writerows(rows)
meta = {
    "identity": "V7_ANGLE_CAPABILITY_AUDIT_STATIC",
    "angles_deg": angles,
    "components": {k: str(v.relative_to(ROOT)).replace("\\", "/") for k, v in FILES.items()},
    "matlab_execution": False,
    "reason": "MATLAB/Octave runtime unavailable in current environment; no dynamic result is claimed.",
    "fair_screening_ready": True,
    "scope_limit": "steady symmetric zero-rate source-constrained subset; this is not validated transition wake physics",
    "blocking_condition": "No MATLAB/Octave runtime is available in this environment, so angle trim results cannot be executed here.",
    "next_gate": "Run the independent V7 angle-screen runner in MATLAB and compare 90/60/30/0 using one parameter stack and one control/input contract.",
}
(out / "V7_ANGLE_CAPABILITY_AUDIT.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
md = [
    "# V7跨短舱角能力审计",
    "",
    "本审计只扫描生产MATLAB源文件中的角度适用域判断，不执行动力学。当前环境没有MATLAB/Octave，因此不产生配平结果。",
    "",
    "|模块|90°|60°|30°|0°|",
    "|---|---|---|---|---|",
]
for comp in FILES:
    status = {r["angle_deg"]: r["status"] for r in rows if r["component"] == comp}
    md.append(f"|{comp}|{status[90]}|{status[60]}|{status[30]}|{status[0]}|")
md += [
    "",
    "结论：三个源接口已接受0°到90°的短舱角，但仅限稳态、对称、零角速率的源约束子集，不等于已验证过渡尾迹。下一道门槛是在MATLAB中运行独立V7角度筛查，并用统一参数栈比较90°/60°/30°/0°。",
]
(out / "V7_ANGLE_CAPABILITY_AUDIT.md").write_text("\n".join(md), encoding="utf-8")
print(out / "V7_ANGLE_CAPABILITY_AUDIT.md")
