function [P13, manifest] = build_xv15_validation_adapter()
%BUILD_XV15_VALIDATION_ADAPTER Build a separately identified XV-15 adapter.
% Only semantically homologous public fields are overlaid. Blocked radial,
% scheduled, or missing fields remain in the manifest.
P13 = params_tiltrotor_generic_core();
[Pbase, manifest] = apply_xv15_public_overlay_second_pass(P13.base);
P13.base = Pbase;
P13.meta.modelIdentity = 'XV15_VALIDATION_ADAPTER_PARTIAL_PUBLIC';
P13.meta.parameterRole = 'XV15_VALIDATION_INSTANCE';
P13.meta.xv15OverlayApplied = true;
P13.meta.claimBoundary = ['Partial public XV-15 validation adapter. ' ...
    'Blocked fields and missing records prevent full-aircraft accuracy claims.'];
P13.meta.sourceManifest = manifest.sourceManifest;
P13.meta.blockedPaths = manifest.blockedLegacyPaths;
P13.meta.modifiedPaths = manifest.modifiedPaths;
end
