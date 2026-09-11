function result=run_d05_state_selection(outputRoot)
%RUN_D05_STATE_SELECTION Nonideal-symmetry, nonlinear residualization, and band gates.
% Numerical comparisons only; neither 5% budget nor epsilon values are flight
% limits or measured manufacturing tolerances. No new external accuracy claim.
if nargin<1,outputRoot=fullfile(pwd,'ci_artifacts','d05');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'model','axial'));addpath(fullfile(root,'analysis','dynamic_fidelity'));
start=tic;checks={};P=d04_nominal_case();laws={'pp_mean','cf_mean'};epsilons=[0,.02,.10,.20];
inputs=[1,1,1;1,.9/1.1,-1];inputNames={'common','mixed','differential'};
bands=[.3 3;3 10;10 30];budget=.05;rows={};records={};matrices={};
% Minimal D04 dependency regression, not rerun the old whole test suite.
for il=1:2
 M=build_axial_nearsymmetric(P,laws{il},0);W=M.workpoint;
 for k=1:3
  zz=W.z+[.1;-.05;.001;-.0005;.002;-.003;.01]*(k-1);uu=W.u+[.0004;-.0002]*(k-1);
  [f,o,y]=axial_nearsymmetric_rhs(zz,uu,M);[fo,oo,yo]=axial_coupled_rhs(zz,uu,M.base);
  ck('D04 unchanged equations at equal slopes',norm(f-fo)<1e-10&&norm(y-[-yo(2);oo.hubThrust(2)-oo.hubThrust(1)])<1e-8,norm(f-fo));
 end
end
for il=1:2
 for ie=1:numel(epsilons)
  ep=epsilons(ie);M=build_axial_nearsymmetric(P,laws{il},ep);W=M.workpoint;
  [f,o,y]=axial_nearsymmetric_rhs(W.z,W.u,M);[fr,orr,yr]=axial_residualized_rhs(W.common,W.u,M);
  ck('full workpoint equilibrium',max(abs(f))<1e-8,max(abs(f)));
  ck('same physical reduced workpoint',norm(orr.reconstructedState-W.z)<1e-10&&max(abs(fr))<1e-8,norm(orr.reconstructedState-W.z));
  ck('same workpoint output',norm(y-yr)<1e-8,norm(y-yr));
  L=d05_linear_model(M);Lf=finite_linear(@(z,u)axial_nearsymmetric_rhs(z,u,M),W.z,W.u);
  ck('analytical full Jacobian',matrix_error(L,Lf)<2e-7,matrix_error(L,Lf));
  Lr=finite_linear(@(z,u)axial_residualized_rhs(z,u,M),W.common,W.u);
  ss=diag(M.stateScales(1:4));ref=struct('A',ss*L.Ared/ss,'B',ss*L.Bred,'C',L.Cred/ss,'D',L.Dred);
  ck('nonlinear reduction Jacobian equals Schur complement',matrix_error(ref,Lr)<2e-7,matrix_error(ref,Lr));
  ck('full and reduced local stability',max(real(eig(L.A)))<0&&max(real(eig(L.Ared)))<0,max(real(eig(L.Ared))));
  off=W.common+[.2;.001;.01;.03];uo=W.u+[.002;-.001];[fr,or,~]=axial_residualized_rhs(off,uo,M);
  [fl,of,~]=axial_nearsymmetric_rhs(or.reconstructedState,uo,M);fq=M.T*fl;
  ck('algebraic differential residual at off-trim state',norm(fq(5:7))<1e-8,norm(fq(5:7)));
  ck('direct four-state RHS equals lifted common RHS',norm(fr-fq(1:4))<1e-9,norm(fr-fq(1:4)));
  ck('transmitted-force balance',abs(or.bodyResidual)<1e-8&&abs(of.bodyResidual)<1e-8,abs(or.bodyResidual));
  G0=L.D-L.C*(L.A\L.B);G0r=L.Dred-L.Cred*(L.Ared\L.Bred);
  ck('DC gain matching',norm(G0-G0r,'fro')<1e-7,norm(G0-G0r,'fro'));
  matrices{end+1}=struct('M',M,'L',L); %#ok<AGROW>
  for iu=1:3
   e=inputs(:,iu);
   for ib=1:3
    band=bands(ib,:);wg=logspace(log10(band(1)),log10(band(2)),151).';
    G=zeros(numel(wg),2);Gr=G;
    for iw=1:numel(wg)
     s=1i*wg(iw);G(iw,:)=((L.C*((s*eye(7)-L.A)\L.B)+L.D)*e).';
     Gr(iw,:)=((L.Cred*((s*eye(4)-L.Ared)\L.Bred)+L.Dred)*e).';
    end
    for jo=1:2
     qual=d05_qualify_band(L,e,band,jo,budget);leaves=qual.leaves;
     envelope=zeros(size(wg));
     for iw=1:numel(wg)
      ix=find(wg(iw)>=leaves(:,1)-1e-12&wg(iw)<=leaves(:,2)+1e-12,1);
      if isempty(ix),error('d05:CoverageGap','Interval qualification missed a frequency.');end
      envelope(iw)=leaves(ix,4);
     end
     er=abs(G(:,jo)-Gr(:,jo));finite=isfinite(envelope);
     violation=max([0;er(finite)-envelope(finite)]);
     ck('independent full FRF is inside interval enclosure',violation<1e-8*M.gainScales(jo),violation/M.gainScales(jo));
     actual=max(er)/M.gainScales(jo);
     if qual.qualified,ck('qualified interval satisfies fixed gain budget',actual<=budget+1e-9,actual);end
     rows(end+1,:)={laws{il},ep,inputNames{iu},M.outputNames{jo},band(1),band(2),budget,qual.selectedStates, ...
      qual.qualified,qual.maxBound/M.gainScales(jo),actual,qual.maxKappa,qual.enclosureCalls,qual.maxDepthUsed}; %#ok<AGROW>
     records{end+1}=struct('modelIndex',numel(matrices),'input',e,'output',jo,'qualification',qual, ...
      'omega',wg,'fullResponse',G(:,jo),'reducedResponse',Gr(:,jo),'enclosure',envelope); %#ok<AGROW>
    end
   end
  end
 end
