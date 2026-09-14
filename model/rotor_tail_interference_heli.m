function flow = rotor_tail_interference_heli(x,betaM,rotorLeft,rotorRight,P)
%ROTOR_TAIL_INTERFERENCE_HELI Source-table, steady, symmetric helicopter coupling.
% Ferguson NASA CR166536 Sep1988 RevA B22/B25/A39/A40.
% Signed values retained without target fitting. V3 additionally supplies
% force coefficients for wing free-stream deflection (A38/A70, B33).
% The source table is a steady helicopter table, but its induced-velocity
% direction is defined by betaM.  This interface therefore permits the
% four-angle screening set (0/30/60/90 deg) while retaining the declared
% low-Mach, zero-rate and longitudinal limitations.  It is not a transition
% wake model or an independent full-aircraft validation.
x=x(:);
if numel(x)~=9 || ~isreal(x) || any(~isfinite(x))
    error('rotor_tail_interference_heli:InvalidState','Expected finite real 9-state.');
end
if ~(isscalar(betaM) && isfinite(betaM) && isreal(betaM) && betaM>=-1e-12 && betaM<=pi/2+1e-12)
    error('rotor_tail_interference_heli:UnsupportedMode','betaM must be in [0,pi/2].');
end
if abs(x(2))>1e-8 || norm(x(4:6))>1e-8
    error('rotor_tail_interference_heli:SteadySymmetricOnly','Only steady symmetric zero-rate use implemented.');
end
v=norm(x(1:3));vkt=v/(1852/3600);alpha=atan2(x(3),x(1))*180/pi;
if ~isfield(P.env,'aSound') || P.env.aSound<=0 || ~isfinite(P.env.aSound)
    error('rotor_tail_interference_heli:MissingSoundSpeed','Finite positive aSound required.');
end
if v/P.env.aSound>=0.2 || vkt>140 || alpha< -30 || alpha>20
    error('rotor_tail_interference_heli:OutsideDeclaredDomain','M<.2,V<=140kt,-30<=alpha<=20deg required.');
end
vi=[rotorLeft.inducedVelocity,rotorRight.inducedVelocity];
if ~isreal(vi) || any(~isfinite(vi)) || any(vi<0)
    error('rotor_tail_interference_heli:InvalidRotorInflow','Finite nonnegative induced velocities required.');
end
agrid=[-30 -28 -24 -20 -16 -12 -8 -4 0 4 8 12 16 20];
vgrid=[0 20 40 60 80 100 120 140];
G=[0 0 0 0 0 0 0 0;0 -.02 -.06 -.10 -.15 -.12 -.02 0; ...
0 -.05 -.15 -.30 -.60 -.37 -.05 0;0 -.06 -.25 -.50 -.92 -.65 -.06 0; ...
0 -.07 -.40 -.70 -1.10 -.85 -.07 0;0 -.07 -.46 -.85 -1.13 -.90 -.08 0; ...
0 -.14 -.46 -.73 -1.05 -.80 -.10 0;0 -.0945 -.33 -.623 -.90 -.67 -.09 0; ...
0 -.06 -.23 -.52 -.725 -.57 -.07 0;0 -.0314 -.113 -.392 -.55 -.45 -.03 0; ...
0 -.075 -.127 -.290 -.44 -.35 -.07 0;0 -.06 -.10 -.250 -.38 -.27 -.06 0; ...
0 -.04 -.045 -.160 -.20 -.15 -.04 0;0 0 0 0 0 0 0 0];
gain=interp2(vgrid,agrid,G,vkt,alpha,'linear');assert(isfinite(gain),'Invalid table interpolation.');
wiTail=gain*mean(vi);
flow.additionalRelativeVelocityBody_mps=wiTail*[sin(betaM);0;-cos(betaM)];
flow.wakeRatio=gain;flow.rotorMeanInduced_mps=mean(vi);flow.tailInducedSigned_mps=wiTail;
flow.alphaBody_deg=alpha;flow.speed_kt=vkt;
flow.betaM_rad=betaM;flow.betaM_deg=betaM*180/pi;
flow.identity='FERGUSON_1988_TABLE_2IA_STEADY_HELI';
flow.source='NASA_CR_166536_B22_B25_A39_A40';
flow.claim='SOURCE_CONSTRAINED_MODEL_EXTENSION_NOT_INDEPENDENT_FLIGHT_VALIDATION';
if isfield(P.htail,'modelIdentity') && strcmp(P.htail.modelIdentity,'GTRS_COHERENT_STEADY_HELI_TAIL_V3')
    if ~isfield(rotorLeft,'F')||~isfield(rotorRight,'F')|| ...
            numel(rotorLeft.F)~=3||numel(rotorRight.F)~=3|| ...
            ~isfield(rotorLeft,'mu')||~isfield(rotorRight,'mu')
        error('rotor_tail_interference_heli:MissingRotorField','V3 requires actual rotor force and mu records.');
    end
    vals=[rotorLeft.F(:);rotorRight.F(:);rotorLeft.mu;rotorRight.mu];
    if ~isreal(vals)||any(~isfinite(vals))||min([rotorLeft.mu rotorRight.mu])<0
        error('rotor_tail_interference_heli:InvalidRotorField','Finite real forces and nonnegative mu required.');
    end
    flow.rotorForceCoefficientSum=(norm(rotorLeft.F)+norm(rotorRight.F))/ ...
        (P.env.rho*pi*P.rotor.Omega^2*P.rotor.R^4);
    flow.rotorMuMean=.5*(rotorLeft.mu+rotorRight.mu);
end
end
