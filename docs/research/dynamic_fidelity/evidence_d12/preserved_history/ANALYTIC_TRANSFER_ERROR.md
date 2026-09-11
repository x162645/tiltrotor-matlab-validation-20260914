# Retained first D12 failure

The first local D12 run stopped at analytic/state-space equivalence before producing a source-comparison table. CHECKS.csv below records the failed residual. In the new derived transfer function only, z was set to 2*Omega*lambda0/k and the denominator constant to z*d. Direct inversion of the unchanged D11 A/B gives a numerator zero term 4*Omega*lambda0/k, while the denominator constant remains 2*Omega*lambda0*d/k. The final new analytic implementation therefore uses z=4*Q*lambda0 and .5*z*d in the denominator. The original D11 source, physical parameters, source data, frequency support and test tolerances were not changed.

The two exact Python line replacements from the first source to the corrected source are:

    d=H*ch.b/p.Vtip; z=2*Q*ch.lambda0
    den=np.array([1., Q*(ch.b+4*ch.lambda0)+d, z*d])

replaced by:

    d=H*ch.b/p.Vtip; z=4*Q*ch.lambda0
    den=np.array([1., Q*(ch.b+4*ch.lambda0)+d, .5*z*d])

The complete first local script and partial results are retained in the D12 attachment under preserved_history/analytic_transfer_zero_error/. This remote record does not claim the full old script was separately uploaded as a Git blob. The correction occurred before the first native MATLAB run and does not create an additional physical branch or fit.