end
T=cell2table(rows,'VariableNames',{'law','epsilonA','input','output','bandLow_rad_s','bandHigh_rad_s', ...
 'budgetFraction','selectedStates','qualified','boundOverFixedGainScale','actualErrorOverFixedGainScale','maxKappa','enclosureCalls','maxDepthUsed'});
writetable(T,fullfile(outputRoot,'BAND_SELECTION.csv'));
ck('selection includes accepted and refused reductions',any(T.qualified)&&any(~T.qualified),sum(T.qualified));
% Symmetry perturbation order, not fitted physical laws. At common input and
% common output, exchange symmetry removes the O(epsilon) error. Differential
% output or input instead produces first-order leakage.
sr={};small=[.005 .01 .02];E=zeros(3,3);
for k=1:3
 M=build_axial_nearsymmetric(P,'pp_mean',small(k));L=d05_linear_model(M);s=20i;
 G=L.C*((s*eye(7)-L.A)\L.B)+L.D;Gr=L.Cred*((s*eye(4)-L.Ared)\L.Bred)+L.Dred;
 ec=(G-Gr)*[1;1];ed=(G-Gr)*[1;-1];E(k,:)=[abs(ec(1)),abs(ec(2)),abs(ed(1))];
end
orders=log(E(2:end,:)./E(1:end-1,:))/log(2);
ck('common heave error is second order near symmetry',max(abs(orders(:,1)-2))<.08,max(abs(orders(:,1)-2)));
ck('differential pathways leak at first order',max(max(abs(orders(:,2:3)-1)))<.08,max(max(abs(orders(:,2:3)-1))));
S=array2table([small.',E],'VariableNames',{'epsilonA','commonToHeaveError','commonToDifferentialForceError','differentialToHeaveError'});
writetable(S,fullfile(outputRoot,'ASYMMETRY_ORDER.csv'));
% Unfitted off-design nonlinear inputs, not independent experimental holdout.
% Case1 is deliberately exactly symmetric with differential forcing: its
% heave LINEAR channel is zero, but quadratic nonlinear heave need not vanish.
scenarios={0,[1;-1],12;.07,[1;1],2;.15,[1;.8],2;.15,[1;-1],12};
trials={};tr={};ti=0;amps=[.2 .1]*pi/180;
for k=1:size(scenarios,1)
 M=build_axial_nearsymmetric(P,'pp_mean',scenarios{k,1});L=d05_linear_model(M);e=scenarios{k,2};omega=scenarios{k,3};
 for ia=1:2
  amp=amps(ia);
  for mode=1:2
   ss=nonlinear_trial(M,L,e,omega,amp,mode);ti=ti+1;trials{ti}=ss;
   dy=ss.y-ss.y0.';el=sqrt(mean((dy-ss.linearOutput).^2,1));sig=sqrt(mean(dy.^2,1));
   scaled=el./(M.gainScales.'*amp);rel=el./max(sig,1e-12);
   ck('nonlinear versus own linear model scaled check',max(scaled)<.005,max(scaled));
   ck('no hidden force imbalance',ss.maxForceResidual<1e-7,ss.maxForceResidual);
   tr(end+1,:)={k,M.epsilonA,omega,amp*180/pi,mode,7-3*(mode==2),sig(1),sig(2),el(1),el(2), ...
    scaled(1),scaled(2),rel(1),rel(2),ss.seconds,ss.calls}; %#ok<AGROW>
   if ia==1
    names={'time_s','accelerationUp','hubForceDifference','linearAccelerationDelta','linearForceDifferenceDelta'};
    writetable(array2table([ss.t,ss.y,ss.linearOutput],'VariableNames',names), ...
     fullfile(outputRoot,sprintf('SCENARIO_%d_MODE_%d.csv',k,mode)));
   end
  end
 end
end
N=cell2table(tr,'VariableNames',{'scenario','epsilonA','omega_rad_s','amplitude_deg','mode','states', ...
 'heaveSignalRMS','diffForceSignalRMS','heaveLinearErrorRMS','diffForceLinearErrorRMS', ...
 'heaveErrorOverFixedScale','diffForceErrorOverFixedScale','heaveRelativeLinearError','diffForceRelativeLinearError','elapsed_s','rhsCalls'});
writetable(N,fullfile(outputRoot,'NONLINEAR_CHECKS.csv'));
pr={};
for k=1:size(scenarios,1)
 for ia=1:2
  ix=(k-1)*4+(ia-1)*2+1;f=trials{ix};rr=trials{ix+1};delta=rr.y-f.y;
  pr(end+1,:)={k,amps(ia)*180/pi,sqrt(mean(delta(:,1).^2)),max(abs(delta(:,1))), ...
   sqrt(mean(delta(:,2).^2)),max(abs(delta(:,2))),f.seconds,rr.seconds}; %#ok<AGROW>
 end
end
Pair=cell2table(pr,'VariableNames',{'scenario','amplitude_deg','heaveReductionRMS','heaveReductionPeak','forceDifferenceReductionRMS','forceDifferenceReductionPeak','fullSeconds','reducedSeconds'});
writetable(Pair,fullfile(outputRoot,'PAIRED_NONLINEAR.csv'));
% Explicit domain and input guards.
expect(@()build_axial_nearsymmetric(P,'pp_mean',.5),'d05:InvalidAsymmetry');
M=build_axial_nearsymmetric(P,'pp_mean',.1);zz=M.workpoint.z;zz(1)=-1;
expect(@()axial_nearsymmetric_rhs(zz,M.workpoint.u,M),'d05:OutsideNormalFlow');
L=d05_linear_model(M);expect(@()d05_error_enclosure(L,[0;0],[1 2]),'d05:InvalidCertificateInput');
Ck=cell2table(checks,'VariableNames',{'name','passed','value'});writetable(Ck,fullfile(outputRoot,'CHECKS.csv'));
[~,head]=system('git rev-parse HEAD');
meta=struct('identity','D05_OUTPUT_AWARE_NEARSYMMETRIC_RESIDUALIZATION','commit',strtrim(head), ...
 'version',version,'release',version('-release'),'checks',height(Ck),'allChecksPassed',all(Ck.passed), ...
 'modelCases',8,'bandDecisions',height(T),'qualifiedFourStateDecisions',sum(T.qualified), ...
 'newNonlinearTrials',ti,'elapsed_s',toc(start),'productionModified',false,'experimentalSamples',0, ...
 'independentDynamicAccuracyPassed',false,'wholeTiltrotorIntegrated',false,'noveltyEstablished',false, ...
 'certificateScope','LOCAL_LINEAR_MODEL_ERROR_IN_EXACT_ARITHMETIC_DOUBLE_IMPLEMENTATION_NOT_INTERVAL_ROUNDING', ...
 'budgetRole','5_PERCENT_OF_FIXED_PITCH_LOAD_GAIN_RESEARCH_DEMONSTRATION_NOT_FLIGHT_QUALITY_STANDARD', ...
 'nonlinearScope','FINITE_AMPLITUDE_DIAGNOSTICS_NOT_COVERED_BY_LINEAR_CERTIFICATE');
result=struct('meta',meta,'checks',Ck,'selection',T,'records',{records},'models',{matrices},'orderTable',S, ...
 'orders',orders,'nonlinearMetrics',N,'paired',Pair,'trials',{trials});
save(fullfile(outputRoot,'D05_RESULTS.mat'),'result');
fid=fopen(fullfile(outputRoot,'RUN_MANIFEST.json'),'w');assert(fid>=0);cl=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear cl;
disp(T);disp(S);disp(orders);disp(N);disp(Pair);disp(meta);
assert(meta.allChecksPassed,'D05 checks contain a retained failure.');
 function ck(name,passed,value)
  checks(end+1,:)={name,logical(passed),value};if ~passed,fprintf('FAILED %s %.12g\n',name,value);end
 end
 function expect(fun,id)
  try,fun();catch ME,ck(['reject ' id],strcmp(ME.identifier,id),strcmp(ME.identifier,id));return;end
  ck(['reject ' id],false,0);
 end
end
function e=matrix_error(A,B)
e=0;for f={'A','B','C','D'},k=f{1};e=max(e,norm(A.(k)-B.(k),'fro')/max(1,norm(A.(k),'fro')));end
end
function L=finite_linear(fun,z,u)
h=2e-6;[~,~,y]=fun(z,u);n=numel(z);A=zeros(n);B=zeros(n,2);C=zeros(numel(y),n);D=zeros(numel(y),2);
for j=1:n,d=h*max(1,abs(z(j)));v=zeros(n,1);v(j)=d;[fp,~,yp]=fun(z+v,u);[fm,~,ym]=fun(z-v,u);A(:,j)=(fp-fm)/(2*d);C(:,j)=(yp-ym)/(2*d);end
for j=1:2,v=zeros(2,1);v(j)=h;[fp,~,yp]=fun(z,u+v);[fm,~,ym]=fun(z,u-v);B(:,j)=(fp-fm)/(2*h);D(:,j)=(yp-ym)/(2*h);end
L=struct('A',A,'B',B,'C',C,'D',D);
end
function s=nonlinear_trial(M,L,e,omega,amp,mode)
% Prescribed smooth actual pitch, no fitted actuator or time shift. Sinusoid
% plus finite onset is NOT strictly band limited; certificate is not applied
% as an all-time peak bound to this signal.
t=(0:.005:4).';calls=0;opt=odeset('RelTol',2e-9,'AbsTol',1e-10,'MaxStep',.01);
if mode==1,z0=M.workpoint.z;A=L.A;B=L.B;C=L.C;D=L.D;fun=@(z,u)axial_nearsymmetric_rhs(z,u,M);
else,z0=M.workpoint.common;A=L.Ared;B=L.Bred;C=L.Cred;D=L.Dred;fun=@(z,u)axial_residualized_rhs(z,u,M);end
clock=tic;[~,z]=ode45(@rhs,t,z0,opt);sec=toc(clock);
[~,xl]=ode45(@(tt,x)A*x+B*command(tt),t,zeros(size(A,1),1),opt);
y=zeros(numel(t),2);yl=y;residual=0;[~,~,y0]=fun(z0,M.workpoint.u);
for k=1:numel(t)
 du=command(t(k));[~,o,yy]=fun(z(k,:).',M.workpoint.u+du);y(k,:)=yy.';yl(k,:)=(C*xl(k,:).'+D*du).';
 residual=max(residual,abs(o.bodyResidual));
end
s=struct('t',t,'z',z,'y',y,'y0',y0,'linearOutput',yl,'mode',mode,'epsilonA',M.epsilonA, ...
 'direction',e,'omega',omega,'amplitude',amp,'seconds',sec,'calls',calls,'maxForceResidual',residual);
 function u=command(tt)
  dt=max(0,tt-.5);envelope=.5*(1-cos(pi*min(dt/.5,1)));u=e*(amp*envelope*sin(omega*dt));
 end
 function f=rhs(tt,zz),calls=calls+1;f=fun(zz,M.workpoint.u+command(tt));end
end
