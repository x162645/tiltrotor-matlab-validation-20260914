# Current HEAD identity-gate run (2026-09-12)

This directory contains the only Betzina-related run completed on the current branch in this work window: the validation-only two-cyclic adapter with lateral cyclic set to zero was compared with the existing Stage-2 forward rotor at three operating points.

MATLAB: R2021a (`F:\matlab\R2021a\bin\matlab.exe`). Command entry point: `analysis/validation_betzina2002/run_betzina2002_two_cyclic_identity_gate.m`.

Result: `pass=1`, all six physical states converged, and maximum absolute difference over CT, CQ, and flap harmonics was `2.6112966972666012e-17`. This is an interface identity check only; it is not a new external prediction. The full Betzina operating-state optimization was attempted but exceeded the available run window and produced no result files.

An additional current-HEAD alpha=0 quick check (two controls only: `theta75` and longitudinal cyclic) completed four physical states but **failed the fixed-CT operating contract**: `solutionValid=0/4`, with CT relative errors `56.6%`, `81.4%`, `82.2%`, and `80.1%`. This is a solver/actuator-contract diagnostic, not an external accuracy pass; the adapter needs the lateral/cosine-harmonic cyclic used by the full Betzina operating contract. The earlier script had mislabeled any positive converged state as `solutionValid`; that bug is fixed in the current script.
