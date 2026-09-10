function result = run_d02_longitudinal_heave(config, P)
%RUN_D02_LONGITUDINAL_HEAVE Opt-in longitudinal/heave dynamic prototype.
% State: [production 9-state; induced velocity L/R; actuator collective,
% cyclic, elevator; inertial altitude hUp]. Commands are [collective, cyclic,
% elevator] in radians. hUp is positive upward; body z is positive downward.
% Rotor loads are recomputed at the current inflow state, and the rotor model
% returns the momentum target used by the inflow ODE. This is not a load filter.
if nargin < 2 || isempty(P), P = params_nominal(); end
if nargin < 1 || isempty(config), config = struct(); end
config = apply_defaults(config);
validate_config(config);
trimResult = run_trim_case(config.trim, P);
if ~trimResult.success
    error('run_d02_longitudinal_heave:UnconvergedTrim','D02 requires a converged trim point.');
end
betaM = trimResult.betaM;
uTrim = [trimResult.uTrim(1); trimResult.uTrim(3); trimResult.uTrim(6)];
viTrim = [trimResult.loads.components.rotorLeft.inducedVelocity; ...
          trimResult.loads.components.rotorRight.inducedVelocity];
zTrim = [trimResult.xTrim(:); viTrim; uTrim; 0];
[trimDerivative, trimOut] = d02_rhs(zTrim, uTrim, betaM, P);
result.kind = 'd02-longitudinal-heave-dynamic-prototype';
result.timestamp = datestr(now,30);
result.success = true;
result.mode = lower(config.action);
result.config = config;
result.betaM = betaM;
result.trim = trimResult;
result.zTrim = zTrim;
result.uTrimCommand = uTrim;
result.trimDerivative = trimDerivative;
result.trimReport = make_trim_report(trimDerivative, trimResult);
result.stateNames = {'u';'v';'w';'p';'q';'r';'phi';'theta';'psi';'inducedVelocityLeft';'inducedVelocityRight';'collectiveActuator';'cyclicActuator';'elevatorActuator';'hUp'};
result.stateUnits = {'m/s';'m/s';'m/s';'rad/s';'rad/s';'rad/s';'rad';'rad';'rad';'m/s';'m/s';'rad';'rad';'rad';'m'};
result.inputNames = {'collectiveCommand';'cyclicLongCommand';'elevatorCommand'};
result.inputUnits = {'rad';'rad';'rad'};
result.trimSnapshot = trimOut;
switch lower(config.action)
    case 'trim'
    case 'linearize'
        [result.A,result.B,result.linearReport] = d02_linearize(zTrim,uTrim,betaM,P,config.linearStep);
    case 'simulate'
        [sim,loads] = d02_simulate(zTrim,uTrim,betaM,P,config);
        result.time = sim.time; result.state = sim.state; result.command = sim.command;
        result.loads = loads;
        result.selectedOutput = sim.state(:,config.outputState);
        result.selectedOutputName = result.stateNames{config.outputState};
        result.selectedOutputUnit = result.stateUnits{config.outputState};
        [result.peakAbs,idx] = max(abs(result.selectedOutput)); result.peakTime = sim.time(idx);
end
end

function [zdot,out] = d02_rhs(z,uCommand,betaM,P)
z=z(:); uCommand=uCommand(:);
if numel(z)~=15 || numel(uCommand)~=3, error('run_d02_longitudinal_heave:DimensionMismatch','Expected 15 states and 3 commands.'); end
x=z(1:9); vi=z(10:11); uAct=z(12:14);
uCtrl=[uAct(1);0;uAct(2);0;0;uAct(3);0];
[xdot,eom]=tiltrotor_eom(x,uCtrl,betaM,P,vi);
targetVi=[eom.components.rotorLeft.inducedVelocityTarget;eom.components.rotorRight.inducedVelocityTarget];
dvi=(targetVi-vi)/P.d02.inflowTimeConstant;
duAct=(uCommand-uAct)./P.d02.actuatorTimeConstant(:);
phi=x(7); theta=x(8); uBody=x(1:3);
Rbi=[cos(theta),sin(phi)*sin(theta),cos(phi)*sin(theta);0,cos(phi),-sin(phi);-sin(theta),sin(phi)*cos(theta),cos(phi)*cos(theta)];
hDot=-Rbi(3,:)*uBody;
zdot=[xdot;dvi;duAct;hDot];
out=eom; out.zdot=zdot; out.targetInducedVelocity=targetVi; out.hDotUp=hDot;
out.longitudinalLoads=struct('Fx',eom.Ftotal(1),'Fz',eom.Ftotal(3),'My',eom.Mtotal(2));
out.componentLoads=component_load_snapshot(eom.components);
end

function [A,B,report]=d02_linearize(z,u,betaM,P,steps)
n=numel(z); m=numel(u); A=zeros(n); B=zeros(n,m);
for j=1:n, h=steps(j); zp=z;zm=z;zp(j)=zp(j)+h;zm(j)=zm(j)-h;A(:,j)=(d02_rhs(zp,u,betaM,P)-d02_rhs(zm,u,betaM,P))/(2*h); end
for j=1:m, h=steps(n+j); up=u;um=u;up(j)=up(j)+h;um(j)=um(j)-h;B(:,j)=(d02_rhs(z,up,betaM,P)-d02_rhs(z,um,betaM,P))/(2*h); end
report.f0=d02_rhs(z,u,betaM,P); report.stateStep=steps(1:n); report.inputStep=steps(n+1:end); report.finite=isreal(A)&&isreal(B)&&all(isfinite(A(:)))&&all(isfinite(B(:)));
end

