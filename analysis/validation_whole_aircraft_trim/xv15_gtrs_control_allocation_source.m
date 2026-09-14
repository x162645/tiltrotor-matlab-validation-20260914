function allocation = xv15_gtrs_control_allocation_source(stickIn,betaM,P)
%XV15_GTRS_CONTROL_ALLOCATION_SOURCE CR-166536 control gearing interface.
%
% Analysis-only replacement for the polynomial XV-15 stick map.  The
% longitudinal cyclic gearing is interpolated from CR-166536 Table 8a-I
% (NASA CR-166536, printed page B-89), rather than from a fitted polynomial.
% The table gives dB1/dXLN in deg/in for betaM=0..90 deg.  The repository
% control coordinate is cyclicLong=-theta_1s, so the sign convention remains
% the same as xv15_helicopter_control_allocation.
%
% Table 8a-VII and 8a-VIII are returned as diagnostics only.  Their labels
% describe flapping-controller gains and a speed schedule in the source;
% they are not silently applied to the trim equations because the source
% report does not define an unambiguous mapping to this reduced model.
%
% Source role: source-backed control-interface candidate; not flight-data
% calibration and not a claim that all GTRS control-system states are present.

if nargin < 3 || isempty(P), P = params_nominal(); end
if ~(isscalar(stickIn) && isfinite(stickIn) && isreal(stickIn))
    error('xv15_gtrs_control_allocation_source:InvalidStick', ...
        'stickIn must be a finite real scalar.');
end
if ~(isscalar(betaM) && isfinite(betaM) && isreal(betaM) && ...
        betaM >= 0 && betaM <= pi/2)
    error('xv15_gtrs_control_allocation_source:InvalidNacelleAngle', ...
        'betaM must be a finite scalar in [0,pi/2] rad.');
end

% CR-166536 Table 8a-I, B-89.  Values are confirmed visual
% transcriptions; preserve the source grid and linearly interpolate only
% inside its stated domain.
betaGridDeg = [0 10 20 30 40 50 60 70 80 90];
cyclicGearingGridDegPerIn = [2.100 2.090 1.980 1.810 1.600 ...
    1.350 1.040 0.710 0.362 0.000];
betaDeg = betaM*180/pi;
cyclicGearingDegPerIn = interp1(betaGridDeg,cyclicGearingGridDegPerIn,...
    betaDeg,'linear');

neutralIn = 4.8;
travelIn = [0 9.6];
elevatorGearingDegPerIn = 4.17; % source convention retained by project
deltaStick = stickIn-neutralIn;
cyclicLong = deltaStick*cyclicGearingDegPerIn*pi/180;
elevator = deltaStick*elevatorGearingDegPerIn*pi/180;

withinStickTravel = stickIn >= travelIn(1) && stickIn <= travelIn(2);
withinCyclicLimit = cyclicLong >= P.control.cyclicLim(1) && ...
    cyclicLong <= P.control.cyclicLim(2);
withinElevatorLimit = elevator >= P.control.elevatorLim(1) && ...
    elevator <= P.control.elevatorLim(2);

% CR-166536 8a-VII (B-95): A1B_m controller gain schedule.
flapBetaDeg = [0 15 30 45 60 75 90];
flapControllerGainGrid = [1.000 1.000 1.000 0.920 0.707 0.384 0.000];
flapControllerGain = interp1(flapBetaDeg,flapControllerGainGrid,betaDeg,...
    'linear');

allocation = struct();
allocation.stickIn = stickIn;
allocation.neutralIn = neutralIn;
allocation.deltaStickIn = deltaStick;
allocation.travelIn = travelIn;
allocation.cyclicGearing_rad_per_in = cyclicGearingDegPerIn*pi/180;
allocation.cyclicGearing_deg_per_in = cyclicGearingDegPerIn;
allocation.elevatorGearing_rad_per_in = elevatorGearingDegPerIn*pi/180;
allocation.elevatorGearing_deg_per_in = elevatorGearingDegPerIn;
allocation.cyclicLong = cyclicLong;
allocation.elevator = elevator;
allocation.physicalTheta1sRight = -cyclicLong;
allocation.withinStickTravel = withinStickTravel;
allocation.withinCyclicLimit = withinCyclicLimit;
allocation.withinElevatorLimit = withinElevatorLimit;
allocation.withinLimits = withinStickTravel && withinCyclicLimit && ...
    withinElevatorLimit;
allocation.sourceRole = 'SOURCE_BACKED_GTRS_TABLE_8A_I_STICK_GEARING';
allocation.sourceTable = 'CR-166536 Table 8a-I';
allocation.sourcePrintedPage = 'B-89';
allocation.sourceReadStatus = 'confirmed_visual';
allocation.flapControllerGain = flapControllerGain;
allocation.flapControllerSourceTable = 'CR-166536 Table 8a-VII';
allocation.flapControllerSourcePrintedPage = 'B-95';
allocation.speedScheduleSourceTable = 'CR-166536 Table 8a-VIII';
allocation.speedScheduleSourcePrintedPage = 'B-95';
allocation.unappliedSchedulesReason = ...
    '8a-VII/8a-VIII labels do not define a reduced-model actuator mapping';
allocation.claimBoundary = ...
    'ANALYSIS_ONLY_SOURCE_GEARING_NO_TARGET_TRIM_FITTING';
end
