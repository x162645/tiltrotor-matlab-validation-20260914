function T = run_v7_fixed_input_replay(outputRoot)
% Replay accepted V7 controls at fixed states; no trim search or target fitting.
if nargin<1||isempty(outputRoot), outputRoot=fullfile(pwd,'outputs','v7_fixed_replay'); end
if ~exist(outputRoot,'dir'), mkdir(outputRoot); end
speeds=[40 65 85 100]; rows=repmat(empty_row(),numel(speeds),1);
for k=1:numel(speeds)
  s=speeds(k); fn=fullfile(outputRoot,sprintf('POINT_%03dp00kt.mat',s));
  if ~exist(fn,'file'), error('Missing frozen point: %s',fn); end
  A=load(fn,'result','P'); p=A.result.point; P=A.P;
  [~,replay]=stage2_tiltrotor_eom('M1_CONTINUOUS_CORRIGAN_V4',p.x,p.u,0,P);
  orig=p.eomOut.components; L0=orig.rotorLeft; R0=orig.rotorRight;
  L=replay.rotorLeft; R=replay.rotorRight;
  r=empty_row(); r.speed_kt=s; r.origReplay='FROZEN_CONTROL_REPLAY';
  r.maxForceDiff_N=norm(replay.FaeroProp-orig.F); r.maxMomentDiff_Nm=norm(replay.Mtotal-orig.M);
  r.leftThrust_orig_N=L0.thrust; r.leftThrust_replay_N=L.thrust;
  r.rightThrust_orig_N=R0.thrust; r.rightThrust_replay_N=R.thrust;
  r.leftTorque_orig_Nm=L0.torque; r.leftTorque_replay_Nm=L.torque;
  r.rightTorque_orig_Nm=R0.torque; r.rightTorque_replay_Nm=R.torque;
  r.leftPower_orig_kW=L0.torque*P.rotor.Omega/1000; r.leftPower_replay_kW=L.torque*P.rotor.Omega/1000;
  r.rightPower_orig_kW=R0.torque*P.rotor.Omega/1000; r.rightPower_replay_kW=R.torque*P.rotor.Omega/1000;
  r.leftInduced_orig_mps=L0.inducedVelocity; r.leftInduced_replay_mps=L.inducedVelocity;
  r.rightInduced_orig_mps=R0.inducedVelocity; r.rightInduced_replay_mps=R.inducedVelocity;
  r.leftAlphaClamp=L0.alphaClampCount; r.rightAlphaClamp=R0.alphaClampCount;
  r.leftReplayAlphaClamp=L.alphaClampCount; r.rightReplayAlphaClamp=R.alphaClampCount;
  r.leftHlong_N=L.Hlong; r.rightHlong_N=R.Hlong;
  r.pass=(r.maxForceDiff_N<1e-7 && r.maxMomentDiff_Nm<1e-7);
  rows(k)=r;
end
T=struct2table(rows); writetable(T,fullfile(outputRoot,'V7_FIXED_INPUT_REPLAY.csv'));
save(fullfile(outputRoot,'V7_FIXED_INPUT_REPLAY.mat'),'T');
meta=struct('identity','FIXED_ACCEPTED_CONTROLS_NO_TRIM_SEARCH','speeds_kt',speeds,'targetDataRead',false,'allPass',all(T.pass),'newTrimSearch',false);
fid=fopen(fullfile(outputRoot,'V7_FIXED_INPUT_REPLAY.json'),'w'); assert(fid>0); fwrite(fid,jsonencode(meta),'char'); fclose(fid);
end
function r=empty_row()
r=struct('speed_kt',NaN,'origReplay','','maxForceDiff_N',NaN,'maxMomentDiff_Nm',NaN, ...
 'leftThrust_orig_N',NaN,'leftThrust_replay_N',NaN,'rightThrust_orig_N',NaN,'rightThrust_replay_N',NaN, ...
 'leftTorque_orig_Nm',NaN,'leftTorque_replay_Nm',NaN,'rightTorque_orig_Nm',NaN,'rightTorque_replay_Nm',NaN, ...
 'leftPower_orig_kW',NaN,'leftPower_replay_kW',NaN,'rightPower_orig_kW',NaN,'rightPower_replay_kW',NaN, ...
 'leftInduced_orig_mps',NaN,'leftInduced_replay_mps',NaN,'rightInduced_orig_mps',NaN,'rightInduced_replay_mps',NaN, ...
 'leftAlphaClamp',NaN,'rightAlphaClamp',NaN,'leftReplayAlphaClamp',NaN,'rightReplayAlphaClamp',NaN, ...
 'leftHlong_N',NaN,'rightHlong_N',NaN,'pass',false);
end
