function [P,contract] = xv15_gtrs_parameters_v1(caseName)
%XV15_GTRS_PARAMETERS_V1 Source-constrained scalar GTRS/XV-15 adapter.
% This adapter applies only scalar values verified in the CR-166536 identity
% table. Angle-dependent aero/interference tables remain explicitly pending.
if nargin < 1 || isempty(caseName), caseName = 'CR166537_HELI'; end
[P,baseContract] = xv15_helicopter_trim_parameters_v1();
ft = 0.3048; in = 0.0254; lb = 0.45359237; slug = 14.59390294;
slugft2 = slug*ft^2; d2r = pi/180;
P.mass.m = 13000*lb;
P.mass.I0 = [52795*slugft2,0,-1234*slugft2; 0,21360*slugft2,0; -1234*slugft2,0,66335*slugft2];
P.rotor.R = 12.5*ft; P.rotor.Nb = 3; P.rotor.chord = 1.167*ft;
P.rotor.Omega = 589*2*pi/60; P.rotor.Ib = 102.5*slugft2;
P.rotor.sigma = 0.089; P.rotor.delta3 = -15*d2r;
P.rotor.pivotX = -(300*in); P.rotor.pivotY = 193*in; P.rotor.pivotZ = -(100*in);
P.wing.S = 181*ft^2; P.wing.b = 32.17*ft; P.wing.c = 5.255*ft;
P.htail.S = 50.25*ft^2; P.htail.c = 3.92*ft; P.htail.rAC = [-(560*in);0;-(103*in)];
P.vtail.SEach = 25.25*ft^2; P.vtail.c = 3.725*ft;
P.fuselage.rAC = -(293*in)*[1;0;0] + [0;0;-(84*in)];
P.control.cyclicLim = [-10.0625,10.0625]*d2r;
P.control.elevatorLim = [-20,20]*d2r;
P.validation.gtrsAdapter = true; P.validation.gtrsCase = caseName;
P.validation.coordinateContract = 'BODY_X_FORWARD_Y_RIGHT_Z_DOWN';
P.validation.angleContract = 'WANG_i_n_deg_TO_REPO_betaM_deg=90-i_n_deg';
P.validation.unresolvedTables = {'fuselage_aero','wing_pylon_aero','tail_aero', ...
    'rotor_wake_interference','max_rotor_thrust','control_schedule'};
contract = baseContract;
contract.identity = 'XV15_GTRS_SCALAR_CR166536_ADAPTER_V1';
contract.sourceRole = 'CR166536_APPENDIX_B_SCALAR_VALUES_ONLY';
contract.caseName = caseName;
contract.targetFitting = false;
contract.coordinateSystem = 'BODY_X_FORWARD_Y_RIGHT_Z_DOWN';
contract.claimBoundary = 'SCALAR_PARAMETER_REPLACEMENT_TABLES_PENDING';
end
