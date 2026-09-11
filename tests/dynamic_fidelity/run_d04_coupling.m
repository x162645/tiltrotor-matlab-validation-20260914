function result=run_d04_coupling(outputRoot)
%RUN_D04_COUPLING Classical coupled baseline and explicit state-removal study.
% Real MATLAB computations; analytical source reconstruction is not flight data.
if nargin<1,outputRoot=fullfile(pwd,'ci_artifacts','d04');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'model','axial'));addpath(fullfile(root,'analysis','dynamic_fidelity'));
checks={};matrices={};sourceRows={};trialRows={};costRows={};freqRows={};rec={};count=0;t0=tic;
P0=d04_nominal_case();Ppaper=d04_paper_case();laws={'pp_mean','cf_mean'};
% Independent Table1 and Eq9 vs nonlinear Jacobian for two parameter cases.
Pref=P0;Pref.nRotors=1;Pref.bodyMass=P0.bodyMass/2;Pref.rotor.rootCut=0;Pref.rotor.twistTip=0;
Pref.identity='GENERIC_RECTANGULAR_LIMIT';
for pc=1:2
 if pc==1,P=Pref;else,P=Ppaper;end
 for li=1:2
  for free=0:1
   if free,fx='free';else,fx='fixed';end
   M=build_axial_coupled(P,laws{li},'coupled',fx);W=axial_workpoint(M);L=d04_linearize(M,W,1e-6);
   [At,Bt]=d04_table1_reference(P,laws{li},fx);
   err=norm(L.A-At,'fro')/max(1,norm(At,'fro'));erb=norm(L.B-Bt,'fro')/max(1,norm(Bt,'fro'));
   ck(sprintf('source A pc%d %s %s',pc,laws{li},fx),err<2e-8,err);
   ck(sprintf('source B pc%d %s %s',pc,laws{li},fx),erb<2e-8,erb);
   ck('analytical steady workpoint',max(abs(W.f))<1e-8,max(abs(W.f)));
   matrices{end+1}=struct('M',M,'W',W,'L',L,'sourceA',At,'sourceB',Bt);
  end
 end
