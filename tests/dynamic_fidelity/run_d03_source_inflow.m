function result=run_d03_source_inflow(outputRoot)
%RUN_D03_SOURCE_INFLOW Source scalar physics + paired near-hover comparison.
% No target fitting, new trim search or replay of old27+24 validations.
% Accepted D02.1 workpoint/trajectories are reused. Derivative identity uses
% same-process baseline; cross-run derivative differences remain recorded.
% Equation/analytic tests are verification, not experimental validation.
if nargin<1,outputRoot=fullfile(pwd,'ci_artifacts','d03');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));startup;
addpath(fullfile(root,'analysis','dynamic_fidelity'));layout=d02_layout('dynamic');
diary(fullfile(outputRoot,'MATLAB_LOG.txt'));diaryCleanup=onCleanup(@()diary('off'));
path=fullfile(root,'docs','research','dynamic_fidelity','evidence_d02_1', ...
 'run_34581649374','D02_CONSISTENCY_RESULTS.mat');
a=load(path,'result');old=a.result;
assert(old.meta.allChecksPassed&&strcmp(old.meta.sourceCommit,'d35cb829c04242a44800ff16071bec93e4315e56'));
wp=old.records.workpoint;P=wp.P;z=wp.dynamicState;cmd=wp.command;
checks={};records=struct('workpoint',wp);tableRows={};frequencyRows={};costRows={};domainRows={};clock=tic;
[~,h]=system('git rev-parse HEAD');
meta=struct('identity','D03_SOURCE_MEAN_AXIAL_DYNAMIC_BASELINES','commit',strtrim(h),'version',version, ...
 'release',version('-release'),'status','RUNNING','newTrimSearches',0,'newAircraftTrajectories',10,'newExperimentalSamples',0, ...
 'source','NASA_TM88327_EQ2_EQ4_EQ5_PDF9_10','sourceModels',{{'pp_mean','cf_mean'}}, ...
 'externalAccuracyPassed',false,'fullPittPetersImplemented',false,'dynamicFlappingImplemented',false, ...
 'coningPumpingOmittedInAircraft',true,'defaultPhysicsChanged',false,'assumedActuatorTimeConstant',P.d02.actuatorTimeConstant, ...
 'sourceModelTimeConstantFitted',false,'oldWorkpointReused',true,'archivedInputRole','D02_1_GENERIC_PRODUCTION_NOT_XV15');
