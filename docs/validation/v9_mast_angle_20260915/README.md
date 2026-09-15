# V9: mast-angle power correction

Baseline: `x162645/tiltrotor-matlab-validation-20260914`, PR1 head
`7f672db177256fa6f89b4df5f369ba33a49fc920`. This change corrects the
opt-in source airframe used for the 30-degree nacelle comparison. It does
not fit power to a reference curve. The historical V8 carriers are retained.

## Actual result

Native MATLAB R2021a Update8 completed successfully in
[run 34955538119](https://github.com/x162645/tiltrotor-matlab-validation-20260914/actions/runs/34955538119),
at code commit `d526fc458a530fc028041f811706330f792524bd`. All three trims
passed the original acceptance gates and independent complete EOM replay.

| Speed (kt) | Previous shaft power (kW) | Corrected shaft power (kW) | Change | Full scaled EOM residual |
|---:|---:|---:|---:|---:|
| 110 | 1184.551 | 757.987 | -36.01% | 5.60e-10 |
| 120 | 1369.928 | 817.149 | -40.35% | 9.95e-10 |
| 130 | 1600.824 | 911.891 | -43.04% | 2.06e-9 |

The unchanged-reference comparison at 61.838235 m/s uses interpolation
between the new 120/130 kt results: 819.082 kW versus the published blue
numerical-reference point 878.571 kW. The conditional discrepancy changes
from +495.878kW (+56.44%) to -59.489kW (-6.77%). This comparison is performed
only after the native results are fixed. It remains one covered reference
point, with an estimated two-pixel power readout tolerance of 28.571 kW;
it is not independent flight validation. Pitch discrepancy changes from
+1.524 deg to -0.831 deg; stick discrepancy from +5.865 to +3.845 percentage
points under the retained 9.6 in stroke convention. Root collective is not
scored against an unresolved reference radial convention.

Recorded native checks: 267 component checks including 205 published cells,
49 spinner checks and 19 tail checks, plus the zero-area and cross-angle
interface checks. Helicopter component loads and the default legacy stage-2
stack were bitwise equal to the immutable pre-fix functions. Python independently
read the MAT/CSV artifacts and passed 66 checks of EOM balance, source loads,
power, parameters, bounds, shared field angles and clamp counts.

Final alpha-clamp counts remain 42/48/52 at 110/120/130 kt; Mach-clamp counts
are zero. Invalid trial evaluations were 0/1/3 respectively, retained in
the carriers; accepted states are finite and physically converged under
the model's current branch criteria. Empty-area coefficient metadata still
intentionally contains NaNs; active loads and accepted EOM states do not.
No solver tolerances or physical parameters were adjusted to obtain these results.

The first four CI attempts stopped in the new verification runner due to
CSV type inference, the nested archived componentInfo layout, and empty
struct assignment in R2021a. Their failed runs and commits remain in GitHub
history. Subsequent fixes changed test/replay plumbing only; the physical
component changes in `cdfb866` were not tuned after observing power.
The setup action warned that R2021a is not formally supported on Ubuntu 22.04;
installation and native execution nevertheless succeeded. Node deprecation
messages were infrastructure warnings, not model-convergence warnings.

## Physical changes

The paper uses nacelle angle `i_n=90-betaM` (degrees). The code uses
`betaM=0` for helicopter and `pi/2` for airplane, in radians. Body axes are
forward/right/down. The passive body-to-mast rotation is
`[cos(betaM),0,sin(betaM);0,1,0;-sin(betaM),0,cos(betaM)]`.
Mast-z is opposite the rotor thrust axis. At betaM=0 this is identity;
at betaM=pi/2 forward flight is axial flow along negative mast-z.

| Root cause | Correction | Source mapping |
|---|---|---|
| Spinner incidence was calculated in body axes | Transform the induced-plus-body velocity into mast axes before computing incidence; resolve drag along the same body velocity as before | A75-A76, PDF143-144 |
| Spinner moment arm was frozen at the helicopter hub | Apply the existing mast length along `[sin(betaM);0;-cos(betaM)]` from the pivot; moment is `cross(r,F)` | A232, PDF300 |
| Wing CL/CD/Cm ignored the supplied mast angle | Use both published CL/CD mast columns and the five Cm mast nodes, at the same 40/25 flap setting | Tables4-II/IV/VIII, B36-37/B41-42/B51, PDF386-387/391-392/401 |
| Wing free-field correction kept only X_RW0 | Use `X_RW0+b*(X_RW1+b*X_RW2)`, with b in degrees | A70/B33, PDF138/383 |
| Tail downwash used betaM=0 at all angles | Pass the same mast angle and free-field wing incidence to Table4-V(a-e) | A74/B45-49, PDF142/395-399 |

Source: NASA CR-166536, September 1988 Rev A. PDF SHA256:
`a2013a314af5beb0c5e9bc5bbeb26f99be9a8aa63f2ebe07deaaf11d0d44d67d`.
The original PDF pages were visually checked. The archived digitization
`CR166536_WING_T4II_VIII.csv` supplies independent source-cell regression.
Areas 1 and 5.5 ft^2 per spinner convert using `0.3048^2`; forces are N,
moment arms m, moments N*m. X_RW1=0.00003341 per degree and
X_RW2=0.000007386 per degree^2; no radian/degree factor is fitted.
Cm is dimensionless under A70 `M=q*S*c*Cm`; the contradictory printed
Table4-VIII heading is retained in the source data provenance.

Piecewise linear interpolation in mast angle is **ASSUMED**, explicitly
identified in output metadata. The published endpoint/node values are
REFERENCE/DIGITIZED; interpolated conversion values are not additional
measurements. No extrapolation, arbitrary flap switch, rotor/RPM change,
drag multiplier, mass/geometry replacement or tolerance relaxation is used.
The existing rounded hub geometry is rotated, not reidentified.

## Validation and reproduction

The local Work Mode environment has no full MATLAB executable (including
the prescribed `F:/matlab/R2021a/bin/matlab.exe` path). Local checks comprised
Git diff/whitespace, immutable-baseline extraction and an independent Python
comparison of 130 CL/CD source cells. These are not MATLAB execution.
Native MATLAB R2021a verification ran successfully in
`line-b-mast-angle-v9.yml`; the results above are actual execution and readback.

```bash
python3 analysis/validation_whole_aircraft_trim/prepare_line_b_v9_baseline.py --output outputs/v9_mast_angle/baseline_sum
```

```matlab
startup;
addpath('analysis/stage2_aircraft');
addpath('analysis/validation_whole_aircraft_trim');
run_line_b_v9_power_correction(fullfile(pwd,'outputs','v9_mast_angle'));
```

The complete 38-file native run is available as the existing
[Actions artifact](https://github.com/x162645/tiltrotor-matlab-validation-20260914/actions/runs/34955538119/artifacts/10392060123)
`v9-mast-angle-r2021a` (341523 bytes), SHA256
`7c08609694f220fddc4bfec9f257a11df017df5b81a188e9ebe4da331c46739e`.
It contains the original MAT/CSV/JSON outputs and immutable baseline functions.
GitHub currently lists its expiration as 2026-12-14; it is not duplicated in
the Git tree. The source runner and reader remain versioned for reproduction.

To verify this native run without re-solving, download the linked artifact
as `outputs/v9-mast-angle-r2021a.zip`, then run:

```bash
python3 -m zipfile -e outputs/v9-mast-angle-r2021a.zip outputs/v9_archive
python3 tools/verify_v9_power_correction.py outputs/v9_archive --output outputs/v9_readback/V9_PYTHON_READBACK.json --code-commit d526fc458a530fc028041f811706330f792524bd --run-id 34955538119
```

The reader generates `V9_PYTHON_READBACK.json` with individual native-file,
reader and source hashes, plus `V9_FIG1c_CONDITIONAL_COMPARISON.csv`. The
actual 66-check readback used reader SHA256
`99e14530d5eb92ad1aca66beb6053540f51e25d139eca5e4ef0cd1b1bfe9e954`.
The unchanged V8 comparison input SHA256 is
`331eedbf67758bef9ccc9456e5d2572f47be21116371984a21ce13a6f4e30adc`.
These outputs are generated by the reader and are not files beside this document.

The Python reader requires NumPy/SciPy; the actual readback used Python 3.12.14,
NumPy 2.3.5 and SciPy 1.17.0. Code-interface changes are backward-compatible
optional mast-angle arguments to the wing coefficient/free-field helpers,
an optional baseline path for the spinner test runner, and an explicit
`flow.betaM_rad` requirement in the coherent-tail path. All production
callers already provide this field. No parameter-pack file was edited;
the two previously omitted source X_RW coefficients were added to the table helper.

The runner checks published source cells, coordinate/energy/moment invariants,
bitwise helicopter component regression against immutable PR1 functions,
the default legacy stage-2 stack, the original imperial spinner comparison,
tail regression and the zero-area source-domain guard. It then evaluates
fixed V8 states and re-trims 120, 110 and 130 kt at i_n=30 deg. The corrected
120 kt solution is only a numerical seed for neighboring points. All physical
parameters and source control allocation remain fixed. Acceptance requires
the original optimizer/limits/physical-branch gates and independent complete
9-state EOM replay. Power is not an acceptance criterion. Each completed
point, including failures, is saved before the next solve.

`V9_FIXED_STATE_COMPONENTS.csv` reports `-F_component dot V_body` in kW;
this is not a re-trimmed shaft-power prediction. `V9_RETRIM_POINTS.csv`
reports summed rotor `Q*Omega`, residuals, controls, bounds and lookup clamps.
At the unchanged archived 120 kt state the independent spinner calculation
gives incidence 33.406839 deg, effective area 0.356369 m^2 and drag power
53.953249 kW, versus the archived 182.029446 kW. The state is no longer trimmed
after the component changes, so this reduction is not subtracted from old
shaft power to claim a new aircraft result.

## Remaining limits

Tail pressure ratio Table5-V(a) and rotor-to-tail wake gain remain the
helicopter source tables under the existing angle-screen extension. Wing
immersed area remains zero in these carriers. Rotor polar clamps/reverse
root flow, rotor torque validation and full source geometry remain open.
The high-Mach airplane/fuselage domain is not repaired by this change.
These are conditional source-model results, not independent flight validation
or a claim that the whole published power discrepancy has been eliminated.
