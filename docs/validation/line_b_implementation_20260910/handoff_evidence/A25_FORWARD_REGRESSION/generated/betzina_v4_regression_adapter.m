function out = betzina_v4_regression_adapter(P,muTotal,alphaDeg,theta75Deg,cyclicLongDeg,cyclicLatDeg)
%BETZINA2002_TWO_CYCLIC_ROTOR Validation-only two-cyclic XV-15 rotor adapter.
%
% Reproduces the forward branch equations of
% m1_evidence_v1_forward_rotor for the right-hand isolated rotor, while
% exposing the missing cosine-harmonic cyclic-pitch degree of freedom needed
% to reproduce the Betzina (2002) wind-tunnel operating contract.
%
% IMPORTANT:
% - This is an analysis/validation adapter, not a production-model change.
% - cyclicLatDeg = 0 must reproduce the existing Stage-2 forward rotor.
% - Betzina controls are used only to reproduce target CT and near-zero
%   first-harmonic flapping; torque remains an external prediction.
% - The RTA used delta3=-36 deg. The current low-order rotor has no active
%   delta3 pitch-flap coupling state; this remains a declared model-form
%   mismatch and is NOT hidden by this adapter.
% - sectionMap is diagnostic-only. Exposing it must not alter any force,
%   moment, induced-flow, or flapping equation.

side = 1; rotDir = side;
R = P.rotor.R; Omega = P.rotor.Omega;
tipSpeed = Omega*R; rho = P.env.rho; A = pi*R^2;
betaM = -alphaDeg*pi/180;
Vbody = [muTotal*tipSpeed;0;0];
omegaBody = zeros(3,1); phiBody = 0; thetaBody = 0;
cgShift = zeros(3,1);

eT = [sin(betaM);0;-cos(betaM)];
eD = [cos(betaM);0; sin(betaM)];
eY = [0;1;0];
rHub0 = [P.rotor.pivotX+P.rotor.RH_hub*sin(betaM); ...
         side*P.rotor.pivotY; ...
         P.rotor.pivotZ-P.rotor.RH_hub*cos(betaM)];
rHub = rHub0-cgShift;
Vhub = Vbody+cross(omegaBody,rHub);
Vaxial = dot(Vhub,eT); Vlong = dot(Vhub,eD); Vlat = dot(Vhub,eY);
mu = hypot(Vlong,Vlat)/max(tipSpeed,eps);

theta75 = theta75Deg*pi/180;
theta1s = -rotDir*cyclicLongDeg*pi/180;
theta1c = cyclicLatDeg*pi/180;

vi = sqrt(max(P.mass.m*P.env.g/2,1)/(2*rho*A));
zFlap = P.rotor.flapInitial(:);
if numel(zFlap) ~= 3
    error('betzina_v4_regression_adapter:InvalidFlapInitial','Expected 3 flap harmonics.');
end
coupledConverged=false; viError=Inf;
flapInfo=struct('converged',false,'residualNorm',Inf,'iterations',0);
for iter=1:P.rotor.inducedMaxIter
    [zFlap,flapInfo]=solve_flap(vi,zFlap);
    if ~flapInfo.converged, break; end
    loads=blade_loads(vi,zFlap);
    lambda0=-Vaxial/max(tipSpeed,eps);
    lambda1=lambda0-vi/max(tipSpeed,eps);
    CTiter=max(loads.T,0)/(0.5*rho*A*tipSpeed^2);
    denom=sqrt(lambda1^2+mu^2);
    viTarget=tipSpeed*CTiter/(4*max(denom,1e-12));
    viNew=0.5*(vi+viTarget);
    viError=abs(viNew-vi)/max(1,abs(vi));
    vi=viNew;
    if viError<P.rotor.inducedTol && flapInfo.residualNorm<=P.rotor.flapResidualTol
        coupledConverged=true; break;
    end
end

if flapInfo.converged
    loads=blade_loads(vi,zFlap);
else
    loads=struct('T',NaN,'Q',NaN,'Hlong',NaN,'Hlat',NaN, ...
        'alphaClampCount',NaN,'machClampCount',NaN,'applyCount',NaN, ...
        'KLMinApplied',NaN,'KLMaxApplied',NaN,'minUT',NaN,'maxUT',NaN, ...
        'maxAbsAlphaBlade',NaN,'dT',NaN,'dH',NaN,'dQ',NaN,'rMid',NaN, ...
        'xSpan',NaN,'psi',NaN,'alpha',NaN,'Mach',NaN,'CL',NaN,'CD',NaN, ...
        'UT',NaN,'UP',NaN,'inflowAngle',NaN);
end
lambda0=-Vaxial/max(tipSpeed,eps);
lambda1=lambda0-vi/max(tipSpeed,eps);
denom=sqrt(lambda1^2+mu^2);
momentumThrust=2*rho*A*tipSpeed*vi*denom;
closureResidual=loads.T-momentumThrust;
closureScale=max([abs(loads.T),abs(momentumThrust),1]);
closureRelative=abs(closureResidual)/closureScale;
closureTolerance=2e-4;
physicalBranchSupported=isfinite(loads.T) && loads.T>0;
physicalConverged=coupledConverged && flapInfo.converged && ...
    closureRelative<=closureTolerance && physicalBranchSupported;
