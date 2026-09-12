function [xdot, out] = tiltrotor_eom_13x10(x13, u10, P13)
%TILTROTOR_EOM_13X10 Isolated 13-state / 10-input PR1 research EOM.
% The first nine equations retain the NUAA physical-baseline rigid-body
% form.  The nacelles use torque/rate dynamics.  Actuator reaction torque,
% nacelle-rate gyroscopic torque, and the variable-inertia I_dot*omega term
% are included explicitly; unavailable local nacelle tensors and higher
% transmission effects remain declared limitations in P13.mechanics.

if nargin < 3 || isempty(P13)
    P13 = params_berger13();
end
x13 = x13(:);
u10 = u10(:);
if ~(isnumeric(x13) && isreal(x13) && numel(x13) == 13 && ...
        all(isfinite(x13)))
    error('tiltrotor_eom_13x10:InvalidState', ...
        'x13 must be a finite real 13-element vector.');
end
if ~(isnumeric(u10) && isreal(u10) && numel(u10) == 10 && ...
        all(isfinite(u10)))
    error('tiltrotor_eom_13x10:InvalidControl', ...
        'u10 must be a finite real 10-element vector.');
end

[Fap, Map, componentInfo] = total_forces_moments_13x10(x13, u10, P13);
Pbase = P13.base;
mp = componentInfo.massProperties;
mass = mp.mass;

xRigid = x13(1:9);
Vbody = xRigid(1:3);
omega = xRigid(4:6);
phi = xRigid(7);
theta = xRigid(8);

Fg = mass*Pbase.env.g * ...
    [-sin(theta);
      sin(phi)*cos(theta);
      cos(phi)*cos(theta)];

Ftotal = Fap + Fg;
Vdot = Ftotal/mass - cross(omega, Vbody);

[betaDotLeft, betaDDotLeft, leftFlags, leftTorqueApplied] = nacelle_derivative( ...
    x13(10), x13(12), u10(9), P13.nacelle);
[betaDotRight, betaDDotRight, rightFlags, rightTorqueApplied] = nacelle_derivative( ...
    x13(11), x13(13), u10(10), P13.nacelle);

% Equal-and-opposite actuator torque closes the torque-input channel to the
% rigid body.  The rotor spin reaction associated with changing nacelle
% angle is also retained, matching the angle-command EOM contract.
eBeta = [0;-1;0];
Mreaction = -leftTorqueApplied*eBeta-rightTorqueApplied*eBeta;
MtiltRateGyro = tilt_rate_gyro(x13,P13,betaDotLeft,betaDotRight);
MInertiaRate = inertia_rate_times_omega(x13,P13,betaDotLeft,betaDotRight,mp);
Mtotal = Map + Mreaction + MtiltRateGyro - MInertiaRate;
omegaDot = mp.I \ (Mtotal - cross(omega, mp.I*omega));
eulerDot = euler_321_dot(phi, theta, omega);

xdot = [Vdot; omegaDot; eulerDot; betaDotLeft; betaDotRight; ...
    betaDDotLeft; betaDDotRight];

out.FaeroProp = Fap;
out.Fgravity = Fg;
out.Ftotal = Ftotal;
out.MaeroProp = Map;
out.MactuatorReaction = Mreaction;
out.MnacelleRateGyro = MtiltRateGyro;
out.MinertiaRate = MInertiaRate;
out.Mtotal = Mtotal;
out.massProperties = mp;
out.components13 = componentInfo;
out.physicalConverged = componentInfo.physicalConverged;
out.physicalBranchSupported = componentInfo.physicalBranchSupported;
out.physicalStatus = componentInfo.physicalStatus;
out.nacelle.left.derivative = [betaDotLeft; betaDDotLeft];
out.nacelle.left.torqueApplied = leftTorqueApplied;
out.nacelle.left.limitFlags = leftFlags;
out.nacelle.right.derivative = [betaDotRight; betaDDotRight];
out.nacelle.right.torqueApplied = rightTorqueApplied;
out.nacelle.right.limitFlags = rightFlags;
out.nacelle.stiffnessImplemented = false;
out.mechanics = P13.mechanics;
out.couplingBoundary = P13.mechanics.couplingBoundary;
out.xdot = xdot;
end