end
% Independent Simpson integration of the radial blade equations (TN3044 Eq3/11).
M=build_axial_coupled(P0,'pp_mean','coupled','free');W=axial_workpoint(M);
r=P0.rotor;R=r.R;rr=linspace(r.rootCut*R,R,513);dr=rr(2)-rr(1);
bd=.012;v=W.out.vi(1)+.13;w=.04;theta=W.u(1)+.001;
a=theta+r.twistTip*(rr-r.rootCut*R)/(R-r.rootCut*R)-(v-w+rr*bd)./(r.Omega*rr);
dl=.5*P0.env.rho*r.liftSlope*r.chord*(r.Omega*rr).^2.*a;
sw=ones(size(rr));sw(2:2:end-1)=4;sw(3:2:end-2)=2;
Tnum=r.Nb*dr/3*sum(sw.*dl);Qnum=dr/3*sum(sw.*rr.*dl);c=M.coefficients;
Ta=c.Ttheta*theta+c.Ttwist+c.Tv*(v-w)+c.Trate*bd;
Qa=c.Qtheta*theta+c.Qtwist+c.Qv*(v-w)+c.Qrate*bd;
ck('radial thrust integral',abs(Tnum-Ta)/abs(Ta)<1e-9,abs(Tnum-Ta));
ck('radial moment integral',abs(Qnum-Qa)/abs(Qa)<1e-9,abs(Qnum-Qa));
ck('positive coning rate gives aerodynamic damping',c.Trate<0&&c.Qrate<0,c.Qrate);
% Joint inertia and source pumping, using off-equilibrium states.
z=W.z;z(M.vi)=z(M.vi)+[.2;-.1];z(M.beta)=z(M.beta)+[.002;-.001];z(M.rate)=[.012;-.008];z(M.w)=.04;
[f,o]=axial_coupled_rhs(z,W.u,M);
ck('free mechanical blade residual',max(abs(o.mechanicalResidual))<1e-8,max(abs(o.mechanicalResidual)));
ck('free total transmitted force balance',abs(o.bodyForceResidual)<1e-8,abs(o.bodyForceResidual));
ck('aero versus transmitted force explicit',norm(o.aeroThrust-o.hubThrust)>1e-3,norm(o.aeroThrust-o.hubThrust));
Mn=build_axial_coupled(P0,'pp_mean','no_pumping','free');[fn,on]=axial_coupled_rhs(z,W.u,Mn);
expected=-(4/3)*P0.env.rho*pi*R^2*o.vi.*R.*o.betaRate/((128/(75*pi))*P0.env.rho*pi*R^3);
ck('source pumping term identity',max(abs(f(M.vi)-fn(M.vi)-expected))<1e-9,max(abs(f(M.vi)-fn(M.vi)-expected)));
ck('pumping ablation changes no instantaneous mechanical acceleration',isequal(f(M.rate),fn(M.rate))&&f(M.w)==fn(M.w),max(abs(f(M.rate)-fn(M.rate))));
Pa=P0;Pa.bodyMass=P0.nRotors*r.Nb*r.Sblade^2/r.Ib*.999;
expect(@()build_axial_coupled(Pa,'pp_mean','coupled','free'),'axial:InvalidMechanicalMass');
zz=z;zz(M.vi(1))=-1;expect(@()axial_coupled_rhs(zz,W.u,M),'axial:OutsideNormalFlow');
expect(@()build_axial_coupled(P0,'arbitrary_tau','coupled','free'),'axial:InvalidModel');
expect(@()axial_coupled_rhs(z,W.u(1),M),'axial:InvalidState');
% One nonlinear fixed-hub trial tests absence of the body coordinate.
Mt=build_axial_coupled(Pref,'cf_mean','coupled','fixed');Wt=axial_workpoint(Mt);
checkT=simulate(Mt,Wt,.001,1);ck('fixed hub response has no free heave',all(checkT.y(:,2)==0),max(abs(checkT.y(:,2))));
% Five free-heave model variants: same load coefficients and static trim.
variants={'coupled','coupled','algebraic_coning','algebraic_coning','quasisteady'};
vlaw={'pp_mean','cf_mean','pp_mean','cf_mean','pp_mean'};
models=cell(5,1);works=cell(5,1);lins=cell(5,1);trials=cell(5,3);
amp=[.2,.1,-.2]*pi/180;
for k=1:5
 Mk=build_axial_coupled(P0,vlaw{k},variants{k},'free');Wk=axial_workpoint(Mk);L=d04_linearize(Mk,Wk,1e-5);Lf=d04_linearize(Mk,Wk,5e-6);
 models{k}=Mk;works{k}=Wk;lins{k}=L;
 ck('common physical trim input',norm(Wk.u-W.u)<1e-12,norm(Wk.u-W.u));
 ck('common aero steady state',norm(Wk.out.aeroThrust-W.out.aeroThrust)<1e-8,norm(Wk.out.aeroThrust-W.out.aeroThrust));
 ck('common coning steady state',norm(Wk.out.beta-W.out.beta)<1e-10,norm(Wk.out.beta-W.out.beta));
 for j=1:numel(amp)
  s=simulate(Mk,Wk,amp(j),3);[yl,xl]=linear_trial(L,s.t,amp(j)*ones(P0.nRotors,1),.5);
  yfine=linear_trial(Lf,s.t,amp(j)*ones(P0.nRotors,1),.5);delta=s.y-Wk.y.';mask=s.t>=.5;
  primary=2;e=sqrt(mean((delta(mask,primary)-yl(mask,primary)).^2));signal=sqrt(mean(delta(mask,primary).^2));rel=e/signal;
  step=sqrt(mean((yfine(mask,primary)-yl(mask,primary)).^2))/signal;
  ck(sprintf('linear nonlinear k%d amp%.4g',k,amp(j)),rel<.02,rel);
  ck(sprintf('derivative step k%d amp%.4g',k,amp(j)),step<.001,step);
  ck('effective common collective input',signal>1e-3,signal);
  ck('left right common symmetry',max(abs(s.y(:,3)-s.y(:,4)))<1e-7,max(abs(s.y(:,3)-s.y(:,4))));
  ck('body balance on whole trajectory',max(abs(s.balance))<1e-7,max(abs(s.balance)));
  trials{k,j}=struct('nonlinear',s,'linearOutput',yl,'linearState',xl,'linearization',L,'amplitude_rad',amp(j));
  count=count+1;trialRows(end+1,:)={k,variants{k},vlaw{k},Mk.n,amp(j)*180/pi,signal,e,rel,step, ...
   max(-delta(mask,2)),max(abs(delta(mask,2))),s.rhsCalls,s.seconds};
  costRows(end+1,:)={k,amp(j)*180/pi,s.rhsCalls,s.seconds};
  if j==1
   names=[{'time_s'},Mk.outputNames];T=array2table([s.t,s.y],'VariableNames',names);writetable(T,fullfile(outputRoot,sprintf('MODEL%d_POS02.csv',k)));
  end
 end
 e1=trialRows{3*(k-1)+1,7};e2=trialRows{3*(k-1)+2,7};
 ck(sprintf('amplitude refinement k%d',k),e2/e1<.45,e2/e1);
