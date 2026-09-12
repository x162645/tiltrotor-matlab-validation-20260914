function results = run_betzina2002_failure_fingerprint(outputDir)
%RUN_BETZINA2002_FAILURE_FINGERPRINT
% Analysis-only replay of the frozen 12 Betzina operating points.
% No trim, parameter fitting, or physics change occurs here. The controls
% come from the previously frozen FAST_LM evidence CSV; this routine only
% exposes where thrust/torque are produced on the rotor disk.

rootDir=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1 || isempty(outputDir)
    outputDir=fullfile(rootDir,'results','betzina2002_failure_fingerprint');
end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
addpath(fullfile(rootDir,'analysis','stage2_aircraft'));
addpath(fullfile(rootDir,'analysis','validation_betzina2002'));

src=fullfile(rootDir,'analysis','validation_betzina2002','evidence','BETZINA2002_FAST_LM_PREDICTIONS.csv');
base=readtable(src);
P=stage2_matched_rotor_parameters();
P.rotor.Omega=0.691*P.env.aSound/P.rotor.R;

summary=table();
raw=table();
for i=1:height(base)
    b=base(i,:);
    e=betzina2002_two_cyclic_rotor(P,b.advance_ratio,b.alpha_exp_deg, ...
        b.theta75_deg,b.cyclicLong_deg,b.cyclicLat_deg);
    assert(e.physicalConverged,'Replayed point is not physical.');
    assert(abs(e.CT-b.CT_model)<5e-10,'CT replay drifted from frozen evidence.');
    assert(abs(e.CQ-b.CQ_model)<5e-10,'CQ replay drifted from frozen evidence.');

    m=e.sectionMap;
    dT=m.dT_N; dQ=m.dQ_Nm; nr=numel(m.rOverR); naz=numel(m.psiDeg);
    outer=m.rOverR>=0.8;
    posT=sum(max(dT(:),0)); negT=-sum(min(dT(:),0));
    posQ=sum(max(dQ(:),0)); negQ=-sum(min(dQ(:),0));
    totalT=sum(dT(:)); totalQ=sum(dQ(:));
    outerT=sum(sum(dT(:,outer))); outerQ=sum(sum(dQ(:,outer)));
    tipNegT=mean(reshape(dT(:,outer)<0,[],1));
    tipNegQ=mean(reshape(dQ(:,outer)<0,[],1));

    % Define the two azimuthal halves by local tangential speed rather than
    % by a convention-dependent advancing/retreating label.
    meanUT=mean(m.UT_mps,2);
    medUT=median(meanUT);
    highMask=meanUT>=medUT; lowMask=~highMask;
    highQ=sum(sum(dQ(highMask,:))); lowQ=sum(sum(dQ(lowMask,:)));
    highT=sum(sum(dT(highMask,:))); lowT=sum(sum(dT(lowMask,:)));

    outerAlpha=m.alphaDeg(:,outer);
    one=table(b.alpha_exp_deg,b.advance_ratio,e.theta75Deg,e.cyclicLongDeg,e.cyclicLatDeg, ...
        e.CT/0.089,e.CQ/0.089,outerT/totalT,outerQ/totalQ, ...
        mean(dT(:)<0),mean(dQ(:)<0),negT/max(posT,eps),negQ/max(posQ,eps), ...
        tipNegT,tipNegQ,min(outerAlpha(:)),max(outerAlpha(:)), ...
        highT/totalT,lowT/totalT,highQ/totalQ,lowQ/totalQ, ...
        e.alphaClampCount,e.machClampCount,e.stallDelayApplyCount, ...
        'VariableNames',{'alpha_exp_deg','advance_ratio','theta75_deg','cyclicLong_deg','cyclicLat_deg', ...
        'CT_over_sigma','CQ_over_sigma','outer20_T_fraction','outer20_Q_fraction', ...
        'negative_T_cell_fraction','negative_Q_cell_fraction','negative_T_magnitude_over_positive', ...
        'negative_Q_magnitude_over_positive','outer20_negative_T_cell_fraction','outer20_negative_Q_cell_fraction', ...
        'outer20_min_alpha_deg','outer20_max_alpha_deg','high_UT_half_T_fraction','low_UT_half_T_fraction', ...
        'high_UT_half_Q_fraction','low_UT_half_Q_fraction','alphaClampCount','machClampCount','stallDelayApplyCount'});
    summary=[summary;one]; %#ok<AGROW>

    [psiGrid,rGrid]=ndgrid(m.psiDeg,m.rOverR);
    ncell=naz*nr;
    caseRaw=table(repmat(b.alpha_exp_deg,ncell,1),repmat(b.advance_ratio,ncell,1), ...
        psiGrid(:),rGrid(:),m.dT_N(:),m.dQ_Nm(:),m.alphaDeg(:),m.Mach(:),m.CL(:),m.CD(:),m.UT_mps(:),m.UP_mps(:), ...
        'VariableNames',{'alpha_exp_deg','advance_ratio','psi_deg','r_over_R','dT_N','dQ_Nm','section_alpha_deg','Mach','CL','CD','UT_mps','UP_mps'});
    raw=[raw;caseRaw]; %#ok<AGROW>
end

writetable(summary,fullfile(outputDir,'BETZINA2002_FAILURE_FINGERPRINT_SUMMARY.csv'));
writetable(raw,fullfile(outputDir,'BETZINA2002_FAILURE_FINGERPRINT_RAW_MAP.csv'));

% Compact angle-wise trends for decision making.
alphaVals=unique(summary.alpha_exp_deg);
trend=table();
for j=1:numel(alphaVals)
    a=alphaVals(j); s=summary(summary.alpha_exp_deg==a,:);
    one=table(a,mean(s.outer20_Q_fraction),max(s.outer20_negative_T_cell_fraction), ...
        max(s.outer20_negative_Q_cell_fraction),max(s.negative_Q_magnitude_over_positive), ...
        min(s.outer20_min_alpha_deg),max(s.outer20_max_alpha_deg), ...
        mean(s.high_UT_half_Q_fraction), ...
        'VariableNames',{'alpha_exp_deg','mean_outer20_Q_fraction','max_outer20_negative_T_cell_fraction', ...
        'max_outer20_negative_Q_cell_fraction','max_negative_Q_magnitude_over_positive', ...
        'min_outer20_alpha_deg','max_outer20_alpha_deg','mean_high_UT_half_Q_fraction'});
    trend=[trend;one]; %#ok<AGROW>
end
writetable(trend,fullfile(outputDir,'BETZINA2002_FAILURE_FINGERPRINT_ALPHA_TREND.csv'));

results=struct('summary',summary,'trend',trend,'allPhysical',true, ...
    'claimBoundary','DIAGNOSTIC_ONLY_FROZEN_12_POINT_REPLAY_NO_PHYSICS_CHANGE_NO_FIT');
save(fullfile(outputDir,'BETZINA2002_FAILURE_FINGERPRINT_RESULTS.mat'),'results');
end
