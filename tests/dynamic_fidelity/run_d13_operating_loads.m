function result=run_d13_operating_loads(outDir)
% D13 only. Static-anchored source load increments, not validated XV15 flight.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'analysis'));
assert(~exist(outDir,'dir'),'D13 requires a new output directory');mkdir(outDir);
start=tic;
p.R=3.81;p.V=768*.3048;p.Omega=p.V/p.R;p.Nb=3;p.rho=1.225;p.g=9.80665;p.m=6000;p.sound=340;
p.scale=p.rho*pi*p.R^2*p.V^2;p.H=2*p.scale/p.m;
dat=readtable(fullfile(root,'docs/research/dynamic_fidelity/evidence_d11/channel/data/OARF_RUN15_EXISTING_STATIC_POINTS.csv'));
p.theta=dat.theta75_report_index_deg*pi/180;p.ct=dat.CT;
p.pp=pchip(p.theta,p.ct);[br,co,~,ord]=unmkpp(p.pp);p.dp=mkpp(br,co(:,1:ord-1).*(ord-1:-1:1));
p.ct0=p.m*p.g/(2*p.scale);p.theta0=fzero(@(q)ppval(p.pp,q)-p.ct0,[p.theta(1),p.theta(end)]);
p.lam0=sqrt(p.ct0/2);p.x0=[p.V*p.lam0;0];p.bold=.15160528305026616;
thetas=sort(unique([p.theta;p.theta0]));res=table();
for n=[64 128 256]
 q=radial(p,n,.0875);
 for j=1:numel(thetas)
  th=thetas(j);ls=sqrt(ppval(p.pp,th)/2);[raw,meta]=blade(th,ls,p,q);
  for h=[1e-4 5e-5 1e-5]
   b=-(blade(th,ls+h,p,q)-blade(th,ls-h,p,q))/(2*h);
   row=table(th*180/pi,n,h,b,raw,ppval(p.pp,th),meta(1),meta(2),meta(3),meta(4), ...
    'VariableNames',{'theta_report_deg','points_per_segment','derivative_step','b','raw_CT','static_CT','alpha_min_deg','alpha_max_deg','mach_min','mach_max'});
   res=[res;row]; %#ok<AGROW>
  end
 end
end
writetable(res,fullfile(outDir,'OPERATING_DERIVATIVES.csv'));
q=radial(p,256,.0875);p.q=q;
bnew=-(blade(p.theta0,p.lam0+1e-5,p,q)-blade(p.theta0,p.lam0-1e-5,p,q))/(2e-5);
qr=radial(p,256,.2);broot=-(blade(p.theta0,p.lam0+1e-5,p,qr)-blade(p.theta0,p.lam0-1e-5,p,qr))/(2e-5);
assert(bnew>0 && broot>0);
% Predeclared classical lookup contenders; no target-data fitting.
build=table();maps=cell(1,2);
for z=1:2
 dims=[21 41;41 81];N=dims(z,1);E=dims(z,2);t0=tic;
 tx=linspace(p.theta(1),p.theta(end),N);ex=linspace(-.01,.01,E);v=zeros(N,E);bs=zeros(N,1);
 for i=1:N
  th=tx(i);ls=sqrt(ppval(p.pp,th)/2);r0=blade(th,ls,p,q);
  bs(i)=-(blade(th,ls+1e-5,p,q)-blade(th,ls-1e-5,p,q))/(2e-5);
  for j=1:E,v(i,j)=blade(th,ls+ex(j),p,q)-r0;end
 end
 assert(max(abs(v(:,(E+1)/2)))<1e-14);
 maps{z}=griddedInterpolant({tx,ex},v,'linear','none');
 build=[build;table(N,E,toc(t0),'VariableNames',{'theta_nodes','e_nodes','build_seconds'})]; %#ok<AGROW>
 if z==2,p.btheta=tx;p.bvalue=bs;end
 [tt,ee]=ndgrid(tx,ex);writetable(table(tt(:),ee(:),v(:),'VariableNames',{'theta_rad','e','delta_CT'}),fullfile(outDir,sprintf('LOAD_TABLE_%d_%d.csv',N,E)));
