function flow = rotor_tail_interference_heli(x,betaM,rotorLeft,rotorRight,P)
%ROTOR_TAIL_INTERFERENCE_HELI Source-table, steady, symmetric helicopter coupling.
% SOURCE: Ferguson, NASA CR-166536, September 1988 Rev A.
% Table 2-Ia, B-22 (PDF 372): signed Wi_R/H / Wi ratio versus alpha_F [deg]
% and V_T [kt], beta_m=0 (mast vertical). Table 2-II, B-25 (PDF 375):
% K_Hbeta=1 at zero sideslip. A-39/40 (PDF 107/108): mean rotor inflow,
% steady transport limit and Uadd=Wi_R/H*sin(betaM), Wadd=-Wi_R/H*cos(betaM).
% Original PDF SHA256 a2013a314af5beb0c5e9bc5bbeb26f99be9a8aa63f2ebe07deaaf11d0d44d67d.
% This is NOT a dynamic-wake or all-mode implementation. Source ratios are
% retained without fitting to the thesis trim table. Negative ratios MUST
% NOT be clipped: at betaM=0 they give positive relative-velocity Wadd.
% Rotor-to-tail route is separate from existing wing-to-tail downwash.

x=x(:);
if numel(x)~=9 || ~isreal(x) || any(~isfinite(x))
    error('rotor_tail_interference_heli:InvalidState','Expected finite real 9-state.');
end
if ~(isscalar(betaM) && isfinite(betaM) && abs(betaM)<1e-12)
    error('rotor_tail_interference_heli:UnsupportedMode','Only betaM=0 supported.');
end
if abs(x(2))>1e-8 || norm(x(4:6))>1e-8
    error('rotor_tail_interference_heli:SteadySymmetricOnly', ...
        'Only steady symmetric zero-rate use is implemented; no dynamic-validation claim.');
end
v=norm(x(1:3)); vkt=v/(1852/3600); alpha=atan2(x(3),x(1))*180/pi;
if ~isfield(P.env,'aSound') || P.env.aSound<=0 || ~isfinite(P.env.aSound)
    error('rotor_tail_interference_heli:MissingSoundSpeed','Finite positive aSound required.');
end
if v/P.env.aSound>=0.2 || vkt>140 || alpha< -30 || alpha>20
    error('rotor_tail_interference_heli:OutsideDeclaredDomain', ...
        'Declared domain: M<0.2, V<=140 kt, -30<=alpha<=20 deg. No extrapolation.');
end
vi=[rotorLeft.inducedVelocity,rotorRight.inducedVelocity];
if ~isreal(vi) || any(~isfinite(vi)) || any(vi<0)
    error('rotor_tail_interference_heli:InvalidRotorInflow', ...
        'Positive-thrust convention requires finite nonnegative rotor induced velocities.');
end
agrid=[-30 -28 -24 -20 -16 -12 -8 -4 0 4 8 12 16 20];
vgrid=[0 20 40 60 80 100 120 140];
G=[0 0 0 0 0 0 0 0; ...
   0 -.02 -.06 -.10 -.15 -.12 -.02 0; ...
   0 -.05 -.15 -.30 -.60 -.37 -.05 0; ...
   0 -.06 -.25 -.50 -.92 -.65 -.06 0; ...
   0 -.07 -.40 -.70 -1.10 -.85 -.07 0; ...
   0 -.07 -.46 -.85 -1.13 -.90 -.08 0; ...
   0 -.14 -.46 -.73 -1.05 -.80 -.10 0; ...
   0 -.0945 -.33 -.623 -.90 -.67 -.09 0; ...
   0 -.06 -.23 -.52 -.725 -.57 -.07 0; ...
   0 -.0314 -.113 -.392 -.55 -.45 -.03 0; ...
   0 -.075 -.127 -.290 -.44 -.35 -.07 0; ...
   0 -.06 -.10 -.250 -.38 -.27 -.06 0; ...
   0 -.04 -.045 -.160 -.20 -.15 -.04 0; ...
   0 0 0 0 0 0 0 0];
gain=interp2(vgrid,agrid,G,vkt,alpha,'linear');
assert(isfinite(gain),'Invalid table interpolation.');
wiTail=gain*mean(vi); % K_Hbeta=1; steady limit of 1/(tau*s+1)=1.
flow.additionalRelativeVelocityBody_mps=wiTail*[sin(betaM);0;-cos(betaM)];
flow.wakeRatio=gain; flow.rotorMeanInduced_mps=mean(vi);
flow.tailInducedSigned_mps=wiTail; flow.alphaBody_deg=alpha; flow.speed_kt=vkt;
flow.identity='FERGUSON_1988_TABLE_2IA_STEADY_HELI';
flow.source='NASA_CR_166536_B22_B25_A39_A40';
flow.claim='SOURCE_CONSTRAINED_MODEL_EXTENSION_NOT_INDEPENDENT_FLIGHT_VALIDATION';
end
