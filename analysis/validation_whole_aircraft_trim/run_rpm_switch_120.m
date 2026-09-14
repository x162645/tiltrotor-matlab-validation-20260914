function result=run_rpm_switch_120(inputFile,outputDir)
%RUN_RPM_SWITCH_120 Fixed-state RPM discrimination test.
% All state, controls, geometry, correction identity and flap seeds come
% from the accepted 30deg/120kt carrier. Only P.rotor.Omega changes 589->517.
% The decision thresholds are frozen before evaluation:
% <=950 kW primary; >1200 kW RPM ruled out; otherwise partial.
if nargin<1||isempty(inputFile)
 inputFile='outputs/V8_CONTINUATION_IN030_20260914/IN030_V120.00.mat';
end
if nargin<2||isempty(outputDir),outputDir='outputs/V8_RPM_SWITCH_20260914';end
if ~exist(outputDir,'dir'),mkdir(outputDir);end
S=load(inputFile);assert(S.rec.row.numericallyAccepted,'Carrier must be accepted.');
z=S.rec.z;P0=S.P;V=S.rec.row.speed_mps;beta=S.rec.row.betaM_deg*pi/180;
x=zeros(9,1);x(1)=V*cos(z(1));x(3)=V*sin(z(1));x(8)=z(1);
if strcmp(S.rec.mode,'airplane_independent_elevator'),u=[z(2);0;0;0;0;z(3);0];
else,a=xv15_gtrs_control_allocation_source(z(3),beta,P0);u=[z(2);0;a.cyclicLong;0;0;a.elevator;0];end
rpms=[589 517];rows=struct([]);details=cell(2,1);
for k=1:2
 P=P0;P.rotor.Omega=rpms(k)*2*pi/60;
 [xdot,out]=stage2_tiltrotor_eom('M1_CONTINUOUS_CORRIGAN_V4',x,u,beta,P);
 r=xdot([1 3 5]);r(1:2)=r(1:2)/P.env.g;
 power=(out.rotorLeft.torque+out.rotorRight.torque)*P.rotor.Omega/1000;
 row=struct('rpm',rpms(k),'power_kW',power,'power_ratio_to_589',NaN,...
  'deltaPower_kW',NaN,'residualNorm',norm(r),'maxAbsXdot',max(abs(xdot)),...
  'alphaClampCount',out.rotorLeft.alphaClampCount+out.rotorRight.alphaClampCount,...
  'physicalConverged',out.physicalConverged,'physicalBranchSupported',out.physicalBranchSupported,...
  'fixedState',true,'fixedControls',true,'onlyChanged','P.rotor.Omega');
 if k==1,rows=row;else,rows(k,1)=row;end
 details{k}=out;
end
rows(2).power_ratio_to_589=rows(2).power_kW/rows(1).power_kW;
rows(2).deltaPower_kW=rows(2).power_kW-rows(1).power_kW;
rows(1).power_ratio_to_589=1;rows(1).deltaPower_kW=0;
if rows(2).power_kW<=950,decision='RPM_PRIMARY_CAUSE';
elseif rows(2).power_kW>1200,decision='RPM_RULED_OUT_CHECK_EFFICIENCY_AND_ALPHA_CLIPPING';
else,decision='RPM_PARTIAL_CONTRIBUTION_THREE_CANDIDATES_PARALLEL';end
T=struct2table(rows);writetable(T,fullfile(outputDir,'RPM_SWITCH_FIXED_STATE.csv'));
result=struct('identity','V8_FIXED_STATE_RPM_SWITCH_589_TO_517',...
 'inputFile',inputFile,'speed_kt',S.rec.row.speed_kt,'nacelle_deg',S.rec.row.nacelle_deg,...
 'thresholds_kW',struct('primary_le950',950,'ruled_out_gt1200',1200),...
 'decision',decision,'rows',rows,'controls_u',u,'state_x',x,...
 'note','Fixed state/control diagnostic; not a re-trim and not external validation.');
save(fullfile(outputDir,'RPM_SWITCH_FIXED_STATE.mat'),'result','details','P0');
fid=fopen(fullfile(outputDir,'RPM_SWITCH_DECISION.json'),'w');assert(fid>0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(result));clear c;
disp(T);disp(decision);
end
