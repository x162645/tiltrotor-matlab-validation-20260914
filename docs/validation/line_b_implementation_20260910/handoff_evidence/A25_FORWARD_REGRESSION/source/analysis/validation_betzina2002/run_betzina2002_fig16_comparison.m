function results = run_betzina2002_fig16_comparison(outputDir)
%RUN_BETZINA2002_FIG16_COMPARISON
% Compare frozen MATLAB forward predictions against explicitly labeled
% diagnostic digitization of the CURRENT TEST open symbols in Betzina Fig.16.
%
% MAPE is deliberately NOT used because the alpha=+15, mu=0.20 test torque
% approaches zero, making relative percentage error singular/misleading.
% Primary metrics are absolute CQ/sigma residual, RMSE, signed bias, and
% residual magnitude relative to the documented forward-flight repeatability
% maximum of 0.00006 CQ/sigma (Betzina 2002, Fig.21 discussion).

rootDir=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1 || isempty(outputDir)
    outputDir=fullfile(rootDir,'results','betzina2002_fig16_comparison');
end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
predPath=fullfile(rootDir,'analysis','validation_betzina2002','evidence','BETZINA2002_FAST_LM_PREDICTIONS.csv');
expPath=fullfile(rootDir,'analysis','validation_betzina2002','data','BETZINA2002_FIG16_CURRENT_TEST_DIGITIZATION.csv');
P=readtable(predPath); E=readtable(expPath);
if height(P)~=12 || height(E)~=12, error('Expected 12 prediction and 12 digitized rows.'); end

rows=table();
for k=1:height(E)
    mask=P.alpha_exp_deg==E.alpha_exp_deg(k) & abs(P.advance_ratio-E.advance_ratio(k))<1e-12;
    if sum(mask)~=1, error('Could not uniquely match alpha/mu row.'); end
    model=P.CQ_over_sigma_model(mask);
    expv=E.CQ_over_sigma_exp(k);
    residual=model-expv;
    absResidual=abs(residual);
    withinDigitizationBand=absResidual<=E.digitization_halfwidth(k);
    repeatabilityUnits=absResidual/0.00006;
    one=table(E.alpha_exp_deg(k),E.advance_ratio(k),expv,model,residual,absResidual, ...
        E.digitization_halfwidth(k),withinDigitizationBand,repeatabilityUnits, ...
        'VariableNames',{'alpha_exp_deg','advance_ratio','CQ_over_sigma_exp_digitized', ...
        'CQ_over_sigma_model','residual_model_minus_exp','absResidual','digitization_halfwidth', ...
        'withinDigitizationBand','absResidual_over_repeatability'});
    rows=[rows;one]; %#ok<AGROW>
end
writetable(rows,fullfile(outputDir,'BETZINA2002_FIG16_POINT_COMPARISON.csv'));

alphas=[-15;0;15]; summary=table();
for i=1:numel(alphas)
    m=rows.alpha_exp_deg==alphas(i); r=rows.residual_model_minus_exp(m);
    alpha_exp_deg=alphas(i);
    MAE_CQ_over_sigma=mean(abs(r));
    RMSE_CQ_over_sigma=sqrt(mean(r.^2));
    signedBias_CQ_over_sigma=mean(r);
    maxAbsResidual=max(abs(r));
    pointsWithinDigitizationBand=sum(rows.withinDigitizationBand(m));
    meanAbsResidual_over_repeatability=mean(rows.absResidual_over_repeatability(m));
    one=table(alpha_exp_deg,MAE_CQ_over_sigma,RMSE_CQ_over_sigma,signedBias_CQ_over_sigma, ...
        maxAbsResidual,pointsWithinDigitizationBand,meanAbsResidual_over_repeatability);
    summary=[summary;one]; %#ok<AGROW>
end
writetable(summary,fullfile(outputDir,'BETZINA2002_FIG16_ALPHA_SUMMARY.csv'));

allR=rows.residual_model_minus_exp;
overall=table(mean(abs(allR)),sqrt(mean(allR.^2)),mean(allR),max(abs(allR)), ...
    sum(rows.withinDigitizationBand),mean(rows.absResidual_over_repeatability), ...
    'VariableNames',{'MAE_CQ_over_sigma','RMSE_CQ_over_sigma','signedBias_CQ_over_sigma', ...
    'maxAbsResidual','pointsWithinDigitizationBand','meanAbsResidual_over_repeatability'});
writetable(overall,fullfile(outputDir,'BETZINA2002_FIG16_OVERALL_SUMMARY.csv'));

results=struct(); results.rows=rows; results.summary=summary; results.overall=overall;
results.claimBoundary=['FIGURE_DIGITIZATION_DIAGNOSTIC_ONLY_NOT_RAW_TEST_TABLE_' ...
    'NO_TORQUE_FIT_M1_FORWARD_TWO_CYCLIC_EXTERNAL_COMPARISON'];
save(fullfile(outputDir,'BETZINA2002_FIG16_COMPARISON.mat'),'results');
end