end
p.maps=maps;writetable(build,fullfile(outDir,'OFFLINE_COST.csv'));
methods={'DIRECT_C81','OPERATING_TANGENT','CLASSICAL_LUT_COARSE','CLASSICAL_LUT_FINE','D11_SMALL_ANGLE'};
% Frozen non-node validation field. Increment RMS and absolute CT, no external truth claim.
idx=(1:101)';tq=p.theta(1)+(p.theta(end)-p.theta(1))*mod(idx*sqrt(2),1);eq=.02*(mod(idx*sqrt(3),1)-.5);
yf=zeros(101,numel(methods));
for k=1:numel(methods)
 for i=1:101,yf(i,k)=delta_load(tq(i),eq(i),methods{k},p);end
end
writetable(array2table([tq eq yf],'VariableNames',[{'theta_rad','e'} methods]),fullfile(outDir,'INDEPENDENT_GRID_QUERIES.csv'));
field=table();
for k=1:numel(methods)
 er=yf(:,k)-yf(:,1);field=[field;table(methods(k),max(abs(er)),norm(er)/norm(yf(:,1)), ...
  'VariableNames',{'method','max_absolute_CT_difference','increment_relative_RMS'})]; %#ok<AGROW>
end
writetable(field,fullfile(outDir,'FIELD_APPROXIMATION.csv'));
% Same input/state/output/integrator. The new source model is reference, not flight truth.
t=(0:.005:4)';trace=table();metric=table();histories=cell(2,numel(methods));
for ia=1:2
 amp=[.1 .3];amp=amp(ia)*pi/180;
 for k=1:numel(methods)
  tt=tic;[x,y,u]=trajectory(t,amp,methods{k},p);elapsed=toc(tt);histories{ia,k}=y;
  balance=max(abs(p.m*(y(:,2)+p.g)-y(:,3)));
  assert(balance<1e-7);assert(all(isfinite(y(:))));
  if k==1,yr=y;end
  er=y(:,1:2)-yr(:,1:2);nr=sqrt(mean(er.^2))./sqrt(mean(yr(:,1:2).^2));
  pk=max(abs(er))./max(abs(yr(:,1:2)));
  metric=[metric;table(amp*180/pi,methods(k),nr(1),nr(2),pk(1),pk(2),elapsed,balance,all(nr<=.01), ...
   'VariableNames',{'amplitude_deg','method','velocity_NRMSE','acceleration_NRMSE','velocity_peak_scaled_error','acceleration_peak_scaled_error','elapsed_seconds','force_balance_error_N','both_NRMSE_within_1pct'})]; %#ok<AGROW>
  n=numel(t);trace=[trace;table(repmat(amp*180/pi,n,1),repmat(methods(k),n,1),t,u*180/pi,x(:,1),x(:,2),y(:,2),y(:,3), ...
   'VariableNames',{'amplitude_deg','method','time_s','theta_report_deg','vi_mps','v_up_mps','a_up_mps2','total_aero_thrust_N'})]; %#ok<AGROW>
 end
