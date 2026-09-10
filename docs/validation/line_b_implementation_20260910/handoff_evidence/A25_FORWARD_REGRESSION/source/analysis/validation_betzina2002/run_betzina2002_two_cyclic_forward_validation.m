function results = run_betzina2002_two_cyclic_forward_validation(outputDir)
%RUN_BETZINA2002_TWO_CYCLIC_FORWARD_VALIDATION
% External forward-flight rotor validation against Betzina (2002).
%
% Experimental contract reproduced:
%   Mtip = 0.691
%   mu = V/(Omega R) = 0.125, 0.15, 0.17, 0.20
%   shaft angle alpha = -15, 0, +15 deg
%   CT/sigma = 0.075, sigma = 0.089
%   first harmonic flapping trimmed to zero (+/-0.1 deg)
%
% For each operating condition ONLY theta75, longitudinal cyclic, and
% lateral/cosine-harmonic cyclic are solved to reproduce the experimental
% operating state. Torque is never fitted and remains an external prediction.

rootDir=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1 || isempty(outputDir), outputDir=fullfile(rootDir,'results','betzina2002_two_cyclic_forward_validation'); end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
addpath(fullfile(rootDir,'analysis','stage2_aircraft'));
addpath(fullfile(rootDir,'analysis','validation_betzina2002'));
P=stage2_matched_rotor_parameters();
P.rotor.Omega=0.691*P.env.aSound/P.rotor.R;
sigma=0.089; targetCTOverSigma=0.075; targetCT=sigma*targetCTOverSigma;
muList=[0.125 0.15 0.17 0.20]; alphaList=[-15 0 15];
rows=table();
for ia=1:numel(alphaList)
    alphaDeg=alphaList(ia);
    seed=[5 -1 1];
    for im=1:numel(muList)
        mu=muList(im);
        [z,ev,report]=solve_case(P,mu,alphaDeg,targetCT,seed);
        if ev.solutionValid, seed=z; end
        one=table(alphaDeg,mu,targetCTOverSigma,targetCT,z(1),z(2),z(3), ...
            ev.CT,ev.CT/sigma,ev.CQ,ev.CQ/sigma,ev.beta0Deg,ev.beta1cDeg,ev.beta1sDeg, ...
            ev.firstHarmonicFlapDeg,ev.thrust,ev.torque,ev.physicalConverged,ev.solutionValid, ...
            report.iterations,report.functionCount,report.residualNorm,{ev.physicalStatus}, ...
            'VariableNames',{'alpha_exp_deg','advance_ratio','target_CT_over_sigma','target_CT', ...
            'theta75_deg','cyclicLong_deg','cyclicLat_deg','CT_model','CT_over_sigma_model', ...
            'CQ_model','CQ_over_sigma_model','beta0_deg','beta1c_deg','beta1s_deg', ...
            'first_harmonic_flap_deg','thrust_N','torque_Nm','physicalConverged','solutionValid', ...
            'solveIterations','functionCount','solveResidualNorm','physicalStatus'});
        rows=[rows;one]; %#ok<AGROW>
    end
end
writetable(rows,fullfile(outputDir,'BETZINA2002_TWO_CYCLIC_MODEL_PREDICTIONS.csv'));
metaName={'source';'facility';'rotor';'tip_mach';'sigma';'target_CT_over_sigma';'advance_ratios'; ...
    'shaft_angles_deg';'flapping_requirement';'control_fit_variables';'prediction_variable'; ...
    'trim_solver';'trim_numerical_guard';'delta3_test_deg';'delta3_model_status'; ...
    'RTA_body_status';'model_identity';'claim_boundary'};
metaValue={'Betzina_2002_Rotor_Performance_of_an_Isolated_Full_Scale_XV15_Tiltrotor_in_Helicopter_Mode'; ...
    'NASA_Ames_80_by_120_Foot_Wind_Tunnel';'full_scale_XV15_right_hand_rotor';'0.691';'0.089';'0.075'; ...
    '0.125,0.15,0.17,0.20';'-15,0,15';'beta1c_and_beta1s_each_target_zero_with_0.1deg_acceptance'; ...
    'theta75,cyclicLong,cyclicLat';'CQ_over_sigma';'multi_start_fminsearch_operating_state_only'; ...
    'theta75_-10_to_25_deg_and_each_cyclic_-15_to_15_deg_SEARCH_GUARD_NOT_CLAIMED_TEST_LIMIT'; ...
    '-36';'NOT_REPRESENTED_ACTIVE_MODEL_FIELD';'NOT_MODELED_EXPECTED_MINOR_TORQUE_EFFECT_PER_BETZINA'; ...
    'M1_EVIDENCE_V1_FORWARD_PROPAGATION_TWO_CYCLIC_DIAGNOSTIC'; ...
    'EXTERNAL_FORWARD_ROTOR_VALIDATION_NO_TORQUE_FIT_NOT_WHOLE_AIRCRAFT_VALIDATION'};