try
 models={'pp_mean','cf_mean'};coeff=[128/(75*pi),.849];
 for mi=1:2
  mode=models{mi};mbar=coeff(mi);R=P.rotor.R;rho=P.env.rho;A=pi*R^2;O=P.rotor.Omega;
  v0=16;thrust0=2*rho*A*v0^2;
  [d,info]=mean_inflow_88327(v0,thrust0,0,0,P,mode);
  check([mode ' hover equilibrium'],abs(d)<1e-12,abs(d));
  check([mode ' apparent mass'],abs(info.apparentAirMass_kg-mbar*rho*A*R)<1e-12,info.apparentAirMass_kg);
  [d,info]=mean_inflow_88327(v0,thrust0*1.04,.4,.002,P,mode);
  CT=thrust0*1.04/(rho*A*(O*R)^2);lambda=v0/(O*R);
  reconstructed=mbar*d/(O^2*R)+2*(lambda+.4/(O*R)+(2/3)*.002/O)*lambda;
  check([mode ' independent nondimensional equation'],abs(CT-reconstructed)<1e-13,CT-reconstructed);
  P2=P;P2.rotor.Omega=1.7*O;
  d2=mean_inflow_88327(v0,thrust0*1.04,.4,.002,P2,mode);
  check([mode ' constant-RPM algebraic cancellation'],d==d2,d-d2);
  P2=P;P2.env.rho=2*rho;
  d2=mean_inflow_88327(v0,2*thrust0*1.04,.4,.002,P2,mode);
  check([mode ' density-thrust scaling'],abs(d-d2)<1e-12,d-d2);
  epsV=1e-3;
  dv=(mean_inflow_88327(v0+epsV,thrust0,0,0,P,mode)-mean_inflow_88327(v0-epsV,thrust0,0,0,P,mode))/(2*epsV);
  check([mode ' analytic fixed-thrust derivative'],abs(dv+4*v0/(mbar*R))<1e-8,dv);
  scalar=cell(2,1);
  for si=1:2
   factor=[1.08,.92];T=thrust0*factor(si);vinf=sqrt(T/(2*rho*A));t=(0:.002:1).';
   [tt,v]=ode45(@(~,vv)mean_inflow_88327(vv,T,0,0,P,mode),t,v0,odeset('RelTol',1e-10,'AbsTol',1e-11));
   kappa=(vinf-v0)/(vinf+v0);e=exp(-4*vinf*tt/(mbar*R));exact=vinf*(1-kappa*e)./(1+kappa*e);
   err=max(abs(v-exact));check(sprintf('%s scalar exact step %d',mode,si),err<1e-7,err);
   scalar{si}=struct('t',tt,'numerical',v,'closedForm',exact,'thrust',T);
  end
  records.(mode).scalar=scalar;
 end
 expect(@()mean_inflow_88327(-1,100,0,0,P,'pp_mean'),'mean_inflow_88327:OutsidePositiveBranch');
 expect(@()mean_inflow_88327(1,0,0,0,P,'pp_mean'),'mean_inflow_88327:OutsidePositiveBranch');
 expect(@()mean_inflow_88327(1,100,-2,0,P,'pp_mean'),'mean_inflow_88327:ReverseThroughflow');
 expect(@()mean_inflow_88327(1,100,0,0,P,'unknown'),'mean_inflow_88327:UnknownModel');
 [fo,~,yo]=d02_rhs(z,cmd,0,P,'dynamic');lOld=old.records.linearizations{1,1};
 check('legacy RHS exact archive identity',isequal(fo,lOld.f0),norm(fo-lOld.f0));
 check('legacy observation exact archive identity',isequal(yo,lOld.y0),norm(yo-lOld.y0));
 archiveLin=lOld;
 fresh=cell(1,2);for sf=1:2,fresh{sf}=d02_linearize(wp,'dynamic',2^(1-sf));end
 lOld=fresh{1};records.archiveLegacyLinearizations=old.records.linearizations(1,:);
 records.currentLegacyLinearizations=fresh;
 differences=struct();
 for field={'A','B','C','D'}
  key=field{1};now=lOld.(key);archived=archiveLin.(key);differences.(key)=max(abs(now(:)-archived(:)));
 end
 records.crossRunDerivativeDifferences=differences;
 fprintf('CROSS_RUN_DIFFERENCES A %.9g B %.9g C %.9g D %.9g; retained, not relaxed into PASS\n', ...
  differences.A,differences.B,differences.C,differences.D);
 [~,eo]=d02_rhs(z,cmd,0,P,'dynamic');
 geom={eo.components.rotorLeft.rHub,eo.components.rotorRight.rHub};
 omegaGrid=logspace(-1,1,81).';
 allModels={'dynamic','quasisteady','pp_mean','cf_mean'};
 lins=cell(4,2);lins(1:2,:)=old.records.linearizations;lins(1,:)=fresh;
 simulations=cell(4,5);simulations(1:2,1:3)=old.records.simulations(:,1:3);
 amps=[.2,.1,-.2,-.1];
 for mi=1:2
  index=mi+2;mode=models{mi};mbar=coeff(mi);
  [f,o,y]=d02_rhs(z,cmd,0,P,mode);
  keep=[1:9,12:15];check([mode ' rigid-body static-limit identity'],isequal(f(keep),fo(keep)),norm(f(keep)-fo(keep)));
  check([mode ' same load observations'],isequal(y,yo),norm(y-yo));
  check([mode ' source workpoint equilibrium'],norm(f(10:11),inf)<1e-5,norm(f(10:11),inf));
  api=run_d02_longitudinal_heave(struct('action','trim','preparedWorkpoint',wp,'modelMode',mode),P);
  check([mode ' public service identity and workpoint'],api.success&&strcmp(api.modelIdentity,['D03_GENERIC_PRODUCTION_' upper(mode)]),0);
  P2=P;P2.d02.inflowTimeConstant=9;
  g=d02_rhs(z,cmd,0,P2,mode);check([mode ' ignores old assumed inflow tau'],isequal(g,f),norm(g-f));
  zx=z;zx(1)=5;expect(@()d02_rhs(zx,cmd,0,P,mode),'d03:OutsideNearAxialTestScope');
  for sf=1:2,lins{index,sf}=d02_linearize(wp,mode,2^(1-sf));end
  lin=lins{index,1};half=lins{index,2};
  aDiff=max(abs(reshape(lin.A(keep,:)-lOld.A(keep,:),[],1)));
  check([mode ' same-process non-inflow A identity'],aDiff<1e-12,aDiff);
  bcdDiff=max(abs([reshape(lin.B(keep,:)-lOld.B(keep,:),[],1);lin.C(:)-lOld.C(:);lin.D(:)-lOld.D(:)]));
  check([mode ' same-process BCD identity'],bcdDiff<1e-12,bcdDiff);
  expected=lOld.A(10,10)*2*z(10)*P.d02.inflowTimeConstant/(mbar*P.rotor.R);
  check([mode ' derived local mass scaling'],abs(lin.A(10,10)-expected)<1e-5,lin.A(10,10)-expected);
  cfg=struct('channel',1,'amplitudeRad',0,'startTime',.5,'totalTime',3,'sampleTime',.05,'maxStep',.05,'storeComponents',true);
  s=d02_simulate(wp,mode,cfg);simulations{index,1}=s;cost(s,mode,0);
  check([mode ' zero command no heave drift'],max(abs(s.output(:,5)))<1e-5,max(abs(s.output(:,5))));save_all();
  for ai=1:4
   cfg.amplitudeRad=amps(ai)*pi/180;s=d02_simulate(wp,mode,cfg);simulations{index,ai+1}=s;
   dy=s.output-simulations{index,1}.output;active=s.time>=.5;
   predicted=linear_step(lin,s.time,.5,cfg.amplitudeRad);p2=linear_step(half,s.time,.5,cfg.amplitudeRad);
   sig=sqrt(mean(dy(active,5).^2));err=sqrt(mean((dy(active,5)-predicted(active,5)).^2));ds=sqrt(mean((predicted(active,5)-p2(active,5)).^2));
   check(sprintf('%s %.1fdeg heave linear agreement',mode,amps(ai)),sig>1e-6&&err/sig<.05,err/sig);
   check(sprintf('%s %.1fdeg difference-step agreement',mode,amps(ai)),ds/sig<.02,ds/sig);
   check(sprintf('%s %.1fdeg actual inflow state',mode,amps(ai)),isequal(s.actualInflow,s.state(:,10:11)),0);
   ratio=0;
   for k=1:numel(s.time)
    for side=1:2
     x=s.state(k,1:9).';hub=x(1:3)+cross(x(4:6),geom{side});through=s.actualInflow(k,side)-hub(3);
     ratio=max(ratio,hypot(hub(1),hub(2))/through);
    end
   end
   check(sprintf('%s %.1fdeg near-axial scope',mode,amps(ai)),ratio<=.02,ratio);
   domainRows(end+1,:)={mode,amps(ai),ratio,sqrt(1+ratio^2)-1};
   tableRows(end+1,:)={mode,amps(ai),sig,err,err/sig,ds/sig,min(dy(active,5)),max(dy(active,5)), ...
    max(abs(dy(active,7))),max(abs(dy(active,9))),lin.A(10,10),-1/lin.A(10,10)};
   s.linearOutput=predicted;simulations{index,ai+1}=s;cost(s,mode,amps(ai));save_all();
   T=array2table([s.time,s.state,s.command,s.output,s.targetInflow], 'VariableNames', ...
    [{'time_s'},strcat('state_',s.layout.stateNames),strcat('cmd_',s.layout.inputNames),strcat('out_',s.layout.outputNames),{'targetViLeft','targetViRight'}]);
   writetable(T,fullfile(outputRoot,sprintf('%s_case%d.csv',mode,ai)));
  end
 end
 G=zeros(numel(omegaGrid),4);
 for k=1:4
  l=lins{k,1};G(:,k)=df_state_space_response(l.A,l.B(:,1),l.C(5,:),l.D(5,1),omegaGrid);
  for j=1:numel(omegaGrid)
   frequencyRows(end+1,:)={allModels{k},omegaGrid(j),real(G(j,k)),imag(G(j,k)),20*log10(abs(G(j,k))),angle(G(j,k))*180/pi};
  end
 end
 records.frequency=struct('omega',omegaGrid,'response',G,'input','COLLECTIVE_COMMAND_RAD', ...
  'output','INERTIAL_ACCELERATION_DOWN_M_S2','role','MODEL_TO_MODEL_NO_EXTERNAL_ACCURACY');
 paired={};
 for ai=1:2
  for k=1:4
   d=simulations{k,ai+1}.output-simulations{k,1}.output;
   reference=simulations{2,ai+1}.output-simulations{2,1}.output;active=simulations{k,ai+1}.time>=.5;
   for j=[1,5,7,9]
    paired(end+1,:)={allModels{k},amps(ai),layout.outputNames{j}, ...
     sqrt(mean(d(active,j).^2)),sqrt(mean((d(active,j)-reference(active,j)).^2)),max(abs(d(active,j)-reference(active,j)))};
   end
  end
 end
 records.paired=cell2table(paired,'VariableNames',{'model','amplitude_deg','output','signalRMS','differenceToQuasisteadyRMS','differenceToQuasisteadyPeak'});
 writetable(records.paired,fullfile(outputRoot,'PAIRED_MODEL_DIFFERENCES.csv'));
 for mi=1:2
  rows=tableRows(strcmp(tableRows(:,1),models{mi}),:);
  for signIndex=1:2
   ix=(signIndex-1)*2+[1,2];big=rows{ix(1),4};small=rows{ix(2),4};
   check(sprintf('%s sign%d perturbation refinement',models{mi},signIndex),small<.8*big+1e-8,small/big);
  end
 end
 records.linearizations=lins;records.simulations=simulations;
 meta.status='COMPLETED';meta.wholeJacobianQualified=false;meta.externalComparisonReady=false;
