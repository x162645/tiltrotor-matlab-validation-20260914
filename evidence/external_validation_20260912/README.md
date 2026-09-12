# External validation evidence package (2026-09-12)

This directory contains the compact, rerunnable evidence exported from the MATLAB runs reported in `docs/EXTERNAL_VALIDATION_REAL_RUN_20260912.md`.

## Evidence roles

- `run15_direct_m0/`: NASA CR-2017-219486 XV-15 OARF Run 15, direct low-order M0 rotor path. This is an external component-level comparison; the 0/2/4 degree nonconverged points remain in the point table and are not counted as successful predictions.
- `run14_direct_m0/`: OARF Run 14, same campaign and model path. It is a run-level repeatability check, not an independent blind experiment.
- `wadc_m1_holdout/`: WADC cross-facility post-freeze comparison of M0 and frozen M1. It documents relative improvement and data provenance; it is not a blind holdout because the public data were used in the prior diagnostic chain.

CSV files preserve metadata, source mapping, point-level outputs, convergence status, identity audit, and aggregate metrics. The PNG is a convenience plot. MATLAB `.mat` files and large historical caches remain in the local output archive and are intentionally not duplicated here.

## Interpretation boundary

The evidence establishes that the external comparison was executed against traceable public data and exposes systematic M0 underprediction of absolute CT/CP. It supports component-level model diagnosis and bounded M1 comparison. It does not establish full-aircraft XV-15 dynamic accuracy, transition-flight fidelity, or domestic leadership.
