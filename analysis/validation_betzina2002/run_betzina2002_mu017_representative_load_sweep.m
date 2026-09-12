function results = run_betzina2002_mu017_representative_load_sweep(outputDir)
%RUN_BETZINA2002_MU017_REPRESENTATIVE_LOAD_SWEEP
% Cost-sensitive diagnostic: 12 representative points at advance ratio 0.17
% and shaft angles -5/0/+5 deg across four thrust levels. Experimental
% torque values are secondary figure digitization from a published Flow360
% replot of Betzina (2002), not NASA raw data. Torque is never fitted.
rootDir=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1 || isempty(outputDir), outputDir=fullfile(rootDir,'results','betzina2002_mu017_representative_load_sweep'); end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
addpath(fullfile(rootDir,'analysis','stage2_aircraft')); addpath(fullfile(rootDir,'analysis','validation_betzina2002'));
P=stage2_matched_rotor_parameters(); P.rotor.Omega=0.691*P.env.aSound/P.rotor.R;
sigma=0.089;
src=fullfile(rootDir,'analysis','validation_betzina2002','data','BETZINA2002_MU017_REPRESENTATIVE_FIG18_SECONDARY_DIGITIZATION.csv');
D=readtable(src);
rows=table();
for a=unique(D.alpha_exp_deg).'
    seed=[5 -1.5 1];
    ids=find(D.alpha_exp_deg==a); [~,ord]=sort(D.target_CT_over_sigma(ids)); ids=ids(ord);
    for k=1:numel(ids)
        i=ids(k); targetCT=D.target_CT_over_sigma(i)*sigma;
        [z,e,rep]=solve_betzina2002_operating_state(P,D.advance_ratio(i),a,targetCT,seed);
        if e.solutionValid, seed=z; end
        expNorm=D.CQ_over_sigma_exp_digitized(i); predNorm=e.CQ/sigma;
        resid=predNorm-expNorm;
        halfNorm=D.CQ_raw_digitization_halfwidth(i)/sigma;
        one=table(a,D.advance_ratio(i),D.target_CT_over_sigma(i),z(1),z(2),z(3), ...
            e.CT/sigma,predNorm,expNorm,resid,abs(resid),halfNorm,abs(resid)<=halfNorm, ...
            e.beta1cDeg,e.beta1sDeg,e.physicalConverged,e.solutionValid,rep.iterations,rep.residualNorm,e.alphaClampCount,e.machClampCount, ...
            'VariableNames',{'alpha_exp_deg','advance_ratio','target_CT_over_sigma','theta75_deg','cyclicLong_deg','cyclicLat_deg', ...
            'CT_over_sigma_model','CQ_over_sigma_model','CQ_over_sigma_exp_digitized','residual_model_minus_exp','absResidual', ...
            'digitization_halfwidth_CQ_over_sigma','withinDigitizationBand','beta1c_deg','beta1s_deg','physicalConverged','solutionValid', ...
            'solveIterations','solveResidualNorm','alphaClampCount','machClampCount'});
        rows=[rows;one]; %#ok<AGROW>
    end
end
writetable(rows,fullfile(outputDir,'BETZINA2002_MU017_REPRESENTATIVE_LOAD_SWEEP_POINTS.csv'));
A=unique(rows.alpha_exp_deg); summary=table();
for j=1:numel(A)
    s=rows(rows.alpha_exp_deg==A(j),:);
    p=polyfit(s.target_CT_over_sigma,s.CQ_over_sigma_model,1); q=polyfit(s.target_CT_over_sigma,s.CQ_over_sigma_exp_digitized,1);
    one=table(A(j),mean(s.absResidual),sqrt(mean(s.residual_model_minus_exp.^2)),mean(s.residual_model_minus_exp), ...
        p(1),q(1),p(1)-q(1),sum(s.withinDigitizationBand), ...
        'VariableNames',{'alpha_exp_deg','MAE_CQ_over_sigma','RMSE_CQ_over_sigma','signedBias_CQ_over_sigma', ...
        'model_dCQoverSigma_dCToverSigma','exp_dCQoverSigma_dCToverSigma','slopeDifference','pointsWithinDigitizationBand'});
    summary=[summary;one]; %#ok<AGROW>
end
writetable(summary,fullfile(outputDir,'BETZINA2002_MU017_REPRESENTATIVE_LOAD_SWEEP_SUMMARY.csv'));
results=struct('points',rows,'summary',summary,'allPhysical',all(rows.physicalConverged),'allSolved',all(rows.solutionValid), ...
    'claimBoundary','SECONDARY_FIGURE_DIGITIZATION_TRIAGE_TORQUE_NOT_FITTED_NOT_NASA_RAW_TABLE');
save(fullfile(outputDir,'BETZINA2002_MU017_REPRESENTATIVE_LOAD_SWEEP_RESULTS.mat'),'results');
end
