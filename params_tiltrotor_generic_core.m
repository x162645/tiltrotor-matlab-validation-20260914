function P13 = params_tiltrotor_generic_core()
%PARAMS_TILTROTOR_GENERIC_CORE Generic 13-state research-model parameters.
% The generic core deliberately contains no XV-15-specific overlay.  Any
% placeholder or assumed value remains labelled in the returned structure.

P13 = params_berger13();
P13.meta.modelIdentity = 'TILTROTOR_GENERIC_CORE';
P13.meta.parameterRole = 'GENERIC_RESEARCH_PARAMETER_SET';
P13.meta.xv15OverlayApplied = false;
P13.meta.claimBoundary = ['Generic low-order tiltrotor research model. ' ...
    'It is not an XV-15 reconstruction and is not flight-test validated.'];
P13.meta.requiredAdapterForXv15 = 'build_xv15_validation_adapter';
end
