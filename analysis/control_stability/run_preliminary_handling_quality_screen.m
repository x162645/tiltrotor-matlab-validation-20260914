function result = run_preliminary_handling_quality_screen(inputMat,outputDir)
%RUN_PRELIMINARY_HANDLING_QUALITY_SCREEN Process frozen trim/linearisation data.
% The input is the generated CONTROL_STABILITY_RESULTS.mat from
% run_control_stability_assessment.  No physics or parameter values are
% changed; this entry point only derives auditable screening tables.

if nargin < 1 || isempty(inputMat)
    rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    inputMat = fullfile(rootDir,'docs', ...
        'tiltrotor_control_stability_technical_report', ...
        'CONTROL_STABILITY_RESULTS.mat');
end
if nargin < 2 || isempty(outputDir)
    outputDir = fileparts(inputMat);
end
if exist(inputMat,'file') ~= 2
    error('handling_quality:MissingInput','Input MAT file does not exist: %s',inputMat);
end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
loaded = load(inputMat,'results');
if ~isfield(loaded,'results') || ~isfield(loaded.results,'pointResults')
    error('handling_quality:InvalidInput','Input MAT lacks pointResults.');
end

criteria = repmat(empty_criteria(),0,1);
controls = repmat(empty_control(),0,1);
points = loaded.results.pointResults;
for k = 1:numel(points)
    point = points(k);
    if ~isfield(point,'linearCommand') || isempty(point.linearCommand) || ...
            ~isfield(point.linearCommand,'symdiff')
        error('handling_quality:MissingLinearModel', ...
            'Point %d has no command-interface linear model.',k);
    end
    sym = point.linearCommand.symdiff;
    pointId = point.definition.id;
    screen = preliminary_handling_quality_screen(sym.A,sym.B, ...
        sym.stateNames,sym.inputNames,pointId,struct());
    c = screen.criteriaTable;
    criteria = [criteria; table_to_criteria(c)]; %#ok<AGROW>
    u = screen.controlTable;
    if ~isempty(u), controls = [controls; table_to_controls(u)]; %#ok<AGROW>
    end
end

criteriaTable = struct2table(criteria);
controlTable = struct2table(controls);
writetable(criteriaTable,fullfile(outputDir, ...
    'PRELIMINARY_HANDLING_QUALITY_SCREEN.csv'));
writetable(controlTable,fullfile(outputDir, ...
    'PRELIMINARY_CONTROL_ACCELERATION_SCREEN.csv'));
result.criteriaTable = criteriaTable;
result.controlTable = controlTable;
result.claimBoundary = ['preliminary model-based screen only; no flight-test ' ...
    'validation and no formal handling-quality level rating'];
save(fullfile(outputDir,'PRELIMINARY_HANDLING_QUALITY_SCREEN.mat'),'result','-v7');
end

function rows = table_to_criteria(T)
rows = repmat(empty_criteria(),height(T),1);
for k = 1:height(T)
    names = fieldnames(rows(k));
    for j = 1:numel(names)
        if ismember(names{j},T.Properties.VariableNames)
            rows(k).(names{j}) = T{k,names{j}};
            if iscell(rows(k).(names{j})), rows(k).(names{j}) = rows(k).(names{j}){1}; end
        end
    end
end
end

function rows = table_to_controls(T)
rows = repmat(empty_control(),height(T),1);
for k = 1:height(T)
    names = fieldnames(rows(k));
    for j = 1:numel(names)
        if ismember(names{j},T.Properties.VariableNames)
            rows(k).(names{j}) = T{k,names{j}};
            if iscell(rows(k).(names{j})), rows(k).(names{j}) = rows(k).(names{j}){1}; end
        end
    end
end
end

function row = empty_criteria()
row = struct('pointId','','criteriaId','','criteriaLabel','','criterionType','', ...
    'thresholdValue',NaN,'thresholdFrequencyRadPerSecond',NaN,'modeIndex',NaN, ...
    'realPartPerSecond',NaN,'naturalFrequencyRadPerSecond',NaN, ...
    'dampingRatio',NaN,'pathologicalEigenvectors',false,'status','');
end

function row = empty_control()
row = struct('pointId','','inputName','','initialRollAccelerationPerRad',NaN, ...
    'initialPitchAccelerationPerRad',NaN,'initialYawAccelerationPerRad',NaN, ...
    'maxAngularAccelerationPerRad',NaN,'finiteReal',false);
end