catch ME
 meta.status='FAILED';meta.errorIdentifier=ME.identifier;meta.errorMessage=ME.message;meta.stack=ME.stack;
 save_all();rethrow(ME);
end
save_all();disp(result.meta);
if ~result.meta.allChecksPassed,error('d03:ChecksFailed','See retained raw failed checks.');end
 function check(name,ok,val)
  checks(end+1,:)={name,logical(ok),val};fprintf('%s: %d (%.8g)\n',name,ok,val);
 end
 function expect(fun,id)
  try,fun();catch ME,check(['reject ' id],strcmp(ME.identifier,id),0);return;end
  check(['reject ' id],false,0);
 end
 function cost(s,mode,amp)
  c=s.cost;costRows(end+1,:)={mode,amp,c.odeSeconds,c.rhsCalls,c.flapSolveCalls,c.diagnosticSeconds};
 end
 function save_all()
  if exist('lins','var'),records.linearizations=lins;end
  if exist('simulations','var'),records.simulations=simulations;end
  meta.elapsed_s=toc(clock);meta.checkCount=size(checks,1);meta.allChecksPassed=~isempty(checks)&&all(cell2mat(checks(:,2)));
  result=struct('meta',meta,'records',records,'checks',{checks},'P',P);
  save(fullfile(outputRoot,'D03_RESULTS.mat'),'result','-v7');
  if ~isempty(checks),writetable(cell2table(checks,'VariableNames',{'check','pass','value'}),fullfile(outputRoot,'CHECKS.csv'));end
  if ~isempty(tableRows)
   A=cell2table(tableRows,'VariableNames',{'model','amplitude_deg','heaveRMS','linearAbsRMS','linearNRMSE','stepChangeNRMSE', ...
    'accelerationMin','accelerationMax','thrustPeakAbs','inflowPeakAbs','inflowSelfDerivative','inflowSelfTimeScale'});
   writetable(A,fullfile(outputRoot,'SOURCE_MODEL_RESPONSE_METRICS.csv'));
  end
  if ~isempty(frequencyRows),writetable(cell2table(frequencyRows,'VariableNames',{'model','omega_rad_s','realG','imagG','gain_dB','phase_deg'}),fullfile(outputRoot,'MODEL_FREQUENCY_RESPONSES.csv'));end
  if ~isempty(costRows),writetable(cell2table(costRows,'VariableNames',{'model','amplitude_deg','odeSeconds','rhsCalls','flapSolveCalls','diagnosticSeconds'}),fullfile(outputRoot,'COST.csv'));end
  if ~isempty(domainRows),writetable(cell2table(domainRows,'VariableNames',{'model','amplitude_deg','maxCrossflowRatio','normalMomentumFluxOmissionBound'}),fullfile(outputRoot,'DOMAIN_USAGE.csv'));end
  fid=fopen(fullfile(outputRoot,'RUN_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear c;
 end
end
function y=linear_step(l,t,stepTime,amp)
n=size(l.A,1);M=[l.A,l.B(:,1)*amp;zeros(1,n+1)];y=zeros(numel(t),size(l.C,1));
for k=1:numel(t)
 if t(k)>=stepTime
  v=expm(M*(t(k)-stepTime))*[zeros(n,1);1];y(k,:)=(l.C*v(1:n)+l.D(:,1)*amp).';
 end
end
end
