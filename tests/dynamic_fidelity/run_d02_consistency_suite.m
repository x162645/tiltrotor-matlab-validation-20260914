function result=run_d02_consistency_suite(outputRoot)
%RUN_D02_CONSISTENCY_SUITE Finite scoped verification, no new external score.
% Source/method: original D02 commit21a699a and existing generic production
% equations. Retains assumed tau=0.15 and actuator taus=0.08; no target fit.
% Predetermined grid: one hover workpoint, command channels1/2, 0.2/0.1deg,
% dynamic/quasisteady, 3s with exact0.5s step. No dense envelope scan.
if nargin<1,outputRoot=fullfile(pwd,'ci_artifacts','d02_consistency');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
logPath=fullfile(outputRoot,'MATLAB_LOG.txt');diary(logPath);clean=onCleanup(@()diary('off'));
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'services'));addpath(fullfile(outputRoot,'baseline_code'));
P0=params_nominal();P=P0;
% NUMERICAL precision for derivatives, not altered physics or looser gates.
P.rotor.inducedTol=1e-9;P.rotor.inducedMaxIter=60;P.rotor.flapResidualTol=1e-10;
checks={};records=struct();comparisons={};costRows={};clock=tic;
[~,head]=system('git rev-parse HEAD');
meta=struct('identity','D02_1_RELIABLE_DYNAMIC_BASELINE','sourceCommit',strtrim(head),'sourceParent','21a699a7f7372769f58e4b8b0f2e227f66f95254', ...
 'version',version,'release',version('-release'),'computer',computer,'status','RUNNING', ...
 'physicsChanged',false,'timeConstantsAssumed',true,'newExternalValidation',false,'defaultCoreNumericsChanged',false, ...
 'executionNumerics',struct('inducedTol',P.rotor.inducedTol,'inducedMaxIter',P.rotor.inducedMaxIter,'flapResidualTol',P.rotor.flapResidualTol), ...
 'limits',struct('primaryLinearNrmse',.05,'primaryStepResponseChange',.02,'primaryExcitationRelativeFloor',1e-6), ...
 'scope','ONE_HOVER_TWO_COMMAND_CHANNELS_TWO_AMPLITUDES_NOT_GLOBAL_OR_FLIGHT_VALIDATION');
