function report = preliminary_handling_quality_screen(A,B,stateNames,inputNames,pointId,opts)
%PRELIMINARY_HANDLING_QUALITY_SCREEN Reproducible modal/control screening.
%
% This function turns a linearised operating point into an auditable set of
% preliminary handling-quality indicators.  It deliberately does not issue
% MIL-F-8785/MIL-HDBK-1797 level ratings: the thresholds below are project
% screening thresholds and require aircraft-specific applicability evidence
% before they can be used for a formal rating.
%
% Inputs
%   A,B          linearised state and control matrices.  B may be [] when
%                only modal screening is required.
%   stateNames   cell array in the same order as A.
%   inputNames   cell array in the same order as columns of B (or []).
%   pointId      operating-point identifier (or '').
%   opts         optional threshold overrides; see default_options below.
%
% The output contains modeTable, criteriaTable, controlTable, and the full
% modal participation result.  Candidate modes are selected from the model
% state participation, while conjugate duplicates and the heading integrator
% are excluded from the corresponding dynamic screen.

if nargin < 2, B = []; end
if nargin < 3 || isempty(stateNames)
    stateNames = get_state_names_13x10();
end
if nargin < 4 || isempty(inputNames)
    inputNames = {};
end
if nargin < 5 || isempty(pointId), pointId = ''; end
if nargin < 6 || isempty(opts), opts = struct(); end
validate_model(A,B,stateNames,inputNames);
opts = default_options(opts);

modelKind = 'PRELIMINARY_HANDLING_QUALITY_SCREEN';
modal = analyze_modal_participation(pointId,modelKind,A,stateNames);
n = size(A,1);
lambda = modal.eigenvalues(:);
p = modal.participationNormalizedMagnitude;
stateNames = stateNames(:);

% Build one row per eigenvalue, then assign at most one role to a mode.  A
% conjugate pair is represented by the member with positive imaginary part.
role = repmat({'UNASSIGNED'},n,1);
score = zeros(n,1);
longScore = zeros(n,1);
latScore = zeros(n,1);
qwScore = zeros(n,1);
prScore = zeros(n,1);
for k = 1:n
    longScore(k) = sum_named(p(:,k),stateNames,{'u','w','q','theta'});
    latScore(k) = sum_named(p(:,k),stateNames,{'v','p','r','phi','psi'});
    qwScore(k) = sum_named(p(:,k),stateNames,{'q','w'});
    prScore(k) = sum_named(p(:,k),stateNames,{'p','r','v'});
end

eligibleOsc = imag(lambda) > opts.imaginaryTolerance & ...
    ~heading_modes(p,stateNames,lambda,opts.zeroTolerance);
shortCandidates = find(eligibleOsc & longScore >= latScore & ...
    qwScore >= opts.minimumCandidateParticipation);
dutchCandidates = find(eligibleOsc & latScore > longScore & ...
    prScore >= opts.minimumCandidateParticipation);
if ~isempty(shortCandidates)
    [scoreValue,local] = max(longScore(shortCandidates)+qwScore(shortCandidates));
    idx = shortCandidates(local); role(idx) = {'SHORT_PERIOD_SCREEN'}; score(idx) = scoreValue;
end
if ~isempty(dutchCandidates)
    [scoreValue,local] = max(latScore(dutchCandidates)+prScore(dutchCandidates));
    idx = dutchCandidates(local); role(idx) = {'DUTCH_ROLL_SCREEN'}; score(idx) = scoreValue;
end

eligibleReal = abs(imag(lambda)) <= opts.imaginaryTolerance & ...
    real(lambda) < -opts.zeroTolerance & ...
    ~heading_modes(p,stateNames,lambda,opts.zeroTolerance);
rollCandidates = find(eligibleReal & latScore > longScore & ...
    sum_named_matrix(p,stateNames,{'p'}) >= opts.minimumCandidateParticipation);
if ~isempty(rollCandidates)
    [~,local] = max(sum_named_matrix(p(:,rollCandidates),stateNames,{'p'}));
    idx = rollCandidates(local); role(idx) = {'ROLL_SUBSIDENCE_SCREEN'};
    score(idx) = sum_named(p(:,idx),stateNames,{'p'});
end
% The least-damped remaining real rigid-body mode is the spiral candidate.
spiralCandidates = find(eligibleReal & strcmp(role,'UNASSIGNED') & ...
    (longScore+latScore) >= opts.minimumCandidateParticipation);
if ~isempty(spiralCandidates)
    [~,local] = max(real(lambda(spiralCandidates)));
    idx = spiralCandidates(local); role(idx) = {'SPIRAL_SCREEN'};
    score(idx) = longScore(idx)+latScore(idx);
