function results = run_betzina2002_forward_rotor_diagnostic(outputDir)
%RUN_BETZINA2002_FORWARD_ROTOR_DIAGNOSTIC
% Analysis-only external comparison against Betzina (2002), full-scale XV-15
% rotor in the NASA Ames 80-by-120-Foot Wind Tunnel.
%
% Published test contract used here:
%   tip Mach number                  = 0.691
%   advance ratio V/(Omega R)       = 0.125, 0.15, 0.17, 0.20
%   shaft angle alpha               = -15, 0, +15 deg
%   nominal CT/sigma for Fig. 16    = 0.075
%   thrust-weighted solidity sigma  = 0.089
%   first-harmonic flapping         = trimmed to zero (+/-0.1 deg)
%
% The runner does NOT fit model physics to Betzina data. For each published
% operating condition it solves only the experimental operating controls:
% physical theta_75 and longitudinal cyclic, so that the model reaches the
% published target CT/sigma and approximately zero first-harmonic flapping.
% The resulting CQ/sigma is then an external prediction to compare with the
% experimental Fig. 16 curve.
%
% IMPORTANT MODEL-IDENTITY BOUNDARY:
% This exercises the existing Stage-2 M1_EVIDENCE_V1_FORWARD_PROPAGATION
% extension (Corrigan n=1/global momentum). It is NOT M1-A/B/C and is not
% silently relabeled as a validated forward-flight rotor.

rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin < 1 || isempty(outputDir)
    outputDir = fullfile(rootDir,'results','betzina2002_forward_diagnostic');
end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
addpath(fullfile(rootDir,'analysis','stage2_aircraft'));

P = stage2_matched_rotor_parameters();
P.rotor.Omega = 0.691 * P.env.aSound / P.rotor.R;

tipSpeed = P.rotor.Omega * P.rotor.R;
A = pi*P.rotor.R^2;
sigma = 0.089;
targetCTOverSigma = 0.075;
targetCT = sigma*targetCTOverSigma;
muList = [0.125 0.15 0.17 0.20];
alphaList = [-15 0 15];

rows = table();
for ia = 1:numel(alphaList)
    alphaDeg = alphaList(ia);
    seed = [8 0]; % [physical theta75 deg, cyclicLong deg]
    for im = 1:numel(muList)
        muTotal = muList(im);
        [best,ev] = solve_case(P,muTotal,alphaDeg,targetCT,seed);
        if ev.valid
            seed = best;
        end
        one = table(alphaDeg,muTotal,-alphaDeg,targetCTOverSigma,targetCT, ...
            ev.theta75_deg,ev.cyclicLong_deg,ev.CT,ev.CT/sigma,ev.CQ,ev.CQ/sigma, ...
            ev.beta0_deg,ev.beta1c_deg,ev.beta1s_deg,ev.flap1_deg, ...
            ev.thrust_N,ev.torque_Nm,ev.physicalConverged,ev.valid,ev.objective, ...
            {ev.physicalStatus}, ...
            'VariableNames',{'alpha_exp_deg','advance_ratio','betaM_model_deg', ...
            'target_CT_over_sigma','target_CT','theta75_deg','cyclicLong_deg', ...
            'CT_model','CT_over_sigma_model','CQ_model','CQ_over_sigma_model', ...
            'beta0_deg','beta1c_deg','beta1s_deg','first_harmonic_flap_deg', ...
            'thrust_N','torque_Nm','physicalConverged','solutionValid','objective', ...
            'physicalStatus'});
        rows = [rows;one]; %#ok<AGROW>
    end
end

writetable(rows,fullfile(outputDir,'BETZINA2002_FORWARD_MODEL_PREDICTIONS.csv'));

metaName = { ...
    'source';'source_test_facility';'source_rotor';'tip_mach'; ...
    'sigma';'target_CT_over_sigma';'advance_ratios';'shaft_angles_deg'; ...
    'shaft_angle_mapping';'flapping_target';'model_identity';'claim_boundary'};
metaValue = { ...
    'Betzina_2002_Rotor_Performance_of_an_Isolated_Full-Scale_XV-15_Tiltrotor_in_Helicopter_Mode'; ...
    'NASA_Ames_80_by_120_Foot_Wind_Tunnel'; ...
    'full_scale_XV15_right_hand_rotor'; ...
    '0.691';'0.089';'0.075';'0.125,0.15,0.17,0.20';'-15,0,15'; ...
    'betaM_model=-alpha_exp_based_on_model_thrust-axis_sign_convention'; ...
    'first_harmonic_flap_norm_near_zero_target_0p1deg_scale'; ...
    'M1_EVIDENCE_V1_FORWARD_PROPAGATION'; ...
    'ANALYSIS_ONLY_EXTERNAL_FORWARD_ROTOR_DIAGNOSTIC_NO_PHYSICS_FIT_NOT_WHOLE_AIRCRAFT_VALIDATION'};
