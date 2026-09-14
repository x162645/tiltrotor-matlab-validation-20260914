from pathlib import Path
p=Path('analysis/validation_whole_aircraft_trim/run_line_b_v7_speed_sweep.m')
s=p.read_text(encoding='utf-8')
s=s.replace('function results=run_line_b_v7_speed_sweep(outputRoot)','function results=run_line_b_v7_speed_sweep_v2(outputRoot)',1)
s=s.replace('%RUN_LINE_B_V7_SPEED_SWEEP Actual trim solves; never interpolated trim points.', '%RUN_LINE_B_V7_SPEED_SWEEP_V2 Damped Newton, crosschecked against V1.\n% Existing accepted V1 points are reused without overwriting their MAT files.\n% V2 changes only numerical search efficiency; source physics and acceptance\n% remain frozen. Central FD h=1e-3 of the original variable scales, at most\n% 10 Newton iterations, 7 backtracking trials, target residual <1e-8.\n% Failure reverts to original fminsearch, starting at the last physical iterate.')
s=s.replace("'solver','fminsearch'", "'solver','DAMPED_NEWTON_THEN_FMINSEARCH','solverRevision','V2', ...\n 'newtonMaxIterations',10,'newtonResidualTarget',1e-8,'newtonFDStepScaled',1e-3, ...\n 'newtonBacktrackingSteps',7,'newtonMaxStepScaled',2,'crosscheckRelativeTolerance',1e-5")
s=s.replace('V7_SWEEP_FROZEN.mat','V7_SWEEP_FROZEN_V2.mat').replace('V7_SWEEP_FROZEN.json','V7_SWEEP_FROZEN_V2.json')
s=s.replace("S=readtable(fullfile(here,'original_baseline_trim_seeds.csv'));", """crossPath=fullfile(outputRoot,'V2_SOLVER_CROSSCHECK_070kt.mat');
if exist(crossPath,'file')
 cc=load(crossPath,'crosscheck');crosscheck=cc.crosscheck;
else
 src=load(fullfile(outputRoot,'POINT_065p00kt.mat'),'result');
 dst=load(fullfile(outputRoot,'POINT_070p00kt.mat'),'result');
 assert(src.result.row.numericallyAccepted&&dst.result.row.numericallyAccepted,'Accepted V1 65/70kt anchor files required.');
 seedCheck=struct('speed_kt',65,'z',src.result.z,'flapL',src.result.point.eomOut.rotorLeft.zFlap(:), ...
  'flapR',src.result.point.eomOut.rotorRight.zFlap(:),'role','V1_ACCEPTED_65KT_CROSSCHECK_SEED');
 fprintf('V2_CROSSCHECK_BEGIN 65kt seed -> 70kt old accepted solution\\n');
 check=solve_one(70,seedCheck,P,config);oldrow=dst.result.row;
 oldValues=[oldrow.theta_deg,oldrow.collectiveControl_deg,oldrow.stick_in,oldrow.totalRotorPower_kW];
 newValues=[check.row.theta_deg,check.row.collectiveControl_deg,check.row.stick_in,check.row.totalRotorPower_kW];
 scaledDifference=abs(newValues-oldValues)./max(1,abs(oldValues));
 crosscheck=struct('passed',check.row.numericallyAccepted&&strcmp(check.row.solverRevision,'NEWTON_V2')&& ...
  all(scaledDifference<=config.crosscheckRelativeTolerance),'oldValues',oldValues,'newValues',newValues, ...
  'fields',{{'theta_deg','collectiveControl_deg','stick_in','totalRotorPower_kW'}}, ...
  'scaledDifference',scaledDifference,'tolerance',config.crosscheckRelativeTolerance, ...
  'numericalResult',check,'purpose','same-physics numerical solver crosscheck; no external target used');
 save(crossPath,'crosscheck','P');write_json(fullfile(outputRoot,'V2_SOLVER_CROSSCHECK_070kt.json'),rmfield(crosscheck,'numericalResult'));
end
assert(crosscheck.passed,'run_line_b_v7_speed_sweep_v2:CrosscheckFailed','V2 crosscheck did not pass; old V1 evidence retained.');
fprintf('V2_CROSSCHECK_PASSED maxRelativeDifference=%.6g\\n',max(crosscheck.scaledDifference));
S=readtable(fullfile(here,'original_baseline_trim_seeds.csv'));""")
s=s.replace("loaded=load(pointPath,'result');result=loaded.result;", "loaded=load(pointPath,'result');result=loaded.result;result.row=upgrade_row(result.row);")
s=s.replace(" [y,cost,ef,optimizer]=fminsearch(@objective,zeros(3,1),opts);z=seed+scale.*y;", """ [z,newtonOK,newtonTrace,newtonFailure]=damped_newton(seed);
 newtonEvaluations=evals;a.newtonTrace=newtonTrace;a.newtonFailure=newtonFailure;
 a.row.newtonIterations=numel(newtonTrace);a.row.newtonEvaluations=newtonEvaluations;
 if newtonOK
  ef=1;cost=newtonTrace(end).residualNorm^2;optimizer=struct('solver','DAMPED_NEWTON_V2','iterations',numel(newtonTrace));
  a.row.solverRevision='NEWTON_V2';a.row.fminsearchEvaluations=0;
 else
  seed=z;a.fminsearchSeed=z;
  [y,cost,ef,optimizer]=fminsearch(@objective,zeros(3,1),opts);z=seed+scale.*y;
  a.row.solverRevision='FMINSEARCH_FALLBACK_V2';a.row.fminsearchEvaluations=evals-newtonEvaluations;
 end""")
