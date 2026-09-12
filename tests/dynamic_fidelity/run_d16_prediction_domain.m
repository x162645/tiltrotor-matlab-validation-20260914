function results=run_d16_prediction_domain(outDir,scope)
% New D16 numerical study. Does not execute historical suites.
if nargin<2,scope='full';end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'analysis'),fullfile(root,'analysis/dynamic_fidelity'));
assert(~exist(outDir,'dir'),'Use a new output directory');mkdir(outDir);started=tic;
p=d16_model(root,'V4');kvals=[128/(75*pi),.637*4/3];memories={'PP','CF'};
methods={'DIRECT','LUT','LTI_EXACT','SCHEDULED_EXACT','QS'};
% Targeted numerical identity with D13 source at its canonical workpoint.
off=d16_model(root,'OFF',128,false);old=readtable(fullfile(root,'docs/research/dynamic_fidelity/evidence_d13/runs/34647299470/native/OPERATING_DERIVATIVES.csv'));
rows=old(old.points_per_segment==128&abs(old.derivative_step-1e-5)<1e-12,:);err=[];
for i=1:height(rows)
 th=rows.theta_report_deg(i)*pi/180;ls=sqrt(ppval(off.pp,th)/2);
 err(end+1)=abs(d16_source(th,ls,off)-rows.raw_CT(i)); %#ok<AGROW>
end
assert(max(err)<1e-12,'D13 OFF source identity changed');
% Representative software checks before the declared expansion.
r=d16_predict(p,8.5,.1,.5,kvals(1),'DIRECT');
rTight=d16_predict(p,8.5,.1,.5,kvals(1),'DIRECT',.002,1e-10);
integ=max(abs(r.CT-rTight.CT));assert(integ<1e-7,'Integration check failed');
fine=d16_model(root,'V4',256,false);
quad=abs(d16_source(8.5*pi/180,sqrt(ppval(p.pp,8.5*pi/180)/2),p)-d16_source(8.5*pi/180,sqrt(ppval(p.pp,8.5*pi/180)/2),fine));
metrics=table();traces=table();caseSpec=table();allOut={};failures=table();count=0;
if strcmp(scope,'representative'),centers=8.5;amps=.1;durations=.5;memoryIds=1;
else,assert(strcmp(scope,'full'));centers=[7 8.5 10];amps=[-.3 -.1 .1 .3];durations=[.1 .5 2];memoryIds=1:2;end
for center=centers
 for amp=amps
  for dur=durations
   for im=memoryIds
    count=count+1;caseSpec=[caseSpec;table(count,center,amp,dur,kvals(im),memories(im),'VariableNames',{'case_id','theta0_deg','amplitude_deg','duration_s','k','memory'})]; %#ok<AGROW>
    ref=[];
    for iz=1:numel(methods)
     method=methods{iz};timer=tic;
     try
      o=d16_predict(p,center,amp,dur,kvals(im),method);seconds=toc(timer);
      if iz==1,ref=o;end
      den=sqrt(mean(ref.non_eq_CT.^2));den2=sqrt(mean(ref.delta_CT.^2));assert(den>1e-12&&den2>1e-12);
      dif=o.CT-ref.CT;rel=sqrt(mean(dif.^2))/den;
      peakDifference=(max(abs(o.non_eq_CT))-max(abs(ref.non_eq_CT)))/max(abs(ref.non_eq_CT));
      metrics=[metrics;table(count,methods(iz),rel,sqrt(mean(dif.^2))/den2,peakDifference,seconds, ...
       'VariableNames',{'case_id','method','nonequilibrium_relative_RMSE','delta_CT_relative_RMSE','nonequilibrium_peak_relative_difference','single_run_seconds'})]; %#ok<AGROW>
      traces=[traces;table(repmat(count,numel(o.t),1),repmat(methods(iz),numel(o.t),1),o.t,o.theta_rad,o.lambda,o.CT,o.S,o.non_eq_CT, ...
       'VariableNames',{'case_id','method','time_s','theta_rad','lambda','CT','S','non_eq_CT'})]; %#ok<AGROW>
      allOut{count,iz}=o;
     catch exception
      failures=[failures;table(count,methods(iz),{exception.identifier},{exception.message},'VariableNames',{'case_id','method','identifier','message'})]; %#ok<AGROW>
      if iz==1,rethrow(exception);end
     end
    end
   end
  end
 end
 fprintf('D16 completed center %.1f: %d cases\n',center,count);