end

modeRows = repmat(empty_mode_row(),n,1);
for k = 1:n
    wn = abs(lambda(k));
    zeta = NaN;
    if wn > opts.zeroTolerance, zeta = -real(lambda(k))/wn; end
    modeRows(k).pointId = pointId;
    modeRows(k).modeIndex = k;
    modeRows(k).candidateRole = role{k};
    modeRows(k).candidateScore = score(k);
    modeRows(k).realPartPerSecond = real(lambda(k));
    modeRows(k).imagPartRadPerSecond = imag(lambda(k));
    modeRows(k).naturalFrequencyRadPerSecond = wn;
    modeRows(k).frequencyHz = wn/(2*pi);
    modeRows(k).dampingRatio = zeta;
    modeRows(k).stable = real(lambda(k)) < -opts.zeroTolerance;
    modeRows(k).pathologicalEigenvectors = modal.classification.pathologicalEigenvectors(k);
    modeRows(k).longitudinalParticipation = longScore(k);
    modeRows(k).lateralParticipation = latScore(k);
    modeRows(k).dominantState = dominant_state(p(:,k),stateNames);
end
modeTable = struct2table(modeRows);

criteriaRows = repmat(empty_criteria_row(),4,1);
criteriaRows(1) = criterion_row('SHORT_PERIOD_SCREEN','short-period',modeRows, ...
    opts.shortPeriodMinDamping,opts.shortPeriodMinFrequencyRadPerSecond, ...
    'DAMPING_AND_FREQUENCY');
criteriaRows(2) = criterion_row('DUTCH_ROLL_SCREEN','dutch-roll',modeRows, ...
    opts.dutchRollMinDamping,opts.dutchRollMinFrequencyRadPerSecond, ...
    'DAMPING_AND_FREQUENCY');
criteriaRows(3) = criterion_row('ROLL_SUBSIDENCE_SCREEN','roll subsidence',modeRows, ...
    opts.rollSubsidenceMinDecayRate,NaN,'DECAY_RATE');
criteriaRows(4) = criterion_row('SPIRAL_SCREEN','spiral',modeRows, ...
    opts.spiralMinDecayRate,NaN,'DECAY_RATE');
criteriaTable = struct2table(criteriaRows);

controlTable = repmat(empty_control_row(),0,1);
if ~isempty(B)
    for j = 1:size(B,2)
        row = empty_control_row();
        row.pointId = pointId;
        row.inputName = inputNames{j};
        row.initialRollAccelerationPerRad = B(find_state(stateNames,'p'),j);
        row.initialPitchAccelerationPerRad = B(find_state(stateNames,'q'),j);
        row.initialYawAccelerationPerRad = B(find_state(stateNames,'r'),j);
        row.maxAngularAccelerationPerRad = max(abs([ ...
            row.initialRollAccelerationPerRad; ...
            row.initialPitchAccelerationPerRad; ...
            row.initialYawAccelerationPerRad]));
        row.finiteReal = isreal(B(:,j)) && all(isfinite(B(:,j)));
        controlTable(end+1,1) = row; %#ok<AGROW>
    end
end
controlTable = struct2table(controlTable);

report.pointId = pointId;
report.modelKind = modelKind;
report.options = opts;
report.modal = modal;
report.modeTable = modeTable;
report.criteriaTable = criteriaTable;
report.controlTable = controlTable;
report.screenSummary = summarize(criteriaRows);
report.claimBoundary = ['preliminary model-based handling-quality screen; ' ...
    'not flight-test validation and not formal MIL-F-8785/MIL-HDBK-1797 rating'];
end

function opts = default_options(opts)
defaults = struct('imaginaryTolerance',1e-6,'zeroTolerance',1e-8, ...
    'minimumCandidateParticipation',0.20, ...
    'shortPeriodMinDamping',0.30, ...
    'shortPeriodMinFrequencyRadPerSecond',1.0, ...
    'dutchRollMinDamping',0.08, ...
    'dutchRollMinFrequencyRadPerSecond',0.40, ...
    'rollSubsidenceMinDecayRate',0.10,'spiralMinDecayRate',0.0);
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(opts,names{k}), opts.(names{k}) = defaults.(names{k}); end
end
end

function validate_model(A,B,stateNames,inputNames)
if size(A,1) ~= size(A,2) || ~isreal(A) || any(~isfinite(A(:)))
    error('handling_quality:InvalidA','A must be a finite real square matrix.');