s=s.replace(" function J=objective(y)", """ function [z,ok,trace,failure]=damped_newton(z)
  ok=false;trace=repmat(struct('iteration',0,'residualNorm',NaN,'stepFraction',NaN),0,1);failure='';
  try
   r=validated_residual(z);
   for it=0:cfg.newtonMaxIterations
    trace(end+1,1)=struct('iteration',it,'residualNorm',norm(r),'stepFraction',NaN); %#ok<AGROW>
    if norm(r)<cfg.newtonResidualTarget,ok=true;return;end
    if it==cfg.newtonMaxIterations,failure='NEWTON_MAX_ITERATIONS';return;end
    h=cfg.newtonFDStepScaled;J=zeros(3,3);
    for jj=1:3
     dz=zeros(3,1);dz(jj)=h*scale(jj);
     rp=validated_residual(z+dz);rm=validated_residual(z-dz);J(:,jj)=(rp-rm)/(2*h);
    end
    if ~all(isfinite(J(:)))||rcond(J)<1e-12,failure='NEWTON_SINGULAR_JACOBIAN';return;end
    dy=-J\\r;dy=dy*min(1,cfg.newtonMaxStepScaled/max(norm(dy,Inf),eps));accepted=false;
    for bt=0:cfg.newtonBacktrackingSteps-1
     fraction=2^(-bt);candidate=z+fraction*scale.*dy;
     try
      rt=validated_residual(candidate);
      if norm(rt)<(1-1e-4*fraction)*norm(r)
       z=candidate;r=rt;accepted=true;trace(end).stepFraction=fraction;break;
      end
     catch ME,invalid=invalid+1;ids{end+1}=ME.identifier;end
    end
    if ~accepted,failure='NEWTON_LINE_SEARCH_FAILED';return;end
   end
  catch ME,invalid=invalid+1;ids{end+1}=ME.identifier;failure=ME.identifier;end
 end
 function r=validated_residual(z)
  if any(z<=bounds(:,1))||any(z>=bounds(:,2)),error('V2Newton:SearchBoundary','Trial outside original bounds.');end
  p=evaluate(z);
  if ~p.allocation.withinLimits||~p.eomOut.physicalConverged||~p.eomOut.physicalBranchSupported|| ...
    ~isreal(p.xdot)||any(~isfinite(p.xdot))
   error('V2Newton:UnsupportedPhysicalTrial','Trial must satisfy original physical/control gates.');
  end
  r=p.xdot([1,3,5]);r(1:2)=r(1:2)/P.env.g;
 end
 function J=objective(y)""")
s=s.replace("'speed_kt',NaN,'speed_mps',NaN,'numericallyAccepted'", "'speed_kt',NaN,'speed_mps',NaN,'solverRevision','FMINSEARCH_V1', ...\n 'newtonIterations',0,'newtonEvaluations',0,'fminsearchEvaluations',0,'numericallyAccepted'",1)
s=s.replace("function v=field_or", """function r=upgrade_row(r)
template=empty_row();names=fieldnames(template);
for k=1:numel(names),if ~isfield(r,names{k}),r.(names{k})=template.(names{k});end,end
if strcmp(r.solverRevision,'FMINSEARCH_V1'),r.fminsearchEvaluations=r.evaluationCount;end
r=orderfields(r,template);
end
function v=field_or""")
out=p.with_name('run_line_b_v7_speed_sweep_v2.m');out.write_text(s,encoding='utf-8')
print(out)
