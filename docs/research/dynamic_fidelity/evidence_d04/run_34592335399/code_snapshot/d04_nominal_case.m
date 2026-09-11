function P=d04_nominal_case()
%D04_NOMINAL_CASE Explicit submodel instance, not a hidden replacement of V7.
% Reuse generic geometry/mass/inertia numbers, but declare THIS model's
% uniform axial inflow, small-angle linear lift and absent wing/fuselage.
% Differences to D03 are therefore NOT purely time-history-only changes.
Q=params_nominal();P=struct('env',Q.env,'rotor',Q.rotor,'bodyMass',Q.mass.m, ...
 'nRotors',2,'initialThrustPerRotor',Q.mass.m*Q.env.g/2, ...
 'identity','GENERIC_TWO_PARALLEL_AXIAL_ROTORS');
P.parameterRole='INHERITED_CONCEPT_GEOMETRY_NOT_XV15_OR_CH47_TEST_PARAMETERS';
P.sourceContract='TN3044_SMALL_ANGLE_MOMENTS_WITH_EXISTING_LINEAR_TWIST_AND_ROOTCUT_INTEGRALS';
end
