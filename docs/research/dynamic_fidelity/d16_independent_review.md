# D16 independent scientific review (static + artifact readback)

Date: 2026-09-12 UTC
Scope: Review of `D16_PLAN_BEFORE_RUN.md`, `d16_model.m`, `d16_source.m`, `d16_predict.m`, `run_d16_prediction_domain.m`, the Python readback, and `evidence_d16/native_full_v1/METRICS.csv`. No MATLAB run or historical suite was performed in this review; source files were not edited.

## Overall assessment

The declared study is mathematically coherent as a **conditional, fixed-hub model-to-model numerical experiment**. The scalar momentum equation and the scheduled Riccati flow are consistent, the ODE and LUT use the same stated tolerances, and all 72 v1 cases completed with finite values. The v1 readback results support the following narrow numerical statements:

- LUT worst non-equilibrium relative RMSE: 0.001114 (0.1114%), below the declared 1% numerical budget.
- SCHEDULED_EXACT worst: 0.002971 (0.2971%), also below 1%.
- LTI_EXACT worst: 1.6802 (168%); QS is exactly 1.0 by construction for this metric.
- v1 online timing medians in `FULL_PREDICTION_COST.csv`: DIRECT ~3.41 s, LUT ~0.0112 s, SCHEDULED_EXACT ~0.0052 s, LTI_EXACT ~0.00029 s, QS ~0.00025 s per complete prediction. These are implementation and environment timings only.

These results do **not** establish aircraft dynamic accuracy, external validation, or superiority of the selected source model.

## Findings that must remain attached to any conclusion

### 1. v1 traces contain repeated command-breakpoint samples (P1 for using v1 as the final dataset)

`d16_predict.m` constructs `t=unique([t;on;off;finish])`. MATLAB `unique` does not merge values that differ by floating-point roundoff. The v1 traces visibly contain zero time increments at some command breakpoints (for example, cases 1-4 and analogous cases in each center group). `evidence_d16/REVISIONS.md` already records this and says v2 aligned breakpoints to the existing grid and retained v1 only as the original run.

This primarily changes sample weighting at one or two points and is unlikely to reverse the broad LUT/LTI ranking, but it violates the declared single 0.002 s output grid and makes v1 metrics unsuitable as the sole final record. Final reporting should use the corrected v2 run (and state that v1 is superseded for this software reason).

### 2. The reference and all competitors are generated from the same static/source construction (P1 scientific scope)

`d16_model.m` reads the six-point OARF Run15 static curve and forms `p.pp`; the equilibrium state is then imposed as `lambda_s=sqrt(S/2)`. `d16_source.m` supplies the same C81/V4 blade source for DIRECT, table construction, local derivatives, and the mechanism ablation. DIRECT is therefore a numerical reference trajectory produced by the same model family, not measured transient data. The manifest explicitly states `new_external_dynamic_records=0` and `source_dynamic_validated=false`.

The Python readback is useful for serialization and formula checks, but it does not independently reproduce the DIRECT integration or the LUT trajectory: it reads CT vectors from the MAT result, recomputes reported scores from CSV, independently propagates only SCHEDULED_EXACT, and checks selected source/derivative values. Thus the readback establishes internal consistency, not independent physical confirmation. Any statement must stay conditional on this source and static curve.

### 3. Do not generalize the LTI failure to all work-point linearization (P1 interpretation)

The fixed LTI branch uses frozen `b0` and the specially derived `a0=S'*(1+b0/(4*lambda_s0))`, then propagates one scalar LTI flow for each constant-command segment. This is a valid declared comparator and its target equilibrium is mathematically consistent with the imposed static curve. Its 1.3%-to-168% case spread in v1 shows that this **specific frozen-coefficient comparator** can be inadequate over the tested pulse amplitudes/durations and memories. It does not disprove all classical scheduled/tangent methods; SCHEDULED_EXACT is precisely a stronger scheduled tangent comparator and remains below 1% in v1.

### 4. Report offline construction cost separately from online cost (P2 fairness)

The v1 manifest records approximately 1.55 s for the 21x41 LUT build and 0.29 s for tangent construction. `FULL_PREDICTION_COST.csv` times only repeated online `d16_predict` calls after a warm call; it excludes those one-time costs. This is fair for repeated predictions with a reused table, but not for a one-shot comparison. Report both the stated online medians and an amortization rule (or a one-shot total) and do not call the online ratio a universal speedup.

### 5. Internal guards are appropriate but are not validation

The source rejects C81 alpha/Mach clamping, negative/nonfinite loads, and departures beyond ±0.01. The 72 cases stay near lambda 0.0701–0.0818 and direct non-equilibrium CT peaks are about 1.34e-4, so the run is numerically inside the declared domain. These guards demonstrate contract compliance only; they do not show that the C81/V4 source or momentum memory represents the physical rotor transient.

## Mathematical checks passed by inspection

- `d16_source` uses the declared nondimensional axial/radial velocity and blade-element integral with segment widths; the dimensions and normalization are internally consistent with the stated contract.
- For DIRECT, `CT=S(theta)+B(theta,lambda)-B(theta,lambda_s)` makes the imposed static curve exact at equilibrium. This is a deliberate conditional construction, not an independent static validation.
- For SCHEDULED_EXACT, with `e=lambda-lambda_s`, the implemented ODE is `e_dot=-(Omega/k)[(b+4 lambda_s)e+2e^2]`; the implemented `z/(1+...)` expression is the correct Riccati branch for a constant segment. The Python readback independently reproduced this branch to its stated tolerance.
- Segment endpoints are propagated with the same state and known future rectangular command, and DIRECT/LUT use the same `ode45` tolerances and `MaxStep`.

## Recommended wording and next evidence

Use wording such as “within this fixed-hub V4/OARF conditional model and tested input family, the 21x41 LUT and scheduled tangent met the 1% non-equilibrium numerical budget relative to DIRECT.” Avoid “validated,” “aircraft-accurate,” or universal speed claims. Before a stronger conclusion, obtain a dynamic record independent of both the OARF static curve and the C81/V4 source, and rerun the final metrics/readback on corrected v2 traces.
