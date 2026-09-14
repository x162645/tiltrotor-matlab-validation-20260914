addpath(genpath('C:\Users\86173\Documents\Codex\2026-09-11\yue\work\tiltrotor-matlab\analysis')); addpath(genpath('C:\Users\86173\Documents\Codex\2026-09-11\yue\work\tiltrotor-matlab\analysis\validation_whole_aircraft_trim'));
[P,c]=xv15_helicopter_trim_parameters_v1(); P.trim.display='off'; P.trim.maxIterations=120; P.trim.residualTolerance=1e-5;
cond=struct('name','test','V',40,'betaM',30*pi/180,'gamma',0);
for mode={'conversion_longitudinal','legacy_symmetric'}
 try
  [x,u,r]=stage2_trim_longitudinal('M1_EVIDENCE_V1_PROPAGATION',cond,P,struct('mode',mode{1})); fprintf('%s cred=%d res=%g z=',mode{1},r.credible,r.residualNorm); disp(r.trimVariableVector')
 catch ME, fprintf('%s ERR %s %s\n',mode{1},ME.identifier,ME.message); end
end
