# V9: mast-angle power correction

Baseline: `x162645/tiltrotor-matlab-validation-20260914`, PR1 head
`7f672db177256fa6f89b4df5f369ba33a49fc920`. This change corrects the
opt-in source airframe used for the 30-degree nacelle comparison. It does
not fit power to a reference curve. The historical V8 carriers are retained.

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

Source: NASA CR-166536, September1988 RevA. PDF SHA256:
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
Native MATLAB R2021a verification runs in `line-b-mast-angle-v9.yml`.
Execution status and accepted results will be recorded after reading that run.

```bash
python3 analysis/validation_whole_aircraft_trim/prepare_line_b_v9_baseline.py --output outputs/v9_mast_angle/baseline_sum
```

```matlab
startup;
addpath('analysis/stage2_aircraft');
addpath('analysis/validation_whole_aircraft_trim');
run_line_b_v9_power_correction(fullfile(pwd,'outputs','v9_mast_angle'));
```

The runner checks published source cells, coordinate/energy/moment invariants,
bitwise helicopter component regression against immutable PR1 functions,
the default legacy stage-2 stack, the original imperial spinner comparison,
tail regression and the zero-area source-domain guard. It then evaluates
fixed V8 states and re-trims 120, 110 and 130kt at i_n=30deg. The corrected
120kt solution is only a numerical seed for neighboring points. All physical
parameters and source control allocation remain fixed. Acceptance requires
the original optimizer/limits/physical-branch gates and independent complete
9-state EOM replay. Power is not an acceptance criterion. Each completed
point, including failures, is saved before the next solve.

`V9_FIXED_STATE_COMPONENTS.csv` reports `-F_component dot V_body` in kW;
this is not a re-trimmed shaft-power prediction. `V9_RETRIM_POINTS.csv`
reports summed rotor `Q*Omega`, residuals, controls, bounds and lookup clamps.
At the unchanged archived 120kt state the independent spinner calculation
gives incidence 33.406839deg, effective area 0.356369m^2 and drag power
53.953249kW, versus the archived 182.029446kW. The state is no longer trimmed
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
