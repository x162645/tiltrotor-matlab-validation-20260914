# Whole-aircraft trim external-validation workspace

## Purpose

This directory is the audit boundary between the repository's Stage-2 generic-airframe propagation work and any future quantitative XV-15 whole-aircraft external validation.

Current status: **BLOCKED_BY_MODEL_HOMOLOGY**.

The block is intentional. `analysis/stage2_aircraft/stage2_matched_rotor_parameters.m` maps an XV-15 validation-instance rotor onto the repository's generic conceptual airframe; it explicitly is not an XV-15 full-aircraft model. Therefore XV-15 flight trim data must not be scored against that Stage-2 configuration as though it were an aircraft-level validation case.

## Files

- `source_manifest.csv` — machine-readable external-source/admissibility ledger.
- `homology_contract.csv` — machine-readable model/case homology gates that must all be closed before scoring.
- `check_validation_gate.m` — MATLAB R2021a-compatible audit helper. It validates both ledgers and reports whether external scoring is currently admissible.
- `../../docs/WHOLE_AIRCRAFT_TRIM_VALIDATION_GATE_20260907.md` — scientific decision record and unlock sequence.

## Rules

1. A source being relevant is not enough; the computational aircraft and the source test configuration must be homologous enough for the claimed comparison.
2. No plot values enter a score until page/figure/table, configuration, units and digitization provenance are recorded.
3. No empirical correction is introduced before the frozen baseline is scored.
4. Failed convergence, missing metadata and non-homologous mappings are preserved as explicit blockers.
5. PR #73 Stage-2 results remain generic-airframe propagation/sensitivity evidence, not XV-15 whole-aircraft validation.

## To unlock quantitative trim validation

Create and freeze an XV-15-specific whole-aircraft mapping for one exact external case, including at minimum:

- wing/fuselage/tail geometry and aerodynamics;
- weight, CG and relevant inertias;
- rotor RPM/governor and rotor configuration;
- nacelle-angle convention and mapping to model coordinates;
- flap/high-lift configuration;
- collective, cyclic and elevator sign/reference/gearing definitions;
- atmosphere and airspeed definition;
- exact external-data provenance.

Only after those fields are closed should a prediction table, residual table, MAPE/RMSE or PASS/FAIL gate be added here.
