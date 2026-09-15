function [epsilon_deg,meta]=gtrs_wing_tail_downwash(alphaWing_deg,Mach,betaM)
%GTRS_WING_TAIL_DOWNWASH CR166536 RevA A74/PDF142, B45-B49/PDF395-399.
% Table 4-V(a-e), fixed flap/flaperon40/25. Source angles are degrees;
% betaM input is radians (0=helicopter). Source epsilon_OGE is divided by
% sqrt(1-Mach^2), A74. No ground-effect correction or new wake model.
% Linear interpolation between published mast nodes is an explicit
% numerical assumption. No extrapolation, clipping or target fitting.
v=[alphaWing_deg;Mach;betaM];
if numel(v)~=3||~isreal(v)||any(~isfinite(v))
 error('gtrs_wing_tail_downwash:InvalidInput','Three finite real scalars required.');
end
if alphaWing_deg< -90||alphaWing_deg>90||Mach<0||Mach>=.2||betaM<0||betaM>pi/2
 error('gtrs_wing_tail_downwash:OutsideSourceDomain','Require alpha -90..90deg, M<.2 and betaM 0..pi/2.');
end
T=gtrs_heli_tail_tables();
% Rows share T.wingAlpha_deg; columns correspond to beta_m=[0 15 30 60 90].
E=[T.wingDownwash_deg(:), ...
 [0 0 .7 2.4 4.1 5.8 7.5 9.2 10.4 10.8 9.8 6.4 0 0].', ...
 [0 0 0 1.3 2.9 4.5 6.1 7.7 8.9 9.1 8.1 5.5 0 0].', ...
 [0 0 0 1.78 3.38 4.98 6.58 8.18 9.2 9.5 8.4 5.5 0 0].', ...
 [0 0 .95 2.54 3.92 5.40 6.88 8.26 8.90 8.80 7.30 4.80 0 0].'];
if betaM==0
 oge=interp1(T.wingAlpha_deg,T.wingDownwash_deg,alphaWing_deg,'linear');
else
 oge=interp2([0 15 30 60 90],T.wingAlpha_deg,E,betaM*180/pi,alphaWing_deg,'linear');
end
epsilon_deg=oge/sqrt(1-Mach^2);
meta=struct('source','CR166536_REVA_A74_TABLE4V_FLAP40_25', ...
 'betaM_deg',betaM*180/pi,'epsilonOGE_deg',oge,'flapSetting','40/25', ...
 'mastInterpolation','ASSUMED_PIECEWISE_LINEAR_BETWEEN_SOURCE_NODES');
end
