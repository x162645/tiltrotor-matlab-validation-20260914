function m=d02_layout(mode)
%D02_LAYOUT One explicit state/input/output contract for model choices.
% D02.1 derives kinematics from the existing x-forward/y-right/z-down EOM.
% No source-identified transfer function is used as the aircraft model.
if nargin<1,mode='dynamic';end
if ~ischar(mode)||~any(strcmp(mode,{'dynamic','quasisteady','pp_mean','cf_mean'}))
 error('d02:InvalidMode','Expected dynamic, quasisteady, pp_mean or cf_mean.');
end
m.mode=mode;m.body=1:9;
body={'u','v','w','p','q','r','phi','theta','psi'};
bodyUnits={'m/s','m/s','m/s','rad/s','rad/s','rad/s','rad','rad','rad'};
if ~strcmp(mode,'quasisteady')
 m.n=15;m.vi=10:11;m.act=12:14;m.height=15;
 m.stateNames=[body,{'viLeft','viRight','collectiveActuator','cyclicActuator','elevatorActuator','hUp'}];
 m.stateUnits=[bodyUnits,{'m/s','m/s','rad','rad','rad','m'}];
 m.stateStep=[1e-3*ones(3,1);1e-4*ones(3,1);1e-5*ones(3,1);1e-3*ones(2,1);1e-5*ones(3,1);1e-3];
else
 m.n=13;m.vi=[];m.act=10:12;m.height=13;
 m.stateNames=[body,{'collectiveActuator','cyclicActuator','elevatorActuator','hUp'}];
 m.stateUnits=[bodyUnits,{'rad','rad','rad','m'}];
 m.stateStep=[1e-3*ones(3,1);1e-4*ones(3,1);1e-5*ones(3,1);1e-5*ones(3,1);1e-3];
end
m.inputNames={'collectiveCommand','cyclicLongCommand','elevatorCommand'};
m.inputUnits={'rad','rad','rad'};m.inputStep=1e-5*ones(3,1);
m.outputNames={'q','theta','wBody','verticalVelocityUp','inertialAccelerationDown', ...
 'specificForceBodyZ','thrustLeft','thrustRight','viLeft','viRight','FxAeroProp','FzAeroProp','My','hUp'};
m.outputUnits={'rad/s','rad','m/s','m/s','m/s^2','m/s^2','N','N','m/s','m/s','N','N','N*m','m'};
m.identity=['D02_1_GENERIC_PRODUCTION_' upper(mode)];
m.physicsRole='ASSUMED_RELAXATION_PROTOTYPE_NOT_V4_OR_V7_VALIDATED_BACKEND';
if any(strcmp(mode,{'pp_mean','cf_mean'}))
 m.identity=['D03_GENERIC_PRODUCTION_' upper(mode)];
 m.physicsRole='SOURCE_MEAN_AXIAL_REDUCTION_CONING_PUMPING_OMITTED_NOT_FLIGHT_VALIDATED';
end
end