end
if numel(stateNames) ~= size(A,1)
    error('handling_quality:StateNameMismatch','stateNames must match A.');
end
if ~isempty(B) && (size(B,1) ~= size(A,1) || numel(inputNames) ~= size(B,2) || ...
        ~isreal(B) || any(~isfinite(B(:))))
    error('handling_quality:InvalidB','B dimensions/names or values are invalid.');
end
end

function mask = heading_modes(p,stateNames,lambda,tol)
mask = false(numel(lambda),1);
psi = find(strcmp(stateNames,'psi'),1);
if isempty(psi), return; end
mask = abs(lambda) <= tol & p(psi,:).' >= 0.5;
end

function value = sum_named(p,names,wanted)
value = sum(p(ismember(names,wanted)));
end

function values = sum_named_matrix(P,names,wanted)
values = sum(P(ismember(names,wanted),:),1).';
end

function name = dominant_state(p,names)
[~,idx] = max(p); name = names{idx};
end

function idx = find_state(names,name)
idx = find(strcmp(names,name),1);
if isempty(idx), error('handling_quality:MissingRateState','State %s is required.',name); end
end

function row = criterion_row(role,label,modes,minValue,minFrequency,criterionType)
row = empty_criteria_row();
if ~isempty(modes), row.pointId = modes(1).pointId; end
mask = strcmp({modes.candidateRole},role);
row.criteriaId = role; row.criteriaLabel = label;
row.criterionType = criterionType; row.thresholdValue = minValue;
row.thresholdFrequencyRadPerSecond = minFrequency;
if ~any(mask)
    row.status = 'NOT_IDENTIFIED'; row.modeIndex = NaN; return;
end
idx = find(mask,1);
row.modeIndex = modes(idx).modeIndex;
row.realPartPerSecond = modes(idx).realPartPerSecond;
row.naturalFrequencyRadPerSecond = modes(idx).naturalFrequencyRadPerSecond;
row.dampingRatio = modes(idx).dampingRatio;
row.pathologicalEigenvectors = modes(idx).pathologicalEigenvectors;
if row.pathologicalEigenvectors || ~isfinite(row.dampingRatio)
    row.status = 'SCREEN_UNCERTAIN';
elseif strcmp(criterionType,'DAMPING_AND_FREQUENCY')
    row.status = ternary(row.dampingRatio >= minValue && ...
        row.naturalFrequencyRadPerSecond >= minFrequency,'SCREEN_PASS','SCREEN_FAIL');
else
    row.status = ternary(row.realPartPerSecond <= -minValue,'SCREEN_PASS','SCREEN_FAIL');
end
end

function row = empty_mode_row()
row = struct('pointId','','modeIndex',NaN,'candidateRole','','candidateScore',NaN, ...
    'realPartPerSecond',NaN,'imagPartRadPerSecond',NaN, ...
    'naturalFrequencyRadPerSecond',NaN,'frequencyHz',NaN,'dampingRatio',NaN, ...
    'stable',false,'pathologicalEigenvectors',false, ...
    'longitudinalParticipation',NaN,'lateralParticipation',NaN,'dominantState','');
end

function row = empty_criteria_row()
row = struct('pointId','','criteriaId','','criteriaLabel','','criterionType','', ...
    'thresholdValue',NaN,'thresholdFrequencyRadPerSecond',NaN,'modeIndex',NaN, ...
    'realPartPerSecond',NaN,'naturalFrequencyRadPerSecond',NaN, ...
    'dampingRatio',NaN,'pathologicalEigenvectors',false,'status','');
end

function row = empty_control_row()
row = struct('pointId','','inputName','','initialRollAccelerationPerRad',NaN, ...
    'initialPitchAccelerationPerRad',NaN,'initialYawAccelerationPerRad',NaN, ...
    'maxAngularAccelerationPerRad',NaN,'finiteReal',false);
end

function summary = summarize(rows)
summary.totalCriteria = numel(rows);
summary.screenPassCount = sum(strcmp({rows.status},'SCREEN_PASS'));
summary.screenFailCount = sum(strcmp({rows.status},'SCREEN_FAIL'));
summary.notIdentifiedCount = sum(strcmp({rows.status},'NOT_IDENTIFIED'));
summary.uncertainCount = sum(strcmp({rows.status},'SCREEN_UNCERTAIN'));
summary.allIdentifiedAndPassing = summary.totalCriteria > 0 && ...
    summary.screenPassCount == summary.totalCriteria;
end

function out = ternary(condition,yesValue,noValue)
if condition, out = yesValue; else, out = noValue; end
end
