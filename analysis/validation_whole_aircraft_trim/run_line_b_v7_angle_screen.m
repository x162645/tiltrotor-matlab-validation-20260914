function results=run_line_b_v7_angle_screen(outputRoot,betaM_deg,speeds_kt)
%RUN_LINE_B_V7_ANGLE_SCREEN Angle-aware source-constrained trim screen.
%
% This runner deliberately does not modify or resume the frozen V7 speed
% sweep.  It uses the same V7 parameter stack, rotor correction, control
% allocation and zero-immersed-wing contract, while exposing nacelle angle
% as an explicit independent variable.  It is intended to find angle/domain
% failures before any global optimization is accepted.
%
% Inputs (optional):
%   outputRoot : output directory (one run, one immutable configuration)
%   betaM_deg  : nacelle angles, default [90 60 30 0]
%   speeds_kt  : forward speeds, default [40 60 80 100]
%
% Outputs: ANGLE_SCREEN_POINTS.csv, ANGLE_SCREEN_SUMMARY.json and MAT
% records.  No external target is read and no external-accuracy claim is
% made by this diagnostic.
if nargin<1||isempty(outputRoot),outputRoot=fullfile(pwd,'outputs','v7_angle_screen');end
if nargin<2||isempty(betaM_deg),betaM_deg=[90 60 30 0];end
if nargin<3||isempty(speeds_kt),speeds_kt=[40 60 80 100];end
betaM_deg=unique(betaM_deg(:).','stable');speeds_kt=unique(speeds_kt(:).','stable');
assert(all(isfinite(betaM_deg))&&all(betaM_deg>=0)&all(betaM_deg<=90), ...
    'betaM_deg must lie in [0,90].');
assert(all(isfinite(speeds_kt))&&all(speeds_kt>0),'speeds_kt must be positive.');
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
here=fileparts(mfilename('fullpath'));repo=fileparts(fileparts(here));
[P,contract]=xv15_helicopter_trim_parameters_v1();P=line_b_coherent_tail_parameters(P);
P.fuselage.coefficientModel='GTRS_LONGITUDINAL_TABLES_V1';
P.validation.gtrsTablePackage='CR166536_DIGITIZED_TABLES_CLOSURE_20260913';
P.rotor.correctionIdentity='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4';
P.wing.coefficientModel='GTRS_FREEFIELD_HELI_V6';P.wing.SslipMaxHalf=0;
P.aeroExtras.spinnerModel='GTRS_TWO_SPINNERS_STEADY_HELI_V7';
identity='V7_ANGLE_SCREEN_ZERO_IMMERSED_V1';modelIdentity='M1_CONTINUOUS_CORRIGAN_V4';
config=struct('identity',identity,'modelIdentity',modelIdentity,'betaM_deg',betaM_deg,...
 'speedOrder_kt',speeds_kt,'solver','FMINSEARCH_BOUNDED_OBJECTIVE','targetDataRead',false,...
 'targetFitting',false,'wingImmersedArea_m2',0,'parameterStack','V7_SPEED_SWEEP_V2',...
 'claim','ANGLE_DOMAIN_SCREEN_ONLY_NO_EXTERNAL_FLIGHT_VALIDATION');
