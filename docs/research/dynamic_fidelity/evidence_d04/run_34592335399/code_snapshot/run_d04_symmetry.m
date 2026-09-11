function result=run_d04_symmetry(outputRoot)
%RUN_D04_SYMMETRY Finite exact-reduction tests; no parameter or response fitting.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'model','axial'));addpath(fullfile(root,'analysis','dynamic_fidelity'));
P=d04_nominal_case();laws={'pp_mean','cf_mean'};checks={};records={};rows={};t0=tic;
for k=1:2
 M=build_axial_coupled(P,laws{k},'coupled','free');W=axial_workpoint(M);S=build_axial_symmetric(M);Ws=axial_workpoint(S.small);
 ck('left inverse of symmetric lift',norm(S.project*S.lift-eye(4),'fro')<1e-14,norm(S.project*S.lift-eye(4),'fro'));
 ck('steady state is same physical state',norm(S.lift*Ws.z-W.z)<1e-12,norm(S.lift*Ws.z-W.z));
 probes=[0 0 0 0; .1 .001 .01 .02;-.1 -.001 -.01 -.02;.05 -.002 .008 .03];
 for j=1:size(probes,1)
  z=Ws.z+probes(j,:).';u=Ws.u+.001*j;
  [fs,os,ys]=axial_symmetric_rhs(z,u,S);[ff,of,yf]=axial_coupled_rhs(S.lift*z,S.inputLift*u,M);
  d=norm(ff-S.lift*fs)/max(1,norm(ff));dy=max(abs(ys-yf)./max(1,abs(yf)));
  ck('nonlinear invariant manifold',d<1e-12,d);ck('all declared physical outputs identical',dy<1e-12,dy);
  ck('reduced full-mass transmitted force closure',abs(os.bodyForceResidual)<1e-8,abs(os.bodyForceResidual));
 end
 L=d04_linearize(M,W,1e-6);Ls=d04_linearize(S.small,Ws,1e-6);
 A=S.project*L.A*S.lift;B=S.project*L.B*S.inputLift;
 da=norm(A-Ls.A,'fro')/norm(A,'fro');db=norm(B-Ls.B)/norm(B);
 ck('projected Jacobian',da<1e-8,da);ck('projected input Jacobian',db<1e-8,db);
 ck('A invariant subspace',norm(L.A*S.lift-S.lift*A,'fro')<1e-8,norm(L.A*S.lift-S.lift*A,'fro'));
 ck('common input invariant subspace',norm(L.B*S.inputLift-S.lift*B)<1e-8,norm(L.B*S.inputLift-S.lift*B));
 w=logspace(log10(.3),log10(30),151).';
 G=df_state_space_response(L.A,L.B*S.inputLift,L.C(2,:),L.D(2,:)*S.inputLift,w);
 Gs=df_state_space_response(Ls.A,Ls.B,Ls.C(2,:),Ls.D(2),w);
 e=max(abs(Gs-G)./abs(G));ck('common heave full-band FRF identity',e<1e-8,e);
 zd=W.z;zd(M.vi)=zd(M.vi)+[.05;-.05];[~,od]=axial_coupled_rhs(zd,W.u,M);
 ck('differential rotor output cannot be claimed by common model',abs(od.aeroThrust(1)-od.aeroThrust(2))>1,abs(od.aeroThrust(1)-od.aeroThrust(2)));
 expect(@()axial_symmetric_rhs(Ws.z,[Ws.u;Ws.u+.01],S),'axialSymmetric:NoncommonInput');
 full=trial(@(z,u)axial_coupled_rhs(z,u,M),W.z,W.u);
 red=trial(@(z,u)axial_symmetric_rhs(z,u,S),Ws.z,Ws.u);
 scale=max(ones(1,size(full.y,2)),max(abs(full.y),[],1));er=max(abs(full.y-red.y)./scale,[],'all');
 ez=max(abs(full.z-red.z*S.lift.')./max(1,max(abs(full.z),[],1)),[],'all');
 ck('paired nonlinear time histories',er<1e-7,er);ck('paired nonlinear lifted states',ez<1e-7,ez);
 rows(end+1,:)={laws{k},M.n,S.n,e,er,ez,full.calls,red.calls,full.elapsed_s,red.elapsed_s};
 records{k}=struct('fullModel',M,'symmetricModel',S,'fullLinearization',L,'reducedLinearization',Ls,'omega',w,'G',G,'Gs',Gs,'fullTrial',full,'reducedTrial',red);
 writetable(array2table([full.t,full.y(:,2),red.y(:,2),full.y(:,3),red.y(:,3)], ...
  'VariableNames',{'time_s','fullAccelerationDown','reducedAccelerationDown','fullRotor1AeroThrust','reducedRotor1AeroThrust'}),fullfile(outputRoot,['SYMMETRIC_' laws{k} '.csv']));
end
C=cell2table(checks,'VariableNames',{'name','passed','value'});writetable(C,fullfile(outputRoot,'SYMMETRY_CHECKS.csv'));
T=cell2table(rows,'VariableNames',{'law','fullStates','reducedStates','maxRelativeFRFdifference','maxScaledOutputDifference','maxScaledStateDifference','fullRhsCalls','reducedRhsCalls','fullODEseconds','reducedODEseconds'});writetable(T,fullfile(outputRoot,'SYMMETRY_METRICS.csv'));disp(T);
[~,head]=system('git rev-parse HEAD');meta=struct('identity','D04_EXACT_SYMMETRIC_STATE_REDUCTION','commit',strtrim(head),'version',version,'release',version('-release'), ...
 'checks',height(C),'allChecksPassed',all(C.passed),'newNonlinearTrials',4,'experimentalSamples',0,'physicalParametersFitted',false,'externalValidationPassed',false, ...
 'novelMethodClaim',false,'allInputReductionClaim',false,'elapsed_s',toc(t0));
result=struct('meta',meta,'checks',C,'metrics',T,'records',{records});save(fullfile(outputRoot,'D04_SYMMETRY_RESULTS.mat'),'result');
fid=fopen(fullfile(outputRoot,'SYMMETRY_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear c;
disp(meta);assert(meta.allChecksPassed,'Retained symmetry checks contain failure.');
 function ck(n,p,v),checks(end+1,:)={n,logical(p),v};if ~p,fprintf('FAIL %s %.12g\n',n,v);end,end
 function expect(fun,id),try,fun();catch ME,ck(['reject ' id],strcmp(ME.identifier,id),strcmp(ME.identifier,id));return;end;ck(['reject ' id],false,0);end
end
function s=trial(fun,z0,u0)
t=(0:.005:3).';calls=0;opts=odeset('RelTol',2e-9,'AbsTol',1e-10,'MaxStep',.005);du=.2*pi/180*ones(size(u0));timer=tic;
[~,a]=ode45(@(tt,z)f(z,u0),t(t<=.5),z0,opts);[~,b]=ode45(@(tt,z)f(z,u0+du),t(t>=.5),a(end,:).',opts);seconds=toc(timer);z=[a(1:end-1,:);b];
[~,~,sample]=fun(z0,u0);y=zeros(numel(t),numel(sample));
for j=1:numel(t),u=u0;if t(j)>=.5,u=u+du;end;[~,~,v]=fun(z(j,:).',u);y(j,:)=v.';end
s=struct('t',t,'z',z,'y',y,'calls',calls,'elapsed_s',seconds);
 function dz=f(z,u),calls=calls+1;dz=fun(z,u);end
end
