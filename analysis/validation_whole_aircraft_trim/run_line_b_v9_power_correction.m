function report=run_line_b_v9_power_correction(outputRoot,baselineRoot)
%RUN_LINE_B_V9_POWER_CORRECTION Fixed-state attribution, then three re-trims.
% Reuses immutable V8 carriers as numerical inputs. Keeps flap40/25, 589RPM,
% rotor model, mass, geometry and convergence criteria. No target curve read.
if nargin<1,outputRoot=fullfile(pwd,'outputs','v9_mast_angle');end
if nargin<2,baselineRoot=fullfile(outputRoot,'baseline_sum');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
componentTests=test_line_b_v9_mast_angle(fullfile(outputRoot,'components'),baselineRoot);
spinnerTests=run_line_b_spinner_tests(fullfile(outputRoot,'spinner_tests'),baselineRoot);
tailTests=run_line_b_coherent_tail_tests(fullfile(outputRoot,'tail_tests'));
addpath(baselineRoot);cleanup=onCleanup(@()rmpath(baselineRoot));
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
carrierRoot=fullfile(root,'docs','validation','v8_grid_review_20260914','carriers');
speeds=[120 110 130];
seeds={fullfile(carrierRoot,'V8_CONTINUATION_IN030_20260914','IN030_V120.00.mat'), ...
 fullfile(carrierRoot,'V7_ANGLE_SCREEN_ADAPTIVE_20260914','IN030','IN030_V110.00.mat'), ...
 fullfile(carrierRoot,'V8_EMPTY_AREA_FIX_20260914','IN030_V130.00.mat')};
fixed=struct([]);trimRows=struct([]);replays=cell(3,1);corrected120='';
for k=1:3
 old=load(seeds{k});assert(old.rec.row.numericallyAccepted);
 P=old.P;rec=old.rec;eo=rec.point.eomOut;beta=rec.betaM_deg*pi/180;
 [x,u]=state_controls(rec);cg=eo.massProperties.cgShift;
 L=eo.rotorLeft;R=eo.rotorRight;
 [Fw0,Mw0,w0]=baseline_wing_model_freefield_consistent(x,u,beta,cg,L,R,P);
 [Fs0,Ms0,s0]=baseline_gtrs_spinner_steady(x,beta,cg,L,R,P);
 flow=rotor_tail_interference_heli(x,beta,L,R,P);
 [Fh0,Mh0,h0]=baseline_gtrs_horizontal_tail_steady(x,u(6),cg,P,flow);
 [Fw,Mw,w]=wing_model_freefield_consistent(x,u,beta,cg,L,R,P);
 [Fs,Ms,s]=gtrs_spinner_steady(x,beta,cg,L,R,P);
 [Fh,Mh,h]=gtrs_horizontal_tail_steady(x,u(6),cg,P,flow);
 cw=component(eo,'wing');cs=component(eo,'hubSpinner');ch=component(eo,'horizontalTail');
 assert(norm(Fw0-cw.F)<1e-6);
 assert(norm(Fs0-cs.F)<1e-6);
 assert(norm(Fh0-ch.F)<1e-6);
 assert(abs(w.freefield.alphaWing_deg-h.wingFreeAlpha_deg)<1e-12);
 deltaF=Fw+Fs+Fh-Fw0-Fs0-Fh0;deltaM=Mw+Ms+Mh-Mw0-Ms0-Mh0;
 nonrotor=eo.FaeroProp-L.F-R.F;
 fixed(k)=struct('speed_kt',speeds(k),'betaM_deg',rec.betaM_deg, ...
  'oldShaftPower_kW',(L.torque+R.torque)*P.rotor.Omega/1000, ...
  'oldWingDragPower_kW',dragpower(Fw0,x),'newWingDragPower_kW',dragpower(Fw,x), ...
  'oldSpinnerDragPower_kW',dragpower(Fs0,x),'newSpinnerDragPower_kW',dragpower(Fs,x), ...
  'oldTailDragPower_kW',dragpower(Fh0,x),'newTailDragPower_kW',dragpower(Fh,x), ...
  'oldNonrotorDragPower_kW',dragpower(nonrotor,x),'newNonrotorDragPower_kW',dragpower(nonrotor+deltaF,x), ...
  'oldSpinnerAlpha_deg',s0.alphaMast_rad*180/pi,'newSpinnerAlpha_deg',s.alphaMast_rad*180/pi, ...
  'oldWingAlpha_deg',w0.freefield.alphaWing_deg,'newWingAlpha_deg',w.freefield.alphaWing_deg, ...
  'oldDownwash_deg',h0.wingDownwash_deg,'newDownwash_deg',h.wingDownwash_deg, ...
  'fixedStateForceImbalance_N',norm(eo.Ftotal+deltaF), ...
  'fixedStateMomentImbalance_Nm',norm(eo.Mtotal+deltaM)); %#ok<AGROW>
 replays{k}=struct('originalCarrier',seeds{k},'x',x,'u',u,'P',P, ...
  'oldWing',w0,'newWing',w,'oldSpinner',s0,'newSpinner',s,'oldTail',h0,'newTail',h);
 % Guard the default stage-2 stack separately: source model opt-ins removed.
 if k==1
  Pl=P;Pl.wing=rmfield(Pl.wing,'coefficientModel');Pl.fuselage=rmfield(Pl.fuselage,'coefficientModel');
  Pl.htail=rmfield(Pl.htail,'modelIdentity');Pl=rmfield(Pl,{'interference','aeroExtras'});
  [F,M]=stage2_total_forces_moments('M1_CONTINUOUS_CORRIGAN_V4',x,u,beta,Pl);
  [Fo,Mo]=baseline_stage2_total_forces_moments('M1_CONTINUOUS_CORRIGAN_V4',x,u,beta,Pl);
  assert(isequal(F,Fo)&&isequal(M,Mo),'Default legacy stack changed.');
 end
 seed=seeds{k};if ~isempty(corrected120),seed=corrected120;end
 pointRoot=fullfile(outputRoot,sprintf('trim_%03dkt',speeds(k)));
 result=run_line_b_v8_continuation(pointRoot,30,speeds(k),seed);
 rr=result.records{1};row=rr.row;
 power=NaN;thrust=NaN;fullResidual=NaN;replayAccepted=false;replay=struct();
 if isfield(rr,'point')
  saved=load(fullfile(pointRoot,sprintf('IN030_V%06.2f.mat',speeds(k))),'P');
  [xr,ur]=state_controls(rr);
  [xdot,actual]=stage2_tiltrotor_eom('M1_CONTINUOUS_CORRIGAN_V4',xr,ur,beta,saved.P);
  scaled=xdot;scaled(1:3)=scaled(1:3)/saved.P.env.g;fullResidual=norm(scaled);
  power=(actual.rotorLeft.torque+actual.rotorRight.torque)*saved.P.rotor.Omega/1000;
  thrust=actual.rotorLeft.thrust+actual.rotorRight.thrust;
  replayAccepted=isreal(xdot)&&all(isfinite(xdot))&&isfinite(power)&& ...
   fullResidual<saved.P.trim.residualTolerance&&actual.physicalConverged&&actual.physicalBranchSupported;
  replay=struct('x',xr,'u',ur,'xdot',xdot,'eomOut',actual,'P',saved.P);
 end
 accepted=row.numericallyAccepted&&replayAccepted;
 trimRows(k)=struct('speed_kt',speeds(k),'nacelle_deg',30,'rpm',P.rotor.Omega*60/(2*pi), ...
  'flap_deg',P.validation.flapDeg,'accepted',accepted,'status',row.status, ...
  'oldPower_kW',fixed(k).oldShaftPower_kW,'newPower_kW',power, ...
  'powerChange_kW',power-fixed(k).oldShaftPower_kW,'totalThrust_N',thrust, ...
  'theta_deg',row.theta_deg,'collective_deg',row.collective_deg,'stick_in',row.stick_in, ...
  'cyclicLong_deg',row.cyclicLong_deg,'elevator_deg',row.elevator_deg, ...
  'trimResidualNorm',row.residualNorm,'replayFullScaledResidualNorm',fullResidual, ...
  'physicalConverged',row.physicalConverged,'physicalBranchSupported',row.physicalBranchSupported, ...
  'withinLimits',row.withinLimits,'minimumBoundMargin',row.minimumBoundMargin, ...
  'alphaClampCount',row.alphaClampCount,'machClampCount',row.machClampCount, ...
  'invalidEvaluationCount',row.invalidEvaluationCount,'evaluationCount',row.evaluationCount, ...
  'elapsed_s',row.elapsed_s); %#ok<AGROW>
 save(fullfile(pointRoot,'V9_INDEPENDENT_REPLAY.mat'),'replay','accepted');
 if k==1&&accepted,corrected120=fullfile(pointRoot,'IN030_V120.00.mat');end
 % Persist each completed result, including failures, before the next solve.
 writetable(struct2table(fixed),fullfile(outputRoot,'V9_FIXED_STATE_COMPONENTS.csv'));
 writetable(struct2table(trimRows),fullfile(outputRoot,'V9_RETRIM_POINTS.csv'));
 save(fullfile(outputRoot,'V9_FIXED_STATE_REPLAYS.mat'),'replays');
