function result=run_d13_api_readback(outDir)
% Targeted new public API check. Reuses D13 outputs, no trajectory reruns.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'model','dynamic_fidelity'));
assert(~exist(outDir,'dir'));mkdir(outDir);tic;
base=fullfile(root,'docs','research','dynamic_fidelity');
static=fullfile(base,'evidence_d11','channel','data','OARF_RUN15_EXISTING_STATIC_POINTS.csv');
native=fullfile(base,'evidence_d13','runs','34647299470','native');
trace=readtable(fullfile(native,'DYNAMIC_TRACES.csv'));field=readtable(fullfile(native,'INDEPENDENT_GRID_QUERIES.csv'));
res=table();
for mode=1:2
 names={'CLASSICAL_LUT_COARSE','CLASSICAL_LUT_FINE'};fn={'LOAD_TABLE_21_41.csv','LOAD_TABLE_41_81.csv'};
 P=d13_load_table_model(static,fullfile(native,fn{mode}),'PP_mean');
 row=strcmp(trace.method,names{mode});T=trace(row,:);err=zeros(height(T),3);
 for i=1:height(T)
  x=[T.vi_mps(i);T.v_up_mps(i)];[~,y]=d13_hover_load_table_rhs(x,T.theta_report_deg(i)*pi/180,P);
  err(i,:)=y'-[T.v_up_mps(i),T.a_up_mps2(i),T.total_aero_thrust_N(i)];
 end
 maxError=max(abs(err));assert(maxError(1)<1e-12&&maxError(2)<1e-10&&maxError(3)<1e-6);
 fieldDiff=max(abs(P.increment(field.theta_rad,field.e)-field.(names{mode})));assert(fieldDiff<2e-12);
 [dx,~,~]=d13_hover_load_table_rhs(P.x0,P.theta0,P);assert(max(abs(dx))<1e-9);
 for th=linspace(P.thetaDomain(1),P.thetaDomain(2),17)
  S=ppval(P.S,th);[~,~,d]=d13_hover_load_table_rhs([P.Vtip*sqrt(S/2);0],th,P);assert(abs(d.CT-S)<1e-14);
 end
 rejected=0;
 for bad=1:3
  try
   if bad==1,d13_hover_load_table_rhs(P.x0,P.thetaDomain(1)-.001,P);
   elseif bad==2,d13_hover_load_table_rhs(P.x0+[P.Vtip*.011;0],P.theta0,P);
   else,d13_hover_load_table_rhs([NaN;0],P.theta0,P);end
  catch,rejected=rejected+1;end
 end
 assert(rejected==3);
 res=[res;table(names(mode),height(T),maxError(1),maxError(2),maxError(3),fieldDiff,rejected, ...
 'VariableNames',{'method','original_trace_rows','velocity_diff','acceleration_diff','force_diff_N','field_diff_CT','invalid_inputs_rejected'})]; %#ok<AGROW>
end
result=struct('status','EXECUTED_API_REQUIRES_EXTERNAL_READBACK','version',version,'computer',computer, ...
 'execution_commit',getenv('GITHUB_SHA'),'run_id',getenv('GITHUB_RUN_ID'),'elapsed_seconds',toc, ...
 'science_source_run',34647299470,'new_ODE_trajectories',0,'passed',true,'rows',res);
save(fullfile(outDir,'API_READBACK.mat'),'result');writetable(res,fullfile(outDir,'API_READBACK.csv'));
r=rmfield(result,'rows');f=fopen(fullfile(outDir,'API_MANIFEST.json'),'w');fprintf(f,'%s',jsonencode(r));fclose(f);disp(res);
end