try
 wp=d02_prepare_workpoint(struct('V',0,'betaMDeg',0,'useMultiStart',false),P);records.workpoint=wp;
 fprintf('WORKPOINT body %.9g inflow %.9g; prepare %.3fs\n',wp.report.bodyDerivativeInf,wp.report.inflowDerivativeInf,wp.preparationSeconds);
 check('workpoint strict numerical residual',wp.report.bodyDerivativeInf<1e-5&&wp.report.inflowDerivativeInf<1e-5,wp.report.inflowDerivativeInf);
 md=d02_layout('dynamic');z=wp.dynamicState;u=wp.command;
 [dz,out,y]=d02_rhs(z,u,0,P,'dynamic');
 check('actual inflow equals explicit state',isequal(out.actualInducedVelocity,z(10:11)),0);
 check('up velocity sign equation',abs(y(4)+[-sin(z(8)),sin(z(7))*cos(z(8)),cos(z(7))*cos(z(8))]*z(1:3))<1e-12,0);
 check('specific force excludes gravity',abs(y(6)-out.FaeroProp(3)/P.mass.m)<1e-12,0);
 check('inertial acceleration differs from body derivative by omega cross V', ...
  norm(out.inertialAccelerationBody-out.velocityDerivativeBody-cross(z(4:6),z(1:3)))<1e-12,0);
 % A true fixed-state load sensitivity, not merely target/state inequality.
 zp=z;zp(10:11)=zp(10:11)+.1;[dp,op,yp]=d02_rhs(zp,u,0,P,'dynamic');
 check('fixed-state inflow perturbs actual rotor loads',abs(sum(yp(7:8))-sum(y(7:8)))>1e-3,sum(yp(7:8))-sum(y(7:8)));
 check('transient is valid without claiming steady closure',op.evaluationValid&&op.dynamicDerivativeValid&&~op.steadyEquilibriumSatisfied,norm(dp(10:11)));
 check('state and target labelled separately',isequal(op.actualInducedVelocity,zp(10:11))&&norm(op.targetInducedVelocity-op.actualInducedVelocity)>1e-5,0);
 za=z;za(12)=za(12)+.1*pi/180;[~,~,ya]=d02_rhs(za,u,0,P,'dynamic');
 check('actual collective excitation changes thrust',sum(ya(7:8))>sum(y(7:8)),sum(ya(7:8))-sum(y(7:8)));
 za=z;za(13)=za(13)+.1*pi/180;[~,~,ya]=d02_rhs(za,u,0,P,'dynamic');
 check('actual cyclic excitation changes pitch moment',abs(ya(13)-y(13))>1e-3,ya(13)-y(13));
 % Existing no-override path equality and within-call load reuse equality.
 for k=1:3
  x=wp.trim.xTrim;if k==2,x(1)=.1;elseif k==3,x(5)=.001;end
  c=wp.trim.uTrim;
  [a,oa]=tiltrotor_eom(x,c,0,P);
  [b,ob]=legacy_d02_tiltrotor_eom(x,c,0,P);
  check(sprintf('legacy static exact identity %d',k),isequal(a,b)&&isequal(oa.FaeroProp,ob.FaeroProp)&&isequal(oa.Mtotal,ob.Mtotal),norm(a-b));
  vi=[oa.components.rotorLeft.inducedVelocity;oa.components.rotorRight.inducedVelocity];
  [a,oa]=tiltrotor_eom(x,c,0,P,vi);[b,ob]=legacy_d02_tiltrotor_eom(x,c,0,P,vi);
  check(sprintf('within-call reuse exact force identity %d',k),isequal(a,b)&&isequal(oa.FaeroProp,ob.FaeroProp)&&isequal(oa.Mtotal,ob.Mtotal),norm(a-b));
 end
 bad=P;bad.d02.inflowTimeConstant=0;expect(@()d02_rhs(z,u,0,bad,'dynamic'),'d02:InvalidTimeConstants');
 bad=P;bad.d02.actuatorTimeConstant=[.08;-.08;.08];expect(@()d02_rhs(z,u,0,bad,'dynamic'),'d02:InvalidTimeConstants');
 expect(@()d02_rhs(z,u,.1,P,'dynamic'),'d02:UnsupportedMode');
 badz=z;badz(10)=-1;expect(@()d02_rhs(badz,u,0,P,'dynamic'),'total_forces_moments:InvalidDynamicInflow');
 badz=z;badz(1)=NaN;expect(@()d02_rhs(badz,u,0,P,'dynamic'),'d02:InvalidState');
 badwp=wp;badwp.P.mass.m=badwp.P.mass.m+1;
 expect(@()run_d02_longitudinal_heave(struct('preparedWorkpoint',badwp),P),'d02:WorkpointMismatch');
 expect(@()run_d02_longitudinal_heave(struct('action','simulate','preparedWorkpoint',wp,'outputState',1.2),P),'d02:InvalidOutputState');
 % Two difference scales; raw directional derivatives retained to expose
 % any hover nonsmoothness rather than silently smoothing physical formulas.
 modes={'dynamic','quasisteady'};amps=[.2 .1];lin=cell(2,2);sim=cell(2,5);nonsmooth={};
 for modeIndex=1:2
  mode=modes{modeIndex};lin{modeIndex,1}=d02_linearize(wp,mode,1);lin{modeIndex,2}=d02_linearize(wp,mode,.5);
  l=lin{modeIndex,1};l2=lin{modeIndex,2};
  check([mode ' ABCD finite'],all(isfinite([l.A(:);l.B(:);l.C(:);l.D(:)])),0);
  for col=[1 2 3]
   for row=[1 3 5]
    a1=l.forwardA(row,col)-l.backwardA(row,col);a2=l2.forwardA(row,col)-l2.backwardA(row,col);
    nonsmooth(end+1,:)={mode,row,col,a1,a2,abs(a2)>1e-5&&abs(a2)>.8*abs(a1)};
   end
  end
  cfg=struct('channel',1,'amplitudeRad',0,'startTime',.5,'totalTime',3,'sampleTime',.05,'maxStep',.05,'storeComponents',true);
  sim{modeIndex,1}=d02_simulate(wp,mode,cfg);collectCost(sim{modeIndex,1},mode,'zero');checkpoint();
  for ch=1:2
   for ai=1:2
    ix=1+(ch-1)*2+ai;cfg.channel=ch;cfg.amplitudeRad=amps(ai)*pi/180;
    sim{modeIndex,ix}=d02_simulate(wp,mode,cfg);s=sim{modeIndex,ix};base=sim{modeIndex,1};
    collectCost(s,mode,sprintf('ch%d_%.1fdeg',ch,amps(ai)));
    dy=s.output-base.output;[linear,deltaState]=linear_step(l,s.time,cfg.startTime,ch,cfg.amplitudeRad);
    linear2=linear_step(l2,s.time,cfg.startTime,ch,cfg.amplitudeRad);
    active=s.time>=cfg.startTime;
    primary=5;if ch==2,primary=1;end
    for outIndex=1:numel(l.layout.outputNames)
     signal=dy(active,outIndex);err=signal-linear(active,outIndex);amp=sqrt(mean(signal.^2));abserr=sqrt(mean(err.^2));
     floor=1e-9;rel=NaN;if amp>floor,rel=abserr/amp;end
     stepDiff=sqrt(mean((linear2(active,outIndex)-linear(active,outIndex)).^2));stepRel=NaN;if amp>floor,stepRel=stepDiff/amp;end
     comparisons(end+1,:)={mode,ch,amps(ai),l.layout.outputNames{outIndex},amp,abserr,rel,stepDiff,stepRel,outIndex==primary};
    end
    amp=sqrt(mean(dy(active,primary).^2));err=sqrt(mean((dy(active,primary)-linear(active,primary)).^2));
    sd=sqrt(mean((linear2(active,primary)-linear(active,primary)).^2));
    check(sprintf('%s ch%d %.1fdeg effective excitation',mode,ch,amps(ai)),amp>1e-6,amp);
    check(sprintf('%s ch%d %.1fdeg primary linear agreement',mode,ch,amps(ai)),amp>1e-6&&err/amp<.05,err/max(amp,1e-12));
    check(sprintf('%s ch%d %.1fdeg derivative-step response',mode,ch,amps(ai)),amp>1e-6&&sd/amp<.02,sd/max(amp,1e-12));
    check(sprintf('%s ch%d actual/target trace validity',mode,ch),all(s.evaluationValid),sum(~s.evaluationValid));
    if strcmp(mode,'dynamic'),check('dynamic state-history equality',isequal(s.state(:,10:11),s.actualInflow),0);end
    s.linearOutput=linear;s.linearStateDelta=deltaState;sim{modeIndex,ix}=s;
    fprintf('SIM_DONE %s ch%d %.1fdeg primary NRMSE %.6g RHS%d ODE%.3fs\n',mode,ch,amps(ai),err/max(amp,1e-12),s.cost.rhsCalls,s.cost.odeSeconds);
    checkpoint();
   end
  end
 end
 records.linearizations=lin;records.simulations=sim;
 comparisonTable=cell2table(comparisons,'VariableNames',{'mode','inputChannel','amplitude_deg','output','nonlinearRMS','linearAbsoluteRMSerror', ...
 'linearRelativeRMSerror','differenceStepAbsoluteChange','differenceStepRelativeChange','primaryChannel'});
 % Perturbation refinement is assessed per chosen primary output, not all
 % near-zero cross-channels. Preserve other channels as descriptive evidence.
 for mi=1:2
  for ch=1:2
   mask=strcmp(comparisonTable.mode,modes{mi})&comparisonTable.inputChannel==ch&comparisonTable.primaryChannel;
   a=comparisonTable(mask,:);large=a.linearAbsoluteRMSerror(a.amplitude_deg==.2);small=a.linearAbsoluteRMSerror(a.amplitude_deg==.1);
   check(sprintf('%s ch%d amplitude refinement',modes{mi},ch),small<=.8*large+1e-8,small/max(large,1e-14));
  end
 end
 paired={};
 for k=2:5
  d=sim{1,k}.output-sim{1,1}.output;q=sim{2,k}.output-sim{2,1}.output;active=sim{1,k}.time>=.5;
  for j=1:size(d,2)
   paired(end+1,:)={sim{1,k}.config.channel,sim{1,k}.config.amplitudeRad*180/pi,md.outputNames{j}, ...
    sqrt(mean(d(active,j).^2)),sqrt(mean(q(active,j).^2)),sqrt(mean((d(active,j)-q(active,j)).^2)),max(abs(d(active,j)-q(active,j)))};
  end
 end
 pairedTable=cell2table(paired,'VariableNames',{'inputChannel','amplitude_deg','output','dynamicRMS','quasisteadyRMS','differenceRMS','differencePeak'});
 directional=cell2table(nonsmooth,'VariableNames',{'mode','rhsRow','stateColumn','forwardMinusBackwardAtH','forwardMinusBackwardAtHalfH','persistentMismatch'});
 records.comparisons=comparisonTable;records.paired=pairedTable;records.directional=directional;
 writetable(comparisonTable,fullfile(outputRoot,'LINEAR_NONLINEAR_COMPARISON.csv'));
 writetable(pairedTable,fullfile(outputRoot,'DYNAMIC_QUASISTEADY_COMPARISON.csv'));
 writetable(directional,fullfile(outputRoot,'DIRECTIONAL_DERIVATIVE_DIAGNOSTIC.csv'));
 for mi=1:2
  for k=1:5
   s=sim{mi,k};timeSeries=array2table([s.time,s.state,s.command,s.output,s.targetInflow], ...
    'VariableNames',[{'time_s'},strcat('state_',s.layout.stateNames),strcat('cmd_',s.layout.inputNames),strcat('out_',s.layout.outputNames),{'targetViLeft','targetViRight'}]);
   writetable(timeSeries,fullfile(outputRoot,sprintf('%s_case%d.csv',modes{mi},k)));
  end
 end
 meta.status='COMPLETED';meta.wholeJacobianDifferentiabilityProven=~any(directional.persistentMismatch);
 meta.linearQualification='PRIMARY_CHANNELS_CHECKED; DIRECTIONAL_AND_CROSS_CHANNEL_LIMITS_RETAINED';