end
report=struct('identity','V9_MAST_ANGLE_POWER_CORRECTION','executionIdentity','MATLAB_NATIVE', ...
 'matlabVersion',version,'matlabRelease',version('-release'), ...
 'baselineCommit','7f672db177256fa6f89b4df5f369ba33a49fc920', ...
 'componentTests',componentTests,'spinnerChecks',spinnerTests.meta.checksPassed, ...
 'tailChecks',tailTests.checksPassed,'defaultLegacyStackBitwiseEqual',true, ...
 'requestedPoints',3,'acceptedPoints',sum([trimRows.accepted]), ...
 'targetFitting',false,'flightValidated',false, ...
 'limitations','LINEAR_MAST_INTERPOLATION_ASSUMED;HELI_TAIL_ETA_AND_WAKE_GAIN_RETAINED;ROTOR_POLAR_CLAMPS_REMAIN');
fid=fopen(fullfile(outputRoot,'V9_SUMMARY.json'),'w');assert(fid>=0);
c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(report),'char');clear c;
save(fullfile(outputRoot,'V9_RESULTS.mat'),'report','fixed','trimRows');
disp(struct2table(trimRows));disp(report);
assert(all([trimRows.accepted]),'V9:RejectedTrim','One or more V9 representative trims failed; inspect saved carriers.');
end

function [x,u]=state_controls(rec)
theta=rec.z(1);V=rec.speed_kt*.514444;x=zeros(9,1);
x(1)=V*cos(theta);x(3)=V*sin(theta);x(8)=theta;
u=[rec.z(2);0;rec.point.cyclic;0;0;rec.point.elevator;0];
end
function p=dragpower(F,x),p=-dot(F,x(1:3))/1000;end
function c=component(eo,name)
for j=1:numel(eo.components)
 c=eo.components{j};if strcmp(c.name,name),return;end
end
error('V9:MissingComponent','Missing component %s.',name);
end
