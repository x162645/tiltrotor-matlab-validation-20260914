# XV-15 helicopter-mode whole-aircraft trim V1

Validation identity: `XV15_HELICOPTER_TRIM_V1_SOURCE_MAPPED_NO_TARGET_FIT`

## Evidence roles

- Quantitative table: GTRS validated-reference-simulation correlation; **not raw flight-test truth**.
- Flight test: Figure 14 narrative trend check only; **no numeric flight score**.
- Target-output fitting: **NO**.
- Production physics modified: **NO**.

## Numerical result

Credible trims: 1 / 1.

- pitch attitude MAE vs GTRS: 1.56899 deg
- longitudinal-stick MAE vs GTRS: 0.131222 in
- per-rotor thrust MAPE vs GTRS: 6.33421 %
- stick trend slope: NaN in/kt
- pitch trend slope: NaN deg/kt
- Figure-14 narrative trend check: 0

## Claim boundary

This is a first source-mapped XV-15 whole-aircraft trim falsification pass. The existing low-order wing slipstream/near-normal interaction is retained and tested, not fitted. A quantitative flight-test PASS/FAIL label remains prohibited until Figure 14 point provenance is visually digitized and frozen.

## Point table

See `XV15_HELICOPTER_TRIM_V1_POINTS.csv` for all declared points, including failed/noncredible cases.
