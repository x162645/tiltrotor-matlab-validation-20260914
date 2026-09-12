# Betzina 2002 forward-flight validation evidence

> **Archive notice (2026-09-12):** The CSV files in this directory were generated on the frozen diagnostic branch/workflow identified below and are retained as inherited evidence. They are not a claim that the current branch has completed a fresh run. The current branch now contains the source scripts under `analysis/validation_betzina2002/`; rerun them before labeling the results current-HEAD evidence.

## Evidence status

This directory is the frozen **preliminary low-speed forward-flight validation evidence** for the XV-15 isolated-rotor model on branch `diagnostic/betzina-80x120-forward-validation-20260907`.

The current supported claim is deliberately limited:

> The frozen low-order rotor model shows useful preliminary correlation with Betzina 2002 full-scale low-speed helicopter-mode forward-flight data. It captures the main torque trends, correlates very closely on the negative-shaft-angle side, and shows systematic positive torque bias as shaft angle becomes zero/positive. This is sufficient to support **preliminary low-speed forward-flight usability**, not full-envelope XV-15 forward-flight validation.

It is not XV-15 whole-aircraft trim, stability, handling-quality, transition-mode, airplane-mode, or flight-test validation.

## Primary source and test contract

Primary source:

`Mark D. Betzina, Rotor Performance of an Isolated Full-Scale XV-15 Tiltrotor in Helicopter Mode, AHS Aerodynamics, Acoustics, and Test and Evaluation Technical Specialists Meeting, 2002.`

Public NASA Ames copy:

`https://rotorcraft.arc.nasa.gov/Publications/files/Betzina_AHS02.pdf`

The main fixed-thrust forward comparison uses:

- full-scale right-hand XV-15 rotor in the NASA Ames 80-by-120-Foot Wind Tunnel;
- `Mtip = 0.691`;
- advance ratio `V/(Omega R) = 0.125, 0.15, 0.17, 0.20`;
- shaft angle `alpha = -15, 0, +15 deg`;
- nominal `CT/sigma = 0.075`, with `sigma = 0.089`;
- first-harmonic flapping trimmed to approximately +/-0.1 deg by cyclic pitch.

The validation solve adjusts only the experimental operating controls `theta75`, longitudinal cyclic and validation-only lateral cyclic. **Torque/CQ is never present in the solve residual and is never fitted.**

## Two-cyclic identity gate

The validation-only two-cyclic adapter must reduce to the existing Stage-2 forward rotor when the added lateral cyclic is zero.

Frozen evidence:

- `BETZINA2002_TWO_CYCLIC_IDENTITY_GATE.csv`
- `BETZINA2002_TWO_CYCLIC_IDENTITY_GATE_SUMMARY.csv`

A later audit on workflow run `34129225469` gives maximum absolute difference `2.6112966972666e-17`; all audited points are physically converged; gate = `PASS`.

This demonstrates numerical identity on the audited zero-lateral-cyclic states. It does not claim that lateral cyclic itself has separate external validation.

## Fixed-thrust Figure 16 comparison

MATLAB R2021a diagnostic workflow:

- workflow run: `34113892134`
- head SHA: `99446ba6ec73439ecf453573e56863a0f02e189a`
- artifact: `betzina2002-fig16-comparison`
- artifact ID: `10015481923`
- artifact digest: `sha256:9dd44a9884ac031cd8d66240c64ae2bf92a52f539f34668926299cdfb0c0d537`

Frozen files:

- `BETZINA2002_FIG16_POINT_COMPARISON.csv`
- `BETZINA2002_FIG16_ALPHA_SUMMARY.csv`
- `BETZINA2002_FIG16_OVERALL_SUMMARY.csv`

All 12 operating states are physically closed without fitting torque.

Figure 16 is published graphically rather than as a machine-readable table. Its experimental carrier is therefore explicitly `FIGURE_DIGITIZATION_DIAGNOSTIC`; it must not be represented as raw NASA tabular data.

