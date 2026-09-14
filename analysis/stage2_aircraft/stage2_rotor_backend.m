function [Fbody,Mbody,out] = stage2_rotor_backend(modelIdentity,x,rotorCtrl,betaM,side,cgShift,P)
% Explicit identities: a new section correction cannot masquerade as frozen M1.
switch upper(char(modelIdentity))
 case 'M0_MATCHED_PRODUCTION'
  [Fbody,Mbody,out]=rotor_model_bemt(x,rotorCtrl,betaM,side,cgShift,P);
  out.stage2ModelIdentity='M0_MATCHED_PRODUCTION';
  out.stage2ComputationPath='DIRECT_PRODUCTION_ROTOR_MODEL_BEMT';
 case 'M1_EVIDENCE_V1_PROPAGATION'
  if isfield(P.rotor,'correctionIdentity')
   error('stage2_rotor_backend:IdentityConflict','Use M1_CONTINUOUS_CORRIGAN_V4 for revised correction.');
  end
  [Fbody,Mbody,out]=m1_evidence_v1_forward_rotor(x,rotorCtrl,betaM,side,cgShift,P);
  out.stage2ModelIdentity='M1_EVIDENCE_V1_PROPAGATION';
  out.stage2ComputationPath='ANALYSIS_ONLY_FROZEN_EVIDENCE_FORWARD_EXTENSION';
 case 'M1_CONTINUOUS_CORRIGAN_V4'
  if ~isfield(P.rotor,'correctionIdentity')||~ismember(P.rotor.correctionIdentity,{'CORRIGAN_POSITIVE_LIFT_WASHOUT_V4','CORRIGAN_POSITIVE_LIFT_WASHOUT_V4_N18'})
   error('stage2_rotor_backend:IdentityConflict','V4 requires its explicit section correction.');
  end
  [Fbody,Mbody,out]=m1_evidence_v1_forward_rotor(x,rotorCtrl,betaM,side,cgShift,P);
  out.stage2ModelIdentity='M1_CONTINUOUS_CORRIGAN_V4';
  out.stage2ComputationPath='SOURCE_MOTIVATED_CONTINUITY_REVISION_NO_SOLVER_CHANGE';
 otherwise
  error('stage2_rotor_backend:UnknownModelIdentity','Unknown modelIdentity: %s',char(modelIdentity));
end
end
