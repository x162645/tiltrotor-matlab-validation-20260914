# Whole-aircraft trim external-validation gate — 2026-09-07

## Status

**BLOCKED / NOT HOMOLOGOUS FOR XV-15 WHOLE-AIRCRAFT EXTERNAL VALIDATION**

This branch was opened to continue the external whole-aircraft trim-validation ladder beyond the Stage-2 internal trim/linearization evidence. The first required check is model/case homology, before any flight-data digitization or error scoring.

That gate currently fails.

## Critical repository evidence

`analysis/stage2_aircraft/stage2_matched_rotor_parameters.m` states that the Stage-2 parameter helper is an:

> XV-15 validation-instance rotor mapping on generic concept airframe — NOT XV15 full aircraft model

The frozen Stage-2 paper-ready findings independently use the same claim boundary: their results are whole-aircraft propagation/sensitivity evidence for the repository's **generic conceptual airframe**, and are **not XV-15 whole-aircraft validation**.

Therefore the present Stage-2 model may be used to study propagation of a frozen rotor-model change through a generic tiltrotor airframe, but it is not an admissible model identity for quantitative comparison against XV-15 whole-aircraft flight trim data.

## What remains valid from PR #73 / Stage 2

The existing Stage-2 evidence remains useful and should not be discarded:

- accepted equilibrium/trim closure at the supported B15/B45/B75 cases;
- accepted control-effectiveness comparisons where the B-matrix gate passes;
- accepted modal/eigenstructure propagation where the A-matrix gate passes;
- retained nonconverged perturbation endpoints as numerical-closure evidence;
- the mechanism chain from frozen rotor-physics changes to equilibrium/load/control-effectiveness/local-dynamic propagation.

Its interpretation must remain **generic-airframe whole-system propagation**, not XV-15 full-aircraft validation.

## Candidate external source identified

A high-value candidate source has been identified:

- G. B. Churchill and D. C. Dugan, *Simulation of the XV-15 Tilt Rotor Research Aircraft*, NASA TM-84222 / AVRADCOM TR-82-A-4, March 1982, NASA NTRS document 19820012300.

The report contains simulation/flight-fidelity comparisons relevant to longitudinal trim and conversion-regime behavior. It is a candidate external-validation source, not yet an admissible scoring dataset for the current Stage-2 model.

No numeric values from plots in this report are promoted in this branch until the exact figure, configuration, units, control definitions, and digitization provenance are visually verified and recorded.

## Why quantitative scoring is blocked

A valid external trim comparison requires both the test case and the computational model to describe the same aircraft/configuration to a declared level of homology. The current Stage-2 model intentionally does not satisfy that requirement at the airframe level.

At minimum, the following contracts must be closed before an XV-15 whole-aircraft trim MAPE/RMSE or PASS/FAIL label is meaningful:

| Gate | Current state | Required state for XV-15 external trim scoring |
|---|---|---|
| Rotor identity | XV-15 validation-instance mapping available | Exact case rotor configuration/RPM/control convention recorded |
| Airframe identity | Generic conceptual airframe | XV-15 wing/fuselage/tail geometry and aerodynamic mapping for the selected test case |
| Mass properties | Generic/model defaults | Selected flight/run weight, CG and relevant inertias documented |
| Nacelle-angle convention | Stage-2 `betaM` exists | Exact mapping to source nacelle-angle convention proven |
| High-lift configuration | Generic schedule/model | Source flap/configuration schedule mapped to the same case |
| Control definitions | Stage-2 collective/cyclic/elevator variables exist | Signs, references, units, gearing/mixing and reported cockpit/control quantities matched |
| Atmosphere / airspeed | Model state available | Source atmosphere and airspeed definition matched |
| External data provenance | Source identified | Exact page/figure/table, case identity, units, and machine-readable values with digitization provenance |
| Scoring policy | Not run | Frozen baseline scored before any empirical correction/tuning |

## Decision

1. **Do not digitize and score XV-15 whole-aircraft trim curves against the current Stage-2 generic airframe.**
2. **Do not tune Stage-2 airframe parameters to make such a comparison pass.**
3. Keep NASA TM-84222 as `SOURCE_IDENTIFIED_NOT_ADMISSIBLE_FOR_CURRENT_MODEL` until the airframe/case homology gate is closed.
4. Preserve PR #73 as generic-airframe propagation evidence under its existing claim boundary.
5. If an XV-15-specific whole-aircraft parameterization is later built, give it a new explicit model identity and freeze it before external scoring.

## Unlock sequence

The next scientifically admissible work is:

1. build an XV-15 whole-aircraft source ledger for geometry, wing/tail aerodynamics, mass properties, controls, nacelle convention, flap schedule, RPM/governor and atmosphere;
2. choose one exact flight/test condition with sufficient metadata;
3. implement a transparent XV-15-specific airframe mapping without fitting to the target trim curve;
4. freeze that mapping as a new validation model identity;
5. visually verify and provenance-log the external trim data;
6. run baseline predictions and only then compute quantitative residuals;
7. retain failures and discrepancies rather than using them for hidden calibration.

Until steps 1–5 are complete, the correct result of this branch is **BLOCKED_BY_MODEL_HOMOLOGY**, not a numerical validation score.

## Repository-staleness note

This diagnostic branch was forked from the 2026-09-01 Stage-2 head. Its inherited root `CODEX_TASK.md` still contains pre-2026-09-05 OARF error numbers and must not be treated as the authoritative statement of the later collective-coordinate correction. This branch does not rewrite that historical file; it only establishes the whole-aircraft trim-validation gate described above.
