function allocation = xv15_helicopter_control_allocation(stickIn,betaM,P)
%XV15_HELICOPTER_CONTROL_ALLOCATION Source-constrained XV-15 pitch control map.
%
% Analysis-only validation interface.  The XV-15 longitudinal stick drives
% both longitudinal rotor cyclic and elevator.  The source convention has
% forward stick producing negative right-rotor theta_1s; the repository's
% stage-2 rotor backend internally applies theta_1s=-cyclicLong, so the
% repository control coordinate is positive for forward stick.
%
% Source contract (Kleinhesselink 2007, control-system model):
%   longitudinal stick neutral = 4.8 in
%   helicopter-mode cyclic gearing at betaM=0 ~= 2.1409 deg/in
%   polynomial gearing = -0.012*betaM^2 - 0.0053*betaM + 0.0374 rad/in
%   elevator gearing = 4.17 deg/in
%
% No trim/reference outputs are used in this allocation.

if nargin < 3 || isempty(P)
    P = params_nominal();
end
if ~(isscalar(stickIn) && isfinite(stickIn) && isreal(stickIn))
    error('xv15_helicopter_control_allocation:InvalidStick', ...
        'stickIn must be a finite real scalar.');
end
if ~(isscalar(betaM) && isfinite(betaM) && isreal(betaM))
    error('xv15_helicopter_control_allocation:InvalidNacelleAngle', ...
        'betaM must be a finite real scalar in radians.');
end

neutralIn = 4.8;
travelIn = [0,9.6];
elevatorGearing = 4.17*pi/180; % rad/in
cyclicGearing = -0.012*betaM^2 - 0.0053*betaM + 0.0374; % rad/in

deltaStick = stickIn-neutralIn;
cyclicLong = deltaStick*cyclicGearing;
elevator = deltaStick*elevatorGearing;
physicalTheta1sRight = -cyclicLong;

withinStickTravel = stickIn >= travelIn(1) && stickIn <= travelIn(2);
withinCyclicLimit = cyclicLong >= P.control.cyclicLim(1) && ...
    cyclicLong <= P.control.cyclicLim(2);
withinElevatorLimit = elevator >= P.control.elevatorLim(1) && ...
    elevator <= P.control.elevatorLim(2);

allocation = struct();
allocation.stickIn = stickIn;
allocation.neutralIn = neutralIn;
allocation.deltaStickIn = deltaStick;
allocation.travelIn = travelIn;
allocation.cyclicGearing_rad_per_in = cyclicGearing;
allocation.cyclicGearing_deg_per_in = cyclicGearing*180/pi;
allocation.elevatorGearing_rad_per_in = elevatorGearing;
allocation.elevatorGearing_deg_per_in = 4.17;
allocation.cyclicLong = cyclicLong;
allocation.elevator = elevator;
allocation.physicalTheta1sRight = physicalTheta1sRight;
allocation.withinStickTravel = withinStickTravel;
allocation.withinCyclicLimit = withinCyclicLimit;
allocation.withinElevatorLimit = withinElevatorLimit;
allocation.withinLimits = withinStickTravel && withinCyclicLimit && withinElevatorLimit;
allocation.sourceRole = 'SOURCE_CONSTRAINED_XV15_LONGITUDINAL_STICK_MIXING';
allocation.claimBoundary = [ ...
    'ANALYSIS_ONLY_CONTROL_INTERFACE_NO_TARGET_TRIM_FITTING'];
end
