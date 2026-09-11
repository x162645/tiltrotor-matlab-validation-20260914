function wp=d02_prepare_workpoint(trimConfig,P)
%D02_PREPARE_WORKPOINT Explicit immutable workpoint, reused across all cases.
% Sources: production trim/EOM at21a699a and dimensional equilibrium equations.
% The old hover helper adjusts collective only. Optional local refinement
% solves theta/collective/cyclic to balance X/Z/My, without parameter fitting
% or subtracting a derivative offset. Original trim is retained separately.
t=tic;original=run_trim_case(trimConfig,P);tr=original;
if ~tr.success||~tr.physicalConverged
 error('d02:ProductionTrimRejected','Require accepted existing production trim.');
end
if abs(tr.config.gammaDeg)>1e-12||abs(tr.betaM)>1e-12
 error('d02:UnsupportedWorkpoint','Only level, fixed helicopter-mode points supported.');
end
refinement=struct('used',false,'initialDerivative',tr.xdot,'calls',0, ...
 'method','LOCAL_SAME_FMINSEARCH_X_Z_MY_EQUILIBRIUM_NOT_TARGET_FIT');
if norm(tr.xdot(1:9),inf)>=1e-5
 seed=[tr.xTrim(8);tr.uTrim(1);tr.uTrim(3)];scale=[1e-3;1e-3;1e-3];
 lo=[-35*pi/180;P.control.collectiveLim(1);P.control.cyclicLim(1)];
 hi=[35*pi/180;P.control.collectiveLim(2);P.control.cyclicLim(2)];calls=0;
 options=optimset('Display','off','MaxIter',300,'MaxFunEvals',900,'TolX',1e-9,'TolFun',1e-16);
 [a,cost,flag,optim]=fminsearch(@objective,zeros(3,1),options);
 solved=seed+scale.*a;[dx,eo,x,u]=evaluate(solved);
 if flag<=0||norm(dx(1:9),inf)>=1e-5||~eo.physicalConverged
  error('d02:EquilibriumRefinementFailed','Refinement did not meet unchanged strict gate: %.9g.',norm(dx(1:9),inf));
 end
 tr.xTrim=x;tr.uTrim=u;tr.xdot=dx;
 tr.loads=struct('FaeroProp',eo.FaeroProp,'Fgravity',eo.Fgravity,'Ftotal',eo.Ftotal, ...
  'Mtotal',eo.Mtotal,'components',eo.components);
 refinement=struct('used',true,'initialDerivative',original.xdot,'finalDerivative',dx, ...
  'seed',seed,'solution',solved,'delta',solved-seed,'cost',cost,'exitflag',flag, ...
  'optimizer',optim,'calls',calls,'method','LOCAL_SAME_FMINSEARCH_X_Z_MY_EQUILIBRIUM_NOT_TARGET_FIT');
 tr.kind='production-trim-plus-explicit-local-equilibrium-refinement';
 tr.originalProductionReport=original.report;
 tr.report.residualNorm=norm([dx(1)/P.env.g;dx(3)/P.env.g;dx(5)]);
 tr.report.refinement=refinement;
end
cmd=tr.uTrim([1 3 6]);L=tr.loads.components.rotorLeft;R=tr.loads.components.rotorRight;
zd=[tr.xTrim;L.inducedVelocity;R.inducedVelocity;cmd;0];zq=[tr.xTrim;cmd;0];
[fd,ed]=d02_rhs(zd,cmd,tr.betaM,P,'dynamic');[fq,eq]=d02_rhs(zq,cmd,tr.betaM,P,'quasisteady');
report=struct('bodyDerivativeInf',norm(fd(1:9),inf),'inflowDerivativeInf',norm(fd(10:11),inf), ...
 'actuatorDerivativeInf',norm(fd(12:14),inf),'heightRateAbs',abs(fd(15)), ...
 'quasisteadyBodyDerivativeInf',norm(fq(1:9),inf), ...
 'sameStateForceDifference_N',norm(ed.FaeroProp-eq.FaeroProp), ...
 'sameStateMomentDifference_Nm',norm(ed.Mtotal-eq.Mtotal), ...
 'bodyLimit',1e-3,'inflowLimit',5e-3,'heightLimit',1e-8, ...
 'productionResidual',original.report.residualNorm);
report.pass=ed.evaluationValid&&eq.evaluationValid&&report.bodyDerivativeInf<report.bodyLimit&& ...
 report.quasisteadyBodyDerivativeInf<report.bodyLimit&&report.inflowDerivativeInf<report.inflowLimit&& ...
 report.actuatorDerivativeInf<1e-12&&report.heightRateAbs<report.heightLimit;
% Named legacy report aliases, with the same physical quantities as before.
report.rigidBodyResidual=report.bodyDerivativeInf;report.inflowResidual=report.inflowDerivativeInf;
report.actuatorResidual=report.actuatorDerivativeInf;report.heightRate=fd(15);
report.productionTrimResidual=original.report.residualNorm;
if ~report.pass,error('d02:WorkpointRejected','Body %.3g inflow %.3g.',report.bodyDerivativeInf,report.inflowDerivativeInf);end
wp=struct('identity','D02_1_EXPLICIT_WORKPOINT','P',P,'trim',tr,'originalProductionTrim',original, ...
 'refinement',refinement,'command',cmd,'dynamicState',zd,'quasisteadyState',zq,'report',report, ...
 'preparationSeconds',toc(t),'externalValidationReady',false,'physicsRole','GENERIC_BASELINE_NOT_XV15_IDENTITY');
 function J=objective(a)
  s=seed+scale.*a;calls=calls+1;
  if any(s<lo)||any(s>hi),v=max(lo-s,0)+max(s-hi,0);J=1e6+1e6*sum(v.^2);return;end
  dx=evaluate(s);r=[dx(1)/P.env.g;dx(3)/P.env.g;dx(5)];J=r.'*r;
 end
 function [dx,eo,x,u]=evaluate(s)
  x=original.xTrim;u=original.uTrim;x(8)=s(1);
  V=original.config.V;x(1)=V*cos(s(1));x(3)=V*sin(s(1));
  u(1)=s(2);u(3)=s(3);[dx,eo]=tiltrotor_eom(x,u,original.betaM,P);
  if ~eo.physicalConverged,error('d02:RefinementLoadInvalid','Unsupported stationary load during refinement.');end
 end
end