function M = tilt_rate_gyro(x13,P13,betaDotLeft,betaDotRight)
% Rotor angular momentum reaction from a changing nacelle direction.
Jomega = P13.base.rotor.Jpolar*P13.base.rotor.Omega;
eDLeft = [cos(x13(10));0;sin(x13(10))];
eDRight = [cos(x13(11));0;sin(x13(11))];
M = -((-1)*Jomega*betaDotLeft*eDLeft + ...
      (+1)*Jomega*betaDotRight*eDRight);
end

function M = inertia_rate_times_omega(x13,P13,betaDotLeft,betaDotRight,mp)
% Compute dI/dt*omega from the moving point-mass reconstruction.  A small
% central difference keeps this term tied to the exact mass-property
% implementation and avoids silently inventing unavailable local tensors.
h = 1e-6;
betaML = x13(10);
betaMR = x13(11);
mpL = mass_properties_berger13(betaML+h,betaMR,P13);
mpLm = mass_properties_berger13(betaML-h,betaMR,P13);
mpR = mass_properties_berger13(betaML,betaMR+h,P13);
mpRm = mass_properties_berger13(betaML,betaMR-h,P13);
dIdBetaL = (mpL.I-mpLm.I)/(2*h);
dIdBetaR = (mpR.I-mpRm.I)/(2*h);
Idot = dIdBetaL*betaDotLeft + dIdBetaR*betaDotRight;
M = Idot*x13(4:6);
% Keep the argument in the signature as an explicit contract check: the
% derivative must correspond to the inertia used in this EOM evaluation.
if norm(mp.I-mass_properties_berger13(betaML,betaMR,P13).I,'fro') > ...
        1e-10*max(1,norm(mp.I,'fro'))
    error('tiltrotor_eom_13x10:InertiaContract', ...
        'Mass-property derivative was evaluated against a different inertia.');
end
end

function eulerDot = euler_321_dot(phi, theta, omega)
cosThetaSafe = cos(theta);
if abs(cosThetaSafe) < 1e-6
    cosThetaSafe = sign(cosThetaSafe + eps)*1e-6;
end
tanThetaSafe = sin(theta)/cosThetaSafe;
T321 = [1, sin(phi)*tanThetaSafe,  cos(phi)*tanThetaSafe;
        0, cos(phi),              -sin(phi);
        0, sin(phi)/cosThetaSafe,  cos(phi)/cosThetaSafe];
eulerDot = T321*omega;
end

function [betaDot, betaDDot, flags, torqueApplied] = nacelle_derivative( ...
        beta, betaRate, torque, cfg)
betaLimits = [cfg.betaMin; cfg.betaMax];
rateLimits = [-cfg.betaDotLim; cfg.betaDotLim];
torqueLimits = [-cfg.torqueLim; cfg.torqueLim];
torqueApplied = clamp(torque, torqueLimits);
betaDot = clamp(betaRate, rateLimits);

% Reviewed PR1 placeholder equation: I*betaDDot=Qsat-D*betaRate.
% cfg.K is retained only for provenance compatibility and is not active.
betaDDot = (torqueApplied - cfg.D*betaRate)/cfg.I;

if beta <= betaLimits(1) && betaDot < 0
    betaDot = 0;
end
if beta >= betaLimits(2) && betaDot > 0
    betaDot = 0;
end
if betaRate >= rateLimits(2) && betaDDot > 0
    betaDDot = 0;
elseif betaRate <= rateLimits(1) && betaDDot < 0
    betaDDot = 0;
end
if beta <= betaLimits(1) && betaDDot < 0
    betaDDot = 0;
elseif beta >= betaLimits(2) && betaDDot > 0
    betaDDot = 0;
end

flags.torqueClamped = abs(torqueApplied-torque) > 0;
flags.rateClamped = abs(clamp(betaRate, rateLimits)-betaRate) > 0;
flags.atLowerAngle = beta <= betaLimits(1);
flags.atUpperAngle = beta >= betaLimits(2);
end

function y = clamp(value, limits)
y = min(max(value, limits(1)), limits(2));
end
