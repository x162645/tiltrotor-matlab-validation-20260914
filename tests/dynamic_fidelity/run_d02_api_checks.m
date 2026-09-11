function result=run_d02_api_checks(outputRoot)
%RUN_D02_API_CHECKS Small default-parameter and facade compatibility checks.
% This is separate from the pinned ten-trajectory benchmark, not a rerun.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
startup;diary(fullfile(outputRoot,'API_LOG.txt'));cleanup=onCleanup(@()diary('off'));
result=struct('status','RUNNING','checks',0,'version',version,'externalValidation',false);
[~,h]=system('git rev-parse HEAD');result.commit=strtrim(h);
try
 result.defaultSmoke=check_d02_longitudinal_heave();assert(result.defaultSmoke.passed);result.checks=6;
 P=params_nominal();P.rotor.inducedTol=1e-9;P.rotor.inducedMaxIter=60;P.rotor.flapResidualTol=1e-10;
 wp=d02_prepare_workpoint(struct('V',0,'betaMDeg',0,'useMultiStart',false),P);
 a=run_d02_longitudinal_heave(struct('action','trim','preparedWorkpoint',wp),P);
 assert(a.success&&a.executionSucceeded&&a.workpointAccepted&&~a.externalAccuracyPassed);result.checks=result.checks+1;
 b=run_d02_longitudinal_heave(struct('action','linearize','preparedWorkpoint',wp),P);
 assert(isequal(size(b.A),[15 15])&&isequal(size(b.B),[15 3])&&isequal(size(b.C),[14 15])&&isequal(size(b.D),[14 3]));result.checks=result.checks+1;
 cfg=struct('action','simulate','preparedWorkpoint',wp,'inputChannel',1,'amplitudeDeg',.1, ...
  'startTime',.1,'totalTime',.3,'timeStep',.02);
 c=run_d02_longitudinal_heave(cfg,P);
 assert(c.success&&isequal(c.state(:,10),c.loads.inducedVelocityLeft)&&isequal(c.state(:,11),c.loads.inducedVelocityRight));result.checks=result.checks+1;
 assert(all(isfinite(c.output(:)))&&all(c.simulation.evaluationValid));result.checks=result.checks+1;
 assert(isfield(c.loads,'targetInducedVelocityLeft')&&numel(c.loads.components)==numel(c.time));result.checks=result.checks+1;
 assert(isequal(c.zTrim,wp.dynamicState)&&isequal(b.zTrim,c.zTrim));result.checks=result.checks+1;
 result.status='PASSED';result.workpoint=wp;result.linear=b;result.simulation=c;
catch ME
 result.status='FAILED';result.errorIdentifier=ME.identifier;result.errorMessage=ME.message;persist();rethrow(ME);
end
persist();disp(result.status);disp(result.checks);
 function persist()
  save(fullfile(outputRoot,'API_RESULTS.mat'),'result','-v7');
  meta=result;for key={'workpoint','linear','simulation'},if isfield(meta,key{1}),meta=rmfield(meta,key{1});end,end
  fid=fopen(fullfile(outputRoot,'API_MANIFEST.json'),'w');assert(fid>=0);cl=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear cl;
 end
end
