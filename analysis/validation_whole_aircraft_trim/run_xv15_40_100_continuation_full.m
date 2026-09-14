function results = run_xv15_40_100_continuation_full(outputRoot)
%RUN_XV15_20KT_CONTINUATION_DIAGNOSTIC Fine speed continuation + multistart.
% Diagnostic only: the canonical XV15 validation runner is unchanged.
% Physics, parameters, controls, and credibility gates are not retuned.
if nargin < 1 || isempty(outputRoot)
    outputRoot = fullfile(pwd,'results','xv15_20kt_continuation_diagnostic_20260912');
end
if ~exist(outputRoot,'dir'), mkdir(outputRoot); end
addpath(fileparts(mfilename('fullpath')));
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'stage2_aircraft'));
[P,contract] = xv15_helicopter_trim_parameters_v1();
speeds = [20 40 60 80 100];
% The original 20-kt candidate is also retained as a declared seed.
d2r=pi/180; knot2mps=0.514444; modelIdentity='M1_EVIDENCE_V1_PROPAGATION';
x75=(0.75-P.rotor.rootCut)/max(1-P.rotor.rootCut,eps);
base=[0; P.validation.initialTheta75_deg*d2r-P.rotor.twistTip*x75; 4.8];
rows=repmat(empty_row(),numel(speeds),1); reports=cell(numel(speeds),1);
seed=base; lastFlapL=[]; lastFlapR=[];
for k=1:numel(speeds)
    c=struct('name',sprintf('XV15_HELI_%06.2fKT',speeds(k)), ...
        'V',speeds(k)*knot2mps,'betaM',0,'gamma',0);
    Pw=P;
    if ~isempty(lastFlapL)
        Pw.stage2Numerics.flapInitialLeft=lastFlapL;
        Pw.stage2Numerics.flapInitialRight=lastFlapR;
    end
    r=solve_one(c,seed,Pw,modelIdentity,500,'ones');
    reports{k}=r; rows(k)=pack_row(r,speeds(k),c,V1_ref(speeds(k),P),d2r);
    if r.solveReturned && r.physicalConverged && r.physicalBranchSupported && all(isfinite(r.z))
        seed=r.z;
        if isfield(r.point.eomOut.rotorLeft,'zFlap'), lastFlapL=r.point.eomOut.rotorLeft.zFlap(:); end
        if isfield(r.point.eomOut.rotorRight,'zFlap'), lastFlapR=r.point.eomOut.rotorRight.zFlap(:); end
    end
end
% Declared multi-start at 20 kt, using the continuation endpoint, base, and
% a nearby GTRS-informed seed. These are diagnostics, not fitted parameters.
c=struct('name','XV15_HELI_100.00KT_MULTISTART','V',100*knot2mps,'betaM',0,'gamma',0);
Pw=P; if ~isempty(lastFlapL), Pw.stage2Numerics.flapInitialLeft=lastFlapL; Pw.stage2Numerics.flapInitialRight=lastFlapR; end
seeds={seed,base,seed+[2*d2r;0;0.5]}; ms=repmat(empty_multistart_row(),numel(seeds),1);
for j=1:numel(seeds)
    rr=solve_one(c,seeds{j},Pw,modelIdentity,400,'ones');
    ms(j)=pack_ms(rr,j,seeds{j},d2r);
end
points=struct2table(rows); multistart=struct2table(ms);
writetable(points,fullfile(outputRoot,'XV15_40_100KT_CONTINUATION_POINTS.csv'));
writetable(multistart,fullfile(outputRoot,'XV15_40_100KT_MULTISTART.csv'));
summary=table(sum(points.credible),height(points),points.residualNorm(end), ...
    min(multistart.residualNorm),max(multistart.residualNorm), ...
    'VariableNames',{'CredibleContinuationCount','ContinuationCount','ResidualAt20kt','BestMultistartResidual','WorstMultistartResidual'});
writetable(summary,fullfile(outputRoot,'XV15_40_100KT_CONTINUATION_SUMMARY.csv'));
results=struct('contract',contract,'points',points,'multistart',multistart,'summary',summary,'reports',{reports});
save(fullfile(outputRoot,'XV15_40_100KT_CONTINUATION_RESULTS.mat'),'results');
disp(points); disp(multistart); disp(summary);
end

