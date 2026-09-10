function result=run_line_b_betzina_regression(outputRoot,sourceRoot)
%RUN_LINE_B_BETZINA_REGRESSION Reuse pinned existing forward validation.
% Source tree 1c4ebc307717bbd74ad22da66ed8dfbdc3001395, no branch merge.
% 12 primary Fig16 points and 12 SECONDARY Fig18 points stay separate.
% Archived MODEL controls are initial states. Only CT and first-harmonic
% flapping define operating constraints; experimental torque NEVER does.
% The immutable source adapter is copied only to change its function name
% and its section-lookup target to the current V4 helper. The existing
% operating solver is copied only to point to that adapter. No numerics fit.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
src=fullfile(sourceRoot,'analysis','validation_betzina2002');
gen=fullfile(outputRoot,'generated');if ~exist(gen,'dir'),mkdir(gen);end
adapter=fileread(fullfile(src,'betzina2002_two_cyclic_rotor.m'));
assert(numel(strfind(adapter,'xv15_c81_corrigan_stall_delay('))==1);
v4=strrep(adapter,'betzina2002_two_cyclic_rotor','betzina_v4_regression_adapter');
v4=strrep(v4,'xv15_c81_corrigan_stall_delay(','xv15_c81_corrigan_continuous_v4(');
v4=strrep(v4,"out.modelId='M1_EVIDENCE_V1_FORWARD_PROPAGATION_TWO_CYCLIC_DIAGNOSTIC';", ...
 "out.modelId='V4_TWO_CYCLIC_REGRESSION_ADAPTER';");
write_text(fullfile(gen,'betzina_v4_regression_adapter.m'),v4);
solver=fileread(fullfile(src,'solve_betzina2002_operating_state.m'));
solver=strrep(solver,'solve_betzina2002_operating_state','solve_betzina_v4_regression');
solver=strrep(solver,'betzina2002_two_cyclic_rotor','betzina_v4_regression_adapter');
write_text(fullfile(gen,'solve_betzina_v4_regression.m'),solver);
addpath(src);addpath(gen);cleanup=onCleanup(@()remove_paths(src,gen));rehash;
P=stage2_matched_rotor_parameters();P.rotor.Omega=.691*P.env.aSound/P.rotor.R;sigma=.089;
% Same 3 zero-lateral-cyclic points as the original identity gate, old AND V4.
mu=[.125 .15 .20];th=[1.8464 3.6963 3.3244];cy=[-.42422 -1.1902 -1.5296];ir={};
for im=1:2
 for k=1:3
  Q=P;if im==2,Q.rotor.correctionIdentity='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4';end
  x=zeros(9,1);tip=Q.rotor.Omega*Q.rotor.R;x(1)=mu(k)*tip;
  ctrl=struct('collective',th(k)*pi/180-Q.rotor.twistTip*(.75-Q.rotor.rootCut)/(1-Q.rotor.rootCut),'cyclicLong',cy(k)*pi/180);
  [~,~,direct]=m1_evidence_v1_forward_rotor(x,ctrl,0,1,zeros(3,1),Q);
  if im==1,e=betzina2002_two_cyclic_rotor(P,mu(k),0,th(k),cy(k),0);else,e=betzina_v4_regression_adapter(P,mu(k),0,th(k),cy(k),0);end
  delta=[e.thrust-direct.thrust;e.torque-direct.torque;e.inducedVelocity-direct.inducedVelocity;e.beta0-direct.beta0;e.beta1c-direct.beta1c;e.beta1s-direct.beta1s];
  passed=direct.physicalConverged&&e.physicalConverged&&max(abs(delta))<1e-8;
  ir(end+1,:)={im,mu(k),max(abs(delta)),passed}; %#ok<AGROW>
 end
end
I=cell2table(ir,'VariableNames',{'variant','mu','maxAbsDimensionalDifference','passed'});
writetable(I,fullfile(outputRoot,'FORWARD_BACKEND_IDENTITY.csv'));
assert(all(I.passed),'Forward adapter not equivalent to actual backend at zero lateral cyclic.');
A=readtable(fullfile(src,'evidence','BETZINA2002_FAST_LM_PREDICTIONS.csv'));
E=readtable(fullfile(src,'data','BETZINA2002_FIG16_CURRENT_TEST_DIGITIZATION.csv'));
B=readtable(fullfile(src,'evidence','BETZINA2002_MU017_REPRESENTATIVE_LOAD_SWEEP_POINTS.csv'));
assert(height(A)==12&&height(E)==12&&height(B)==12);
rows={};records=cell(24,1);count=0;solveCount=0;t0=tic;
for dataset=1:2
 if dataset==1,N=A;else,N=B;end
 for k=1:height(N)
  count=count+1;a=N.alpha_exp_deg(k);m=N.advance_ratio(k);z=[N.theta75_deg(k),N.cyclicLong_deg(k),N.cyclicLat_deg(k)];
  if dataset==1
   target=.075*sigma;ix=find(E.alpha_exp_deg==a&abs(E.advance_ratio-m)<1e-12);assert(isscalar(ix));
   obs=E.CQ_over_sigma_exp(ix);band=E.digitization_halfwidth(ix);role='PRIMARY_FIG16_CURRENT_TEST_DIGITIZATION';
  else
   target=N.target_CT_over_sigma(k)*sigma;obs=N.CQ_over_sigma_exp_digitized(k);band=N.digitization_halfwidth_CQ_over_sigma(k);
   role='SECONDARY_FIG18_REPLOT_DIGITIZATION_NOT_RAW_NASA';
  end
  old=betzina2002_two_cyclic_rotor(P,m,a,z(1),z(2),z(3));
  new=betzina_v4_regression_adapter(P,m,a,z(1),z(2),z(3));initialNew=new;newz=z;
  oldok=valid(old,target);newok=valid(new,target);retried=false;report=struct('iterations',0,'residualNorm',NaN);
  if ~newok
   solveCount=solveCount+1;retried=true;[newz,new,report]=solve_betzina_v4_regression(P,m,a,target,z);newok=valid(new,target);
  end
  legacyDiff=old.CQ/sigma-N.CQ_over_sigma_model(k);
  rows(end+1,:)={dataset,role,a,m,target/sigma,oldok,newok,retried,newz(1),newz(2),newz(3),old.CQ/sigma,new.CQ/sigma,obs, ...
   old.CQ/sigma-obs,new.CQ/sigma-obs,band,abs(old.CQ/sigma-obs)<=band,abs(new.CQ/sigma-obs)<=band, ...
   new.CT/sigma,new.beta1cDeg,new.beta1sDeg,legacyDiff,old.alphaClampCount,new.alphaClampCount, ...
   new.machClampCount,new.physicalStatus,report.iterations}; %#ok<AGROW>
  records{count}=struct('old',old,'newAtOldControls',initialNew,'new',new,'controls',newz,'operatingReport',report);
 end