metadata = table(metaName,metaValue);
writetable(metadata,fullfile(outputDir,'BETZINA2002_FORWARD_METADATA.csv'));

results = struct();
results.predictions = rows;
results.metadata = metadata;
results.allSolved = all(rows.solutionValid);
results.allPhysical = all(rows.physicalConverged);
results.maxCTRelativeError = max(abs(rows.CT_model-targetCT)/targetCT);
results.maxFlapDeg = max(rows.first_harmonic_flap_deg);
results.claimBoundary = ['EXTERNAL_FORWARD_ROTOR_DIAGNOSTIC_' ...
    'NO_BETZINA_PERFORMANCE_TARGET_USED_TO_FIT_PHYSICS'];
save(fullfile(outputDir,'BETZINA2002_FORWARD_RESULTS.mat'),'results');
end

function [best,evBest] = solve_case(P,muTotal,alphaDeg,targetCT,continuationSeed)
starts = [continuationSeed; 5 0; 7 0; 9 0; 11 0; 13 0; 16 0];
best = [NaN NaN];
evBest = invalid_eval();
bestJ = Inf;
opts = optimset('Display','off','MaxIter',160,'MaxFunEvals',1200, ...
    'TolX',1e-7,'TolFun',1e-10);
for k = 1:size(starts,1)
    z0 = starts(k,:);
    try
        [z,j] = fminsearch(@objective,z0,opts);
        ev = evaluate(z);
    catch
        continue;
    end
    if ev.valid && j < bestJ
        bestJ = j;
        best = z;
        evBest = ev;
        evBest.objective = j;
    end
end

    function J = objective(z)
        if any(~isfinite(z))
            J = 1e12; return;
        end
        boundPenalty = 0;
        if z(1)<0, boundPenalty=boundPenalty+(0-z(1))^2; end
        if z(1)>25, boundPenalty=boundPenalty+(z(1)-25)^2; end
        if z(2)<-15, boundPenalty=boundPenalty+(z(2)+15)^2; end
        if z(2)>15, boundPenalty=boundPenalty+(z(2)-15)^2; end
        if boundPenalty>0
            J=1e6+1e4*boundPenalty; return;
        end
        e = evaluate(z);
        if ~e.valid
            J=1e8; return;
        end
        eCT = (e.CT-targetCT)/targetCT;
        eFlap = e.flap1_deg/0.1;
        J = eCT^2 + eFlap^2;
    end

    function e = evaluate(z)
        e = invalid_eval();
        try
            R = P.rotor.R;
            tipSpeed = P.rotor.Omega*R;
            V = muTotal*tipSpeed;
            x = zeros(9,1);
            x(1) = V;
            betaM = -alphaDeg*pi/180;
            x75Linear = (0.75-P.rotor.rootCut)/max(1-P.rotor.rootCut,eps);
            theta75 = z(1)*pi/180;
            rotorCtrl = struct();
            rotorCtrl.collective = theta75-P.rotor.twistTip*x75Linear;
            rotorCtrl.cyclicLong = z(2)*pi/180;
            [~,~,out] = m1_evidence_v1_forward_rotor( ...
                x,rotorCtrl,betaM,1,zeros(3,1),P);
            A = pi*R^2;
            tip2 = tipSpeed^2;
            CT = out.thrust/(P.env.rho*A*tip2);
            CQ = out.torque/(P.env.rho*A*tip2*R);
            flap1 = hypot(out.beta1c,out.beta1s)*180/pi;
            finite = all(isfinite([CT,CQ,out.beta0,out.beta1c,out.beta1s]));
            e.valid = finite && out.physicalConverged && CT>0 && CQ>0;
            e.theta75_deg = z(1);
            e.cyclicLong_deg = z(2);
            e.CT = CT;
            e.CQ = CQ;
            e.beta0_deg = out.beta0*180/pi;
            e.beta1c_deg = out.beta1c*180/pi;
            e.beta1s_deg = out.beta1s*180/pi;
            e.flap1_deg = flap1;
            e.thrust_N = out.thrust;
            e.torque_Nm = out.torque;
            e.physicalConverged = out.physicalConverged;
            e.physicalStatus = out.physicalStatus;
            e.objective = Inf;
        catch ME
            e.physicalStatus = ['ERROR_' ME.identifier];
        end
    end
end

function e = invalid_eval()
e = struct('valid',false,'theta75_deg',NaN,'cyclicLong_deg',NaN, ...
    'CT',NaN,'CQ',NaN,'beta0_deg',NaN,'beta1c_deg',NaN,'beta1s_deg',NaN, ...
    'flap1_deg',NaN,'thrust_N',NaN,'torque_Nm',NaN, ...
    'physicalConverged',false,'physicalStatus','NO_VALID_SOLUTION','objective',Inf);
end