function r=solve_one(c,seed,P,modelIdentity,maxIter,initVariant)
d2r=pi/180; bounds=[-35*d2r,35*d2r;P.control.collectiveLim(:).';0,9.6]; scale=[2*d2r;10*d2r;1]; bad=0; ids={};
opt=optimset('Display','off','MaxIter',maxIter,'MaxFunEvals',12*maxIter,'TolX',1e-7,'TolFun',1e-9);
if nargin<6, initVariant='ones'; end
if strcmpi(initVariant,'ones')
    y0=ones(3,1); map=@(y) seed(:)+scale.*(y(:)-ones(3,1));
else
    y0=zeros(3,1); map=@(y) seed(:)+scale.*y(:);
end
[yo,fv,ef,out]=fminsearch(@obj,y0,opt); z=map(yo); r=empty_report(); r.exitflag=ef;r.output=out;r.cost=fv;r.z=z;r.invalidEvaluationCount=bad;r.invalidEvaluationIdentifiers=unique(ids);
try
 p=evaluate_point(c,z,P,modelIdentity); r.solveReturned=true;r.point=p; rs=p.residual;rs(1:2)=rs(1:2)/P.env.g;r.residualNorm=norm(rs);r.solverConverged=ef>0;r.physicalConverged=p.eomOut.physicalConverged;r.physicalBranchSupported=p.eomOut.physicalBranchSupported;span=bounds(:,2)-bounds(:,1);m=min(z-bounds(:,1),bounds(:,2)-z)./span;r.atLimit=any(m<=1e-7);r.withinLimits=all(z>=bounds(:,1)-1e-10&z<=bounds(:,2)+1e-10)&&p.allocation.withinLimits;r.credible=r.solverConverged&&r.residualNorm<P.trim.residualTolerance&&p.finiteReal&&r.physicalConverged&&r.physicalBranchSupported&&~r.atLimit&&r.withinLimits;
 if r.credible,r.status='CREDIBLE_SOURCE_MAPPED_TRIM';elseif ~r.solverConverged,r.status='SOLVER_NOT_CONVERGED';elseif ~r.physicalConverged,r.status=['PHYSICAL_' p.eomOut.physicalStatus];elseif ~r.withinLimits||r.atLimit,r.status='CONTROL_OR_SEARCH_BOUNDARY_LIMITED';elseif r.residualNorm>=P.trim.residualTolerance,r.status='RESIDUAL_FAILED';else,r.status='NONCREDIBLE_UNCLASSIFIED';end
catch ME,r.status=['FINAL_EVALUATION_ERROR_' ME.identifier];r.finalErrorIdentifier=ME.identifier;end
 function J=obj(y)
  zz=map(y);if any(zz<bounds(:,1))||any(zz>bounds(:,2)),v=max(bounds(:,1)-zz,0)./max(bounds(:,2)-bounds(:,1),eps)+max(zz-bounds(:,2),0)./max(bounds(:,2)-bounds(:,1),eps);J=1e4+1e4*sum(v.^2);return;end
  try,pp=evaluate_point(c,zz,P,modelIdentity);q=pp.residual;q(1:2)=q(1:2)/P.env.g;J=q.'*q;if ~pp.allocation.withinLimits,J=J+1e3;end;if ~pp.eomOut.physicalConverged||~pp.eomOut.physicalBranchSupported,bad=bad+1;ids{end+1}=pp.eomOut.physicalStatus;J=J+1e3;end;if ~isfinite(J)||~isreal(J),J=1e30;end
  catch ME,bad=bad+1;ids{end+1}=ME.identifier;J=1e30;end
 end
end

function p=evaluate_point(c,z,P,modelIdentity)
z=z(:);a=xv15_helicopter_control_allocation(z(3),c.betaM,P);u=[z(2);0;a.cyclicLong;0;0;a.elevator;0];alpha=z(1)-c.gamma;x=zeros(9,1);x(1)=c.V*cos(alpha);x(3)=c.V*sin(alpha);x(8)=z(1);[xd,o]=stage2_tiltrotor_eom(modelIdentity,x,u,c.betaM,P);p=struct('x9',x,'u7',u,'xdot9',xd,'residual',[xd(1);xd(3);xd(5)],'allocation',a,'eomOut',o,'finiteReal',all(isfinite(xd))&&isreal(xd));
end
function row=pack_row(r,v,c,ref,d2r)
row=empty_row();row.speed_kts=v;row.speed_mps=c.V;row.solveReturned=r.solveReturned;row.solverConverged=r.solverConverged;row.physicalConverged=r.physicalConverged;row.physicalBranchSupported=r.physicalBranchSupported;row.credible=r.credible;row.residualNorm=r.residualNorm;row.status=r.status;row.exitflag=r.exitflag;row.invalidEvaluationCount=r.invalidEvaluationCount;if r.solveReturned,z=r.z;p=r.point;row.theta_deg=z(1)/d2r;row.collectiveControl_deg=z(2)/d2r;row.stick_in=z(3);row.theta1sRight_deg=p.allocation.physicalTheta1sRight/d2r;row.elevator_deg=p.allocation.elevator/d2r;row.meanThrustPerRotor_lb=.5*(p.eomOut.rotorLeft.thrust+p.eomOut.rotorRight.thrust)/4.4482216152605;row.theta_error_vs_GTRS_deg=row.theta_deg-ref.theta;row.stick_error_vs_GTRS_in=row.stick_in-ref.stick;row.theta1s_error_vs_GTRS_deg=row.theta1sRight_deg-ref.theta1s;row.elevator_error_vs_GTRS_deg=row.elevator_deg-ref.elev;row.thrust_error_vs_GTRS_pct=100*(row.meanThrustPerRotor_lb-ref.thrust)/ref.thrust;end
end
function r=V1_ref(v,P)
% Values needed only to make the diagnostic directly comparable to V1.
T=readtable(fullfile(fileparts(mfilename('fullpath')),'reference_gtrs_helicopter_trim_kleinhesselink2007.csv'));i=find(abs(T.speed_kts-v)<1e-8,1);if isempty(i),r=struct('theta',NaN,'stick',NaN,'theta1s',NaN,'elev',NaN,'thrust',NaN);else,r=struct('theta',T.theta_gtrs_deg(i),'stick',T.stick_gtrs_in(i),'theta1s',T.theta1s_gtrs_deg(i),'elev',T.elevator_gtrs_deg(i),'thrust',T.thrust_per_rotor_gtrs_lb(i));end
end
function r=empty_report(),r=struct('solveReturned',false,'solverConverged',false,'physicalConverged',false,'physicalBranchSupported',false,'credible',false,'residualNorm',NaN,'status','UNSET','exitflag',NaN,'invalidEvaluationCount',0,'invalidEvaluationIdentifiers',{{}},'z',[NaN;NaN;NaN]);end
function r=empty_row(),r=struct('speed_kts',NaN,'speed_mps',NaN,'solveReturned',false,'solverConverged',false,'physicalConverged',false,'physicalBranchSupported',false,'credible',false,'residualNorm',NaN,'status','','exitflag',NaN,'invalidEvaluationCount',NaN,'theta_deg',NaN,'collectiveControl_deg',NaN,'stick_in',NaN,'theta1sRight_deg',NaN,'elevator_deg',NaN,'meanThrustPerRotor_lb',NaN,'theta_error_vs_GTRS_deg',NaN,'stick_error_vs_GTRS_in',NaN,'theta1s_error_vs_GTRS_deg',NaN,'elevator_error_vs_GTRS_deg',NaN,'thrust_error_vs_GTRS_pct',NaN);end
function r=empty_multistart_row(),r=struct('seedIndex',NaN,'seedTheta_deg',NaN,'seedCollective_deg',NaN,'seedStick_in',NaN,'credible',false,'residualNorm',NaN,'status','','exitflag',NaN,'invalidEvaluationCount',NaN,'theta_deg',NaN,'collectiveControl_deg',NaN,'stick_in',NaN);end
function r=pack_ms(a,i,s,d2r),r=empty_multistart_row();r.seedIndex=i;r.seedTheta_deg=s(1)/d2r;r.seedCollective_deg=s(2)/d2r;r.seedStick_in=s(3);r.credible=a.credible;r.residualNorm=a.residualNorm;r.status=a.status;r.exitflag=a.exitflag;r.invalidEvaluationCount=a.invalidEvaluationCount;if a.solveReturned,r.theta_deg=a.z(1)/d2r;r.collectiveControl_deg=a.z(2)/d2r;r.stick_in=a.z(3);end,end
