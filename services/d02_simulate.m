function sim=d02_simulate(wp,mode,cfg)
%D02_SIMULATE Constant-input segments split exactly at the step event.
% Output sampling does not discretize the command event. Timing distinguishes
% ODE RHS work from optional replay/diagnostics. Never subtract f0 physically.
m=d02_layout(mode);if strcmp(mode,'dynamic'),z0=wp.dynamicState;else,z0=wp.quasisteadyState;end
fields={'channel','amplitudeRad','startTime','totalTime','sampleTime'};
for j=1:numel(fields),if ~isfield(cfg,fields{j}),error('d02:InvalidSimulationConfig','Missing %s',fields{j});end,end
v=[cfg.channel,cfg.amplitudeRad,cfg.startTime,cfg.totalTime,cfg.sampleTime];
if ~isnumeric(v)||~isreal(v)||any(~isfinite(v))||~ismember(cfg.channel,1:3)|| ...
 cfg.startTime<0||cfg.totalTime<=cfg.startTime||cfg.sampleTime<=0||cfg.sampleTime>cfg.totalTime
 error('d02:InvalidSimulationConfig','Invalid channel/amplitude/times.');end
if ~isfield(cfg,'maxStep'),cfg.maxStep=.05;end
if ~isfield(cfg,'relTol'),cfg.relTol=1e-7;end
if ~isfield(cfg,'absTol'),cfg.absTol=1e-9;end
if ~isfield(cfg,'storeComponents'),cfg.storeComponents=false;end
vv=[cfg.maxStep,cfg.relTol,cfg.absTol];
if ~isreal(vv)||any(~isfinite(vv))||any(vv<=0)||~isscalar(cfg.storeComponents)
 error('d02:InvalidSimulationConfig','Positive integrator settings required.');end
u0=wp.command;u1=u0;u1(cfg.channel)=u1(cfg.channel)+cfg.amplitudeRad;
% Validate both commands before starting any integration.
d02_rhs(z0,u0,wp.trim.betaM,wp.P,mode);d02_rhs(z0,u1,wp.trim.betaM,wp.P,mode);
opts=odeset('RelTol',cfg.relTol,'AbsTol',cfg.absTol,'MaxStep',cfg.maxStep);
rhsCalls=0;modelSeconds=0;flapSeconds=0;rotorSeconds=0;bladeCalls=0;flapCalls=0;
clock=tic;
if cfg.startTime>0
 pre=ode45(@(t,z)fun(t,z,u0),[0 cfg.startTime],z0,opts);zEvent=deval(pre,cfg.startTime);
else,pre=[];zEvent=z0;end
post=ode45(@(t,z)fun(t,z,u1),[cfg.startTime cfg.totalTime],zEvent,opts);
odeSeconds=toc(clock);
t=unique([(0:cfg.sampleTime:cfg.totalTime).';cfg.startTime;cfg.totalTime]);n=numel(t);state=zeros(n,m.n);
mask=t<cfg.startTime;if any(mask),state(mask,:)=deval(pre,t(mask)).';end
state(~mask,:)=deval(post,t(~mask)).';
cmd=repmat(u0.',n,1);cmd(~mask,:)=repmat(u1.',sum(~mask),1);
y=zeros(n,numel(m.outputNames));actual=zeros(n,2);target=actual;valid=false(n,1);steady=valid;component=cell(n,1);
clock=tic;diagBlade=0;diagFlap=0;
for k=1:n
 [~,o,yy]=d02_rhs(state(k,:).',cmd(k,:).',wp.trim.betaM,wp.P,mode);
 y(k,:)=yy.';actual(k,:)=o.actualInducedVelocity.';target(k,:)=o.targetInducedVelocity.';
 valid(k)=o.evaluationValid;steady(k)=o.steadyEquilibriumSatisfied;
 diagBlade=diagBlade+o.work.bladeLoadCalls;diagFlap=diagFlap+o.work.flapSolveCalls;
 if cfg.storeComponents
  data=o.components.components;snap=struct();
  for j=1:numel(data),s=data{j};snap.(s.name)=struct('F',s.F,'M',s.M);end
  component{k}=snap;
 end
end
diagSeconds=toc(clock);
sim=struct('time',t,'state',state,'command',cmd,'output',y,'actualInflow',actual, ...
 'targetInflow',target,'evaluationValid',valid,'steadyEquilibriumSatisfied',steady, ...
 'componentLoads',{component},'layout',m,'config',cfg, ...
 'cost',struct('rhsCalls',rhsCalls,'odeSeconds',odeSeconds,'modelSeconds',modelSeconds, ...
 'flapSeconds',flapSeconds,'rotorSeconds',rotorSeconds,'bladeLoadCalls',bladeCalls,'flapSolveCalls',flapCalls, ...
 'diagnosticCalls',n,'diagnosticSeconds',diagSeconds,'diagnosticBladeCalls',diagBlade,'diagnosticFlapCalls',diagFlap), ...
 'executionSucceeded',true,'externalAccuracyPassed',false);
 function dz=fun(~,z,u)
  [dz,oo]=d02_rhs(z,u,wp.trim.betaM,wp.P,mode);rhsCalls=rhsCalls+1;
  modelSeconds=modelSeconds+oo.work.modelSeconds;flapSeconds=flapSeconds+oo.work.flapSeconds;
  rotorSeconds=rotorSeconds+oo.work.rotorSeconds;bladeCalls=bladeCalls+oo.work.bladeLoadCalls;flapCalls=flapCalls+oo.work.flapSolveCalls;
 end
end
