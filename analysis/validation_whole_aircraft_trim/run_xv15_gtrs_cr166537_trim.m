function results = run_xv15_gtrs_cr166537_trim(outputRoot)
%RUN_XV15_GTRS_CR166537_TRIM Apply verified CR-166536 scalar inputs and
% compare the four CR-166537 helicopter reference points.
if nargin<1 || isempty(outputRoot), outputRoot=fullfile(pwd,'results','xv15_gtrs_cr166537_trim'); end
if ~exist(outputRoot,'dir'), mkdir(outputRoot); end
[P,contract]=xv15_gtrs_parameters_v1('CR166537_HELI');
P.trim.display='off'; P.trim.maxIterations=500; P.trim.maxFunctionEvaluations=6000;
modelIdentity='M1_EVIDENCE_V1_PROPAGATION'; d2r=pi/180; knot2mps=0.514444;
T=readtable(fullfile(fileparts(mfilename('fullpath')),'reference_gtrs_helicopter_trim_kleinhesselink2007.csv'));
speeds=[40 60 80 100]; rows=[]; last=[];
for k=1:numel(speeds)
 c=struct('name',sprintf('CR166537_%03dKT',speeds(k)),'V',speeds(k)*knot2mps,'betaM',0,'gamma',0);
 if isempty(last), seed=[0;P.validation.initialTheta75_deg*d2r-P.rotor.twistTip*(.75-P.rotor.rootCut)/(1-P.rotor.rootCut);4.8]; else, seed=last; end
 [z,rep]=solve_point(c,seed,P,modelIdentity);
 row=struct('speed_kts',speeds(k),'speed_mps',c.V,'credible',rep.credible,'status',rep.status,'residualNorm',rep.residualNorm,'theta_deg',NaN,'stick_in',NaN,'cyclic_deg',NaN,'elevator_deg',NaN,'thrust_lb',NaN,'theta_error_deg',NaN,'stick_error_in',NaN,'cyclic_error_deg',NaN,'elevator_error_deg',NaN,'thrust_error_pct',NaN);
 if rep.solveReturned
  row.theta_deg=z(1)/d2r; row.stick_in=z(3); row.cyclic_deg=rep.point.allocation.cyclicLong/d2r; row.elevator_deg=rep.point.allocation.elevator/d2r; row.thrust_lb=.5*(rep.point.eomOut.rotorLeft.thrust+rep.point.eomOut.rotorRight.thrust)/4.4482216152605;
  q=T(T.speed_kts==speeds(k),:); row.theta_error_deg=row.theta_deg-q.theta_gtrs_deg; row.stick_error_in=row.stick_in-q.stick_gtrs_in; row.cyclic_error_deg=row.cyclic_deg-q.theta1s_gtrs_deg; row.elevator_error_deg=row.elevator_deg-q.elevator_gtrs_deg; row.thrust_error_pct=100*(row.thrust_lb-q.thrust_per_rotor_gtrs_lb)/q.thrust_per_rotor_gtrs_lb;
  if rep.credible, last=z; end
 end
 rows=[rows;row]; %#ok<AGROW>
end
points=struct2table(rows); writetable(points,fullfile(outputRoot,'CR166537_GTRS_SCALAR_TRIM_COMPARISON.csv'));
mask=points.credible; summary=table(sum(mask),height(points),mean(abs(points.theta_error_deg(mask))),mean(abs(points.stick_error_in(mask))),mean(abs(points.cyclic_error_deg(mask))),mean(abs(points.elevator_error_deg(mask))),mean(abs(points.thrust_error_pct(mask))),'VariableNames',{'credibleCount','pointCount','thetaMAE_deg','stickMAE_in','cyclicMAE_deg','elevatorMAE_deg','thrustMAPE_pct'}); writetable(summary,fullfile(outputRoot,'CR166537_GTRS_SCALAR_TRIM_SUMMARY.csv'));
results=struct('points',points,'summary',summary,'contract',contract); save(fullfile(outputRoot,'CR166537_GTRS_SCALAR_TRIM_RESULTS.mat'),'results'); disp(points); disp(summary);
end
function [z,r]=solve_point(c,seed,P,modelIdentity)
d2r=pi/180; bounds=[-35*d2r,35*d2r;P.control.collectiveLim(:).';0,9.6]; scale=[2*d2r;10*d2r;1]; opt=optimset('Display','off','MaxIter',500,'MaxFunEvals',6000,'TolX',1e-8,'TolFun',1e-10); y0=ones(3,1); map=@(y)seed(:)+scale.*(y(:)-1); bad=0; ids={}; [y,~,ef,~]=fminsearch(@obj,y0,opt); z=map(y); r=struct('solveReturned',false,'credible',false,'status','SOLVER_NOT_CONVERGED','residualNorm',Inf,'point',[]);
 try, p=evaluate(c,z,P,modelIdentity); rs=p.residual;rs(1:2)=rs(1:2)/P.env.g; r.solveReturned=true;r.point=p;r.residualNorm=norm(rs);r.credible=ef>0&&r.residualNorm<P.trim.residualTolerance&&p.eomOut.physicalConverged&&p.eomOut.physicalBranchSupported&&p.allocation.withinLimits&&all(z>=bounds(:,1))&&all(z<=bounds(:,2)); if r.credible,r.status='CREDIBLE'; elseif ~p.eomOut.physicalBranchSupported,r.status='PHYSICAL_BRANCH_FAILED'; elseif ef<=0,r.status='SOLVER_NOT_CONVERGED'; else,r.status='RESIDUAL_FAILED'; end; catch ME,r.status=['ERROR_' ME.identifier]; end
 function J=obj(y),zz=map(y);if any(zz<bounds(:,1))||any(zz>bounds(:,2)),J=1e8;return;end;try,pp=evaluate(c,zz,P,modelIdentity); q=pp.residual;q(1:2)=q(1:2)/P.env.g;J=q.'*q;if ~pp.eomOut.physicalConverged||~pp.eomOut.physicalBranchSupported,J=J+1e3;end;catch,J=1e8;end; end
end
function p=evaluate(c,z,P,m), a=xv15_helicopter_control_allocation(z(3),c.betaM,P); u=[z(2);0;a.cyclicLong;0;0;a.elevator;0]; x=zeros(9,1); x(1)=c.V*cos(z(1)); x(3)=c.V*sin(z(1)); x(8)=z(1); [xd,o]=stage2_tiltrotor_eom(m,x,u,c.betaM,P); p=struct('residual',[xd(1);xd(3);xd(5)],'allocation',a,'eomOut',o); end
