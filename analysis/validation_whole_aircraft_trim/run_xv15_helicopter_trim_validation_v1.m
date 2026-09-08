function results = run_xv15_helicopter_trim_validation_v1(outputRoot)
%RUN_XV15_HELICOPTER_TRIM_VALIDATION_V1 First XV-15 aircraft trim pass.
%
% This analysis-only runner uses a frozen source-mapped XV-15 helicopter
% case and the real longitudinal-stick mixing contract.  It does NOT tune
% any model parameter to the GTRS or flight-test trim outputs.
%
% Quantitative comparison role:
%   Kleinhesselink 2007 Appendix C Table C-1 GTRS column
%   = validated-reference-simulation correlation, NOT raw flight truth.
%
% External flight-test role:
%   Figure 14 narrative trend check only until plot digitization provenance
%   is visually closed; no invented flight-test point values are scored.

if nargin < 1 || isempty(outputRoot)
    outputRoot = fullfile(pwd,'results','xv15_helicopter_trim_v1');
end
if ~exist(outputRoot,'dir'), mkdir(outputRoot); end

[P,contract] = xv15_helicopter_trim_parameters_v1();
here = fileparts(mfilename('fullpath'));
referencePath = fullfile(here,'reference_gtrs_helicopter_trim_kleinhesselink2007.csv');
reference = readtable(referencePath);

modelIdentity = 'M1_EVIDENCE_V1_PROPAGATION';
d2r = pi/180;
knot2mps = 0.514444;
x75 = (0.75-P.rotor.rootCut)/max(1-P.rotor.rootCut,eps);
collectiveSeed = P.validation.initialTheta75_deg*d2r - P.rotor.twistTip*x75;
baseSeed = [0*d2r; collectiveSeed; 4.8]; % theta, common collective, stick [in]

n = height(reference);
rows = repmat(empty_row(),n,1);
lastCredible = [];
reports = cell(n,1);
for i = 1:n
    condition = struct('name',sprintf('XV15_HELI_%06.2fKT',reference.speed_kts(i)), ...
        'V',reference.speed_kts(i)*knot2mps,'betaM',0,'gamma',0);
    if isempty(lastCredible)
        seed = baseSeed;
    else
        seed = lastCredible;
    end
    report = solve_one(condition,seed,P,modelIdentity);
    reports{i} = report;
    row = empty_row();
    row.speed_kts = reference.speed_kts(i);
    row.speed_mps = condition.V;
    row.solveReturned = report.solveReturned;
    row.solverConverged = report.solverConverged;
    row.physicalConverged = report.physicalConverged;
    row.physicalBranchSupported = report.physicalBranchSupported;
    row.credible = report.credible;
    row.residualNorm = report.residualNorm;
    row.status = report.status;
    row.exitflag = report.exitflag;
    row.invalidEvaluationCount = report.invalidEvaluationCount;
    if report.solveReturned
        z = report.z;
        p = report.point;
        alloc = p.allocation;
        row.theta_deg = z(1)/d2r;
        row.collectiveControl_deg = z(2)/d2r;
        row.stick_in = z(3);
        row.cyclicLong_deg = alloc.cyclicLong/d2r;
        row.theta1sRight_deg = alloc.physicalTheta1sRight/d2r;
        row.elevator_deg = alloc.elevator/d2r;
        if isfield(p.eomOut.rotorLeft,'theta75')
            row.theta75_deg = p.eomOut.rotorLeft.theta75/d2r;
        end
        row.leftThrust_N = p.eomOut.rotorLeft.thrust;
        row.rightThrust_N = p.eomOut.rotorRight.thrust;
        row.meanThrustPerRotor_lb = 0.5*(row.leftThrust_N+row.rightThrust_N)/4.4482216152605;
        row.theta_error_vs_GTRS_deg = row.theta_deg-reference.theta_gtrs_deg(i);
        row.stick_error_vs_GTRS_in = row.stick_in-reference.stick_gtrs_in(i);
        row.theta1s_error_vs_GTRS_deg = row.theta1sRight_deg-reference.theta1s_gtrs_deg(i);
        row.elevator_error_vs_GTRS_deg = row.elevator_deg-reference.elevator_gtrs_deg(i);
        row.thrust_error_vs_GTRS_pct = 100*(row.meanThrustPerRotor_lb- ...
            reference.thrust_per_rotor_gtrs_lb(i))/reference.thrust_per_rotor_gtrs_lb(i);
        if report.credible
            lastCredible = z;
        end
    end
    rows(i) = row;
