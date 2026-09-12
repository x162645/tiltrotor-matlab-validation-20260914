function report = check_berger13_transition_envelope()
%CHECK_BERGER13_TRANSITION_ENVELOPE Contract test for the trim-envelope API.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
outDir = fullfile(tempdir, 'berger13_transition_envelope_contract');
if exist(outDir, 'dir'), rmdir(outDir, 's'); end
mkdir(outDir);

% A small two-point grid exercises the public workflow while keeping this
% contract check independent of the expensive default research envelope.
opts = struct('betaMDeg', [45 75], 'speedMps', 35, ...
    'runMultipleSeeds', false, 'useContinuation', false);
result = run_berger13_transition_envelope(outDir, opts);

checks = [numel(result.points) == 2, height(result.summary) == 2, ...
    exist(result.csvPath, 'file') == 2, ...
    exist(fullfile(outDir, 'BERGER13_TRANSITION_ENVELOPE.mat'), 'file') == 2, ...
    all(isfinite(result.summary.elapsedSeconds)), ...
    contains(result.claimBoundary, 'not an XV-15')];
report.passed = all(checks);
report.checks = checks;
report.result = result;
fprintf('Berger13 transition-envelope API checks\n');
fprintf('  %d/%d checks passed\n', sum(checks), numel(checks));
if ~report.passed
    error('check_berger13_transition_envelope:Failed', ...
        'Transition-envelope API contract failed.');
end
end