if ~flapInfo.converged
    physicalStatus='FLAP_NOT_CONVERGED';
elseif ~coupledConverged
    physicalStatus='COUPLED_NOT_CONVERGED';
elseif ~physicalBranchSupported
    physicalStatus='UNSUPPORTED_NONPOSITIVE_THRUST_BRANCH';
elseif closureRelative>closureTolerance
    physicalStatus='INDUCED_CLOSURE_RESIDUAL_NOT_SATISFIED';
else
    physicalStatus='PHYSICAL_CONVERGED';
end

CT=loads.T/(rho*A*tipSpeed^2);
CQ=loads.Q/(rho*A*tipSpeed^2*R);
out=struct();
out.modelId='V4_TWO_CYCLIC_REGRESSION_ADAPTER';
out.claimBoundary='VALIDATION_ONLY_TWO_CYCLIC_EXTENSION_NO_PHYSICS_FIT_NOT_PRODUCTION';
out.muTotal=muTotal; out.alphaDeg=alphaDeg; out.betaM=betaM;
out.theta75Deg=theta75Deg; out.cyclicLongDeg=cyclicLongDeg; out.cyclicLatDeg=cyclicLatDeg;
out.theta1s=theta1s; out.theta1c=theta1c;
out.beta0=zFlap(1); out.beta1c=zFlap(2); out.beta1s=zFlap(3);
out.beta0Deg=zFlap(1)*180/pi; out.beta1cDeg=zFlap(2)*180/pi; out.beta1sDeg=zFlap(3)*180/pi;
out.firstHarmonicFlapDeg=hypot(out.beta1cDeg,out.beta1sDeg);
out.thrust=loads.T; out.torque=loads.Q; out.Hlong=loads.Hlong; out.Hlat=loads.Hlat;
out.CT=CT; out.CQ=CQ; out.inducedVelocity=vi; out.inducedVelocityError=viError;
out.inducedClosureResidualRelative=closureRelative; out.flapConverged=flapInfo.converged;
out.coupledConverged=coupledConverged; out.physicalBranchSupported=physicalBranchSupported;
out.physicalConverged=physicalConverged; out.physicalStatus=physicalStatus; out.iterations=iter;
out.alphaClampCount=loads.alphaClampCount; out.machClampCount=loads.machClampCount;
out.stallDelayApplyCount=loads.applyCount; out.KLMinApplied=loads.KLMinApplied; out.KLMaxApplied=loads.KLMaxApplied;
out.minUT=loads.minUT; out.maxUT=loads.maxUT; out.maxAbsAlphaBlade=loads.maxAbsAlphaBlade;
out.sectionMap=struct('rOverR',loads.xSpan,'rMid_m',loads.rMid, ...
    'psiDeg',loads.psi*180/pi,'dT_N',loads.dT,'dH_N',loads.dH, ...
    'dQ_Nm',loads.dQ,'alphaDeg',loads.alpha*180/pi,'Mach',loads.Mach, ...
    'CL',loads.CL,'CD',loads.CD,'UT_mps',loads.UT,'UP_mps',loads.UP, ...
    'inflowAngleDeg',loads.inflowAngle*180/pi);

    function [z,info]=solve_flap(viNow,z0)
        z=z0(:); info=struct('converged',false,'iterations',0,'residualNorm',Inf);
        for kk=1:P.rotor.flapMaxIter
            [res,scale]=flap_residual(z,viNow); rn=res/scale;
            if norm(rn)<=P.rotor.flapResidualTol
                info.converged=true; info.iterations=kk; info.residualNorm=norm(rn); return;
            end
            J=zeros(3,3);
            for jj=1:3
                h=P.rotor.flapJacobianStep*max(1,abs(z(jj)));
                zp=z; zm=z; zp(jj)=zp(jj)+h; zm(jj)=zm(jj)-h;
                [rp,~]=flap_residual(zp,viNow); [rm,~]=flap_residual(zm,viNow);
                J(:,jj)=(rp-rm)/(2*h*scale);
            end
            if any(~isfinite(J(:))) || rcond(J.'*J)<1e-14, return; end
            dz=-(J.'*J+P.rotor.flapNewtonRegularization*eye(3))\(J.'*rn);
            step=1; accepted=false;
            for trial=1:P.rotor.flapLineSearchMaxIter
                zc=z+step*dz;
                bc=zc(1)+zc(2)*cos(azimuth_grid())+zc(3)*sin(azimuth_grid());
                if all(isfinite(zc)) && max(abs(bc))<P.rotor.flapDivergenceAngle
                    [rc,sc]=flap_residual(zc,viNow);
                    if norm(rc/sc)<norm(rn), z=zc; accepted=true; break; end
                end
                step=step*P.rotor.flapNewtonDamping;
            end
            if ~accepted, return; end
        end
        [res,scale]=flap_residual(z,viNow); info.iterations=P.rotor.flapMaxIter; info.residualNorm=norm(res/scale);
    end

    function [res,scale]=flap_residual(z,viNow)
        ll=blade_loads(viNow,z);
        gBody=P.env.g*[-sin(thetaBody);sin(phiBody)*cos(thetaBody);cos(phiBody)*cos(thetaBody)];
        gT=dot(gBody,eT); gD=dot(gBody,eD); gY=dot(gBody,eY);
        gRadial=gD*cos(ll.psi)+gY*sin(ll.psi);
        gravityMoment=P.rotor.Sblade*(-sin(ll.beta).*gRadial+cos(ll.beta).*gT);
        inertial=P.rotor.Ib*ll.betaDDot+P.rotor.Ib*Omega^2*ll.beta;
        byAz=inertial-ll.flapMomentByAzimuth-gravityMoment;
        res=[mean(byAz);2*mean(byAz.*cos(ll.psi));2*mean(byAz.*sin(ll.psi))];
        scale=max([max(abs(ll.flapMomentByAzimuth)),max(abs(gravityMoment)),P.rotor.Ib*Omega^2*0.05,1]);
    end

    function ll=blade_loads(viNow,z)
        r0=P.rotor.rootCut*R; edges=linspace(r0,R,P.rotor.nRadial+1);
        rMid=0.5*(edges(1:end-1)+edges(2:end)); dr=diff(edges); psi=azimuth_grid().';
        xSpan=rMid/R; chordIn=14*ones(size(xSpan)); ib=xSpan<=0.25;
        chordIn(ib)=-18.4615*xSpan(ib)+18.6154; chord=chordIn*0.0254;
        sourceTwistDeg=nasa_metal_twist_deg(xSpan); sourceTwist75Deg=nasa_metal_twist_deg(0.75);
        thetaGeom=theta75+(sourceTwistDeg-sourceTwist75Deg)*pi/180;
        beta=z(1)+z(2)*cos(psi)+z(3)*sin(psi);
        betaDot=rotDir*Omega*(-z(2)*sin(psi)+z(3)*cos(psi));
        betaDDot=-Omega^2*(z(2)*cos(psi)+z(3)*sin(psi));
        etD=-rotDir*sin(psi); etY=rotDir*cos(psi);
        VtanTrans=Vlong*etD+Vlat*etY; Vrad=Vlong*cos(psi)+Vlat*sin(psi);
        thetaBlade=thetaGeom+theta1c*cos(psi)+theta1s*sin(psi);
        UT=Omega*rMid+VtanTrans; viField=viNow.*(1+cos(psi).*(rMid/R));
        UP=Vaxial+viField-beta.*Vrad-betaDot.*rMid;
        W=hypot(UT,UP); inflowAngle=atan2(UP,max(abs(UT),1e-8));
        alpha=thetaBlade-inflowAngle; Mach=W/P.env.aSound;
        chordField=ones(size(alpha)).*chord; rField=ones(size(alpha)).*xSpan;
        [CL,CD,meta]=xv15_c81_corrigan_continuous_v4(alpha,Mach,rField,chordField,R,'CORRIGAN_GENERIC_N1');
        q=0.5*rho*W.^2; dL=q.*chord.*CL.*dr; dD=q.*chord.*CD.*dr;
        dT=dL.*cos(inflowAngle)-dD.*sin(inflowAngle);
        dH=dD.*cos(inflowAngle)+dL.*sin(inflowAngle); dQ=dH.*rMid;
        factor=P.rotor.Nb/P.rotor.nAzimuth; ll.T=factor*sum(dT(:)); ll.Q=factor*sum(dQ(:));
        Hvec=-[sum(sum(dH.*etD));sum(sum(dH.*etY))]; ll.Hlong=factor*Hvec(1); ll.Hlat=factor*Hvec(2);
        ll.flapMomentByAzimuth=sum(dT.*rMid,2); ll.beta=beta; ll.betaDDot=betaDDot; ll.psi=psi;
        ll.alphaClampCount=meta.alphaClampCount; ll.machClampCount=meta.machClampCount;
        ll.applyCount=meta.applyCount; ll.KLMinApplied=meta.KLMinApplied; ll.KLMaxApplied=meta.KLMaxApplied;
        ll.minUT=min(UT(:)); ll.maxUT=max(UT(:)); ll.maxAbsAlphaBlade=max(abs(alpha(:)));
        ll.dT=dT; ll.dH=dH; ll.dQ=dQ; ll.rMid=rMid; ll.xSpan=xSpan;
        ll.alpha=alpha; ll.Mach=Mach; ll.CL=CL; ll.CD=CD; ll.UT=UT; ll.UP=UP; ll.inflowAngle=inflowAngle;
    end

    function psi=azimuth_grid()
        psi=(0:P.rotor.nAzimuth-1)*(2*pi/P.rotor.nAzimuth);
    end
end
