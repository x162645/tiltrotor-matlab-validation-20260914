# Berger13 transition-envelope entry point

`analysis/berger13/run_berger13_transition_envelope.m` evaluates a declared
grid of speed and nacelle angle conditions with the 13-state/10-input
research model. It preserves solver failures, non-credible trim points, trim
residuals, conditioning, and the continuation seed source in
`BERGER13_TRANSITION_ENVELOPE.csv` and `.mat`.

Example:

```matlab
opts = struct('betaMDeg',[0 15 30 45 60 75 90], ...
    'speedMps',[5 15 25 35 45 60 80]);
result = run_berger13_transition_envelope('outputs/transition_envelope',opts);
```

The default grid is an analysis grid selected for this research model. A
credible numerical trim point is not evidence of an XV-15 flight condition,
a validated transition corridor, or a formal handling-quality level. The
model still contains declared research-placeholder nacelle/actuator values,
and full-aircraft dynamic external validation remains blocked until matched
synchronized records are available.
