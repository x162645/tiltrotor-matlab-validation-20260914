# D12 pre-computation contract: externally sourced response shape and input mapping

2026-09-11. This plan is written after reading the archived D01 source coefficient, and before any D12 numerical comparison. This is development analysis, not preregistration before all data exposure, and not a new blind test.

## Fixed dependencies

D11 channel, static table, reference C81 derivative conventions and concept mass remain unchanged. No TN3044 refit, added compensation, new physical state, or historical suite rerun. D11's 5% finite-family model comparison is not an aircraft accuracy target.

D01 source library at b5a9c20833d65b21a192417ffc54433047d7fdb8, evidence/INPUT_CASES_SNAPSHOT.json blob f606c6cab74793af0126de7ad72b53ebc3c87bb3, case HOVER_AZ_POWER. Original TM89428 PDF was retrieved through existing Actions artifact10175006778 and SHA256 checked as 252f7df0c0e05bd8dece0a923d337df2231c0148f897f0376f930f6102b90ba2. PDF110/printed87 Eq4.8 has been rendered and read: G=-.0098*s/(s+.105)*exp(-.0074*s), units downward g per power-lever percentage point, support .1-3 rad/s. This is an identified flight-response descriptor, not raw flight samples or a newly identified physical model. Source condition and control-chain restrictions remain.

## Questions and fixed comparison

1. Can an unknown constant input calibration explain D11's response shape relative to this external descriptor? Use H(jw)/H(j1) on .1-3 rad/s, a fixed 1 rad/s normalization, with no fitted gain, delay, pole or physical parameter. Keep the source-delay-included and explicitly descriptor-delay-factored diagnostics separately; do not choose the favorable one.
2. Derive an anchor-independent lower bound against ANY constant input gain using q=abs(G_model/G_source), (max(q)-min(q))/(max(q)+min(q)). This is a finite-frequency necessary mismatch bound, not a confidence bound. A complex-response minimax error cannot be smaller than its amplitude-only lower bound.
3. Compare unchanged two-state PP/CF, physical QS and classical velocity-BT with kinematic reconstruction on identical source support and metrics. Do not use rankings to pick a new physical calibration.
4. Form the algebraically required dynamic input map G_source/G_model only as a non-identifiability diagnostic. Never adopt it as an actuator model or claim it is measured. Check whether the rational factor is proper/stable, preserving the source delay. An unrestricted unknown dynamic input chain may defeat an unconditional aircraft-model rejection.
5. Record the reduced D11 acceleration transfer algebra, why static-map slope and a constant input gain cancel from normalized shape, and which source gaps remain. Do not claim normalization cancels unknown dynamic input mapping, different loading, governor effects or missing aircraft physics.

## Execution and bounded checks

Python first, new output directory and source/hash/environment ledger. Use 129/257/513 logarithmic frequency grids including exact endpoints, selected analytic/state-space checks, gain/unit invariance, source support rejection and null/mismatched input-role guards. No timing race or scan of new aircraft parameters. No simulation of unmeasured absolute collective from power lever.

A small native-MATLAB implementation/verification may be executed through an authorized manual workflow if available. It must use the same frozen inputs, independently build the local state-space/transfer relation, retain all results and failures, and report its actual run/commit/artifact only after readback. No MATLAB execution is claimed by this plan. No PR merge, force push, post-reply background promise, or credential/access workaround.