end
% Direct coupled-vs-reduced differences; report all outputs, no external score.
pr={};base=trials{1,1}.nonlinear.y-works{1}.y.';
for k=2:5
 delta=trials{k,1}.nonlinear.y-works{k}.y.';
 for q=[2,3,5,7,9]
  d=delta(:,q)-base(:,q);pr(end+1,:)={k,models{k}.mode,models{k}.law,models{k}.outputNames{q},sqrt(mean(d.^2)),max(abs(d))};
 end
end
% Source-parametric case connects to published Table1/Fig10/Fig14, NOT actual
% CH47 parameter identity. Actual pitch gain from text .0201rad/.62in.
w=logspace(log10(.1),log10(100),401).';paper={};bands=[.3 3;3 10;10 30];fr={};sourceTime=(0:.002:5).';
for li=1:2
 full=build_axial_coupled(Ppaper,laws{li},'coupled','free');fw=axial_workpoint(full);lf=d04_linearize(full,fw,1e-6);
 gf=df_state_space_response(lf.A,lf.B,lf.C(2,:),lf.D(2),w);
 [yst,~]=linear_trial(lf,sourceTime,.0201,0);au=-yst(:,2);[peak,ip]=max(au);
 % Local magnitude maximum above 3rad/s, kept separate from boundary maxima.
 ix=find(w>3&w<40);[~,im]=max(abs(gf(ix)));peakW=w(ix(im));
 sourceRows(end+1,:)={laws{li},peak/.3048,sourceTime(ip),-min(au)/.3048,peakW, ...
  9.9,11,17,'SOURCE_THEORY_RECONSTRUCTION_AND_APPROX_FLIGHT_FEATURES_NOT_VALIDATION'};
 paper{li}=struct('model',full,'workpoint',fw,'linearization',lf,'omega',w,'frequencyResponse',gf,'t',sourceTime,'linearStep',yst);
 reductions={'algebraic_coning','quasisteady'};
 for k=1:2
  mr=build_axial_coupled(Ppaper,laws{li},reductions{k},'free');wr=axial_workpoint(mr);lr=d04_linearize(mr,wr,1e-6);
  gr=df_state_space_response(lr.A,lr.B,lr.C(2,:),lr.D(2),w);rat=gr./gf;
  for ib=1:3
   mask=w>=bands(ib,1)&w<=bands(ib,2);gd=20*log10(abs(rat(mask)));pd=angle(rat(mask))*180/pi;
   fr(end+1,:)={laws{li},reductions{k},mr.n,bands(ib,1),bands(ib,2),max(abs(gd)),max(abs(pd)),sqrt(mean(abs(rat(mask)-1).^2))};
  end
  for iq=1:numel(w),freqRows(end+1,:)={laws{li},reductions{k},w(iq),real(gf(iq)),imag(gf(iq)),real(gr(iq)),imag(gr(iq))};end
 end
