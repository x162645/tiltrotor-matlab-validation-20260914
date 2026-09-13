function results=run_line_b_v7_speed_sweep(outputRoot)
%RUN_LINE_B_V7_SPEED_SWEEP Actual trim solves; never interpolated trim points.
% Source-table V7, betaM=0, flap40/25, 13000lb, 589rpm, zero immersed wing.
% All physics, limits, and acceptance tests equal the frozen V7 contract.
% Order is 40:5:105, then 35:-5:5. If 5/10kt both succeed, try 0.01kt.
% Zero speed is outside the implemented
% forward-flow source APIs and is recorded as a skipped point, not solved.
% Continuation uses only numerically accepted solutions. If needed, retry
% deterministic neighbouring accepted/baseline seeds; never use target data.
% Per-attempt and per-point MAT files are immutable; same-config reruns resume.
if nargin<1||isempty(outputRoot),outputRoot=fullfile(pwd,'outputs','v7_speed_sweep');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
here=fileparts(mfilename('fullpath'));repo=fileparts(fileparts(here));
[P,contract]=xv15_helicopter_trim_parameters_v1();P=line_b_coherent_tail_parameters(P);
P.fuselage.coefficientModel='GTRS_LONGITUDINAL_TABLES_V1';
P.validation.gtrsTablePackage='CR166536_DIGITIZED_TABLES_CLOSURE_20260913';
P.rotor.correctionIdentity='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4';
P.wing.coefficientModel='GTRS_FREEFIELD_HELI_V6';P.wing.SslipMaxHalf=0;
P.aeroExtras.spinnerModel='GTRS_TWO_SPINNERS_STEADY_HELI_V7';
P.validation.frozenInteractionCaveat='ZERO_IMMERSED_REFERENCE_CASE_NOT_GENERAL_GTRS_WAKE';
identity='V7_SPEED_SWEEP_ZERO_IMMERSED_V1';
speeds=[40:5:105,35:-5:5,0.01,0];
config=struct('identity',identity,'speedOrder_kt',speeds,'solver','fminsearch', ...
 'maxIterations',P.trim.maxIterations,'maxFunEvals',12*P.trim.maxIterations, ...
 'TolX',1e-8,'TolFun',1e-10,'residualTolerance',P.trim.residualTolerance, ...
 'residualDefinition','norm([u_dot/g,w_dot/g,q_dot])','boundsTheta_deg',[-35,35], ...
 'boundsCollective_rad',P.control.collectiveLim,'boundsStick_in',[0,9.6], ...
 'minimumNormalizedBoundMargin',1e-7,'maxAttemptsPerPoint',3, ...
 'seedRule','nearest accepted first; next accepted; nearest original baseline; first accepted wins', ...
 'failureSelection','lowest finite residual diagnostic; never counts as accepted', ...
 'zeroSpeedRule','SKIPPED_SOURCE_DOMAIN_FORWARD_VELOCITY_REQUIRED', ...
 'nearHoverRule','0.01kt only if 5kt and 10kt were accepted; never labeled zero', ...
 'targetDataRead',false,'targetFitting',false,'wingImmersedArea_m2',0, ...
 'wingImmersedRole','CR166537 matching-case zero immersion; not universal low-speed physics', ...
 'claim','SOURCE_CONSTRAINED_MODEL_REFERENCE_CORRELATION_NOT_FLIGHT_VALIDATION');
contract.identity=identity;contract.targetFitting=false;contract.productionPhysicsModified=true;
contract.rotorIdentity='M1_CONTINUOUS_CORRIGAN_V4';
contract.wingIdentity=P.wing.coefficientModel;contract.fuselageIdentity=P.fuselage.coefficientModel;
contract.spinnerIdentity=P.aeroExtras.spinnerModel;contract.claimBoundary=config.claim;
files={mfilename('fullpath'),'model/gtrs_fuselage_longitudinal_table.m', ...
 'model/wing_model_freefield_consistent.m','model/wing_model_source_family.m', ...
 'model/gtrs_horizontal_tail_steady.m','model/rotor_tail_interference_heli.m', ...
 'model/gtrs_spinner_steady.m','analysis/validation_whole_aircraft_trim/xv15_helicopter_control_allocation.m', ...
 'analysis/validation_whole_aircraft_trim/original_baseline_trim_seeds.csv'};