catch ME
 meta.status='EXECUTION_FAILED';meta.failureIdentifier=ME.identifier;meta.failureMessage=ME.message;
 meta.failureStack=ME.stack;save_all();rethrow(ME);
end
save_all();disp(records.comparisons(records.comparisons.primaryChannel,:));disp(result.meta);
if ~result.meta.allChecksPassed,error('d02:VerificationFailed','See retained failed checks and raw records.');end
 function check(name,pass,value)
  checks(end+1,:)={name,logical(pass),value};fprintf('%s: %s (%.8g)\n',name,word(pass),value);
 end
 function expect(fun,id)
  try,fun();catch ME,check(['reject ' id],strcmp(ME.identifier,id),double(strcmp(ME.identifier,id)));return;end
  check(['reject ' id],false,0);
 end
 function collectCost(s,mode,name)
  c=s.cost;costRows(end+1,:)={mode,name,c.rhsCalls,c.odeSeconds,c.modelSeconds,c.flapSeconds,c.rotorSeconds, ...
   c.bladeLoadCalls,c.flapSolveCalls,c.diagnosticCalls,c.diagnosticSeconds,c.diagnosticBladeCalls};
 end
 function checkpoint()
  records.linearizations=lin;records.simulations=sim;save_all();
 end
 function save_all()
  meta.elapsed_s=toc(clock);meta.checkCount=size(checks,1);
  if isempty(checks),meta.allChecksPassed=false;else,meta.allChecksPassed=all(cell2mat(checks(:,2)));end
  result=struct('meta',meta,'records',records,'checks',{checks},'costRows',{costRows},'baseP',P0,'executionP',P);
  save(fullfile(outputRoot,'D02_CONSISTENCY_RESULTS.mat'),'result','-v7');
  if ~isempty(checks),T=cell2table(checks,'VariableNames',{'check','pass','value'});writetable(T,fullfile(outputRoot,'CHECKS.csv'));end
  if ~isempty(costRows),T=cell2table(costRows,'VariableNames',{'mode','case','rhsCalls','odeSeconds','modelSeconds','flapSeconds','rotorSeconds','bladeLoadCalls','flapSolveCalls','diagnosticCalls','diagnosticSeconds','diagnosticBladeCalls'});writetable(T,fullfile(outputRoot,'COST.csv'));end
  fid=fopen(fullfile(outputRoot,'RUN_MANIFEST.json'),'w');assert(fid>=0);cc=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear cc;
 end
end
function [y,states]=linear_step(l,t,startTime,ch,amp)
% Exact linear forced solution using an augmented matrix exponential;
% avoids inverting singular A (height/heading integrators are retained).
n=size(l.A,1);M=[l.A,l.B(:,ch)*amp;zeros(1,n+1)];states=zeros(numel(t),n);y=zeros(numel(t),size(l.C,1));
for k=1:numel(t)
 if t(k)>=startTime
  v=expm(M*(t(k)-startTime))*[zeros(n,1);1];states(k,:)=v(1:n).';y(k,:)=(l.C*v(1:n)+l.D(:,ch)*amp).';
 end
end
end
function w=word(b),if b,w='PASS';else,w='FAIL';end,end
