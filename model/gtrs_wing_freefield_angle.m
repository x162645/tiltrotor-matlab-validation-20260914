function [alphaWing_deg,meta]=gtrs_wing_freefield_angle(alphaBody_deg,forceCoefficientSum,muMean,betaM)
%GTRS_WING_FREEFIELD_ANGLE Shared steady wing field input, not a fit.
% Ferguson CR166536 Sep1988 RevA, A70/PDF138 and B33/PDF383.
% CF is sum(norm(Frotor))/(rho*pi*Omega^2*R^4); NOT the doubled code CT.
% betaM is radians; source X_RW1 and X_RW2 are per degree and per degree^2.
% Three-argument calls retain the historical beta_m=0 helicopter contract.
if nargin<4,betaM=0;end
if ~isscalar(betaM)||~isreal(betaM)||~isfinite(betaM)||betaM<0||betaM>pi/2
 error('gtrs_wing_freefield_angle:OutsideMastDomain','Require scalar betaM in 0..pi/2 rad.');
end
values=[alphaBody_deg;forceCoefficientSum;muMean];
if numel(values)~=3||~isreal(values)||any(~isfinite(values))||forceCoefficientSum<0||muMean<0
 error('gtrs_wing_freefield_angle:InvalidInput','Three finite scalars, nonnegative CF/mu required.');
end
T=gtrs_heli_tail_tables();
b=betaM*180/pi;XRW=T.XRW0+b*(T.XRW1+b*T.XRW2);
delta=T.KXRW*XRW*forceCoefficientSum/max(.15,muMean)^2*57.3;
alphaWing_deg=alphaBody_deg-delta;
meta=struct('alphaBody_deg',alphaBody_deg,'alphaWing_deg',alphaWing_deg, ...
 'deflection_deg',delta,'forceCoefficientSum',forceCoefficientSum,'muMean',muMean, ...
 'betaM_rad',betaM,'betaM_deg',b,'XRW',XRW, ...
 'source','CR166536_REVA_A70_B33','role','EFFECTIVE_ANGLE_QBAR_DEFINED_SEPARATELY');
end