hashes=cell(size(files));
for k=1:numel(files)
 if k==1,files{k}=[files{k} '.m'];else,files{k}=fullfile(repo,files{k});end
 hashes{k}=file_hash(files{k});
end
frozenPath=fullfile(outputRoot,'V7_SWEEP_FROZEN.mat');
if exist(frozenPath,'file')
 old=load(frozenPath,'config','P','hashes');
 assert(isequaln(old.config,config)&&isequaln(old.P,P)&&isequaln(old.hashes(2:end),hashes(2:end)), ...
  'run_line_b_v7_speed_sweep:ResumeMismatch','Existing output uses a different frozen configuration.');
 if ~strcmp(old.hashes{1},hashes{1})
  % The frozen parameters and physical source hashes remain mandatory.
  % Keep an explicit runner revision record for output-only recovery edits.
  revisionPath=fullfile(outputRoot,['RUNNER_REVISION_' hashes{1}(1:12) '.json']);
  if ~exist(revisionPath,'file'),write_json(revisionPath,struct('initialRunnerSHA256',old.hashes{1}, ...
   'currentRunnerSHA256',hashes{1},'physicsAndConfigurationUnchanged',true));end
 end
else
 save(frozenPath,'P','config','contract','files','hashes');
 [~,commit]=system(sprintf('git -C "%s" rev-parse HEAD',repo));
 manifest=struct('config',config,'contract',contract,'commit',strtrim(commit), ...
  'MATLAB',version,'release',version('-release'),'sourceFiles',{files},'sourceSHA256',{hashes}, ...
  'executionIdentity','MATLAB_NATIVE','createdUTC',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss')));
 write_json(fullfile(outputRoot,'V7_SWEEP_FROZEN.json'),manifest);
end
S=readtable(fullfile(here,'original_baseline_trim_seeds.csv'));
base=repmat(empty_seed(),height(S),1);
for j=1:height(S)
 base(j)=struct('speed_kt',S.speed_kt(j),'z',[S.theta_rad(j);S.collective_rad(j);S.stick_in(j)], ...
 'flapL',[S.flapL0(j);S.flapL1c(j);S.flapL1s(j)], ...
 'flapR',[S.flapR0(j);S.flapR1c(j);S.flapR1s(j)],'role','ORIGINAL_ACCEPTED_BASELINE_NUMERICAL_SEED');
end
pool=repmat(empty_seed(),0,1);rows=repmat(empty_row(),0,1);records=cell(0,1);
for k=1:numel(speeds)
 v=speeds(k);tag=strrep(sprintf('%06.2f',v),'.','p');pointPath=fullfile(outputRoot,['POINT_' tag 'kt.mat']);
 fprintf('SWEEP_BEGIN %g kt (%d/%d)\n',v,k,numel(speeds));
 if exist(pointPath,'file')
  loaded=load(pointPath,'result');result=loaded.result;
  assert(strcmp(result.identity,identity),'Existing point identity mismatch.');
  fprintf('SWEEP_RESUME %g kt %s\n',v,result.row.status);
 elseif v==0||(v==0.01&&~all(ismember([5 10],[pool.speed_kt])))
  row=empty_row();row.speed_kt=v;row.speed_mps=v*.514444;row.status=config.zeroSpeedRule;
  if v>0,row.status='SKIPPED_NEAR_HOVER_PREREQUISITE_5KT_10KT_NOT_ACCEPTED';end
  result=struct('identity',identity,'row',row,'attempts',{{}},'point',[], ...
   'skipReason','wing/fuselage/tail/spinner APIs explicitly require x(1)>0');
  result.runnerSHA256=hashes{1};save(pointPath,'result','P');
 else
  queue=seed_queue(v,pool,base,config.maxAttemptsPerPoint);attempts=cell(0,1);
  for j=1:numel(queue)
   fprintf('SWEEP_ATTEMPT %g kt seed=%g kt %s\n',v,queue(j).speed_kt,queue(j).role);
   attemptPath=fullfile(outputRoot,sprintf('POINT_%skt_ATTEMPT_%02d.mat',tag,j));
   if exist(attemptPath,'file')
    stored=load(attemptPath,'attempt');attempt=stored.attempt;
   else
    attempt=solve_one(v,queue(j),P,config);save(attemptPath,'attempt','P');
   end
   attempts{end+1}=attempt; %#ok<AGROW>
   fprintf('SWEEP_ATTEMPT_END %g kt %s residual=%.6g elapsed=%.1fs\n',v,attempt.row.status,attempt.row.residualNorm,attempt.row.elapsed_s);
   if attempt.row.numericallyAccepted,break;end
  end
  accepted=cellfun(@(a)a.row.numericallyAccepted,attempts);i=find(accepted,1);
  if isempty(i)
   vals=cellfun(@(a)a.row.residualNorm,attempts);vals(~isfinite(vals))=Inf;[~,i]=min(vals);
  end
  selected=attempts{i};selected.row.attemptCount=numel(attempts);selected.row.selectedAttempt=i;
  selected.row.totalElapsed_s=sum(cellfun(@(a)a.row.elapsed_s,attempts));
  result=struct('identity',identity,'row',selected.row,'z',selected.z, ...
   'point',selected.point,'attempts',{attempts},'selectedAttempt',i);
  result.runnerSHA256=hashes{1};save(pointPath,'result','P');
 end
 rows(end+1,1)=result.row;records{end+1,1}=result; %#ok<AGROW>
 if result.row.numericallyAccepted
  pool(end+1,1)=struct('speed_kt',v,'z',result.z, ...
   'flapL',result.point.eomOut.rotorLeft.zFlap(:), ...
   'flapR',result.point.eomOut.rotorRight.zFlap(:),'role','ACCEPTED_SAME_PHYSICS_CONTINUATION'); %#ok<AGROW>
 end
 points=sortrows(struct2table(rows,'AsArray',true),'speed_kt');
 writetable(points,fullfile(outputRoot,'V7_SPEED_SWEEP_POINTS.csv'));
 fprintf('SWEEP_POINT %g kt %s theta=%.5g collective=%.5g stick=%.5g power=%.5g kW\n', ...
  v,result.row.status,result.row.theta_deg,result.row.collectiveControl_deg,result.row.stick_in,result.row.totalRotorPower_kW);
end
results=struct('config',config,'contract',contract,'points',points,'records',{records});
save(fullfile(outputRoot,'V7_SPEED_SWEEP_RESULTS.mat'),'results');
summary=struct('requestedPointCount',numel(speeds),'actualSolvePointCount',sum(points.attemptCount>0), ...
 'acceptedCount',sum(points.numericallyAccepted),'failedActualSolveCount',sum(points.attemptCount>0&~points.numericallyAccepted), ...
 'skippedCount',sum(points.attemptCount==0),'acceptedSpeeds_kt',points.speed_kt(points.numericallyAccepted).', ...
 'failedSpeeds_kt',points.speed_kt(points.attemptCount>0&~points.numericallyAccepted).', ...
 'claim',config.claim,'executionIdentity','MATLAB_NATIVE');
write_json(fullfile(outputRoot,'V7_SPEED_SWEEP_SUMMARY.json'),summary);disp(points);disp(summary);
end

function a=solve_one(speedKt,s,P,cfg)
t0=tic;P.stage2Numerics.flapInitialLeft=s.flapL;P.stage2Numerics.flapInitialRight=s.flapR;
d2r=pi/180;bounds=[-35*d2r 35*d2r;P.control.collectiveLim(:).';0 9.6];scale=[2*d2r;10*d2r;1];
seed=s.z(:);invalid=0;ids={};evals=0;
opts=optimset('Display','off','MaxIter',cfg.maxIterations,'MaxFunEvals',cfg.maxFunEvals,'TolX',cfg.TolX,'TolFun',cfg.TolFun);
row=empty_row();row.speed_kt=speedKt;row.speed_mps=speedKt*.514444;
row.seedSpeed_kt=s.speed_kt;row.seedRole=s.role;row.attemptCount=1;
a=struct('row',row,'z',seed,'point',[],'seed',s,'optimizer',struct(),'invalidIdentifiers',{{}});
try
 [y,cost,ef,optimizer]=fminsearch(@objective,zeros(3,1),opts);z=seed+scale.*y;
 a.z=z;a.cost=cost;a.optimizer=optimizer;a.row.exitflag=ef;
 p=evaluate(z);a.point=p;r=p.xdot([1,3,5]);r(1:2)=r(1:2)/P.env.g;
 margin=min(z-bounds(:,1),bounds(:,2)-z)./(bounds(:,2)-bounds(:,1));
 finiteReal=isreal(p.xdot)&&all(isfinite(p.xdot));
 row=a.row;row.residualNorm=norm(r);row.residualUdot_g=r(1);row.residualWdot_g=r(2);row.residualQdot_radps2=r(3);
 row.theta_deg=z(1)/d2r;row.collectiveControl_deg=z(2)/d2r;row.stick_in=z(3);
 x75=(.75-P.rotor.rootCut)/max(1-P.rotor.rootCut,eps);
 row.collectiveGeometric75_deg=(z(2)+P.rotor.twistTip*x75)/d2r;
 row.theta75Deg=row.collectiveGeometric75_deg;
 row.cyclicLong_deg=p.allocation.cyclicLong/d2r;row.theta1sRight_deg=p.allocation.physicalTheta1sRight/d2r;
 row.elevator_deg=p.allocation.elevator/d2r;row.stick_pct=100*z(3)/9.6;
 L=p.eomOut.rotorLeft;R=p.eomOut.rotorRight;
 row.thrustLeft_N=L.thrust;row.thrustRight_N=R.thrust;row.thrustPerRotor_lbf=.5*(L.thrust+R.thrust)/4.4482216152605;
 row.shaftPowerLeft_kW=L.torque*P.rotor.Omega/1000;row.shaftPowerRight_kW=R.torque*P.rotor.Omega/1000;
 row.totalRotorPower_kW=row.shaftPowerLeft_kW+row.shaftPowerRight_kW;
 row.alphaClampCount=L.alphaClampCount+R.alphaClampCount;row.machClampCount=field_or(L,'machClampCount',0)+field_or(R,'machClampCount',0);
 row.physicalConverged=p.eomOut.physicalConverged;row.physicalBranchSupported=p.eomOut.physicalBranchSupported;
 row.withinLimits=p.allocation.withinLimits;row.atBound=any(margin<=cfg.minimumNormalizedBoundMargin);row.minimumBoundMargin=min(margin);
 row.controlsClamped=norm(p.eomOut.components.commandedControls-p.eomOut.components.appliedControls)>1e-12;
 row.wingImmersedHalf_m2=p.eomOut.components.wing.SslipHalf;row.finiteReal=finiteReal;
 row.numericallyAccepted=ef>0&&row.residualNorm<P.trim.residualTolerance&&row.withinLimits&&~row.atBound&& ...
  row.physicalConverged&&row.physicalBranchSupported&&finiteReal;
 if row.numericallyAccepted,row.status='NUMERICALLY_ACCEPTED_SOURCE_SUBSET';
 elseif ef<=0,row.status='SOLVER_NOT_CONVERGED';
 elseif ~row.physicalConverged||~row.physicalBranchSupported,row.status=['PHYSICAL_' p.eomOut.physicalStatus];
 elseif ~row.withinLimits||row.atBound,row.status='CONTROL_OR_SEARCH_BOUNDARY_LIMITED';
 elseif ~finiteReal,row.status='NONFINITE_OR_COMPLEX';
 else,row.status='RESIDUAL_FAILED';end
 replay=evaluate(z);row.repeatEvaluationDifference=norm(replay.xdot-p.xdot);a.row=row;
catch ME
 a.row.status=['FINAL_EVALUATION_ERROR_' ME.identifier];a.row.errorIdentifier=ME.identifier;a.errorMessage=ME.message;
end
a.row.elapsed_s=toc(t0);a.row.invalidEvaluationCount=invalid;a.row.evaluationCount=evals;a.invalidIdentifiers=unique(ids);
 function p=evaluate(z)
  evals=evals+1;allocation=xv15_helicopter_control_allocation(z(3),0,P);
  u=[z(2);0;allocation.cyclicLong;0;0;allocation.elevator;0];x=zeros(9,1);V=speedKt*.514444;
  x(1)=V*cos(z(1));x(3)=V*sin(z(1));x(8)=z(1);
  [xdot,e]=stage2_tiltrotor_eom('M1_CONTINUOUS_CORRIGAN_V4',x,u,0,P);
  p=struct('x',x,'u',u,'xdot',xdot,'eomOut',e,'allocation',allocation);
 end
 function J=objective(y)
  z=seed+scale.*y;
  if any(z<bounds(:,1))||any(z>bounds(:,2))
   d=max(bounds(:,1)-z,0)./(bounds(:,2)-bounds(:,1))+max(z-bounds(:,2),0)./(bounds(:,2)-bounds(:,1));J=1e4+1e4*sum(d.^2);return;
  end
  try
   p=evaluate(z);r=p.xdot([1,3,5]);r(1:2)=r(1:2)/P.env.g;J=r.'*r;
   if ~p.allocation.withinLimits,J=J+1e3;end
   if ~p.eomOut.physicalConverged||~p.eomOut.physicalBranchSupported,invalid=invalid+1;ids{end+1}=p.eomOut.physicalStatus;J=J+1e3;end
   if ~isfinite(J)||~isreal(J),error('run_line_b_v7_speed_sweep:NonfiniteCost','Invalid cost.');end
  catch ME,invalid=invalid+1;ids{end+1}=ME.identifier;J=1e30;end
 end
end

function q=seed_queue(v,pool,base,maxAttempts)
q=repmat(empty_seed(),0,1);
if ~isempty(pool)
 [~,ix]=sort(abs([pool.speed_kt]-v));q=pool(ix(1:min(2,numel(ix))));
end
[~,ix]=sort(abs([base.speed_kt]-v));q=[q(:);base(ix(:))];
q=q(1:min(maxAttempts,numel(q)));
end
function r=empty_seed(),r=struct('speed_kt',NaN,'z',NaN(3,1),'flapL',NaN(3,1),'flapR',NaN(3,1),'role','');end
function r=empty_row()
r=struct('speed_kt',NaN,'speed_mps',NaN,'numericallyAccepted',false,'status','NOT_RUN', ...
 'theta_deg',NaN,'collectiveControl_deg',NaN,'collectiveGeometric75_deg',NaN,'theta75Deg',NaN,'stick_in',NaN,'stick_pct',NaN, ...
 'cyclicLong_deg',NaN,'theta1sRight_deg',NaN,'elevator_deg',NaN,'thrustLeft_N',NaN,'thrustRight_N',NaN, ...
 'thrustPerRotor_lbf',NaN,'shaftPowerLeft_kW',NaN,'shaftPowerRight_kW',NaN,'totalRotorPower_kW',NaN, ...
 'residualNorm',NaN,'residualUdot_g',NaN,'residualWdot_g',NaN,'residualQdot_radps2',NaN, ...
 'withinLimits',false,'atBound',false,'controlsClamped',false,'minimumBoundMargin',NaN, ...
 'physicalConverged',false,'physicalBranchSupported',false,'finiteReal',false,'alphaClampCount',NaN,'machClampCount',NaN, ...
 'wingImmersedHalf_m2',NaN,'repeatEvaluationDifference',NaN,'exitflag',NaN,'evaluationCount',0,'invalidEvaluationCount',0, ...
 'attemptCount',0,'selectedAttempt',0,'seedSpeed_kt',NaN,'seedRole','','elapsed_s',0,'totalElapsed_s',0,'errorIdentifier','');
end
function v=field_or(s,k,fallbackValue),if isfield(s,k),v=s.(k);else,v=fallbackValue;end,end
function write_json(path,s),fid=fopen(path,'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(s),'char');end
function h=file_hash(path)
fid=fopen(path,'rb');assert(fid>=0,'Source file unavailable: %s',path);c=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');
md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