end
writetable(caseSpec,fullfile(outDir,'CASES.csv'));writetable(metrics,fullfile(outDir,'METRICS.csv'));
writetable(traces,fullfile(outDir,'TRACES.csv'));
if ~isempty(failures),writetable(failures,fullfile(outDir,'FAILURES.csv'));end
% Local derivative hypotheses; not a continuous uncertainty enclosure.
sens=table();sources={'OFF','V4','LEGACY_N1'};sourceModels={off,p,d16_model(root,'LEGACY_N1',128,false)};
freq=table();omega=logspace(log10(.1),log10(100),121);
for is=1:3
 pp=sourceModels{is};
 for center=[7 8.5 10]
  th=center*pi/180;S=ppval(p.pp,th);ls=sqrt(S/2);sd=ppval(p.dp,th);
  for shift=[-1 0 1]
   actual=th+shift*pi/180;B=d16_source(actual,ls,pp);
   for h=[1e-5 5e-6]
    b=-(d16_source(actual,ls+h,pp)-d16_source(actual,ls-h,pp))/(2*h);
    sens=[sens;table(sources(is),center,shift,h,S,B,(B-S)/S,b,'VariableNames',{'source','theta_report_deg','offset_deg','derivative_step','S','raw_B','raw_B_minus_S_relative','b'})]; %#ok<AGROW>
    if h==1e-5
     a=sd*(1+b/(4*ls));
     for im=1:2
      Q=p.Omega/kvals(im);z=1i*omega;G=a*(z+4*Q*ls)./(z+Q*(b+4*ls));
      freq=[freq;table(repmat(sources(is),numel(omega),1),repmat(center,numel(omega),1),repmat(shift,numel(omega),1),repmat(memories(im),numel(omega),1), ...
       omega',real(G)',imag(G)',repmat(sd,numel(omega),1),'VariableNames',{'source','theta_report_deg','offset_deg','memory','omega_rad_s','G_real_CT_per_rad','G_imag_CT_per_rad','static_slope_CT_per_rad'})]; %#ok<AGROW>
     end
    end
   end
  end
 end
end
writetable(sens,fullfile(outDir,'SOURCE_HYPOTHESES.csv'));writetable(freq,fullfile(outDir,'CONDITIONAL_FRF.csv'));
% Six nonlinear mechanism ablations, same source/input/memory allocation.
ablation=table();
for center=[7 8.5 10]
 for im=1:2
  v=d16_predict(p,center,.3,.1,kvals(im),'DIRECT');o=d16_predict(off,center,.3,.1,kvals(im),'DIRECT');
  ablation=[ablation;table(repmat(center,numel(v.t),1),repmat(memories(im),numel(v.t),1),v.t,v.CT,o.CT,v.non_eq_CT,o.non_eq_CT, ...
   'VariableNames',{'theta0_deg','memory','time_s','V4_CT','OFF_CT','V4_non_eq_CT','OFF_non_eq_CT'})]; %#ok<AGROW>
 end
end
writetable(ablation,fullfile(outDir,'MECHANISM_ABLATION.csv'));
% Repeated complete prediction timing; each method returns identical fields.
cost=table();
for iz=1:numel(methods)
 warm=d16_predict(p,8.5,.3,.5,kvals(1),methods{iz}); %#ok<NASGU>
 for rep=1:7
  timer=tic;o=d16_predict(p,8.5,.3,.5,kvals(1),methods{iz});seconds=toc(timer);
  cost=[cost;table(methods(iz),rep,seconds,sum(o.CT),numel(o.t),'VariableNames',{'method','repeat','seconds','checksum','query_count'})]; %#ok<AGROW>
 end
end
writetable(cost,fullfile(outDir,'FULL_PREDICTION_COST.csv'));
[tt,ee]=ndgrid(p.table_theta,p.table_e);writetable(table(tt(:),ee(:),p.table_values(:),'VariableNames',{'theta_rad','e','delta_CT'}),fullfile(outDir,'V4_LOAD_TABLE_21_41.csv'));
[status,head]=system('git rev-parse HEAD');assert(status==0);
manifest=struct('identity','D16_NEW_FIXED_HUB_CONDITIONAL_PREDICTION','utc',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss')),'head',strtrim(head),'matlab',version,'computer',computer,'scope',scope, ...
 'cases',count,'methods',{methods},'D13_OFF_identity_max_CT_difference',max(err),'integration_tightening_max_CT_difference',integ,'radial128_256_anchor_CT_difference',quad, ...
 'table_build_seconds',p.table_build_seconds,'tangent_build_seconds',p.tangent_build_seconds,'total_seconds',toc(started),'failure_count',height(failures),'new_external_dynamic_records',0,'source_dynamic_validated',false,'threshold_role','1_percent_non_equilibrium_numerical_demo_budget_not_aircraft_standard');
fid=fopen(fullfile(outDir,'NATIVE_MANIFEST.json'),'w');fprintf(fid,'%s',jsonencode(manifest));fclose(fid);
results=struct('manifest',manifest,'metrics',metrics,'cases',caseSpec,'traces',traces,'outputs',{allOut},'source_hypotheses',sens,'frequency',freq,'ablation',ablation,'cost',cost,'failures',failures);
save(fullfile(outDir,'D16_RESULTS.mat'),'results','-v7');
disp(manifest);
end
