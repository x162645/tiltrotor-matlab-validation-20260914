function report = check_berger13_variable_inertia()
%CHECK_BERGER13_VARIABLE_INERTIA Verify moving-nacelle rigid-body closure.
% This check covers the two terms that are easy to omit when adding the
% nacelle states: equal-and-opposite actuator torque and dI/dt*omega.

rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(rootDir);
addpath(fullfile(rootDir,'model'));
addpath(fullfile(rootDir,'model','berger13'));

P = params_berger13();
x = zeros(13,1);
x(1:6) = [20;1;-0.5;0.2;-0.1;0.4];
x(10:13) = [35;52;0.25;-0.18]*pi/180;
u = zeros(10,1);
u(9:10) = [1200;-400];
[xdot,out] = tiltrotor_eom_13x10(x,u,P);

% Torque input must be observable in the rigid-body moment equation with
% the reviewed body/nacelle sign convention.
eBeta = [0;-1;0];
expectedReaction = -out.nacelle.left.torqueApplied*eBeta - ...
    out.nacelle.right.torqueApplied*eBeta;
reactionResidual = norm(out.MactuatorReaction-expectedReaction,inf);

% Unequal nacelle rates and nonzero body angular velocity should produce a
% finite, nonzero variable-inertia term.  Check the exact Newton-Euler
% closure rather than a hard-coded numerical value.
closure = out.massProperties.I*xdot(4:6) - ...
    (out.Mtotal-cross(x(4:6),out.massProperties.I*x(4:6)));
report.reactionResidual = reactionResidual;
report.reactionNorm = norm(out.MactuatorReaction);
report.inertiaRateNorm = norm(out.MinertiaRate);
report.omegaClosureResidual = norm(closure,inf);
report.mechanicsFlags = P.mechanics;
report.allPassed = reactionResidual < 1e-12 && ...
    report.reactionNorm > 1e-8 && report.inertiaRateNorm > 1e-12 && ...
    report.omegaClosureResidual < 1e-8 && ...
    isfield(out,'MinertiaRate') && P.mechanics.iDotOmegaImplemented;
fprintf('Berger13 variable-inertia closure: %d (reaction %.3e, |reaction| %.3e, I-dot-omega %.3e, closure %.3e)\n', ...
    report.allPassed,reactionResidual,report.reactionNorm,report.inertiaRateNorm,report.omegaClosureResidual);
end