metadata=table(metaName,metaValue); writetable(metadata,fullfile(outputDir,'BETZINA2002_TWO_CYCLIC_METADATA.csv'));
results=struct(); results.predictions=rows; results.metadata=metadata;
results.allSolved=all(rows.solutionValid); results.allPhysical=all(rows.physicalConverged);
results.maxCTRelativeError=max(abs(rows.CT_model-targetCT)/targetCT);
results.maxAbsBeta1cDeg=max(abs(rows.beta1c_deg)); results.maxAbsBeta1sDeg=max(abs(rows.beta1s_deg));
results.claimBoundary='EXTERNAL_FORWARD_ROTOR_VALIDATION_OPERATING_CONTROLS_ONLY_TORQUE_UNFITTED';
save(fullfile(outputDir,'BETZINA2002_TWO_CYCLIC_RESULTS.mat'),'results');
end

function [zBest,eBest,reportBest]=solve_case(P,mu,alphaDeg,targetCT,continuationSeed)
starts=[continuationSeed(:).';5 -1 1;8 -2 1;3 -2 1;0 -3 1;-3 -4 1];
opts=optimset('Display','off','MaxIter',120,'MaxFunEvals',500,'TolX',1e-7,'TolFun',1e-10);
bestJ=Inf; zBest=[NaN NaN NaN]; eBest=invalid_eval();
reportBest=struct('iterations',0,'functionCount',0,'residualNorm',Inf);
for s=1:size(starts,1)
    z0=starts(s,:);
    try
        [z,j,~,output]=fminsearch(@objective,z0,opts);
        e=evaluate_state(P,mu,alphaDeg,z);
    catch
        continue;
    end
    if e.physicalConverged && j<bestJ
        bestJ=j; zBest=z(:).'; eBest=e;
        reportBest=struct('iterations',output.iterations,'functionCount',output.funcCount, ...
            'residualNorm',sqrt(max(j,0)));
    end
    if is_solution(e,targetCT)
        e.solutionValid=true; zBest=z(:).'; eBest=e;
        reportBest=struct('iterations',output.iterations,'functionCount',output.funcCount, ...
            'residualNorm',sqrt(max(j,0)));
        return;
    end
end
eBest.solutionValid=is_solution(eBest,targetCT);

    function J=objective(z)
        if any(~isfinite(z)), J=1e12; return; end
        low=[-10 -15 -15]; high=[25 15 15];
        below=max(low-z(:).',0); above=max(z(:).'-high,0);
        boundPenalty=sum(below.^2+above.^2);
        if boundPenalty>0, J=1e5+1e4*boundPenalty; return; end
        e=evaluate_state(P,mu,alphaDeg,z);
        if ~e.physicalConverged, J=1e4; return; end
        r=residual(e,targetCT); J=r.'*r;
    end
end

function tf=is_solution(e,targetCT)
tf=e.physicalConverged && abs((e.CT-targetCT)/targetCT)<=0.005 && ...
    abs(e.beta1cDeg)<=0.1 && abs(e.beta1sDeg)<=0.1;
end

function r=residual(e,targetCT)
if ~e.physicalConverged, r=[1e3;1e3;1e3]; return; end
r=[(e.CT-targetCT)/targetCT;e.beta1cDeg/0.1;e.beta1sDeg/0.1];
end

function e=evaluate_state(P,mu,alphaDeg,z)
try
    e=betzina2002_two_cyclic_rotor(P,mu,alphaDeg,z(1),z(2),z(3));
    e.solutionValid=false;
catch ME
    e=invalid_eval(); e.physicalStatus=['ERROR_' ME.identifier];
end
end

function e=invalid_eval()
e=struct('CT',NaN,'CQ',NaN,'beta0Deg',NaN,'beta1cDeg',NaN,'beta1sDeg',NaN, ...
    'firstHarmonicFlapDeg',NaN,'thrust',NaN,'torque',NaN,'physicalConverged',false, ...
    'solutionValid',false,'physicalStatus','NO_VALID_SOLUTION');
end
