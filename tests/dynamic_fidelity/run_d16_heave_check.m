function results=run_d16_heave_check(outDir)
% Targeted conditional load-to-heave interface extension, not fixed-hub proof.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));addpath(fullfile(root,'analysis'),fullfile(root,'analysis/dynamic_fidelity'));
assert(~exist(outDir,'dir'));mkdir(outDir);p=d16_model(root,'V4');rho=1.225;m=6000;g=9.80665;H=2*rho*pi*p.R^2*p.V^2/m;
ct0=g/H;theta0=fzero(@(th)ppval(p.pp,th)-ct0,[p.theta(1),p.theta(end)]);l0=sqrt(ct0/2);k=128/(75*pi);
methods={'DIRECT','LUT','SCHEDULED_RHS'};traces=table();metrics=table();all={};t=(0:.005:4)';
for amp=[.1 .3]
 ref=[];
 for j=1:3
  method=methods{j};timer=tic;opts=odeset('RelTol',1e-8,'AbsTol',[1e-11 1e-9],'MaxStep',.02);
  [~,x]=ode45(@rhs,t,[l0;0],opts);a=zeros(size(t));ct=zeros(size(t));th=zeros(size(t));
  for i=1:numel(t),[~,a(i),ct(i),th(i)]=rhs(t(i),x(i,:)');end
  seconds=toc(timer);if j==1,ref=[x(:,2),a];end
  er=[norm(x(:,2)-ref(:,1))/norm(ref(:,1)),norm(a-ref(:,2))/norm(ref(:,2))];
  metrics=[metrics;table(amp,methods(j),er(1),er(2),seconds,'VariableNames',{'amplitude_deg','method','velocity_relative_RMSE','acceleration_relative_RMSE','single_run_seconds'})]; %#ok<AGROW>
  traces=[traces;table(repmat(amp,numel(t),1),repmat(methods(j),numel(t),1),t,th,x(:,1),x(:,2),a,ct,'VariableNames',{'amplitude_deg','method','time_s','theta_rad','lambda_induced','velocity_up_mps','acceleration_up_mps2','CT'})]; %#ok<AGROW>
  all{end+1}=struct('t',t,'x',x,'a',a,'CT',ct); %#ok<AGROW>
 end
end
writetable(metrics,fullfile(outDir,'HEAVE_METRICS.csv'));writetable(traces,fullfile(outDir,'HEAVE_TRACES.csv'));
[~,head]=system('git rev-parse HEAD');manifest=struct('identity','D16_V4_CONDITIONAL_TWO_STATE_HEAVE_EXTENSION','head',strtrim(head),'utc',char(datetime('now','TimeZone','UTC')),'matlab',version,'mass_kg',m,'rho',rho,'theta0_deg',theta0*180/pi,'memory','PP_only','new_external_dynamic_records',0,'fixed_hub_72_case_qualification_inherited',false);
fid=fopen(fullfile(outDir,'HEAVE_MANIFEST.json'),'w');fprintf(fid,'%s',jsonencode(manifest));fclose(fid);results=struct('manifest',manifest,'metrics',metrics,'traces',traces,'raw',{all});save(fullfile(outDir,'HEAVE_RESULTS.mat'),'results','-v7');disp(metrics);
 function [dx,a,ct,th]=rhs(time,state)
  if time>=1&&time<=3,pulse=.5*(1-cos(pi*(time-1)));else,pulse=0;end
  th=theta0+amp*pi/180*pulse;S=ppval(p.pp,th);ls=sqrt(S/2);nu=state(2)/p.V;e=state(1)+nu-ls;
  assert(all(isfinite(state))&&state(1)>0&&abs(e)<=.01);
  switch method
   case 'DIRECT',ct=S+d16_source(th,state(1)+nu,p)-d16_source(th,ls,p);
   case 'LUT',ct=S+p.table(th,e);
   case 'SCHEDULED_RHS',ct=S-interp1(p.bt,p.bv,th)*e;
  end
  assert(isfinite(ct)&&ct>0);a=H*ct-g;dx=[p.Omega/k*(ct-2*state(1)*(state(1)+nu));a];
 end
end
