# D15 independent review (static code and artifact readback)

Date: 2026-09-12 UTC  
Scope: `docs/research/dynamic_fidelity/evidence_d15_recovery_reimplementation/code/reimplement_d15.py`, the visible recovered D15 text, and `run_v2`/`run_v3` CSV/JSON artifacts. I read `AGENTS.md` and `CODEX_TASK.md`. No MATLAB run, historical suite, or source edit was performed. The only new file is this review outside the repository.

## Overall assessment

The endpoint propagator is mathematically coherent for

`y_dot = -pole*y - kappa*d/dt u(t-delay)`

with piecewise-linear `u`, constant prehistory, and a fixed origin state. `weights` splits at delayed input knots and integrates the local FOH slope analytically; `independent_expm` agrees with the default-parameter endpoint check. The final artifact population is now 65 common starts for each requested horizon (195 overlapping forecasts, not independent trials), and `MANIFEST.json` correctly says `new_independent_records=0` and that the boxes are not confidence intervals.

The numerical readback in `run_v3` is internally consistent: pointwise metrics reproduce `METRICS.csv` to about `1e-16`, checks pass, and the 2/5 s reading-box mean loss differences are negative for all three discrete shifts while 0.5 s remains mixed. These are conditional results for the digitized record and declared command model.

## Findings

### 1. MEDIUM — prefix-leak check is vacuous

At lines 114–115 the code creates `poisoned` post-18 s targets, then only compares `poisoned[time<18]` with the already extracted `yp`. It never reruns `fit_at`, the profile search, or the frozen fit with `poisoned` as the source dataframe. Thus `CHECKS.csv` entry `prefix_target_poison_inputs` proves only that the slice operation preserves its own prefix; it does not test that fitting is invariant to future target values. The current fit is in fact prefix-only, but the claimed check is not evidence of that. A real check should recompute the prefix fit/profile from the poisoned dataframe (or isolate a fit function accepting `tp,yp`) and compare pole, kappa, and loss.

### 2. MEDIUM — causal unknown-command branch needs an explicit semantic contract

Lines 93–95 truncate to `t<=origin`, append a synthetic endpoint, and call the original delayed model with default (`KAPPA`, `POLE`, `DELAY`) parameters. This is causal with respect to recorded command samples, but it means: (a) the interval from the last received sample to the origin is held at the last sample value, and (b) the first `DELAY` seconds after the origin still use the known pre-origin command history. It is not the same as the preserved pre-review implementation's documented “hold the delayed command at its value at origin” branch (which starts a zero-delay constant-command prediction), and it does not use the prefix-fitted pole/kappa used by `prefix_known`. The difference is measurable (about `-1.53e-4 g` worst over the common starts when compared with the preserved delayed-command-hold interpretation). Keep the current branch if this is intended, but name it “raw-command sample hold with retained delay,” add a future-input tamper check, and do not present it as the former delayed-command-hold definition. If the intended comparator is the preserved definition, change the branch and regenerate outputs.

### 3. LOW/MEDIUM — endpoint support silently extrapolates the last command after the final input sample

`weights` accepts `target <= t[-1] + delay` (line 28), and `basis` clamps `q>=t[-1]` to the last input sample (lines 31–34). This is a constant posthistory assumption for up to one delay, whereas the docstring mentions only explicit constant *prehistory*. The current v3 targets appear inside the recorded-command support, so this does not change those rows, but it is an undocumented behavior of the public endpoint API. Either document both pre- and posthistory assumptions in the contract/manifest or reject targets requiring posthistory except in the explicit causal-hold construction.

### 4. LOW — `weights` itself does not validate input arrays

`predict` calls `checked`, but callers can invoke `weights` directly with unsorted, duplicate, mismatched, short, complex, or nonfinite `t,u`; the function then indexes/interpolates without the series contract. Internal calls currently pass validated arrays, so this is an API robustness issue rather than a v3 result error. Add `t,u=checked(t,u)` at the endpoint boundary or mark `weights` private and test only through `predict`.

### 5. LOW/MEDIUM — uncertainty boxes are exact only conditionally and lack bound guards

`loss_box` enumerates faces and interior stationary points of the quadratic loss difference correctly for a finite three-variable box, and the source/input interval construction is reasonable. However it does not validate finite ordered `lo<=hi` bounds, and its fixed rank tolerance can skip a singular stationary solve (the boundary-equality argument should be documented or covered by a targeted test). More materially, the box includes digitization bounds for initial/target output and command samples plus three discrete global shifts only; it excludes fitted pole/kappa uncertainty, continuous timing error, sensor/model-form error, and cross-forecast dependence. The manifest caveat is correct; report the mean extrema as conservative bounds for these finite boxes, never as confidence intervals or robust guarantees over all timing/parameter uncertainty.

## Forecast population and claims

The v3 origin predicate (`18 <= origin <= 24` and a recorded 5 s target) correctly yields 65 shared starts; `searchsorted` deliberately reports the first observed target at or beyond each requested horizon, producing the stated actual-horizon ranges. Since starts reuse one trace, RMSE rows are dependent rolling forecasts. The source-known versus prefix-known columns also use different parameter sets by design (`default` source versus prefix fit), while `static_increment` uses the default KAPPA; retain those labels and avoid treating their rank as a physical-model ranking.

## Validation status

I inspected the source, recovered report, v2/v3 artifacts, and repository guidance. I did not run MATLAB or historical suites. `git status --short` showed unrelated pre-existing untracked D16 heave artifacts; no repository files were changed by this review.
