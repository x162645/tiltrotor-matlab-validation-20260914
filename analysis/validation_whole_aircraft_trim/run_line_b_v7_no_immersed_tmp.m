function result=run_line_b_v7_no_immersed_tmp(speedKt,outputRoot)
% V7 = V6 plus source-defined, independent two-spinner drag and force arm.
% Initial guesses, optimizer and acceptance thresholds are identical to V6.
% All four original points are prescribed, no result-dependent parameter choice.
% Old scalar reference CSV retained for matched V6/V7 scoring; the new original
% output carrier is not mixed into this physical-change comparison.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
[P,contract]=xv15_helicopter_trim_parameters_v1();P=line_b_coherent_tail_parameters(P);
P.fuselage.coefficientModel='GTRS_LONGITUDINAL_TABLES_V1';
P.validation.gtrsTablePackage='CR166536_DIGITIZED_TABLES_CLOSURE_20260913';
P.rotor.correctionIdentity='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4';P.wing.coefficientModel='GTRS_FREEFIELD_HELI_V6';P.wing.SslipMaxHalf=0;
P.aeroExtras.spinnerModel='GTRS_TWO_SPINNERS_STEADY_HELI_V7';
S=readtable(fullfile(fileparts(mfilename('fullpath')),'original_baseline_trim_seeds.csv'));S=S(S.speed_kt==speedKt,:);assert(height(S)==1);
seed=[S.theta_rad;S.collective_rad;S.stick_in];d2r=pi/180;scale=[2*d2r;10*d2r;1];
P.stage2Numerics.flapInitialLeft=[S.flapL0;S.flapL1c;S.flapL1s];P.stage2Numerics.flapInitialRight=[S.flapR0;S.flapR1c;S.flapR1s];
contract.identity='XV15_SHARED_FREEFIELD_AND_SPINNERS_V7';contract.targetFitting=false;contract.productionPhysicsModified=true;
contract.rotorIdentity='M1_CONTINUOUS_CORRIGAN_V4';contract.rotorCorrectionIdentity=P.rotor.correctionIdentity;
contract.wingIdentity=P.wing.coefficientModel;contract.spinnerIdentity=P.aeroExtras.spinnerModel;
contract.fuselageIdentity=P.fuselage.coefficientModel;
contract.tablePackage=P.validation.gtrsTablePackage;
contract.claimBoundary='NEW_MODEL_REFERENCE_CORRELATION_NOT_INDEPENDENT_FLIGHT_VALIDATION';
bounds=[-35*d2r 35*d2r;P.control.collectiveLim(:).';0 9.6];
opt=optimset('Display','off','MaxIter',P.trim.maxIterations,'MaxFunEvals',12*P.trim.maxIterations,'TolX',1e-8,'TolFun',1e-10);
invalidCount=0;invalidIds={};t0=tic;
[y,cost,exitflag,optimizer]=fminsearch(@objective,zeros(3,1),opt);z=seed+scale.*y;
result=struct('identity',contract.identity,'speed_kt',speedKt,'z',z,'seed',seed,'cost',cost,'exitflag',exitflag, ...
 'optimizer',optimizer,'invalidCount',invalidCount,'invalidIdentifiers',{unique(invalidIds)},'elapsed_s',toc(t0), ...
 'version',version,'release',version('-release'),'contract',contract,'numericallyAccepted',false,'externalAccuracyPassed',false);
try
 point=evaluate(z);r=point.xdot([1 3 5]);r(1:2)=r(1:2)/P.env.g;rn=norm(r);
 margin=min(z-bounds(:,1),bounds(:,2)-z)./(bounds(:,2)-bounds(:,1));
 accepted=exitflag>0&&rn<P.trim.residualTolerance&&point.allocation.withinLimits&&all(margin>1e-7)&& ...
  point.eomOut.physicalConverged&&point.eomOut.physicalBranchSupported&&isreal(point.xdot)&&all(isfinite(point.xdot));
 result.point=point;result.numericallyAccepted=accepted;replay=evaluate(z);result.repeatEvaluationDifference=norm(replay.xdot-point.xdot);
 ref=readtable(fullfile(fileparts(mfilename('fullpath')),'reference_gtrs_helicopter_trim_kleinhesselink2007.csv'));ref=ref(ref.speed_kts==speedKt,:);
 L=point.eomOut.rotorLeft;R=point.eomOut.rotorRight;T=.5*(L.thrust+R.thrust)/4.4482216152605;
 row=table(speedKt,accepted,rn,z(1)/d2r,z(3),point.allocation.elevator/d2r,T, ...
  z(1)/d2r-ref.theta_gtrs_deg,z(3)-ref.stick_gtrs_in,point.allocation.elevator/d2r-ref.elevator_gtrs_deg, ...
  100*(T-ref.thrust_per_rotor_gtrs_lb)/ref.thrust_per_rotor_gtrs_lb,L.alphaClampCount+R.alphaClampCount, ...
  'VariableNames',{'speed_kt','numericallyAccepted','residualNorm','theta_deg','stick_in','elevator_deg','thrustPerRotor_lbf', ...
  'thetaDifference_deg','stickDifference_in','elevatorDifference_deg','thrustDifference_pct','alphaClampCount'});
 writetable(row,fullfile(outputRoot,'V7_TRIM_POINT.csv'));disp(row);result.summary=row;
 sp=point.eomOut.components.hubSpinner;
 result.spinnerAtTrim=struct('X_lbf',sp.F(1)/4.4482216152605,'Z_lbf',sp.F(3)/4.4482216152605, ...
 'M_lbfft',sp.M(2)/1.3558179483314,'induced_mps',sp.meanInduced_mps,'dragArea_m2',sp.effectiveDragArea_m2);
catch ME,result.finalErrorIdentifier=ME.identifier;result.finalErrorMessage=ME.message;fprintf('FINAL_FAILED %s %s\n',ME.identifier,ME.message);end
[~,h]=system('git rev-parse HEAD');result.commit=strtrim(h);save(fullfile(outputRoot,'V7_TRIM_RESULTS.mat'),'result','P');
meta=result;for name={'point','summary'},if isfield(meta,name{1}),meta=rmfield(meta,name{1});end,end
fid=fopen(fullfile(outputRoot,'V7_TRIM_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta));clear c;
 function p=evaluate(zz)
  a=xv15_helicopter_control_allocation(zz(3),0,P);u=[zz(2);0;a.cyclicLong;0;0;a.elevator;0];x=zeros(9,1);V=speedKt*.514444;
  x(1)=V*cos(zz(1));x(3)=V*sin(zz(1));x(8)=zz(1);
  [xdot,e]=stage2_tiltrotor_eom('M1_CONTINUOUS_CORRIGAN_V4',x,u,0,P);p=struct('x',x,'u',u,'xdot',xdot,'eomOut',e,'allocation',a);
 end
 function J=objective(yv)
  zz=seed+scale.*yv;
  if any(zz<bounds(:,1))||any(zz>bounds(:,2))
   d=max(bounds(:,1)-zz,0)./(bounds(:,2)-bounds(:,1))+max(zz-bounds(:,2),0)./(bounds(:,2)-bounds(:,1));J=1e4+1e4*sum(d.^2);return;
  end
  try
   p=evaluate(zz);r=p.xdot([1 3 5]);r(1:2)=r(1:2)/P.env.g;J=r.'*r;
   if ~p.allocation.withinLimits,J=J+1e3;end
   if ~p.eomOut.physicalConverged||~p.eomOut.physicalBranchSupported,invalidCount=invalidCount+1;invalidIds{end+1}=p.eomOut.physicalStatus;J=J+1e3;end
   if ~isfinite(J)||~isreal(J),error('run_line_b_v7_trim_case:NonfiniteCost','Invalid cost');end
  catch ME,invalidCount=invalidCount+1;invalidIds{end+1}=ME.identifier;J=1e30;end
 end
end
