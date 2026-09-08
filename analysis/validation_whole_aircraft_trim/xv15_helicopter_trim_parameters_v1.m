function [P,contract] = xv15_helicopter_trim_parameters_v1()
%XV15_HELICOPTER_TRIM_PARAMETERS_V1 Analysis-only XV-15 helicopter trim map.
%
% This builder closes only parameters that are active in the symmetric
% longitudinal trim path and are supported by the declared public source
% contract.  It starts from the frozen Stage-2/M1 rotor identity; rotor
% physics is not retuned to trim targets.  Airframe coefficients are mapped
% from the source model/component data and the fixed 40-deg flap case.
%
% IMPORTANT: this is a first external-validation/falsification identity,
% not a claim that the repository reproduces the historical GTRS model.

P = stage2_matched_rotor_parameters();

ft2m = 0.3048;
in2m = 0.0254;
lb2kg = 0.45359237;
slugkg = 14.59390294;
slugft2_to_kgm2 = slugkg*ft2m^2;
d2r = pi/180;

%% Exact helicopter trim-case environment / mass contract
P.env.rho = 0.00238*slugkg/(ft2m^3);
P.env.g = 32.2*ft2m;
P.mass.m = 13000*lb2kg;
P.mass.baselineCG = [-25.10*ft2m; 0; -6.80*ft2m];
Ixx = 52800*slugft2_to_kgm2;
Iyy = 21360*slugft2_to_kgm2;
Izz = 66340*slugft2_to_kgm2;
Ixz = 1234*slugft2_to_kgm2;
P.mass.I0 = [Ixx,0,-Ixz; 0,Iyy,0; -Ixz,0,Izz];
% betaM=0 for this validation set, so configuration-variation slopes do not
% enter the case.  Freeze them to zero rather than inheriting generic slopes.
P.mass.KI = zeros(3,3);

%% Frozen validated rotor identity + exact case RPM and layout
% Preserve Stage-2/M1 blade/airfoil/flapping identity.  Change only exact
% case RPM and source geometric placement used by the aircraft force/moment
% balance.  The zero-lateral-cyclic Betzina identity gate showed the later
% two-cyclic validation adapter reduces to this Stage-2 rotor path.
P.rotor.Omega = 589*2*pi/60;
P.rotor.pivotX = -25.0*ft2m;
P.rotor.pivotY = 16.1*ft2m;
P.rotor.pivotZ = -8.3*ft2m;
P.rotor.RH_hub = 4.67*ft2m;

%% Wing: source geometry + fixed-40-deg-flap effective coefficients
P.wing.S = 181*ft2m^2;
P.wing.b = 32.2*ft2m;
P.wing.c = 5.25*ft2m;
P.wing.xAC = -24.3*ft2m;
P.wing.zAC = -8.0*ft2m;
P.wing.CLalpha = 5.31;
alpha0Wing = -4.02*d2r;
flapDeg = 40;
flapRad = flapDeg*d2r;
P.wing.CL0 = -P.wing.CLalpha*alpha0Wing + 0.34*flapRad;
P.wing.CLmax = 1.70; % maximum tabulated fixed-40-deg value in source audit
P.wing.CD0 = 0.017 + 0.30367*flapRad;
P.wing.kInduced = 1/(pi*0.9*5.7);
P.wing.Cm0 = -0.02;
P.wing.Cmalpha = 0;

%% Fuselage: source longitudinal coefficients / station
% The source fuselage drag is a 1.6-ft^2 flat-plate area.  The current
% coefficient interface uses q*S*CD, so CD0=f/S is the exact homologous
% conversion for zero-sideslip longitudinal trim.
P.fuselage.S = P.wing.S;
P.fuselage.b = P.wing.b;
P.fuselage.c = P.wing.c;
P.fuselage.rAC = [-293*in2m; 0; -7.0*ft2m];
P.fuselage.CD0 = 1.6/181;
P.fuselage.CDalpha2 = 0;
P.fuselage.CDbeta2 = 0;
P.fuselage.CLalpha = 0.286;
P.fuselage.CL0 = P.fuselage.CLalpha*(8*d2r);
P.fuselage.Cm0 = -0.070;
P.fuselage.Cmalpha = 1.145;

