cd('C:\Users\86173\Documents\Codex\2026-09-11\yue\work\tiltrotor-matlab'); addpath(fullfile(pwd,'model')); addpath(fullfile(pwd,'analysis')); addpath(fullfile(pwd,'analysis','validation_whole_aircraft_trim')); addpath(fullfile(pwd,'analysis','stage2_aircraft'));
P=xv15_helicopter_trim_parameters_v1(); P=line_b_coherent_tail_parameters(P); P.rotor.correctionIdentity='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4'; P.wing.coefficientModel='GTRS_FREEFIELD_HELI_V6'; P.aeroExtras.spinnerModel='GTRS_TWO_SPINNERS_STEADY_HELI_V7';
V=40*.514444; x=zeros(9,1); x(1)=V; u=[8*pi/180;0;0;0;0;0;0];
try
 [F,M,info]=stage2_total_forces_moments('M1_CONTINUOUS_CORRIGAN_V4',x,u,0,P); disp('OK'); disp(F); disp(M); disp(info.physicalStatus); catch ME, disp(ME.identifier); disp(ME.message); end
exit
