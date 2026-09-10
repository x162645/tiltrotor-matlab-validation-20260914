function result=run_line_b_independent_rotor_regression(outputRoot)
%RUN_LINE_B_INDEPENDENT_ROTOR_REGRESSION Reuse 27 external hover records.
% Test the EXACT backend used by V5, not a new copied rotor implementation.
% Inherited set: OARF Run15 6:11, Run14 6:11, WADC Runs1:3 [6,8,9,10,11].
% Sources and old environment contract are unchanged. aSound=340; rho/g and
% blade-mass assumptions remain inherited and are explicitly not test facts.
% This is post-development regression, NOT a new blind/holdout designation.
% Model source aa0b73d; no new solver, tolerance, geometry, target gain or fit.
if nargin<1,outputRoot=fullfile(pwd,'ci_artifacts','rotor_regression');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
[Pbase,unused]=base_parameters(); %#ok<ASGLU>
D=table();
files={'analysis/run_m1_stage3_corrigan_stall_delay.m','analysis/run_xv15_v1_run14_external_validation.m'};
names={'OARF_RUN15','OARF_RUN14'};
for j=1:2
 path=fullfile(root,files{j});s=fileread(path);
 pitch=read_vector(s,'collective75_deg');vtip=read_vector(s,'Vtip_fps');
 ct=read_vector(s,'CT_exp');cp=read_vector(s,'CP_exp');fm=read_vector(s,'FM_exp');
 assert(numel(pitch)==numel(vtip)&&numel(pitch)==numel(ct)&&numel(pitch)==numel(cp)&&numel(pitch)==numel(fm));
 keep=pitch>=6&pitch<=11;assert(isequal(pitch(keep),(6:11).'));
 n=sum(keep);one=table(repmat(names(j),n,1),pitch(keep),vtip(keep),ct(keep),cp(keep),fm(keep), ...
  repmat(files(j),n,1),nan(n,1),nan(n,1),'VariableNames', ...
  {'dataset','theta75_deg','Vtip_fps','CT_exp','CP_exp','FM_exp','sourceCarrier','sourceRun','sourcePoint'});
 D=[D;one]; %#ok<AGROW>
end
wf='analysis/data/xv15_wadc_metal_table_a3.csv';W=readtable(fullfile(root,wf));
W=W(ismember(W.run,1:3)&W.collective75_deg>=6&W.collective75_deg<=11,:);
assert(height(W)==15);for j=1:3,assert(isequal(W.collective75_deg(W.run==j),[6;8;9;10;11]));end
for k=1:height(W)
 D=[D;table({sprintf('WADC_RUN%d',W.run(k))},W.collective75_deg(k),W.Vtip_fps(k),W.CT_exp(k),W.CP_exp(k),W.FM_exp(k), ...
  {wf},W.run(k),W.point(k),'VariableNames',D.Properties.VariableNames)]; %#ok<AGROW>
end
assert(height(D)==27);writetable(D,fullfile(outputRoot,'EXTERNAL_CASE_MANIFEST.csv'));
rows={};records=cell(27,2);models={'LEGACY_M1','V4_CONTINUOUS'};t0=tic;
for k=1:height(D)
 for im=1:2
  P=Pbase;vtip=D.Vtip_fps(k)*.3048;P.rotor.Omega=vtip/P.rotor.R;
  if im==2,P.rotor.correctionIdentity='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4';end
  theta75=D.theta75_deg(k)*pi/180;
  ctrl=struct('collective',theta75-P.rotor.twistTip*(.75-P.rotor.rootCut)/(1-P.rotor.rootCut),'cyclicLong',0);
  ok=false;returned=false;err='';msg='';T=NaN;Q=NaN;CT=NaN;CP=NaN;FM=NaN;
  ac=NaN;mc=NaN;closure=NaN;iter=NaN;actualModel='';o=struct();
  try
   [F,M,o]=m1_evidence_v1_forward_rotor(zeros(9,1),ctrl,0,-1,zeros(3,1),P);
   returned=true;T=o.thrust;Q=o.torque;
   ok=o.physicalConverged&&o.physicalBranchSupported&&isreal([F;M;T;Q])&&all(isfinite([F;M;T;Q]));
   CT=T/(P.env.rho*pi*P.rotor.R^2*vtip^2);CP=Q*P.rotor.Omega/(P.env.rho*pi*P.rotor.R^2*vtip^3);
   if CT>0&&CP>0,FM=CT^1.5/(sqrt(2)*CP);end
   ac=o.alphaClampCount;mc=o.machClampCount;closure=o.inducedClosureResidualRelative;iter=o.iterations;
   actualModel=o.modelId;
   if im==2,assert(strcmp(o.correctionIdentity,'CORRIGAN_POSITIVE_LIFT_WASHOUT_V4'));end
   assert(abs(o.theta75-theta75)<1e-13,'Physical collective mapping mismatch.');
   if ~ok,err=o.physicalStatus;end
  catch ME
   ok=false;err=ME.identifier;msg=ME.message;
  end
  records{k,im}=struct('P',P,'control',ctrl,'out',o,'errorIdentifier',err,'errorMessage',msg);
  rows(end+1,:)={k,D.dataset{k},D.theta75_deg(k),D.Vtip_fps(k),models{im},actualModel,returned,ok,T,Q, ...
   D.CT_exp(k),CT,100*(CT-D.CT_exp(k))/D.CT_exp(k),D.CP_exp(k),CP,100*(CP-D.CP_exp(k))/D.CP_exp(k), ...
   D.FM_exp(k),FM,100*(FM-D.FM_exp(k))/D.FM_exp(k),closure,iter,ac,mc,P.env.rho,P.env.aSound,err,msg}; %#ok<AGROW>
 end
end
A=cell2table(rows,'VariableNames',{'caseIndex','dataset','theta75_deg','Vtip_fps','requestedModel','actualModel', ...
 'returned','physicallySupported','thrust_N','torque_Nm','CT_exp','CT','CT_error_pct','CP_exp','CP','CP_error_pct', ...
 'FM_exp','FM','FM_error_pct','closureRelative','iterations','alphaClampCount','machClampCount', ...
 'rho_kg_m3','aSound_mps','errorIdentifier','errorMessage'});
writetable(A,fullfile(outputRoot,'EXTERNAL_ROTOR_POINTS.csv'));
% All candidate records retained; incomplete groups have no pooled score.
groups=[names,{'WADC_RUN1','WADC_RUN2','WADC_RUN3','WADC_ALL'}];mr={};
for j=1:numel(groups)
 for im=1:2
  mask=strcmp(A.requestedModel,models{im});
  if strcmp(groups{j},'WADC_ALL'),mask=mask&startsWith(A.dataset,'WADC_');else,mask=mask&strcmp(A.dataset,groups{j});end
  B=A(mask,:);complete=all(B.physicallySupported)&&all(isfinite([B.CT;B.CP;B.FM]));scores=nan(1,6);
  if complete,scores=[mean(abs(B.CT_error_pct)),mean(abs(B.CP_error_pct)),mean(abs(B.FM_error_pct)), ...
    mean(B.CT_error_pct),mean(B.CP_error_pct),mean(B.FM_error_pct)];end
  mr(end+1,:)=[{groups{j},models{im},height(B),sum(B.physicallySupported),complete},num2cell(scores)]; %#ok<AGROW>
 end
end
metrics=cell2table(mr,'VariableNames',{'dataset','model','expectedCount','supportedCount','complete', ...
 'CT_MAPE_pct','CP_MAPE_pct','FM_MAPE_pct','CT_meanSigned_pct','CP_meanSigned_pct','FM_meanSigned_pct'});
writetable(metrics,fullfile(outputRoot,'EXTERNAL_ROTOR_METRICS.csv'));
old=A(strcmp(A.requestedModel,models{1}),:);new=A(strcmp(A.requestedModel,models{2}),:);
assert(isequal(old.caseIndex,new.caseIndex));paired=old.physicallySupported&new.physicallySupported;
diffTable=table(old.caseIndex,old.dataset,old.theta75_deg,paired,new.CT-old.CT,new.CP-old.CP,new.FM-old.FM, ...
 'VariableNames',{'caseIndex','dataset','theta75_deg','pairSupported','dCT','dCP','dFM'});
writetable(diffTable,fullfile(outputRoot,'V4_MINUS_LEGACY.csv'));
% Reuse archived identity carrier, not rerun all historical model ladders.
old15=old(strcmp(old.dataset,'OARF_RUN15'),:);
I=readtable(fullfile(root,'results','m1_stage5_wadc_holdout','M1_STAGE5_M1_IDENTITY_EQUIVALENCE.csv'));
assert(isequal(old15.theta75_deg,I.collective75_deg));
idDiff=max(abs([old15.CT-I.CT_stage3;old15.CP-I.CP_stage3;old15.FM-I.FM_stage3]));
[~,head]=system('git rev-parse HEAD');
meta=struct('identity','V4_EXTERNAL_HOVER_REGRESSION_27_CASES','head',strtrim(head), ...
 'version',version,'release',version('-release'),'elapsed_s',toc(t0),'expectedCases',27,'rotorCalls',54, ...
 'allLegacySupported',all(old.physicallySupported),'allV4Supported',all(new.physicallySupported), ...
 'archivedOarfIdentityMaxAbsDifference',idDiff,'archivedOarfIdentityPassed',isfinite(idDiff)&&idDiff<1e-10, ...
 'maxAbsV4minusLegacyCT',max(abs(diffTable.dCT(paired))),'maxAbsV4minusLegacyCP',max(abs(diffTable.dCP(paired))), ...
 'oldM1HoldoutStatusNotReassigned',true,'noRetuning',true,'newTrimSearches',0,'solverChanged',false, ...
 'datasetRole','EXISTING_PHYSICAL_EXPERIMENTS_POSTDEVELOPMENT_REGRESSION_NOT_NEW_BLIND_TEST', ...
 'inputCaveat','Historical generic rho/g/aSound/blade inertia contract retained; WADC facility caveats retained', ...
 'wholeAircraftExternalPass',false);
result=struct('meta',meta,'cases',D,'points',A,'metrics',metrics,'difference',diffTable,'records',{records});
save(fullfile(outputRoot,'EXTERNAL_ROTOR_RESULTS.mat'),'result');
fid=fopen(fullfile(outputRoot,'EXTERNAL_ROTOR_MANIFEST.json'),'w');assert(fid>=0);cl=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta));clear cl;
disp(metrics);disp(meta);
assert(meta.archivedOarfIdentityPassed,'Legacy backend does not reproduce archived OARF identity; do not reuse old labels.');
end
function [P,meta]=base_parameters()
P=stage2_matched_rotor_parameters();P.env.aSound=340;P.rotor.flapInitial=zeros(3,1);
meta='EXACT_HISTORICAL_COMPONENT_INPUT_CONTRACT_NO_AIRFRAME_SOURCE_OVERRIDES';
end
function v=read_vector(s,name)
% Read ONLY literal numeric assignment arrays from already tracked carriers.
t=regexp(s,['(?m)^' name '\s*=\s*\[([^\]]+)\]'],'tokens','once');assert(~isempty(t),['Missing literal source array ' name]);
a=strrep(t{1},'...',' ');assert(isempty(regexp(a,'[^0-9eE+.;,\s-]','once')),'Nonliteral source vector.');
nums=regexp(a,'[+-]?(?:\d*\.?\d+)(?:[eE][+-]?\d+)?','match');v=str2double(nums(:));
assert(~isempty(v)&&all(isfinite(v)),'Bad numeric source vector.');
end
