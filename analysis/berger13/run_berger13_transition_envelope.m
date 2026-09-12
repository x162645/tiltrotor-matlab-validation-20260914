function result = run_berger13_transition_envelope(outputDir, opts)
%RUN_BERGER13_TRANSITION_ENVELOPE Evaluate a reproducible trim envelope.
%
% This entry point turns the isolated 13-state model into an explicit
% transition-study workflow.  It evaluates every requested speed/nacelle
% angle pair, retains failed and non-credible points, and optionally uses a
% converged point as the continuation seed for the next speed at the same
% nacelle angle.  The output is an analysis envelope, not a flight corridor
% or an XV-15 validation result.

if nargin < 1 || isempty(outputDir)
    error('run_berger13_transition_envelope:OutputRequired', ...
        'An explicit output directory is required.');
end
if nargin < 2 || isempty(opts), opts = struct(); end
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

P13 = get_option(opts, 'P13', params_berger13());
betaMDeg = get_option(opts, 'betaMDeg', [0 15 30 45 60 75 90]);
speedMps = get_option(opts, 'speedMps', [5 15 25 35 45 60 80]);
gamma = get_option(opts, 'gamma', 0);
runMultipleSeeds = get_option(opts, 'runMultipleSeeds', true);
useContinuation = get_option(opts, 'useContinuation', true);

validate_grid(betaMDeg, speedMps, gamma);
betaMDeg = betaMDeg(:);
speedMps = speedMps(:);
n = numel(betaMDeg)*numel(speedMps);

empty = struct('pointId', '', 'condition', [], 'mode', '', ...
    'status', 'FAILED', 'credible', false, 'trim', [], ...
    'failureIdentifier', '', 'failureMessage', '', 'seedSource', '', ...
    'elapsedSeconds', NaN);
points = repmat(empty, n, 1);
rows = cell(n, 14);
rowIndex = 0;

for ib = 1:numel(betaMDeg)
    previousZ = [];
    previousSpeed = NaN;
    for iv = 1:numel(speedMps)
        rowIndex = rowIndex + 1;
        beta = betaMDeg(ib);
        speed = speedMps(iv);
        condition = struct('V', speed, 'betaM', beta*pi/180, ...
            'gamma', gamma);
        mode = mode_for_beta(beta);
        pointId = sprintf('T%03d_V%03d', round(beta), round(speed));
        points(rowIndex).pointId = pointId;
        points(rowIndex).condition = condition;
        points(rowIndex).mode = mode;
        seedSource = '';
        trimOpts = struct('mode', mode, ...
            'runMultipleSeeds', runMultipleSeeds);
        if useContinuation && ~isempty(previousZ) && ...
                isfinite(previousSpeed)
            trimOpts.initialValues = previousZ;
            seedSource = sprintf('same_beta_previous_speed_%g_mps', ...
                previousSpeed);
        end
        points(rowIndex).seedSource = seedSource;
        started = tic;
        try
            [~, ~, trim] = trim_berger13_symmetric(condition, P13, trimOpts);
            points(rowIndex).trim = trim;
            points(rowIndex).status = trim.status;
            points(rowIndex).credible = trim.credible;
            points(rowIndex).elapsedSeconds = toc(started);
            if trim.credible
                previousZ = trim.trimVariableVector;
                previousSpeed = speed;
            else
                previousZ = [];
                previousSpeed = NaN;
            end
        catch ME
            points(rowIndex).failureIdentifier = ME.identifier;
            points(rowIndex).failureMessage = ME.message;
            points(rowIndex).elapsedSeconds = toc(started);
            previousZ = [];
            previousSpeed = NaN;
        end
        rows(rowIndex,:) = summary_row(points(rowIndex), beta, speed);
    end
end

summary = cell2table(rows, 'VariableNames', {'pointId','betaMDeg', ...
    'speedMps','mode','status','credible','thetaDeg','collectiveDeg', ...
    'cyclicLongDeg','elevatorDeg','dynamicResidualNorm', ...
    'conditionNumber','elapsedSeconds','failureReason'});
csvPath = fullfile(outputDir, 'BERGER13_TRANSITION_ENVELOPE.csv');
writetable(summary, csvPath);

result.points = points;
result.summary = summary;
result.grid.betaMDeg = betaMDeg;
result.grid.speedMps = speedMps;
result.grid.gamma = gamma;
result.grid.order = 'nacelle angle outer loop, speed inner loop';
result.credibleCount = sum([points.credible]);
result.failedCount = n - result.credibleCount;
result.outputDir = outputDir;
result.csvPath = csvPath;
result.modelIdentity = get_model_identity(P13);
result.claimBoundary = ['generic Berger13 13-state numerical trim envelope; ' ...
    'not an XV-15 full-aircraft validation set, certified flight corridor, ' ...
    'or handling-quality acceptance result'];
result.finiteReal = all(isfinite(summary.elapsedSeconds));
save(fullfile(outputDir, 'BERGER13_TRANSITION_ENVELOPE.mat'), ...
    'result', '-v7');
end

function row = summary_row(point, beta, speed)
theta = NaN; collective = NaN; cyclic = NaN; elevator = NaN;
residual = NaN; conditionNumber = NaN; reason = point.failureMessage;
if ~isempty(point.trim)
    tr = point.trim;
    theta = tr.x13(8)*180/pi;
    collective = tr.u10Torque(1)*180/pi;
    cyclic = tr.u10Torque(3)*180/pi;
    elevator = tr.u10Torque(7)*180/pi;
    residual = tr.dynamicResidualNorm;
    conditionNumber = tr.conditionNumber;
    if isempty(reason) && ~tr.credible
        reason = strjoin(tr.reasons, '; ');
    end
end
row = {point.pointId, beta, speed, point.mode, point.status, ...
    point.credible, theta, collective, cyclic, elevator, residual, ...
    conditionNumber, point.elapsedSeconds, reason};
end

function mode = mode_for_beta(beta)
if beta <= 30
    mode = 'helicopter_longitudinal';
elseif beta >= 60
    mode = 'airplane_longitudinal';
else
    mode = 'conversion_longitudinal';
end
end

function validate_grid(beta, speed, gamma)
if ~(isnumeric(beta) && isreal(beta) && ~isempty(beta) && ...
        all(isfinite(beta(:))) && all(beta(:) >= 0) && ...
        all(beta(:) <= 90))
    error('run_berger13_transition_envelope:InvalidAngles', ...
        'betaMDeg must contain finite angles in [0,90] degrees.');
end
if ~(isnumeric(speed) && isreal(speed) && ~isempty(speed) && ...
        all(isfinite(speed(:))) && all(speed(:) >= 0))
    error('run_berger13_transition_envelope:InvalidSpeeds', ...
        'speedMps must contain finite nonnegative speeds.');
end
if ~(isscalar(gamma) && isreal(gamma) && isfinite(gamma))
    error('run_berger13_transition_envelope:InvalidGamma', ...
        'gamma must be a finite real scalar.');
end
end

function value = get_option(opts, name, defaultValue)
if isfield(opts, name), value = opts.(name); else, value = defaultValue; end
end

function identity = get_model_identity(P13)
if isfield(P13, 'meta') && isfield(P13.meta, 'scope')
    identity = P13.meta.scope;
else
    identity = 'UNDECLARED_MODEL_SCOPE';
end
end