Shaft-angle summary:

| shaft angle | MAE of CQ/sigma | interpretation |
|---:|---:|---|
| -15 deg | `6.1375e-05` | very close correlation; all four points lie within the declared +/-1e-4 digitization band |
| 0 deg | `3.1359e-04` | main trend retained, with systematic positive torque bias increasing toward higher advance ratio |
| +15 deg | `5.5688e-04` | correct qualitative torque-reduction trend, but systematic positive torque bias in the very-low-torque region |

Percentage error is deliberately not used as the main metric because the experimental +15 deg / high-advance-ratio torque approaches zero.

## Representative multi-load sweep

A second low-cost diagnostic checks whether the Figure-16 behavior is only a single-load coincidence.

MATLAB R2021a workflow:

- workflow run: `34129225469`
- head SHA: `2481fd23cf65a91a0ae133e505cb27460c379f16`
- artifact: `betzina2002-mu017-representative-load-sweep`
- artifact ID: `10021428067`
- artifact digest: `sha256:4ea0153f1f88a710232fa87050a5fe0104806a239a6ae31d049d89605af2b5a1`

Frozen files:

- `BETZINA2002_MU017_REPRESENTATIVE_LOAD_SWEEP_POINTS.csv`
- `BETZINA2002_MU017_REPRESENTATIVE_LOAD_SWEEP_SUMMARY.csv`

The sweep uses advance ratio `0.17`, shaft angles `-5, 0, +5 deg`, and four thrust levels `CT/sigma = 0.06, 0.075, 0.09, 0.105`. All 12 states are physically converged and satisfy the operating-state solve without torque fitting.

The torque-vs-thrust slope has the correct sign and overall trend at all three shaft angles. Model slopes are lower than the digitized experimental slopes:

- -5 deg: model `0.05103`, experiment diagnostic `0.06217`;
- 0 deg: model `0.03594`, experiment diagnostic `0.04232`;
- +5 deg: model `0.02242`, experiment diagnostic `0.02659`.

This shows a load-dependent quantitative discrepancy, but not a collapse of the forward-flight trend structure.

## Declared model/test mismatches

The source/test and present low-order model are not silently treated as identical:

- the Rotor Test Apparatus pitch-link arrangement had `delta3 = -36 deg`; the present rotor has no active homologous delta3 pitch-flap-coupling state;
- Betzina reports 1.5 deg hub precone; the current adapter does not add a new precone state merely to improve correlation;
- Rotor Test Apparatus body effects are not modeled;
- the forward rotor retains the Stage-2 source-informed geometry/C81 + Corrigan n=1 + global-momentum/first-harmonic low-order identity;
- the C81 diagnostic lookup has a finite incidence range and any out-of-range use is reported rather than hidden;
- higher-order/nonlocal wake, elastic blade dynamics, and full three-dimensional/unsteady section aerodynamics are not represented.

## Current preliminary conclusion

The evidence supports the following bounded conclusion:

1. The model is not generally invalid in low-speed forward flight.
2. It reproduces the principal torque trend with advance ratio and thrust loading.
3. Negative shaft-angle correlation is quantitatively strong in the tested Figure-16 slice.
4. Zero and positive shaft-angle regions show a systematic positive torque bias, strongest where the measured torque itself becomes very small.
5. The representative multi-load sweep confirms that the forward trend is not limited to one thrust point, while also showing non-negligible slope error.
6. The present evidence is enough to justify carrying the rotor model forward as a **preliminarily validated low-speed forward-flight research model**, while explicitly retaining a limited accuracy envelope.
7. Full forward-flight validation still requires at least an independent additional dataset and/or broader observables before claiming full helicopter-mode coverage.

Claim boundary: **isolated-rotor low-speed helicopter-mode preliminary external validation; not full XV-15 forward-flight envelope or whole-aircraft validation.**