contract.identity=identity;contract.targetFitting=false;contract.productionPhysicsModified=true;
contract.rotorIdentity='M1_CONTINUOUS_CORRIGAN_V4';contract.wingIdentity=P.wing.coefficientModel;
contract.fuselageIdentity=P.fuselage.coefficientModel;contract.spinnerIdentity=P.aeroExtras.spinnerModel;
contract.claimBoundary=config.claim;
seedTable=readtable(fullfile(here,'original_baseline_trim_seeds.csv'));
d2r=pi/180; bounds=[-35*d2r 35*d2r;P.control.collectiveLim(:).';0 9.6];
rows=repmat(empty_row(),0,1);records=cell(0,1);
for ib=1:numel(betaM_deg)
  beta=betaM_deg(ib)*d2r;
  for iv=1:numel(speeds_kt)
    Vkt=speeds_kt(iv); tag=sprintf('B%03.0f_V%06.2f',betaM_deg(ib),Vkt);
    seed=make_seed(seedTable,Vkt,P);P.stage2Numerics.flapInitialLeft=seed.flapL;P.stage2Numerics.flapInitialRight=seed.flapR;
    scale=[2*d2r;10*d2r;1]; t0=tic; invalid=0; ids={};
    opt=optimset('Display','off','MaxIter',P.trim.maxIterations,'MaxFunEvals',12*P.trim.maxIterations,'TolX',1e-8,'TolFun',1e-10); evals=0;
    try
      [yv,cost,ef,optimizer]=fminsearch(@objective,zeros(3,1),opt); z=seed.z+scale.*yv;
      p=evaluate(z); r=p.xdot([1 3 5]);r(1:2)=r(1:2)/P.env.g; rn=norm(r);
      margin=min(z-bounds(:,1),bounds(:,2)-z)./(bounds(:,2)-bounds(:,1));
      L=p.eomOut.rotorLeft;R=p.eomOut.rotorRight;alloc=p.allocation;
      accepted=ef>0&&rn<P.trim.residualTolerance&&alloc.withinLimits&&all(margin>1e-7)&&...
        p.eomOut.physicalConverged&&p.eomOut.physicalBranchSupported&&p.finiteReal;
      row=empty_row();row.betaM_deg=betaM_deg(ib);row.speed_kt=Vkt;row.speed_mps=Vkt*.514444;
      row.status=ternary(accepted,'NUMERICALLY_ACCEPTED_SOURCE_SUBSET','NOT_ACCEPTED');row.numericallyAccepted=accepted;
      row.residualNorm=rn;row.theta_deg=z(1)/d2r;row.collectiveControl_deg=z(2)/d2r;row.stick_in=z(3);
      row.stick_pct=100*z(3)/9.6;row.cyclicLong_deg=alloc.cyclicLong/d2r;row.elevator_deg=alloc.elevator/d2r;
      row.thrustLeft_N=L.thrust;row.thrustRight_N=R.thrust;row.thrustPerRotor_lbf=.5*(L.thrust+R.thrust)/4.4482216152605;
      row.totalRotorPower_kW=(L.torque+R.torque)*P.rotor.Omega/1000;
      row.shaftPowerLeft_kW=L.torque*P.rotor.Omega/1000;row.shaftPowerRight_kW=R.torque*P.rotor.Omega/1000;
      row.alphaClampCount=L.alphaClampCount+R.alphaClampCount;row.machClampCount=field_or(L,'machClampCount',0)+field_or(R,'machClampCount',0);
      row.physicalConverged=p.eomOut.physicalConverged;row.physicalBranchSupported=p.eomOut.physicalBranchSupported;
      row.withinLimits=alloc.withinLimits;row.minimumBoundMargin=min(margin);row.invalidEvaluationCount=invalid;row.evaluationCount=p.evalCount;row.elapsed_s=toc(t0);
      rec=struct('identity',identity,'betaM_deg',betaM_deg(ib),'speed_kt',Vkt,'z',z,'seed',seed.z,'cost',cost,'exitflag',ef,'optimizer',optimizer,'row',row,'point',p,'invalidIdentifiers',{unique(ids)});
    catch ME
      row=empty_row();row.betaM_deg=betaM_deg(ib);row.speed_kt=Vkt;row.speed_mps=Vkt*.514444;row.status=['ERROR_' ME.identifier];row.errorMessage=ME.message;row.elapsed_s=toc(t0);
      rec=struct('identity',identity,'betaM_deg',betaM_deg(ib),'speed_kt',Vkt,'row',row,'errorIdentifier',ME.identifier,'errorMessage',ME.message);
    end
    rows(end+1,1)=row;records{end+1,1}=rec; %#ok<AGROW>
    save(fullfile(outputRoot,[tag '.mat']),'rec','P','config');
  end
end
points=struct2table(rows,'AsArray',true);writetable(points,fullfile(outputRoot,'ANGLE_SCREEN_POINTS.csv'));
summary=struct('identity',identity,'betaM_deg',betaM_deg,'speedOrder_kt',speeds_kt,'requestedPointCount',height(points),...
 'acceptedCount',sum(points.numericallyAccepted),'rejectedCount',sum(~points.numericallyAccepted),...
 'acceptedFraction',sum(points.numericallyAccepted)/max(height(points),1),'claim',config.claim,'executionIdentity','MATLAB_NATIVE');
write_json(fullfile(outputRoot,'ANGLE_SCREEN_SUMMARY.json'),summary);
meta=struct('config',config,'contract',contract,'repo',repo,'createdUTC',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss')));
write_json(fullfile(outputRoot,'ANGLE_SCREEN_MANIFEST.json'),meta);results=struct('config',config,'contract',contract,'points',points,'summary',summary,'records',{records});
save(fullfile(outputRoot,'ANGLE_SCREEN_RESULTS.mat'),'results','P','config');disp(points);disp(summary);
 function p=evaluate(zz)
  evals=evals+1; p=struct();p.evalCount=evals; a=xv15_helicopter_control_allocation(zz(3),beta,P);
  u=[zz(2);0;a.cyclicLong;0;0;a.elevator;0]; x=zeros(9,1);V=Vkt*.514444;x(1)=V*cos(zz(1));x(3)=V*sin(zz(1));x(8)=zz(1);
  [xdot,e]=stage2_tiltrotor_eom(modelIdentity,x,u,beta,P);p.x=x;p.u=u;p.xdot=xdot;p.eomOut=e;p.allocation=a;p.finiteReal=isreal(xdot)&&all(isfinite(xdot));
 end
 function J=objective(yv)
  zz=seed.z+scale.*yv;
  if any(zz<bounds(:,1))||any(zz>bounds(:,2)),d=max(bounds(:,1)-zz,0)./(bounds(:,2)-bounds(:,1))+max(zz-bounds(:,2),0)./(bounds(:,2)-bounds(:,1));J=1e4+1e4*sum(d.^2);return;end
  try
   pp=evaluate(zz);rr=pp.xdot([1 3 5]);rr(1:2)=rr(1:2)/P.env.g;J=rr.'*rr;
   if ~pp.allocation.withinLimits,J=J+1e3;end
   if ~pp.eomOut.physicalConverged||~pp.eomOut.physicalBranchSupported,invalid=invalid+1;ids{end+1}=pp.eomOut.physicalStatus;J=J+1e3;end
   if ~isfinite(J)||~isreal(J),error('run_line_b_v7_angle_screen:NonfiniteCost','Invalid objective');end
  catch ME,invalid=invalid+1;ids{end+1}=ME.identifier;J=1e30;end
  end
 end
end

function s=make_seed(T,V,P)
 [~,i]=min(abs(T.speed_kt-V));r=T(i,:);s=struct('z',[r.theta_rad;r.collective_rad;r.stick_in],...
  'flapL',[r.flapL0;r.flapL1c;r.flapL1s],'flapR',[r.flapR0;r.flapR1c;r.flapR1s]);
end
function r=empty_row()
 r=struct('betaM_deg',NaN,'speed_kt',NaN,'speed_mps',NaN,'status','','numericallyAccepted',false,'residualNorm',NaN,'theta_deg',NaN,'collectiveControl_deg',NaN,'stick_in',NaN,'stick_pct',NaN,'cyclicLong_deg',NaN,'elevator_deg',NaN,'thrustLeft_N',NaN,'thrustRight_N',NaN,'thrustPerRotor_lbf',NaN,'totalRotorPower_kW',NaN,'shaftPowerLeft_kW',NaN,'shaftPowerRight_kW',NaN,'alphaClampCount',NaN,'machClampCount',NaN,'physicalConverged',false,'physicalBranchSupported',false,'withinLimits',false,'minimumBoundMargin',NaN,'invalidEvaluationCount',NaN,'evaluationCount',NaN,'elapsed_s',NaN,'errorMessage','');
end
function out=ternary(c,a,b),if c,out=a;else,out=b;end,end
function v=field_or(s,n,d),if isfield(s,n)&&~isempty(s.(n)),v=s.(n);else,v=d;end,end
function write_json(path,s),fid=fopen(path,'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(s),'char');end
