function report = check_model_identity_separation()
%CHECK_MODEL_IDENTITY_SEPARATION Ensure generic and XV-15 identities stay distinct.
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(rootDir);
addpath(fullfile(rootDir,'model'));
addpath(fullfile(rootDir,'model','berger13'));
addpath(fullfile(rootDir,'model','parameter_sets'));
generic = params_tiltrotor_generic_core();
[xv15, manifest] = build_xv15_validation_adapter();
cases = {'generic identity'; 'generic has no overlay'; 'adapter identity'; ...
    'adapter records blocked fields'; 'adapter has source manifest'};
passed = false(5,1);
passed(1) = strcmp(generic.meta.modelIdentity,'TILTROTOR_GENERIC_CORE');
passed(2) = ~generic.meta.xv15OverlayApplied;
passed(3) = strcmp(xv15.meta.modelIdentity,'XV15_VALIDATION_ADAPTER_PARTIAL_PUBLIC');
passed(4) = ~isempty(manifest.blockedLegacyPaths) && ~isempty(xv15.meta.blockedPaths);
passed(5) = ~isempty(manifest.sourceManifest);
report.cases = table(cases,passed,'VariableNames',{'caseName','passed'});
report.allPassed = all(passed);
if ~report.allPassed
    error('check_model_identity_separation:Failed', ...
        'Generic/XV-15 model identities are not separated.');
end
end
