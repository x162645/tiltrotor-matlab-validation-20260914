function result=run_line_b_tail_trim_case(speedKt,outputRoot,useArchivedInitials)
% One prescribed case with source-based tail coupling; same V1 solver settings.
% V2 changes ONLY the optional tail local-relative-velocity route.
% Optional archival initialization uses previous MODEL results, NOT GTRS targets.
% Source: original run34175347392 artifact10037420339, MAT SHA256
% 7169f2d470de72674af683c4c83e82f1fc516a456129efe1bff80257d4c3312f.
% Per-side flap guesses use the already-existing stage2Numerics interface.
% Tolerances, iteration limits, residual equations and physical parameters are unchanged.
if nargin<3,useArchivedInitials=false;end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
speed=[40 60 80 100];theta=[.99845 -.65282 -2.7162 -4.6968];
collective=[34.776 33.864 33.776 34.655];stick=[5.6133 6.0749 6.3549 6.4279];
k=find(speed==speedKt);assert(isscalar(k),'Only existing four-point set supported.');
[P,contract]=xv15_helicopter_trim_parameters_v1(); d2r=pi/180;
P.interference.rotorToTailModel='FERGUSON_1988_TABLE_2IA_STEADY_HELI';
contract.identity='XV15_SOURCE_MAPPED_STEADY_HELI_TAIL_COUPLING_V2';
contract.interactionSource='NASA_CR166536_B22_B25_A39_A40';
contract.targetFitting=false;contract.productionPhysicsModified=true;
contract.claimBoundary='SOURCE_CONSTRAINED_STEADY_HELI_EXTENSION_GTRS_CORRELATION_NOT_FLIGHT_VALIDATION';
seed=[theta(k)*d2r;collective(k)*d2r;stick(k)];scale=[2*d2r;10*d2r;1];
seedSource='Run34175347392_model_results_rounded_not_GTRS';
if useArchivedInitials
    S=readtable(fullfile(fileparts(mfilename('fullpath')),'original_baseline_trim_seeds.csv'));
    S=S(S.speed_kt==speedKt,:);assert(height(S)==1);
    seed=[S.theta_rad;S.collective_rad;S.stick_in];
    P.stage2Numerics.flapInitialLeft=[S.flapL0;S.flapL1c;S.flapL1s];
    P.stage2Numerics.flapInitialRight=[S.flapR0;S.flapR1c;S.flapR1s];
    seedSource='Run34175347392_exact_outer_state_and_per_side_flap_initial_guesses';
