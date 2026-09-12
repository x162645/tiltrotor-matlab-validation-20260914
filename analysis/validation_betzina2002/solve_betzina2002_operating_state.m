function [zBest,eBest,repBest] = solve_betzina2002_operating_state(P,mu,alphaDeg,targetCT,seed)
%SOLVE_BETZINA2002_OPERATING_STATE Analysis-only three-control operating-state solver.
% Targets only thrust and near-zero first-harmonic flapping. Torque is never
% included in the residual and therefore remains an external prediction.
if nargin<5 || isempty(seed), seed=[5 -1.5 1]; end
starts=[seed(:).';5 -1.5 1;2 -2 1;-1 -3 1;-4 -4 1;8 -1 1];
zBest=[NaN NaN NaN]; eBest=invalid_eval(); repBest=struct('iterations',0,'residualNorm',Inf); best=Inf;
for s=1:size(starts,1)
    [z,e,rep]=lm_one(P,mu,alphaDeg,targetCT,starts(s,:));
    if e.physicalConverged && rep.residualNorm<best
        best=rep.residualNorm; zBest=z; eBest=e; repBest=rep;
    end
    if e.solutionValid, zBest=z; eBest=e; repBest=rep; return; end
end
end

function [z,e,rep]=lm_one(P,mu,a,targetCT,z0)
z=z0(:); lambda=1e-3; best=Inf; bestZ=z; bestE=invalid_eval(); maxIter=35;
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
        dz=-(J.'*J+lambda*eye(3))\(J.'*r); dz=max(min(dz,3),-3);
        step=1;
        for ls=1:8
            zc=z+step*dz;
            if zc(1)<-10 || zc(1)>25 || any(zc(2:3)<-15) || any(zc(2:3)>15), step=step/2; continue; end
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
try, e=betzina2002_two_cyclic_rotor(P,mu,a,z(1),z(2),z(3)); e.solutionValid=false;
catch ME, e=invalid_eval(); e.physicalStatus=['ERROR_' ME.identifier]; end
end
function e=invalid_eval()
e=struct('CT',NaN,'CQ',NaN,'beta0Deg',NaN,'beta1cDeg',NaN,'beta1sDeg',NaN,'firstHarmonicFlapDeg',NaN,'physicalConverged',false,'solutionValid',false,'physicalStatus','NO_VALID_SOLUTION');
end