end
writetable(trace,fullfile(outDir,'DYNAMIC_TRACES.csv'));writetable(metric,fullfile(outDir,'DYNAMIC_COMPARISON.csv'));
[~,half]=trajectory((0:.0025:4)',.3*pi/180,'DIRECT_C81',p);coarse=histories{2,1};err=half(1:2:end,1:2)-coarse(:,1:2);
integration=max(abs(err))./max(abs(half(:,1:2)));
writetable(table(integration(1),integration(2),'VariableNames',{'velocity_halfstep_scaled_difference','acceleration_halfstep_scaled_difference'}),fullfile(outDir,'INTEGRATOR_REFINEMENT.csv'));
assert(all(integration<1e-4));
% Timing includes the same caller and same sequence of 100 queries. Five repeats.
cost=table();checksum=zeros(numel(methods),1);
for k=1:numel(methods)
 for rep=1:5
  tt=tic;acc=0;
  for i=1:100,acc=acc+delta_load(tq(i),eq(i),methods{k},p);end
  sec=toc(tt);checksum(k)=acc;
  cost=[cost;table(methods(k),rep,100,sec,acc,'VariableNames',{'method','repeat','query_count','seconds','checksum'})]; %#ok<AGROW>
 end
end
writetable(cost,fullfile(outDir,'MATCHED_KERNEL_COST.csv'));
% D12 source-shape re-evaluation ONLY because b changes; do not fit source.
w=unique([logspace(-1,log10(3),513) 1])';s=1i*w;gf=-.0098*s./(s+.105).*exp(-.0074*s);ia=find(w==1,1);shape=table();
bs=[p.bold,bnew,broot];bn={'D11_SMALL_ANGLE','OPERATING_C81_ROOT_EXTENDED','OPERATING_C81_NO_ROOT'};
kn=[128/(75*pi),.637*4/3];ln={'PP_mean','CF_TN3044'};
for i=1:3
 for j=1:2
  b=bs(i);Q=p.Omega/kn(j);d=p.H*b/p.V;alpha=ppval(p.dp,p.theta0)*(1+b/(4*p.lam0));
  den=[1,Q*(b+4*p.lam0)+d,2*Q*p.lam0*d];gm=-p.H*alpha/p.g*s.*(s+4*Q*p.lam0)./polyval(den,s);
  ratios=abs(gm./gf);bound=(max(ratios)-min(ratios))/(max(ratios)+min(ratios));
  dif=gm/gm(ia)./(gf/gf(ia))-1;po=sort(real(roots(den)));
  shape=[shape;table(bn(i),ln(j),b,po(1),po(2),bound,max(abs(dif)), ...
    'VariableNames',{'load_convention','memory','b','fast_pole','slow_pole','constant_gain_amplitude_lower_bound','normalized_complex_max'})]; %#ok<AGROW>
 end
end
writetable(shape,fullfile(outDir,'SOURCE_SHAPE_DEPENDENCY_REGRESSION.csv'));
% Domain and exact-static boundary checks are limited to this API.
for k=1:numel(methods)
 for th=linspace(p.theta(1),p.theta(end),17),assert(abs(delta_load(th,0,methods{k},p))<1e-13);end
 failed=false;try,delta_load(p.theta(1)-.001,0,methods{k},p);catch,failed=true;end;assert(failed);
 failed=false;try,delta_load(p.theta0,.011,methods{k},p);catch,failed=true;end;assert(failed);
end
manifest=struct('status','NATIVE_EXECUTED_REQUIRES_EXTERNAL_READBACK','matlab_version',version,'computer',computer, ...
 'execution_commit',getenv('GITHUB_SHA'),'run_id',getenv('GITHUB_RUN_ID'),'total_elapsed_seconds',toc(start), ...
 'theta0_deg',p.theta0*180/pi,'CT0',p.ct0,'b_old',p.bold,'b_operating',bnew,'b_no_root',broot, ...
 'new_experimental_samples',0,'parameters_fitted_to_flight',0,'full_aircraft_validation',false,'new_physical_states',0, ...
 'scope','D13 source-conditioned load increments and computational approximation; two states, hover only');
fid=fopen(fullfile(outDir,'NATIVE_MANIFEST.json'),'w');fprintf(fid,'%s',jsonencode(manifest));fclose(fid);
result=struct('manifest',manifest,'derivatives',res,'field',field,'dynamic',metric,'shape',shape,'cost',cost,'offline',build,'integration',integration);
save(fullfile(outDir,'D13_NATIVE_RESULTS.mat'),'result','histories','-v7');disp(manifest);disp(metric);disp(shape);
end

function q=radial(p,n,root)
edge=unique([root,.2,.25,.55,.8,.95,1]);edge=edge(edge>=root);x=[];wt=[];
for i=1:numel(edge)-1
 h=(edge(i+1)-edge(i))/n;x=[x,edge(i)+((1:n)-.5)*h];wt=[wt,ones(1,n)*h]; %#ok<AGROW>
end
q.x=x;q.wt=wt;q.c=ones(size(x))*14*.0254/p.R;mask=x<=.25;q.c(mask)=(-18.4615*x(mask)+18.6154)*.0254/p.R;
tw=@(r)289.98*r.^5-892.87*r.^4+987.06*r.^3-438.31*r.^2+15.695*r+32.057;q.tw=(tw(x)-tw(.75))*pi/180;
end

function [ct,meta]=blade(theta,lambda,p,q)
assert(isfinite(lambda)&&lambda>0);x=q.x;vel=hypot(x,lambda);phi=atan2(lambda,x);alpha=theta+q.tw-phi;mach=vel*p.V/p.sound;
[cl,cd,m]=xv15_c81_section_lookup(alpha,mach,x);
assert(m.alphaClampCount==0 && m.machClampCount==0,'D13 rejects C81 out-of-domain queries');
ct=p.Nb/(2*pi)*sum(q.wt.*q.c.*vel.*(cl.*x-cd.*lambda));
meta=[min(alpha)*180/pi,max(alpha)*180/pi,min(mach),max(mach)];
end

function val=delta_load(theta,e,method,p)
assert(isfinite(theta)&&theta>=p.theta(1)&&theta<=p.theta(end),'D13 theta outside supported report-index interval');
assert(isfinite(e)&&abs(e)<=.01,'D13 inflow departure outside declared table domain');
switch method
 case 'DIRECT_C81'
  ls=sqrt(ppval(p.pp,theta)/2);val=blade(theta,ls+e,p,p.q)-blade(theta,ls,p,p.q);
 case 'OPERATING_TANGENT'
  val=-interp1(p.btheta,p.bvalue,theta,'linear')*e;
 case 'CLASSICAL_LUT_COARSE'
  val=p.maps{1}(theta,e);
 case 'CLASSICAL_LUT_FINE'
  val=p.maps{2}(theta,e);
 case 'D11_SMALL_ANGLE'
  val=-p.bold*e;
 otherwise,error('Unknown D13 method');
end
assert(isfinite(val));
end

function [x,y,u]=trajectory(t,amp,method,p)
n=numel(t);x=zeros(n,2);y=zeros(n,3);u=zeros(n,1);x(1,:)=p.x0';
for j=1:n
 [~,y(j,:),u(j)]=flow(t(j),x(j,:)',amp,method,p);
 if j<n
  h=t(j+1)-t(j);z=x(j,:)';
  k1=flow(t(j),z,amp,method,p);k2=flow(t(j)+h/2,z+h*k1/2,amp,method,p);
  k3=flow(t(j)+h/2,z+h*k2/2,amp,method,p);k4=flow(t(j)+h,z+h*k3,amp,method,p);
  x(j+1,:)=(z+h*(k1+2*k2+2*k3+k4)/6)';
 end
end
end

function [dx,y,theta]=flow(t,x,amp,method,p)
if t>=1&&t<=3,theta=p.theta0+amp*.5*(1-cos(pi*(t-1)));else,theta=p.theta0;end
S=ppval(p.pp,theta);e=(x(1)+x(2))/p.V-sqrt(S/2);ct=S+delta_load(theta,e,method,p);
assert(ct>0&&x(1)>0);k=128/(75*pi);
dx=[p.V*p.Omega/k*(ct-2*x(1)*(x(1)+x(2))/p.V^2);p.H*ct-p.g];
y=[x(2),dx(2),2*p.scale*ct];
end
