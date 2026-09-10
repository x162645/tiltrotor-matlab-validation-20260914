function summary = check_d02_longitudinal_heave()
%CHECK_D02_LONGITUDINAL_HEAVE Verification gates for the opt-in D02 prototype.
run(fullfile(fileparts(mfilename('fullpath')),'..','startup.m'));
P = params_nominal();
checks = struct('name',{},'pass',{},'detail',{});

trim = run_d02_longitudinal_heave(struct('action','trim', ...
    'trim',struct('V',0,'betaMDeg',0)), P);
checks(end+1) = c('steady trim residual closes', trim.trimReport.pass, ...
    sprintf('rigid %.3e, inflow %.3e',trim.trimReport.rigidBodyResidual,trim.trimReport.inflowResidual));

lin = run_d02_longitudinal_heave(struct('action','linearize', ...
    'trim',struct('V',0,'betaMDeg',0)), P);
checks(end+1) = c('15-state/3-input linearization finite', ...
    isequal(size(lin.A),[15 15]) && isequal(size(lin.B),[15 3]) && lin.linearReport.finite, ...
    sprintf('%dx%d A, %dx%d B',size(lin.A,1),size(lin.A,2),size(lin.B,1),size(lin.B,2)));

simCfg = struct('action','simulate','trim',struct('V',0,'betaMDeg',0), ...
    'totalTime',1.5,'timeStep',0.05,'inputChannel',3,'amplitudeDeg',0.2);
sim = run_d02_longitudinal_heave(simCfg, P);
finiteSim = all(isfinite(sim.state(:))) && all(isfinite(sim.loads.Fx)) && ...
    all(isfinite(sim.loads.Fz)) && all(isfinite(sim.loads.My));
checks(end+1) = c('nonlinear small-disturbance simulation finite',finiteSim, ...
    sprintf('%d samples',numel(sim.time)));
checks(end+1) = c('component load history is exposed', ...
    isfield(sim.loads,'components') && numel(sim.loads.components)==numel(sim.time) && ...
    isfield(sim.loads.components{1},'rotorLeft') && isfield(sim.loads.components{1},'horizontalTail'), ...
    'rotor, wing, fuselage and tail snapshots present');
checks(end+1) = c('inflow state is coupled to rotor load target', ...
    max(abs(sim.state(:,10)-sim.loads.inducedVelocityLeft)) > 1e-8, ...
    'state and target are distinct during the command transient');

summary = struct();
summary.name = 'D02 longitudinal-heave dynamic prototype';
summary.passed = all([checks.pass]);
summary.checks = checks;
for k = 1:numel(checks)
    fprintf('%-48s : %s (%s)\n',checks(k).name, ternary(checks(k).pass,'PASS','FAIL'),checks(k).detail);
end
if ~summary.passed, error('check_d02_longitudinal_heave:Failed','One or more D02 checks failed.'); end
end

function out = c(name,pass,detail), out=struct('name',name,'pass',logical(pass),'detail',detail); end
function value = ternary(condition,a,b), if condition,value=a;else,value=b;end,end
