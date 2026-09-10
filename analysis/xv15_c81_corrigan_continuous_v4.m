function [CL,CD,meta]=xv15_c81_corrigan_continuous_v4(alphaRad,Mach,rOverR,chord_m,R_m,mode)
%XV15_C81_CORRIGAN_CONTINUOUS_V4 Explicit new model, not the frozen M1 helper.
% Koning NASA/CR2016-219086 printed pp20-21, PDF36-37, equations17-20.
% Source SHA256:225e8ba7ff647dfd396a6287e592f9b4b44f94ad05199c9e937ff1b4ca857adf.
% Source explains correction applies only to positive section lift, assuming
% zero-lift alpha approximately zero. Current C81 camber makes that assumption
% false. An alpha>0 hard gate therefore creates a finite lift jump at alpha=0.
% V4 uses the ACTUAL CL>0 boundary, where the augmentation vanishes continuously.
% This is an explicit source-motivated modeling revision, not a verbatim copy
% of equation18's approximate zero-angle gate. No free smoothing width or fit.
% The previously omitted linear washout from30 to60deg follows equations19-20.
% Existing C81 input clamping and all its diagnostics remain visible. This
% correction does NOT supply missing high-incidence/reverse-flow polar data.
if nargin<6||~strcmp(mode,'CORRIGAN_GENERIC_N1')
    error('xv15_c81_corrigan_continuous_v4:InvalidMode','Only fixed n=1 is supported.');
end
[base,CD,meta]=xv15_c81_section_lookup(alphaRad,Mach,rOverR);
a=alphaRad*180/pi;
if ~isreal([a(:);chord_m(:);rOverR(:);R_m])|| ...
        any(~isfinite([a(:);chord_m(:);rOverR(:);R_m]))|| ...
        any(chord_m(:)<=0)||any(rOverR(:)<=0)||~isscalar(R_m)||R_m<=0
    error('xv15_c81_corrigan_continuous_v4:InvalidGeometry','Finite positive section geometry required.');
end
KL=1.291*(chord_m./(rOverR*R_m)).^.0775+zeros(size(base));
wash=ones(size(a));mid=a>30&a<60;wash(mid)=(60-a(mid))/30;wash(a>=60)=0;
apply=base>0&wash>0;
CL=base;CL(apply)=(1+wash(apply).*(KL(apply)-1)).*base(apply);
meta.mode='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4';meta.nExponent=1;
meta.KL=KL;meta.applyMask=apply;meta.applyCount=nnz(apply);
meta.washoutWeight=wash;meta.positiveLiftBoundaryUsed=true;
meta.KLMinApplied=NaN;meta.KLMaxApplied=NaN;
if any(apply(:)),meta.KLMinApplied=min(KL(apply));meta.KLMaxApplied=max(KL(apply));end
meta.sourceClassRotational='SOURCE_MOTIVATED_CONTINUOUS_POSITIVE_LIFT_REVISION';
meta.independence='NOT_FITTED_TO_TRIM_TARGETS_NEW_MODEL_REQUIRES_REVALIDATION';
meta.claimBoundary='CONTINUITY_REPAIR_AND_SOURCE_WASHOUT_NOT_HIGH_ALPHA_POLAR_VALIDATION';
end