%% Horizontal tail: source geometry/aero + source-derived wing downwash
P.htail.S = 50.25*ft2m^2;
P.htail.c = 3.916*ft2m;
P.htail.rAC = [-46.7*ft2m; 0; -8.6*ft2m];
P.htail.CL0 = 0;
P.htail.CLalpha = 4.03;
P.htail.CLelevator = 2.29;
P.htail.CD0 = 0.0088;
P.htail.kInduced = 1/(pi*0.8*3.27);
P.htail.Cm0 = 0;
P.htail.Cmelevator = 0;
% Lifting-line downwash mapping: epsilon ~= 2*CL/(pi*AR).
% A constant flap/zero-lift contribution is folded into incidence because
% the production tail interface exposes only incidence + d(epsilon)/d(alpha).
wingAR = 5.7;
P.htail.downwashAlpha = 2*P.wing.CLalpha/(pi*wingAR);
P.htail.incidence = -2*P.wing.CL0/(pi*wingAR);

%% Twin vertical tails: source geometry/aero; longitudinally only drag acts
P.vtail.SEach = 25.25*ft2m^2;
P.vtail.c = (P.vtail.SEach/(7.7*ft2m));
P.vtail.xAC = -47.5*ft2m;
P.vtail.yAC = 6.4*ft2m;
P.vtail.zAC = -9.6*ft2m;
P.vtail.CD0 = 0.0071;
P.vtail.CYbeta = -3.06;
P.vtail.CYrudder = 1.15;

%% Validation metadata
P.validation = struct();
P.validation.identity = 'XV15_HELICOPTER_TRIM_V1_SOURCE_MAPPED_NO_TARGET_FIT';
P.validation.flapDeg = flapDeg;
P.validation.caseWeight_lb = 13000;
P.validation.caseCG_ft = [25.10,0,6.80];
P.validation.caseRPM = 589;
P.validation.caseBetaM_deg = 0;
P.validation.caseGamma_deg = 0;
P.validation.initialTheta75_deg = 10;
P.validation.controlAllocation = 'XV15_LONGITUDINAL_STICK_SOURCE_GEARING';
P.validation.airframeInterfaceCaveat = [ ...
    'SOURCE_COEFFICIENTS_MAPPED_INTO_EXISTING_LOW_ORDER_COMPONENT_FORMS_' ...
    'NO_TARGET_TRIM_FITTING'];
P.validation.frozenInteractionCaveat = [ ...
    'WING_SLIPSTREAM_AREA_AND_NEAR_NORMAL_MODEL_RETAIN_EXISTING_LOW_ORDER_' ...
    'PHYSICS_AND_ARE_TESTED_NOT_FITTED'];

contract = struct();
contract.identity = P.validation.identity;
contract.sourceCase = [ ...
    'Kleinhesselink_2007_Appendix_C_Table_C1_13000lb_CG25.10ft_' ...
    '589rpm_flap40_betaM0_gamma0'];
contract.referenceRole = 'GTRS_VALIDATED_REFERENCE_SIMULATION_CORRELATION';
contract.flightRole = 'FIGURE14_EXTERNAL_FLIGHT_TREND_CHECK_NO_DIGITIZED_SCORE';
contract.targetFitting = false;
contract.productionPhysicsModified = false;
contract.rotorIdentity = 'FROZEN_STAGE2_M1_ZERO_LATERAL_CYCLIC_PATH';
contract.claimBoundary = [ ...
    'FIRST_XV15_WHOLE_AIRCRAFT_TRIM_EXTERNAL_FALSIFICATION_PASS_' ...
    'WITH_DECLARED_LOW_ORDER_INTERFACE_CAVEATS'];
end