end
bounds=[-35*d2r,35*d2r;P.control.collectiveLim(:).';0,9.6];
options=optimset('Display','off','MaxIter',P.trim.maxIterations, ...
    'MaxFunEvals',12*P.trim.maxIterations,'TolX',1e-8,'TolFun',1e-10);
invalidCount=0;invalidIds={};t0=tic;
[y,cost,exitflag,optimout]=fminsearch(@objective,zeros(3,1),options);
z=seed+scale.*y;elapsed=toc(t0);
result=struct('identity',contract.identity,'speed_kt',speedKt,'cost',cost, ...
    'exitflag',exitflag,'optimizer',optimout,'invalidCount',invalidCount, ...
    'invalidIdentifiers',{unique(invalidIds)},'seed',seed,'z',z,'contract',contract, ...
    'elapsed_s',elapsed,'version',version,'release',version('-release'), ...
    'sourceSeed',seedSource,'archivalInitialization',useArchivedInitials, ...
    'externalAccuracyPassed',false,'referenceRole','GTRS_REFERENCE_SIMULATION_NOT_FLIGHT');
try
    point=evaluate(z); result.point=point;
    rs=point.residual;rs(1:2)=rs(1:2)/P.env.g;rn=norm(rs);
    margin=min(z-bounds(:,1),bounds(:,2)-z)./(bounds(:,2)-bounds(:,1));
    accepted=exitflag>0 && rn<P.trim.residualTolerance && ...
        point.allocation.withinLimits && all(margin>1e-7) && ...
        point.eomOut.physicalConverged && point.eomOut.physicalBranchSupported && ...
        isreal(point.xdot)&&all(isfinite(point.xdot));
    repeated=evaluate(z); result.repeatEvaluationDifference=norm(repeated.xdot-point.xdot);
    result.replayMeaning='Same converged outer state, reset deterministic inner guesses; not independent trim search.';
    ref=readtable(fullfile(fileparts(mfilename('fullpath')), ...
        'reference_gtrs_helicopter_trim_kleinhesselink2007.csv'));ref=ref(ref.speed_kts==speedKt,:);
    T=.5*(point.eomOut.rotorLeft.thrust+point.eomOut.rotorRight.thrust)/4.4482216152605;
    row=table(speedKt,accepted,rn,z(1)/d2r,z(3),point.allocation.elevator/d2r,T, ...
        z(1)/d2r-ref.theta_gtrs_deg,z(3)-ref.stick_gtrs_in, ...
        point.allocation.elevator/d2r-ref.elevator_gtrs_deg, ...
        100*(T-ref.thrust_per_rotor_gtrs_lb)/ref.thrust_per_rotor_gtrs_lb, ...
        point.eomOut.components.horizontalTail.explicitLocalFlow.wakeRatio, ...
        'VariableNames',{'speed_kt','numericallyAccepted','residualNorm','theta_deg','stick_in', ...
        'elevator_deg','thrustPerRotor_lbf','thetaDifference_deg','stickDifference_in', ...
        'elevatorDifference_deg','thrustDifference_pct','tailWakeRatio'});
    result.summary=row;result.numericallyAccepted=accepted;disp(row);
    writetable(row,fullfile(outputRoot,'TAIL_COUPLED_TRIM_POINT.csv'));
catch ME
    result.numericallyAccepted=false;result.finalErrorIdentifier=ME.identifier;
    result.finalErrorMessage=ME.message;fprintf('FINAL_EVALUATION_FAILED %s: %s\n',ME.identifier,ME.message);
end
[~,head]=system('git rev-parse HEAD');result.commit=strtrim(head);
save(fullfile(outputRoot,'TAIL_COUPLED_TRIM_RESULTS.mat'),'result','P');
meta=result;for name={'point','summary'},if isfield(meta,name{1}),meta=rmfield(meta,name{1});end,end
fid=fopen(fullfile(outputRoot,'TAIL_COUPLED_TRIM_MANIFEST.json'),'w');assert(fid>=0);
c=onCleanup(@() fclose(fid));fwrite(fid,jsonencode(meta),'char');clear c;

    function point=evaluate(zz)
        alloc=xv15_helicopter_control_allocation(zz(3),0,P);
        u=[zz(2);0;alloc.cyclicLong;0;0;alloc.elevator;0];x=zeros(9,1);
        V=speedKt*.514444; x(1)=V*cos(zz(1));x(3)=V*sin(zz(1));x(8)=zz(1);
        [xdot,eom]=stage2_tiltrotor_eom('M1_EVIDENCE_V1_PROPAGATION',x,u,0,P);
        point=struct('x',x,'u',u,'xdot',xdot,'residual',xdot([1 3 5]), ...
            'eomOut',eom,'allocation',alloc);
    end
    function J=objective(yv)
        zz=seed+scale.*yv;
        if any(zz<bounds(:,1))||any(zz>bounds(:,2))
            violation=max(bounds(:,1)-zz,0)./(bounds(:,2)-bounds(:,1))+ ...
                max(zz-bounds(:,2),0)./(bounds(:,2)-bounds(:,1));
            J=1e4+1e4*sum(violation.^2);return;
        end
        try
            p=evaluate(zz);r=p.residual;r(1:2)=r(1:2)/P.env.g;J=r.'*r;
            if ~p.allocation.withinLimits,J=J+1e3;end
            if ~p.eomOut.physicalConverged||~p.eomOut.physicalBranchSupported
                invalidCount=invalidCount+1;invalidIds{end+1}=p.eomOut.physicalStatus;J=J+1e3;
            end
            if ~isfinite(J)||~isreal(J),J=1e30;end
        catch ME
            invalidCount=invalidCount+1;invalidIds{end+1}=ME.identifier;J=1e30;
        end
    end
end