end

points = struct2table(rows);
writetable(points,fullfile(outputRoot,'XV15_HELICOPTER_TRIM_V1_POINTS.csv'));

mask = points.credible;
if any(mask)
    thetaMAE = mean(abs(points.theta_error_vs_GTRS_deg(mask)));
    thetaRMSE = sqrt(mean(points.theta_error_vs_GTRS_deg(mask).^2));
    stickMAE = mean(abs(points.stick_error_vs_GTRS_in(mask)));
    stickRMSE = sqrt(mean(points.stick_error_vs_GTRS_in(mask).^2));
    theta1sMAE = mean(abs(points.theta1s_error_vs_GTRS_deg(mask)));
    elevatorMAE = mean(abs(points.elevator_error_vs_GTRS_deg(mask)));
    thrustMAPE = mean(abs(points.thrust_error_vs_GTRS_pct(mask)));
else
    thetaMAE=NaN; thetaRMSE=NaN; stickMAE=NaN; stickRMSE=NaN;
    theta1sMAE=NaN; elevatorMAE=NaN; thrustMAPE=NaN;
end

trendMask = mask & isfinite(points.stick_in) & isfinite(points.theta_deg);
if sum(trendMask) >= 2
    stickFit = polyfit(points.speed_kts(trendMask),points.stick_in(trendMask),1);
    thetaFit = polyfit(points.speed_kts(trendMask),points.theta_deg(trendMask),1);
    stickSlope_in_per_kt = stickFit(1);
    thetaSlope_deg_per_kt = thetaFit(1);
else
    stickSlope_in_per_kt = NaN;
    thetaSlope_deg_per_kt = NaN;
end
flightTrendCheck = isfinite(stickSlope_in_per_kt) && ...
    isfinite(thetaSlope_deg_per_kt) && stickSlope_in_per_kt > 0 && ...
    thetaSlope_deg_per_kt < 0;

summary = table(sum(mask),n,thetaMAE,thetaRMSE,stickMAE,stickRMSE, ...
    theta1sMAE,elevatorMAE,thrustMAPE,stickSlope_in_per_kt, ...
    thetaSlope_deg_per_kt,flightTrendCheck, ...
    'VariableNames',{'CredibleCount','DeclaredCaseCount','ThetaMAE_deg', ...
    'ThetaRMSE_deg','StickMAE_in','StickRMSE_in','Theta1sMAE_deg', ...
    'ElevatorMAE_deg','ThrustMAPE_pct','StickTrendSlope_in_per_kt', ...
    'ThetaTrendSlope_deg_per_kt','FlightNarrativeTrendCheck'});
writetable(summary,fullfile(outputRoot,'XV15_HELICOPTER_TRIM_V1_SUMMARY.csv'));

write_markdown_summary(fullfile(outputRoot,'XV15_HELICOPTER_TRIM_V1_SUMMARY.md'), ...
    contract,points,summary);

results = struct();
results.modelIdentity = modelIdentity;
results.validationIdentity = P.validation.identity;
results.contract = contract;
results.reference = reference;
results.points = points;
results.summary = summary;
results.reports = reports;
results.quantitativeReferenceRole = ...
    'GTRS_VALIDATED_REFERENCE_SIMULATION_CORRELATION_NOT_RAW_FLIGHT_DATA';
results.flightExternalRole = ...
    'FIGURE14_NARRATIVE_TREND_CHECK_NO_NUMERIC_FLIGHT_SCORE';
results.claimBoundary = [ ...
    'XV15_HELICOPTER_TRIM_FIRST_EXTERNAL_FALSIFICATION_PASS_' ...
    'NO_TARGET_FITTING_RETAIN_DECLARED_MODEL_FORM_CAVEATS'];
save(fullfile(outputRoot,'XV15_HELICOPTER_TRIM_V1_RESULTS.mat'),'results');

disp(points);
disp(summary);
fprintf('VALIDATION_IDENTITY=%s\n',P.validation.identity);
fprintf('GTRS_REFERENCE_ROLE=%s\n',results.quantitativeReferenceRole);
fprintf('FLIGHT_REFERENCE_ROLE=%s\n',results.flightExternalRole);
fprintf('TARGET_FITTING=NO\n');
end

