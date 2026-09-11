function result=run_d02_longitudinal_heave(config,P)
%RUN_D02_LONGITUDINAL_HEAVE Reviewed facade; explicit reusable workpoint.
% Inherited 15-state mode is preserved. Quasisteady mode algebraically removes
% the two inflow states; actuator dynamics and body/observation equations match.
if nargin<1||isempty(config),config=struct();end
if ~isstruct(config)||~isscalar(config),error('d02:InvalidConfig','Scalar config required.');end
if nargin<2||isempty(P)
 if isfield(config,'preparedWorkpoint'),P=config.preparedWorkpoint.P;else,P=params_nominal();end
end
if ~isfield(config,'action'),config.action='trim';end
if ~ischar(config.action)||~any(strcmp(config.action,{'trim','linearize','simulate'}))
 error('d02:InvalidAction','Expected trim, linearize or simulate.');end
if ~isfield(config,'modelMode'),config.modelMode='dynamic';end
m=d02_layout(config.modelMode);
if isfield(config,'preparedWorkpoint')
 wp=config.preparedWorkpoint;
 if ~isstruct(wp)||~isfield(wp,'identity')||~strcmp(wp.identity,'D02_1_EXPLICIT_WORKPOINT')||~isequaln(P,wp.P)||~wp.report.pass
  error('d02:WorkpointMismatch','Reused workpoint must match the exact parameter structure and be accepted.');end
 if isfield(config,'trim')
  names=fieldnames(config.trim);
  for j=1:numel(names)
   key=names{j};if ~isfield(wp.trim.config,key)||~isequal(config.trim.(key),wp.trim.config.(key))
    error('d02:WorkpointMismatch','Reused trim config mismatch: %s',key);end
  end
 end
else
 if ~isfield(config,'trim'),config.trim=struct('V',0,'betaMDeg',0);end
 wp=d02_prepare_workpoint(config.trim,P);
end
if strcmp(m.mode,'dynamic'),z=wp.dynamicState;else,z=wp.quasisteadyState;end
[f0,snapshot]=d02_rhs(z,wp.command,wp.trim.betaM,P,m.mode);
result=struct('kind','d02-longitudinal-heave-reviewed','modelIdentity',m.identity, ...
 'success',false,'executionSucceeded',false,'workpointAccepted',wp.report.pass, ...
 'externalAccuracyPassed',false,'config',config,'workpoint',wp,'trim',wp.trim, ...
 'betaM',wp.trim.betaM,'zTrim',z,'uTrimCommand',wp.command,'trimDerivative',f0, ...
 'trimReport',wp.report,'trimSnapshot',snapshot,'stateNames',{m.stateNames.'}, ...
 'stateUnits',{m.stateUnits.'},'inputNames',{m.inputNames.'},'inputUnits',{m.inputUnits.'}, ...
 'outputNames',{m.outputNames.'},'outputUnits',{m.outputUnits.'});
if strcmp(config.action,'linearize')
 if ~isfield(config,'stepFactor'),config.stepFactor=1;end
 if isfield(config,'linearStep')
  error('d02:LegacyStepOption','Use explicit stepFactor with documented state/input scales; arbitrary old step vector is not silently ignored.');end
 lin=d02_linearize(wp,m.mode,config.stepFactor);
 result.A=lin.A;result.B=lin.B;result.C=lin.C;result.D=lin.D;result.linearReport=lin;
elseif strcmp(config.action,'simulate')
 defaults=struct('inputChannel',1,'amplitudeDeg',.2,'startTime',1,'totalTime',3,'timeStep',.05,'outputState',m.height);
 keys=fieldnames(defaults);for j=1:numel(keys),key=keys{j};if ~isfield(config,key),config.(key)=defaults.(key);end,end
 index=config.outputState;
 if ~isnumeric(index)||~isscalar(index)||~isreal(index)||~isfinite(index)||index~=fix(index)||index<1||index>m.n
  error('d02:InvalidOutputState','Integer output state index required.');end
 cfg=struct('channel',config.inputChannel,'amplitudeRad',config.amplitudeDeg*pi/180,'startTime',config.startTime, ...
  'totalTime',config.totalTime,'sampleTime',config.timeStep,'storeComponents',true);
 sim=d02_simulate(wp,m.mode,cfg);
 result.simulation=sim;result.time=sim.time;result.state=sim.state;result.command=sim.command;
 result.output=sim.output;result.selectedOutput=sim.state(:,index);result.selectedOutputName=m.stateNames{index};
 result.selectedOutputUnit=m.stateUnits{index};result.cost=sim.cost;
 result.loads=struct('FxAeroProp',sim.output(:,11),'FzAeroProp',sim.output(:,12),'My',sim.output(:,13), ...
  'rotorThrustLeft',sim.output(:,7),'rotorThrustRight',sim.output(:,8), ...
  'inducedVelocityLeft',sim.actualInflow(:,1),'inducedVelocityRight',sim.actualInflow(:,2), ...
  'targetInducedVelocityLeft',sim.targetInflow(:,1),'targetInducedVelocityRight',sim.targetInflow(:,2), ...
  'hDotUp',sim.output(:,4),'components',{sim.componentLoads});
 mass=snapshot.massProperties.mass;
 result.loads.Fx=sim.output(:,11)-mass*P.env.g*sin(sim.state(:,8));
 result.loads.Fz=sim.output(:,12)+mass*P.env.g*cos(sim.state(:,7)).*cos(sim.state(:,8));
 result.peakAbs=max(abs(result.selectedOutput));
end
result.config=config;result.executionSucceeded=true;result.success=result.workpointAccepted;
end
