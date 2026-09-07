function status = check_validation_gate()
%CHECK_VALIDATION_GATE Audit the XV-15 whole-aircraft trim validation gate.
%
% This helper intentionally does not run a trim comparison.  It checks
% whether the source ledger and model/case homology contract are complete
% enough to permit quantitative external scoring.
%
% MATLAB R2021a compatible.

rootDir = fileparts(mfilename('fullpath'));
sourceFile = fullfile(rootDir, 'source_manifest.csv');
contractFile = fullfile(rootDir, 'homology_contract.csv');

assert(exist(sourceFile, 'file') == 2, 'Missing source manifest: %s', sourceFile);
assert(exist(contractFile, 'file') == 2, 'Missing homology contract: %s', contractFile);

sources = readtable(sourceFile, 'TextType', 'string');
contract = readtable(contractFile, 'TextType', 'string');

requiredSourceVars = ["source_id", "citation", "source_locator", "quantity", ...
    "data_role", "acquisition_status", "admissibility", "notes"];
requiredContractVars = ["gate_id", "category", "required_contract", ...
    "current_state", "status", "evidence_or_source", "notes"];

assert(all(ismember(requiredSourceVars, string(sources.Properties.VariableNames))), ...
    'source_manifest.csv schema is incomplete.');
assert(all(ismember(requiredContractVars, string(contract.Properties.VariableNames))), ...
    'homology_contract.csv schema is incomplete.');

assert(height(sources) > 0, 'source_manifest.csv contains no source rows.');
assert(height(contract) > 0, 'homology_contract.csv contains no gate rows.');
assert(numel(unique(sources.source_id)) == height(sources), ...
    'source_manifest.csv contains duplicate source_id values.');
assert(numel(unique(contract.gate_id)) == height(contract), ...
    'homology_contract.csv contains duplicate gate_id values.');

sourceAdmissibility = upper(strtrim(string(sources.admissibility)));
sourceAcquisition = upper(strtrim(string(sources.acquisition_status)));
contractStatus = upper(strtrim(string(contract.status)));

sourceBlocked = startsWith(sourceAdmissibility, "BLOCKED");
sourceNotReady = sourceBlocked | contains(sourceAcquisition, "NOT_DIGITIZED") | ...
    contains(sourceAcquisition, "NOT_VERIFIED");
contractClosed = contractStatus == "CLOSED";

status = struct();
status.nSources = height(sources);
status.nSourceNotReady = nnz(sourceNotReady);
status.nContractGates = height(contract);
status.nContractClosed = nnz(contractClosed);
status.nContractOpen = height(contract) - nnz(contractClosed);
status.readyForScoring = ~any(sourceNotReady) && all(contractClosed);

fprintf('Whole-aircraft trim external-validation gate\n');
fprintf('  sources: %d total, %d not ready\n', ...
    status.nSources, status.nSourceNotReady);
fprintf('  homology contract: %d total, %d closed, %d open\n', ...
    status.nContractGates, status.nContractClosed, status.nContractOpen);

if status.readyForScoring
    fprintf('  RESULT: READY_FOR_EXTERNAL_SCORING\n');
else
    fprintf('  RESULT: BLOCKED_BY_MODEL_OR_CASE_HOMOLOGY\n');
end

end