function report = solve_one(condition,seed,P,modelIdentity)
d2r = pi/180;
bounds = [-35*d2r,35*d2r; P.control.collectiveLim(:).'; 0,9.6];
scale = [2*d2r;10*d2r;1.0];
options = optimset('Display',P.trim.display,'MaxIter',P.trim.maxIterations, ...
    'MaxFunEvals',12*P.trim.maxIterations,'TolX',1e-8,'TolFun',1e-10);
invalidCount = 0;
invalidIds = {};
y0 = zeros(3,1);
[yOpt,fval,exitflag,output] = fminsearch(@objective,y0,options);
zOpt = seed(:)+scale.*yOpt(:);
report = empty_report();
report.exitflag = exitflag;
report.output = output;
report.cost = fval;
report.z = zOpt;
report.invalidEvaluationCount = invalidCount;
report.invalidEvaluationIdentifiers = unique(invalidIds);
try
    point = evaluate_point(condition,zOpt,P,modelIdentity);
    report.solveReturned = true;
    report.point = point;
    scaledResidual = point.residual;
    scaledResidual(1:2) = scaledResidual(1:2)/P.env.g;
    report.residualNorm = norm(scaledResidual);
    report.solverConverged = exitflag > 0;
    report.physicalConverged = point.eomOut.physicalConverged;
    report.physicalBranchSupported = point.eomOut.physicalBranchSupported;
    span = bounds(:,2)-bounds(:,1);
    margin = min(zOpt-bounds(:,1),bounds(:,2)-zOpt)./span;
    report.atLimit = any(margin <= 1e-7);
    report.withinLimits = all(zOpt >= bounds(:,1)-1e-10 & zOpt <= bounds(:,2)+1e-10) && ...
        point.allocation.withinLimits;
    report.credible = report.solverConverged && ...
        report.residualNorm < P.trim.residualTolerance && ...
        point.finiteReal && report.physicalConverged && ...
        report.physicalBranchSupported && ~report.atLimit && report.withinLimits;
    if report.credible
        report.status = 'CREDIBLE_SOURCE_MAPPED_TRIM';
    elseif ~report.solverConverged
        report.status = 'SOLVER_NOT_CONVERGED';
    elseif ~report.physicalConverged
        report.status = ['PHYSICAL_' point.eomOut.physicalStatus];
    elseif ~report.withinLimits || report.atLimit
        report.status = 'CONTROL_OR_SEARCH_BOUNDARY_LIMITED';
    elseif report.residualNorm >= P.trim.residualTolerance
        report.status = 'RESIDUAL_FAILED';
    else
        report.status = 'NONCREDIBLE_UNCLASSIFIED';
    end
catch ME
    report.solveReturned = false;
    report.status = ['FINAL_EVALUATION_ERROR_' compact_id(ME.identifier)];
    report.finalErrorIdentifier = ME.identifier;
end

    function J = objective(y)
        z = seed(:)+scale.*y(:);
        if any(z < bounds(:,1)) || any(z > bounds(:,2))
            v = max(bounds(:,1)-z,0)./max(bounds(:,2)-bounds(:,1),eps) + ...
                max(z-bounds(:,2),0)./max(bounds(:,2)-bounds(:,1),eps);
            J = 1e4 + 1e4*sum(v.^2);
            return;
        end
        try
            p = evaluate_point(condition,z,P,modelIdentity);
            rs = p.residual;
            rs(1:2) = rs(1:2)/P.env.g;
            J = rs.'*rs;
            if ~p.allocation.withinLimits
                J = J + 1e3;
            end
            if ~p.eomOut.physicalConverged || ~p.eomOut.physicalBranchSupported
                invalidCount = invalidCount+1;
                invalidIds{end+1} = p.eomOut.physicalStatus; %#ok<AGROW>
                J = J + 1e3;
            end
            if ~isfinite(J) || ~isreal(J), J = 1e30; end
        catch ME
            invalidCount = invalidCount+1;
            invalidIds{end+1} = ME.identifier; %#ok<AGROW>
            J = 1e30;
        end
    end
end

function point = evaluate_point(condition,z,P,modelIdentity)
z = z(:);
theta = z(1);
collective = z(2);
stickIn = z(3);
allocation = xv15_helicopter_control_allocation(stickIn,condition.betaM,P);
uCtrl = [collective;0;allocation.cyclicLong;0;0;allocation.elevator;0];
alpha = theta-condition.gamma;
x = zeros(9,1);
x(1) = condition.V*cos(alpha);
x(3) = condition.V*sin(alpha);
x(8) = theta;
[xdot,eomOut] = stage2_tiltrotor_eom(modelIdentity,x,uCtrl,condition.betaM,P);
residual = [xdot(1);xdot(3);xdot(5)];
point = struct();
point.x9 = x;
point.u7 = uCtrl;
point.xdot9 = xdot;
point.residual = residual;
point.eomOut = eomOut;
point.allocation = allocation;
point.finiteReal = isreal(xdot) && all(isfinite(xdot));
end

function r = empty_row()
r = struct('speed_kts',NaN,'speed_mps',NaN,'solveReturned',false, ...
    'solverConverged',false,'physicalConverged',false, ...
    'physicalBranchSupported',false,'credible',false,'residualNorm',NaN, ...
    'status','NOT_RUN','exitflag',NaN,'invalidEvaluationCount',NaN, ...
    'theta_deg',NaN,'collectiveControl_deg',NaN,'theta75_deg',NaN, ...
    'stick_in',NaN,'cyclicLong_deg',NaN,'theta1sRight_deg',NaN, ...
    'elevator_deg',NaN,'leftThrust_N',NaN,'rightThrust_N',NaN, ...
    'meanThrustPerRotor_lb',NaN,'theta_error_vs_GTRS_deg',NaN, ...
    'stick_error_vs_GTRS_in',NaN,'theta1s_error_vs_GTRS_deg',NaN, ...
    'elevator_error_vs_GTRS_deg',NaN,'thrust_error_vs_GTRS_pct',NaN);
end

function r = empty_report()
r = struct('solveReturned',false,'solverConverged',false, ...
    'physicalConverged',false,'physicalBranchSupported',false, ...
    'credible',false,'residualNorm',Inf,'status','NOT_RUN','exitflag',NaN, ...
    'output',struct(),'cost',Inf,'z',nan(3,1),'point',struct(), ...
    'invalidEvaluationCount',0,'invalidEvaluationIdentifiers',{{}}, ...
    'atLimit',false,'withinLimits',false,'finalErrorIdentifier','');
end

function write_markdown_summary(path,contract,points,summary)
fid = fopen(path,'w');
if fid < 0, error('run_xv15_helicopter_trim_validation_v1:WriteFailed','Cannot open summary file.'); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# XV-15 helicopter-mode whole-aircraft trim V1\n\n');
fprintf(fid,'Validation identity: `%s`\n\n',contract.identity);
fprintf(fid,'## Evidence roles\n\n');
fprintf(fid,'- Quantitative table: GTRS validated-reference-simulation correlation; **not raw flight-test truth**.\n');
fprintf(fid,'- Flight test: Figure 14 narrative trend check only; **no numeric flight score**.\n');
fprintf(fid,'- Target-output fitting: **NO**.\n');
fprintf(fid,'- Production physics modified: **NO**.\n\n');
fprintf(fid,'## Numerical result\n\n');
fprintf(fid,'Credible trims: %d / %d.\n\n',summary.CredibleCount(1),summary.DeclaredCaseCount(1));
fprintf(fid,'- pitch attitude MAE vs GTRS: %.6g deg\n',summary.ThetaMAE_deg(1));
fprintf(fid,'- longitudinal-stick MAE vs GTRS: %.6g in\n',summary.StickMAE_in(1));
fprintf(fid,'- per-rotor thrust MAPE vs GTRS: %.6g %%\n',summary.ThrustMAPE_pct(1));
fprintf(fid,'- stick trend slope: %.6g in/kt\n',summary.StickTrendSlope_in_per_kt(1));
fprintf(fid,'- pitch trend slope: %.6g deg/kt\n',summary.ThetaTrendSlope_deg_per_kt(1));
fprintf(fid,'- Figure-14 narrative trend check: %d\n\n',summary.FlightNarrativeTrendCheck(1));
fprintf(fid,'## Claim boundary\n\n');
fprintf(fid,'This is a first source-mapped XV-15 whole-aircraft trim falsification pass. ');
fprintf(fid,'The existing low-order wing slipstream/near-normal interaction is retained and tested, not fitted. ');
fprintf(fid,'A quantitative flight-test PASS/FAIL label remains prohibited until Figure 14 point provenance is visually digitized and frozen.\n\n');
fprintf(fid,'## Point table\n\n');
fprintf(fid,'See `XV15_HELICOPTER_TRIM_V1_POINTS.csv` for all declared points, including failed/noncredible cases.\n');
end

function s = compact_id(s)
s = strrep(s,':','_');
s = strrep(s,' ','_');
end
