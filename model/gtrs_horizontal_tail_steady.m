function [Fbody,Mbody,out]=gtrs_horizontal_tail_steady(x,elevator,cgShift,P,flow)
%GTRS_HORIZONTAL_TAIL_STEADY Coherent GTRS low-Mach steady-tail subset.
% A70/A74: rotor field on wing free-stream alpha, wing->tail downwash.
% A85-A88: local velocities, separate load/drag angles, pressure and forces.
% B49/B56-B58/B62-B65: source coefficient families. No target fitting.
% The steady restriction is intentional. Wdot damping and transport lag are
% not set to zero for a claimed dynamic model: this API rejects nonzero rates.
% Existing linear downwash/effective incidence/tanh coefficients are NOT read.
% GTRS source-based correlation is not independent flight validation.
x=x(:);cgShift=cgShift(:);
if numel(x)~=9||numel(cgShift)~=3||~isreal([x;cgShift;elevator])|| ...
        any(~isfinite([x;cgShift;elevator]))||~isscalar(elevator)
    error('gtrs_horizontal_tail_steady:InvalidInput','Finite real state/CG/elevator required.');
end
if abs(x(2))>1e-8||norm(x(4:6))>1e-8||x(1)<=0
    error('gtrs_horizontal_tail_steady:SteadyForwardOnly','Only forward symmetric zero-rate states supported.');
end
T=gtrs_heli_tail_tables();V=norm(x(1:3));aF=atan2(x(3),x(1))*180/pi;
Mach=V/P.env.aSound;vkt=V/(1852/3600);de=elevator*180/pi;
if Mach>=.2||vkt>140||aF< -30||aF>20||abs(de)>20
    error('gtrs_horizontal_tail_steady:OutsideSourceDomain','Outside declared low-Mach source domain.');
end
if ~isfield(P,'validation')||P.validation.flapDeg~=40|| ...
        ~isfield(flow,'rotorForceCoefficientSum')||~isfield(flow,'rotorMuMean')
    error('gtrs_horizontal_tail_steady:MissingSourceInputs','Flap40/25 and explicit rotor field inputs required.');
end
rAC=P.htail.rAC-cgShift;
vel=x(1:3)+flow.additionalRelativeVelocityBody_mps(:);
if vel(1)<=0,error('gtrs_horizontal_tail_steady:ReverseLocalFlow','Reverse local flow is not implemented.');end
% A38: C_RF=norm(rotor force)/(rho*pi*Omega^2*R^4), NOT the repository CT
% using 0.5*rho*A*(Omega*R)^2. A70 and B33 supply the next relation.
aWing=aF-T.KXRW*T.XRW0*flow.rotorForceCoefficientSum/ ...
    max(.15,flow.rotorMuMean)^2*57.3;
epsilon=interp1(T.wingAlpha_deg,T.wingDownwash_deg,aWing,'linear')/sqrt(1-Mach^2);
alphaFlow=atan2(vel(3),vel(1))*180/pi;
alphaLift=alphaFlow-epsilon+T.geometricIncidence_deg;
% A86 and Table5-IV: XKe=1 for M<.2; reduction above15deg applies to drag angle.
Ke=1-T.DKe*max(abs(de)-15,0)/15;
alphaDrag=alphaLift+Ke*T.tauElevator*de;
if alphaLift<T.liftAlpha_deg(1)||alphaLift>T.liftAlpha_deg(end)|| ...
        alphaDrag<T.dragAlpha_deg(1)||alphaDrag>T.dragAlpha_deg(end)||~isfinite(epsilon)
    error('gtrs_horizontal_tail_steady:OutsideCoefficientSubset','No coefficient extrapolation or clipping.');
end
CL=interp2(T.elevator_deg,T.liftAlpha_deg,T.CL,de,alphaLift,'linear');
CD=interp1(T.dragAlpha_deg,T.CD,alphaDrag,'linear');
eta=interp2(T.etaSpeed_kt,T.etaAlpha_deg,T.eta,min(vkt,100),aF,'linear');
% A87: at q=0 and beta=0, qH=0.5*rho*KHNU*eta*(U^2+W^2).
% It is NOT qH=0.5*rho*norm(Vbody+Vrotor)^2. eta is not capped at1.
qbar=.5*P.env.rho*T.KHNU*eta*(x(1)^2+x(3)^2);
L=qbar*P.htail.S*CL;D=qbar*P.htail.S*CD;
% A88: force resolution also subtracts wing downwash; incidence excluded.
alphaResolve=(alphaFlow-epsilon)*pi/180;
Fbody=aero_force_body(D,0,L,alphaResolve,0);
Maero=zeros(3,1);Marm=cross(rAC,Fbody);Mbody=Maero+Marm;
out=struct('rAC',rAC,'Vlocal',vel,'V',norm(vel),'alphaLocal',alphaFlow*pi/180, ...
 'alphaCG',aF*pi/180,'alphaEff',alphaLift*pi/180,'alphaDrag',alphaDrag*pi/180, ...
 'alphaResolve',alphaResolve,'wingFreeAlpha_deg',aWing,'wingDownwash_deg',epsilon, ...
 'beta',0,'qbar',qbar,'qbarFree',.5*P.env.rho*V^2,'eta',eta,'KHNU',T.KHNU, ...
 'CL',CL,'CD',CD,'Cm',0,'Maero',Maero,'Marm',Marm,'F',Fbody,'M',Mbody, ...
 'explicitLocalFlow',flow,'identity','GTRS_COHERENT_STEADY_HELI_TAIL_V3', ...
 'legacyDownwashAndIncidenceApplied',false,'noTargetFit',true);
end