end
metrics=cell2table(trialRows,'VariableNames',{'caseIndex','mode','law','states','amplitude_deg','signalRMS','linearAbsoluteError','linearRelativeError','stepRelativeChange','peakUpAcceleration','peakAbsoluteAcceleration','rhsCalls','elapsed_s'});
writetable(metrics,fullfile(outputRoot,'NONLINEAR_LINEAR_METRICS.csv'));
paired=cell2table(pr,'VariableNames',{'caseIndex','mode','law','output','RMSdifferenceFromCoupledPP','peakDifferenceFromCoupledPP'});writetable(paired,fullfile(outputRoot,'PAIRED_REDUCTIONS.csv'));
source=cell2table(sourceRows,'VariableNames',{'law','linearPeakUp_ft_s2','peakTime_s','initialOppositePeak_ft_s2','resonance_rad_s','publishedCalculatedPeak_approx_ft_s2','publishedMeasuredPeak_approx_ft_s2','publishedMeasuredResonance_approx_rad_s','role'});writetable(source,fullfile(outputRoot,'SOURCE_FEATURES.csv'));
fmetrics=cell2table(fr,'VariableNames',{'law','reduction','states','bandLow_rad_s','bandHigh_rad_s','maxGainDifference_dB','maxPhaseDifference_deg','unweightedComplexRelativeRMS'});writetable(fmetrics,fullfile(outputRoot,'STATE_REMOVAL_FREQUENCY_METRICS.csv'));
frequency=cell2table(freqRows,'VariableNames',{'law','reduction','omega_rad_s','fullReal','fullImag','reducedReal','reducedImag'});writetable(frequency,fullfile(outputRoot,'FREQUENCY_RESPONSES.csv'));
Ck=cell2table(checks,'VariableNames',{'name','passed','value'});writetable(Ck,fullfile(outputRoot,'CHECKS.csv'));
[~,head]=system('git rev-parse HEAD');meta=struct('identity','D04_AXIAL_CONING_INFLOW_BODY_CLASSICAL_BENCHMARK', ...
 'commit',strtrim(head),'version',version,'release',version('-release'),'checks',height(Ck),'allChecksPassed',all(Ck.passed), ...
 'newNonlinearTrials',count+1,'experimentalSamplesUsedInFit',0,'independentFlightValidationPassed',false,'productionModelModified',false, ...
 'elapsed_s',toc(t0),'sameAsV7Dynamics',false,'newMethodLeadingAdvantageProven',false);
result=struct('meta',meta,'checks',Ck,'models',{models},'workpoints',{works},'trials',{trials},'sourceMatrices',{matrices}, ...
 'metrics',metrics,'paired',paired,'sourceFeatures',source,'frequencyMetrics',fmetrics,'paper',{paper},'fixedHubTrial',checkT, ...
 'nominalParameters',P0,'sourceEquivalentParameters',Ppaper);
save(fullfile(outputRoot,'D04_RESULTS.mat'),'result');fid=fopen(fullfile(outputRoot,'RUN_MANIFEST.json'),'w');assert(fid>=0);cl=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear cl;
disp(metrics);disp(source);disp(fmetrics);disp(meta);assert(meta.allChecksPassed,'D04 retained checks contain failure.');
 function ck(name,pass,value)
  checks(end+1,:)={name,logical(pass),value};if ~pass,fprintf('FAILED %s %.12g\n',name,value);end
 end
 function expect(fun,id)
  try,fun();catch ME,ck(['reject ' id],strcmp(ME.identifier,id),strcmp(ME.identifier,id));return;end
  ck(['reject ' id],false,0);
 end
end
function s=simulate(M,W,amplitude,duration)
% Exact event split; no workpoint offset subtraction in physical RHS.
cmd=amplitude*ones(M.nRotors,1);t=(0:.005:duration).';ts=.5;calls=0;start=tic;
opts=odeset('RelTol',2e-9,'AbsTol',1e-10,'MaxStep',.005);
t1=t(t<=ts);t2=t(t>=ts);
[~,a]=ode45(@(tt,z)f(z,W.u),t1,W.z,opts);
[~,b]=ode45(@(tt,z)f(z,W.u+cmd),t2,a(end,:).',opts);z=[a(1:end-1,:);b];sec=toc(start);
y=zeros(numel(t),numel(W.y));balance=zeros(numel(t),1);
for k=1:numel(t)
 u=W.u;if t(k)>=ts,u=u+cmd;end
 [~,o,yy]=axial_coupled_rhs(z(k,:).',u,M);y(k,:)=yy.';balance(k)=o.bodyForceResidual;
end
s=struct('t',t,'z',z,'y',y,'balance',balance,'rhsCalls',calls,'seconds',sec);
 function dz=f(z,u),calls=calls+1;dz=axial_coupled_rhs(z,u,M);end
end
function [y,x]=linear_trial(L,t,amplitude,stepTime)
n=size(L.A,1);nu=size(L.B,2);x=zeros(numel(t),n);y=zeros(numel(t),size(L.C,1));
dt=t(2)-t(1);block=zeros(n+nu);block(1:n,1:n)=L.A;block(1:n,n+1:end)=L.B;
Phi=expm(block*dt);Ad=Phi(1:n,1:n);Bd=Phi(1:n,n+1:end);
for k=1:numel(t)
 u=zeros(nu,1);if t(k)>=stepTime-1e-12,u=amplitude;end
 y(k,:)=(L.C*x(k,:).'+L.D*u).';
 if k<numel(t),x(k+1,:)=(Ad*x(k,:).'+Bd*u).';end
end
end
