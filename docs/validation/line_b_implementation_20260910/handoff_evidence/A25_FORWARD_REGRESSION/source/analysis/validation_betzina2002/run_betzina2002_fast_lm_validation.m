function results = run_betzina2002_fast_lm_validation(outputDir)
%RUN_BETZINA2002_FAST_LM_VALIDATION
% Fast independent trim-solver audit for the Betzina two-cyclic adapter.
% Solves only the experimental operating-state constraints:
% CT/sigma=0.075, beta1c=0, beta1s=0. Torque is never in the residual.

rootDir=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1 || isempty(outputDir), outputDir=fullfile(rootDir,'results','betzina2002_fast_lm_validation'); end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
addpath(fullfile(rootDir,'analysis','stage2_aircraft'));
addpath(fullfile(rootDir,'analysis','validation_betzina2002'));
P=stage2_matched_rotor_parameters();
P.rotor.Omega=0.691*P.env.aSound/P.rotor.R;
sigma=0.089; targetCT=0.075*sigma;
muList=[0.125 0.15 0.17 0.20]; alphaList=[-15 0 15];
rows=table();
for ia=1:numel(alphaList)
    a=alphaList(ia);
    if a==-15, seed=[7.5 -1.7 1.3]; elseif a==0, seed=[5 -1.5 1.1]; else, seed=[3 -1.1 1.45]; end
    for im=1:numel(muList)
        mu=muList(im);
        [z,e,rep]=solve_case(P,mu,a,targetCT,seed);
        if e.solutionValid, seed=z; end
        one=table(a,mu,z(1),z(2),z(3),e.CT,e.CT/sigma,e.CQ,e.CQ/sigma, ...
            e.beta0Deg,e.beta1cDeg,e.beta1sDeg,e.firstHarmonicFlapDeg,e.physicalConverged, ...
            e.solutionValid,rep.iterations,rep.residualNorm,{e.physicalStatus}, ...
            'VariableNames',{'alpha_exp_deg','advance_ratio','theta75_deg','cyclicLong_deg', ...
            'cyclicLat_deg','CT_model','CT_over_sigma_model','CQ_model','CQ_over_sigma_model', ...
            'beta0_deg','beta1c_deg','beta1s_deg','first_harmonic_flap_deg','physicalConverged', ...
            'solutionValid','solveIterations','solveResidualNorm','physicalStatus'});
        rows=[rows;one]; %#ok<AGROW>
    end
end
writetable(rows,fullfile(outputDir,'BETZINA2002_FAST_LM_PREDICTIONS.csv'));
results=struct(); results.rows=rows; results.allPhysical=all(rows.physicalConverged); results.allSolved=all(rows.solutionValid);
results.maxCTRelativeError=max(abs(rows.CT_model-targetCT)/targetCT);
results.maxAbsBeta1cDeg=max(abs(rows.beta1c_deg)); results.maxAbsBeta1sDeg=max(abs(rows.beta1s_deg));
results.claimBoundary='INDEPENDENT_TRIM_SOLVER_AUDIT_TORQUE_NOT_FITTED';
save(fullfile(outputDir,'BETZINA2002_FAST_LM_RESULTS.mat'),'results');
end

function [zBest,eBest,repBest]=solve_case(P,mu,a,targetCT,seed)
starts=[seed(:).';5 -1.5 1;2 -2 1;-1 -3 1;-4 -4 1];
zBest=[NaN NaN NaN]; eBest=invalid_eval(); repBest=struct('iterations',0,'residualNorm',Inf);
best=Inf;
for s=1:size(starts,1)
    [z,e,rep]=lm_one(P,mu,a,targetCT,starts(s,:));
    if e.physicalConverged && rep.residualNorm<best
        best=rep.residualNorm; zBest=z; eBest=e; repBest=rep;
    end
    if e.solutionValid, zBest=z; eBest=e; repBest=rep; return; end
end
end

function [z,e,rep]=lm_one(P,mu,a,targetCT,z0)
z=z0(:); lambda=1e-3; best=Inf; bestZ=z; bestE=invalid_eval(); maxIter=30;
for iter=1:maxIter
    e=eval_state(P,mu,a,z); if ~e.physicalConverged, break; end
    r=resid(e,targetCT); rn=norm(r);
    if rn<best, best=rn; bestZ=z; bestE=e; end
    if valid_solution(e,targetCT), e.solutionValid=true; rep=struct('iterations',iter,'residualNorm',rn); return; end
    J=zeros(3,3); ok=true;
    for j=1:3
        h=0.02; got=false;
        for shrink=1:4
            zp=z; zm=z; zp(j)=zp(j)+h; zm(j)=zm(j)-h;
            ep=eval_state(P,mu,a,zp); em=eval_state(P,mu,a,zm);
            if ep.physicalConverged && em.physicalConverged
                J(:,j)=(resid(ep,targetCT)-resid(em,targetCT))/(2*h); got=true; break;
            end
            h=h/4;
        end
        if ~got, ok=false; break; end
    end
    if ~ok || any(~isfinite(J(:))), break; end
    accepted=false;
    for damp=1:8
        A=J.'*J+lambda*eye(3); g=J.'*r;
        dz=-A\g; dz=max(min(dz,3),-3);
        step=1;
        for ls=1:8
            zc=z+step*dz;
            if zc(1)<-10 || zc(1)>25 || any(zc(2:3)<-15) || any(zc(2:3)>15)
                step=step/2; continue;
            end
            ec=eval_state(P,mu,a,zc);
            if ec.physicalConverged && norm(resid(ec,targetCT))<rn
                z=zc; lambda=max(lambda/3,1e-8); accepted=true; break;
            end
            step=step/2;
        end
        if accepted, break; end
        lambda=lambda*10;
    end
    if ~accepted, break; end
end
z=bestZ; e=bestE; e.solutionValid=valid_solution(e,targetCT); rep=struct('iterations',iter,'residualNorm',best);
end

function tf=valid_solution(e,targetCT)
tf=e.physicalConverged && abs((e.CT-targetCT)/targetCT)<=0.005 && abs(e.beta1cDeg)<=0.1 && abs(e.beta1sDeg)<=0.1;
end
function r=resid(e,targetCT), r=[(e.CT-targetCT)/targetCT;e.beta1cDeg/0.1;e.beta1sDeg/0.1]; end
function e=eval_state(P,mu,a,z)
try
    e=betzina2002_two_cyclic_rotor(P,mu,a,z(1),z(2),z(3)); e.solutionValid=false;
catch ME
    e=invalid_eval(); e.physicalStatus=['ERROR_' ME.identifier];
end
end
function e=invalid_eval()
e=struct('CT',NaN,'CQ',NaN,'beta0Deg',NaN,'beta1cDeg',NaN,'beta1sDeg',NaN,'firstHarmonicFlapDeg',NaN, ...
    'physicalConverged',false,'solutionValid',false,'physicalStatus','NO_VALID_SOLUTION');
end