end
R=cell2table(rows,'VariableNames',{'datasetCode','evidenceRole','shaftAngle_deg','advanceRatio','targetCT_over_sigma', ...
 'oldOperatingAccepted','v4OperatingAccepted','requiredOperatingResolve','theta75_deg','cyclicLong_deg','cyclicLat_deg', ...
 'legacyCQ_over_sigma','v4CQ_over_sigma','experimentCQ_over_sigma','legacyError','v4Error','digitizationHalfwidth', ...
 'legacyWithinBand','v4WithinBand','v4CT_over_sigma','v4Beta1c_deg','v4Beta1s_deg','legacyArchiveDifference', ...
 'oldAlphaClampCount','newAlphaClampCount','newMachClampCount','newPhysicalStatus','resolveIterations'});
writetable(R,fullfile(outputRoot,'FORWARD_EXTERNAL_REGRESSION_POINTS.csv'));
srows={};
for ds=1:2
 angles=unique(R.shaftAngle_deg(R.datasetCode==ds));angles=[angles;NaN];
 for a=angles.'
  mask=R.datasetCode==ds;if isfinite(a),mask=mask&R.shaftAngle_deg==a;end
  S=R(mask,:);complete=all(S.oldOperatingAccepted&S.v4OperatingAccepted);vals=nan(1,4);
  if complete,vals=[mean(abs(S.legacyError)),mean(abs(S.v4Error)),max(abs(S.v4Error)),max(abs(S.v4CQ_over_sigma-S.legacyCQ_over_sigma))];end
  srows(end+1,:)=[{ds,a,height(S),sum(S.v4OperatingAccepted),complete},num2cell(vals),{sum(S.legacyWithinBand&S.oldOperatingAccepted),sum(S.v4WithinBand&S.v4OperatingAccepted)}]; %#ok<AGROW>
 end
end
S=cell2table(srows,'VariableNames',{'datasetCode','shaftAngle_deg','expectedCount','v4AcceptedCount','complete', ...
 'legacyMAE_CQ_over_sigma','v4MAE_CQ_over_sigma','v4MaxAbsError','maxAbsV4minusLegacy','legacyWithinBand','v4WithinBand'});
writetable(S,fullfile(outputRoot,'FORWARD_EXTERNAL_REGRESSION_METRICS.csv'));
[~,head]=system('git rev-parse HEAD');
meta=struct('identity','V4_BETZINA_EXISTING_24_CASE_REGRESSION','head',strtrim(head),'sourceCommit','1c4ebc307717bbd74ad22da66ed8dfbdc3001395', ...
 'version',version,'release',version('-release'),'cases',24,'zeroLateralIdentityCases',6,'initialOperatingEvaluations',48, ...
 'additionalOperatingSolves',solveCount,'allV4OperatingAccepted',all(R.v4OperatingAccepted), ...
 'legacyArchiveMaxAbsCQoverSigmaDifference',max(abs(R.legacyArchiveDifference)), ...
 'elapsed_s',toc(t0),'torqueIncludedInOperatingResidual',false,'solverSettingsChanged',false,'targetFitting',false, ...
 'wholeAircraftExternalPass',false,'independence','EXISTING_EXPERIMENT_REGRESSION_NOT_NEW_BLIND_TEST', ...
 'limitations','Primary Fig16 and secondary replot kept separate; RTA delta3 mismatch and polar clipping remain.');
result=struct('meta',meta,'identity',I,'points',R,'metrics',S,'records',{records},'P',P);
save(fullfile(outputRoot,'FORWARD_EXTERNAL_REGRESSION.mat'),'result');
write_text(fullfile(outputRoot,'FORWARD_EXTERNAL_REGRESSION_MANIFEST.json'),jsonencode(meta));disp(S);disp(meta);
assert(meta.legacyArchiveMaxAbsCQoverSigmaDifference<1e-10,'Old forward adapter drifted from archived predictions.');
end
function tf=valid(e,target)
tf=e.physicalConverged&&isfinite(e.CQ)&&abs(e.CT-target)/target<=.005&&abs(e.beta1cDeg)<=.1&&abs(e.beta1sDeg)<=.1;
end
function write_text(p,t),fid=fopen(p,'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,t,'char');end
function remove_paths(a,b),rmpath(a);rmpath(b);end
