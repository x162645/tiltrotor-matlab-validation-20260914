function results = run_line_b_v7_angle_screen_source_modes(outputRoot,nacelleDeg,speedsKt)
%RUN_LINE_B_V7_ANGLE_SCREEN_SOURCE_MODES Source-backed trim-mode screen.
%
% This is an analysis-only companion to run_line_b_v7_angle_screen.  It
% keeps the production stage-2 equations fixed while removing one known
% confounder: airplane-mode trim is solved with an independent elevator
% command and zero cyclic, instead of forcing both through a helicopter
% stick mixer.  Helicopter and intermediate angles use the source-backed
% CR-166536 Table 8a-I cyclic gearing allocator.  No target output is read
% and no parameters are fitted.
%
% Paper convention: nacelle i_n=90 deg helicopter, i_n=0 deg airplane.
% Internal betaM=90-i_n (degrees), as required by production equations.

if nargin<1||isempty(outputRoot), outputRoot=fullfile(pwd,'outputs','v7_angle_screen_source_modes'); end
if nargin<2||isempty(nacelleDeg), nacelleDeg=[90 60 30 0]; end
if nargin<3||isempty(speedsKt), speedsKt=[40 80 120]; end
nacelleDeg=unique(nacelleDeg(:).','stable'); speedsKt=speedsKt(:).';
assert(all(isfinite(nacelleDeg))&&all(nacelleDeg>=0)&&all(nacelleDeg<=90));
assert(all(isfinite(speedsKt))&&all(speedsKt>0));
if ~exist(outputRoot,'dir'), mkdir(outputRoot); end
here=fileparts(mfilename('fullpath'));
[P,contract]=xv15_helicopter_trim_parameters_v1(); P=line_b_coherent_tail_parameters(P);
P.fuselage.coefficientModel='GTRS_LONGITUDINAL_TABLES_V1';
P.validation.gtrsTablePackage='CR166536_DIGITIZED_TABLES_CLOSURE_20260913';
P.rotor.correctionIdentity='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4';
P.wing.coefficientModel='GTRS_FREEFIELD_HELI_V6'; P.wing.SslipMaxHalf=0;
P.aeroExtras.spinnerModel='GTRS_TWO_SPINNERS_STEADY_HELI_V7';
modelIdentity='M1_CONTINUOUS_CORRIGAN_V4'; identity='V7_ANGLE_SCREEN_SOURCE_MODES_V1';
seedTable=readtable(fullfile(here,'original_baseline_trim_seeds.csv')); d2r=pi/180;
rows=repmat(empty_row(),0,1); records=cell(0,1);
for ia=1:numel(nacelleDeg)
 betaDeg=90-nacelleDeg(ia); beta=betaDeg*d2r;
 for iv=1:numel(speedsKt)
  Vkt=speedsKt(iv); mode=mode_for_beta(betaDeg); seed=make_seed(seedTable,Vkt);
  t0=tic; evals=0; invalid=0; ids={};
  if strcmp(mode,'airplane_independent_elevator')
   z0=[seed.theta; seed.collective; 0]; scale=[2*d2r;10*d2r;2*d2r];
   bounds=[-35*d2r 35*d2r; P.control.collectiveLim(:).'; P.control.elevatorLim(:).'];
  else
   z0=[seed.theta; seed.collective; seed.stick]; scale=[2*d2r;10*d2r;1];
   bounds=[-35*d2r 35*d2r; P.control.collectiveLim(:).'; 0 9.6];
  end
  opt=optimset('Display','off','MaxIter',P.trim.maxIterations,'MaxFunEvals',12*P.trim.maxIterations,'TolX',1e-8,'TolFun',1e-10);
  try
   [y,cost,ef,optimizer]=fminsearch(@objective,ones(numel(z0),1),opt); z=z0+scale.*(y-1); p=evaluate(z);
   rr=p.xdot([1 3 5]); rr(1:2)=rr(1:2)/P.env.g; rn=norm(rr);
   if strcmp(mode,'airplane_independent_elevator'), within=p.elevator>=P.control.elevatorLim(1)&&p.elevator<=P.control.elevatorLim(2); ctrl3=p.elevator/d2r; stick=NaN; else, within=p.alloc.withinLimits; ctrl3=p.stick; stick=p.stick; end
   m=min(z-bounds(:,1),bounds(:,2)-z)./(bounds(:,2)-bounds(:,1));
   accepted=ef>0&&rn<P.trim.residualTolerance&&within&&all(m>1e-7)&&p.eomOut.physicalConverged&&p.eomOut.physicalBranchSupported&&p.finiteReal;
   row=empty_row(); row.nacelle_deg=nacelleDeg(ia); row.betaM_deg=betaDeg; row.speed_kt=Vkt; row.speed_mps=Vkt*.514444; row.mode=mode; row.status=ternary(accepted,'NUMERICALLY_ACCEPTED_SOURCE_MODE','NOT_ACCEPTED'); row.numericallyAccepted=accepted; row.residualNorm=rn; row.theta_deg=z(1)/d2r; row.collective_deg=z(2)/d2r; row.command3=ctrl3; row.stick_in=stick; row.cyclicLong_deg=p.cyclic/d2r; row.elevator_deg=p.elevator/d2r; row.alphaClampCount=field_or(p.eomOut.rotorLeft,'alphaClampCount',0)+field_or(p.eomOut.rotorRight,'alphaClampCount',0); row.machClampCount=field_or(p.eomOut.rotorLeft,'machClampCount',0)+field_or(p.eomOut.rotorRight,'machClampCount',0); row.physicalConverged=p.eomOut.physicalConverged; row.physicalBranchSupported=p.eomOut.physicalBranchSupported; row.withinLimits=within; row.minimumBoundMargin=min(m); row.invalidEvaluationCount=invalid; row.evaluationCount=evals; row.elapsed_s=toc(t0);
   rec=struct('identity',identity,'nacelle_deg',nacelleDeg(ia),'betaM_deg',betaDeg,'speed_kt',Vkt,'mode',mode,'z',z,'seed',z0,'cost',cost,'exitflag',ef,'optimizer',optimizer,'row',row,'point',p,'invalidIdentifiers',{unique(ids)});
  catch ME
   row=empty_row(); row.nacelle_deg=nacelleDeg(ia); row.betaM_deg=betaDeg; row.speed_kt=Vkt; row.speed_mps=Vkt*.514444; row.mode=mode; row.status=['ERROR_' ME.identifier]; row.errorMessage=ME.message; row.elapsed_s=toc(t0); rec=struct('identity',identity,'row',row,'errorIdentifier',ME.identifier,'errorMessage',ME.message);
  end
  rows(end+1,1)=row; records{end+1,1}=rec; save(fullfile(outputRoot,sprintf('IN%03.0f_V%06.2f.mat',nacelleDeg(ia),Vkt)),'rec','P');
 end
end
points=struct2table(rows,'AsArray',true); writetable(points,fullfile(outputRoot,'ANGLE_SCREEN_SOURCE_MODE_POINTS.csv'));
summary=struct('identity',identity,'nacelle_deg',nacelleDeg,'betaM_internal_deg',90-nacelleDeg,'speedOrder_kt',speedsKt,'requestedPointCount',height(points),'acceptedCount',sum(points.numericallyAccepted),'rejectedCount',sum(~points.numericallyAccepted),'acceptedFraction',sum(points.numericallyAccepted)/max(height(points),1),'claim','ANGLE_MODE_DIAGNOSTIC_NO_EXTERNAL_FLIGHT_VALIDATION','executionIdentity','MATLAB_NATIVE');
write_json(fullfile(outputRoot,'ANGLE_SCREEN_SOURCE_MODE_SUMMARY.json'),summary); results=struct('points',points,'summary',summary,'records',{records}); save(fullfile(outputRoot,'ANGLE_SCREEN_SOURCE_MODE_RESULTS.mat'),'results','P','summary'); disp(points); disp(summary);

 function p=evaluate(z)
  evals=evals+1; p=struct(); V=Vkt*.514444; theta=z(1); x=zeros(9,1); x(1)=V*cos(theta); x(3)=V*sin(theta); x(8)=theta;
  if strcmp(mode,'airplane_independent_elevator'), p.stick=NaN; p.cyclic=0; p.elevator=z(3); p.alloc=struct('withinLimits',p.elevator>=P.control.elevatorLim(1)&&p.elevator<=P.control.elevatorLim(2)); u=[z(2);0;0;0;0;p.elevator;0];
  else, p.stick=z(3); p.alloc=xv15_gtrs_control_allocation_source(z(3),beta,P); p.cyclic=p.alloc.cyclicLong; p.elevator=p.alloc.elevator; u=[z(2);0;p.cyclic;0;0;p.elevator;0]; end
  [p.xdot,p.eomOut]=stage2_tiltrotor_eom(modelIdentity,x,u,beta,P); p.finiteReal=isreal(p.xdot)&&all(isfinite(p.xdot));
 end
 function J=objective(y)
  z=z0+scale.*(y-1); if any(z<bounds(:,1))||any(z>bounds(:,2)), d=max(bounds(:,1)-z,0)./(bounds(:,2)-bounds(:,1))+max(z-bounds(:,2),0)./(bounds(:,2)-bounds(:,1)); J=1e4+1e4*sum(d.^2); return; end
  try, q=evaluate(z); r=q.xdot([1 3 5]); r(1:2)=r(1:2)/P.env.g; J=r.'*r; if ~q.eomOut.physicalConverged, invalid=invalid+1; ids{end+1}=q.eomOut.physicalStatus; J=J+1e3; end; if ~isfinite(J)||~isreal(J), J=1e30; end; catch ME, invalid=invalid+1; ids{end+1}=ME.identifier; J=1e30; end
 end
end

function mode=mode_for_beta(b)
if b>=89.999, mode='airplane_independent_elevator'; elseif b<=0.001, mode='helicopter_source_stick'; else, mode='conversion_source_stick'; end
end
function s=make_seed(T,V), [~,i]=min(abs(T.speed_kt-V)); r=T(i,:); s.theta=r.theta_rad; s.collective=r.collective_rad; s.stick=r.stick_in; end
function r=empty_row(), r=struct('nacelle_deg',NaN,'betaM_deg',NaN,'speed_kt',NaN,'speed_mps',NaN,'mode','','status','','numericallyAccepted',false,'residualNorm',NaN,'theta_deg',NaN,'collective_deg',NaN,'command3',NaN,'stick_in',NaN,'cyclicLong_deg',NaN,'elevator_deg',NaN,'alphaClampCount',NaN,'machClampCount',NaN,'physicalConverged',false,'physicalBranchSupported',false,'withinLimits',false,'minimumBoundMargin',NaN,'invalidEvaluationCount',NaN,'evaluationCount',NaN,'elapsed_s',NaN,'errorMessage',''); end
function v=field_or(s,n,d), if isfield(s,n)&&~isempty(s.(n)),v=s.(n);else,v=d;end,end
function out=ternary(c,a,b),if c,out=a;else,out=b;end,end
function write_json(path,s),fid=fopen(path,'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(s),'char');end