function [sim,history]=d02_simulate(z0,u0,betaM,P,config)
t=(0:config.timeStep:config.totalTime).'; if t(end)<config.totalTime,t(end+1)=config.totalTime;end
cmd=repmat(u0.',numel(t),1);tau=t-config.startTime;active=tau>=0;amp=config.amplitudeDeg*pi/180;cmd(:,config.inputChannel)=cmd(:,config.inputChannel)+amp*double(active);
opts=odeset('RelTol',1e-7,'AbsTol',1e-9); [tout,state]=ode45(@rhs,t,z0,opts); if ~isequal(tout,t),cmd=interp1(t,cmd,tout,'previous');end
sim.time=tout;sim.state=state;sim.command=cmd;raw=cell(numel(tout),1);
for k=1:numel(tout),[~,tmp]=d02_rhs(state(k,:).',cmd(k,:).',betaM,P);raw{k}=tmp;end
history=flatten_history(raw);
    function dz=rhs(currentTime,currentState), currentCommand=interp1(t,cmd,currentTime,'previous').'; dz=d02_rhs(currentState,currentCommand,betaM,P); end
end

function history=flatten_history(raw)
history=struct();
history.Fx=zeros(numel(raw),1); history.Fz=zeros(numel(raw),1); history.My=zeros(numel(raw),1);
history.rotorThrustLeft=zeros(numel(raw),1); history.rotorThrustRight=zeros(numel(raw),1);
history.inducedVelocityLeft=zeros(numel(raw),1); history.inducedVelocityRight=zeros(numel(raw),1);
history.hDotUp=zeros(numel(raw),1); history.components=cell(numel(raw),1);
for k=1:numel(raw)
    r=raw{k};
    if ~isstruct(r), error('run_d02_longitudinal_heave:InvalidHistory','History sample %d is %s.',k,class(r)); end
    if ~isstruct(r.longitudinalLoads), error('run_d02_longitudinal_heave:InvalidHistory','longitudinalLoads sample %d is %s.',k,class(r.longitudinalLoads)); end
    history.Fx(k)=r.longitudinalLoads.Fx;history.Fz(k)=r.longitudinalLoads.Fz;history.My(k)=r.longitudinalLoads.My;
    history.rotorThrustLeft(k)=r.componentLoads.rotorLeft.thrust;history.rotorThrustRight(k)=r.componentLoads.rotorRight.thrust;
    history.inducedVelocityLeft(k)=r.targetInducedVelocity(1);history.inducedVelocityRight(k)=r.targetInducedVelocity(2);history.hDotUp(k)=r.hDotUp;history.components{k}=r.componentLoads;
end
end

function snapshot=component_load_snapshot(info)
names={'rotorLeft','rotorRight','wing','fuselage','horizontalTail','verticalTail'};snapshot=struct();
for k=1:numel(names), c=info.components{k}; snapshot.(names{k})=struct('Fx',c.F(1),'Fz',c.F(3),'My',c.M(2)); end
snapshot.rotorLeft.thrust=info.rotorLeft.thrust;snapshot.rotorRight.thrust=info.rotorRight.thrust;snapshot.rotorLeft.inducedVelocity=info.rotorLeft.inducedVelocity;snapshot.rotorRight.inducedVelocity=info.rotorRight.inducedVelocity;
end

function report=make_trim_report(dz,trim)
report.rigidBodyResidual=norm(dz(1:9),inf);report.inflowResidual=norm(dz(10:11),inf);report.actuatorResidual=norm(dz(12:14),inf);report.heightRate=dz(15);report.productionTrimResidual=trim.report.residualNorm;report.pass=report.rigidBodyResidual<5e-2&&report.inflowResidual<5e-3;
end

function config=apply_defaults(config)
defaults=struct('action','trim','trim',struct('V',0,'betaMDeg',0),'inputChannel',1,'amplitudeDeg',0.5,'startTime',1,'totalTime',8,'timeStep',0.02,'outputState',15,'linearStep',[0.05;0.05;0.05;1e-3;1e-3;1e-3;1e-4;1e-4;1e-4;1e-4;1e-4;1e-4;1e-4;1e-4;1e-3;1e-4;1e-4;1e-4]);
names=fieldnames(defaults);for k=1:numel(names),if ~isfield(config,names{k})||isempty(config.(names{k})),config.(names{k})=defaults.(names{k});end,end
if ~isfield(config.trim,'V'),config.trim.V=0;end;if ~isfield(config.trim,'betaMDeg'),config.trim.betaMDeg=0;end
end

function validate_config(config)
if ~ischar(config.action)||~any(strcmpi(config.action,{'trim','linearize','simulate'})),error('run_d02_longitudinal_heave:InvalidAction','action must be trim, linearize, or simulate.');end
if ~isscalar(config.inputChannel)||~ismember(config.inputChannel,1:3),error('run_d02_longitudinal_heave:InvalidInputChannel','inputChannel must be 1, 2, or 3.');end
if ~isscalar(config.amplitudeDeg)||~isfinite(config.amplitudeDeg)||~isscalar(config.startTime)||~isfinite(config.startTime)||config.startTime<0||~isscalar(config.totalTime)||~isfinite(config.totalTime)||config.totalTime<=0||~isscalar(config.timeStep)||~isfinite(config.timeStep)||config.timeStep<=0||config.startTime>config.totalTime,error('run_d02_longitudinal_heave:InvalidConfig','Invalid time or amplitude configuration.');end
if numel(config.linearStep)~=18||any(~isfinite(config.linearStep(:)))||any(config.linearStep(:)<=0),error('run_d02_longitudinal_heave:InvalidConfig','linearStep must contain 18 positive finite values.');end
if ~isscalar(config.outputState)||config.outputState<1||config.outputState>15,error('run_d02_longitudinal_heave:InvalidOutputState','outputState must be in 1..15.');end
end
