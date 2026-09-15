function [CL,CD,Cm,meta]=gtrs_wing_heli_coefficients(alphaRad,Mach,betaM)
%GTRS_WING_HELI_COEFFICIENTS Source wing-pylon family, fixed flap40/25.
% NASA CR166536 Sep1988 RevA, B36-B37/B41-B42/B51; PDF386/387/391/392/401.
% Source hash a2013a314af5beb0c5e9bc5bbeb26f99be9a8aa63f2ebe07deaaf11d0d44d67d.
% Column X_FL3=40/25, mast angle0..90deg, Mach0..0.2. No target-data fitting.
% Optional betaM is in radians, 0=helicopter, pi/2=airplane; the historical
% two-argument API explicitly retains its betaM=0 helicopter definition.
% CL/CD are linearly interpolated between the two published mast columns;
% Cm uses its five published mast nodes. This interpolation policy is a
% declared numerical assumption, not additional measured conversion data.
% These are total lift/drag coefficients: do not add a second induced-drag
% polar, tanh cap, or near-normal flat-plate force. Cm is a zero-lift value;
% despite the table heading 1/rad, A70/A71 uses it as q*S*c*Cm, not a slope.
% Only forward-flow source subset [-90,40]deg is transcribed. No extrapolation.
if nargin<3,betaM=0;end
if ~isscalar(betaM)||~isreal(betaM)||~isfinite(betaM)||betaM<0||betaM>pi/2
 error('gtrs_wing_heli_coefficients:OutsideMastDomain','Require scalar betaM in 0..pi/2 rad.');
end
a=alphaRad*180/pi;
if ~isreal([a(:);Mach(:)])||any(~isfinite([a(:);Mach(:)]))||any(Mach(:)<0)||any(Mach(:)>.2)||any(a(:)<-90)||any(a(:)>40)
 error('gtrs_wing_heli_coefficients:OutsideSourceSubset','Require Mach0..0.2 and alpha -90..40deg.');
end
al=[-90 -80 -70 -60 -50 -40 -36 -32 -28 -24 -21.5 -21 -20 -19.2 -16 -12 -8 -4 0 4 8 11 12 13.6 16 18.4 20 24 28 32 36 40];
cl=[0 -.245 -.400 -.480 -.420 -.265 -.250 -.260 -.300 -.380 -.440 -.440 -.395 -.360 -.165 .0628 .291 .518 .749 .975 1.205 1.380 1.433 1.500 1.400 1.260 1.200 1.15 1.20 1.32 1.41 1.47];
ad=[-90 -80 -70 -60 -50 -40 -36 -32 -28 -24 -20 -16 -12 -8 -4 0 4 8 12 16 20 24 28 32 36 40];
cd=[1.44 1.33 1.12 .91 .75 .54 .468 .405 .352 .310 .282 .263 .253 .267 .307 .345 .394 .453 .537 .589 .630 .690 .748 .800 .845 .888];
CL=interp1(al,cl,a,'linear');CD=interp1(ad,cd,a,'linear');Cm=-.110+zeros(size(CL));
if betaM~=0
 % Same alpha nodes as the betaM=0 columns above, source B36/B37/B41/B42.
 cl90=[0 -.325 -.520 -.610 -.590 -.410 -.400 -.425 -.515 -.660 -.690 -.680 -.640 -.580 -.320 0 .42 .84 1.18 1.46 1.70 1.86 1.92 1.94 1.79 1.62 1.51 1.48 1.54 1.69 1.76 1.80];
 cd90=[1.18 1.10 .93 .705 .565 .430 .335 .245 .180 .130 .090 .065 .058 .076 .106 .141 .186 .243 .322 .404 .528 .630 .710 .764 .805 .865];
 w=betaM/(pi/2);
 CL=(1-w)*CL+w*interp1(al,cl90,a,'linear');
 CD=(1-w)*CD+w*interp1(ad,cd90,a,'linear');
 Cm=interp1([0 15 30 60 90],[-.110 -.090 -.060 -.110 -.170],betaM*180/pi,'linear')+zeros(size(CL));
end
meta=struct('identity','GTRS_WING_PYLON_FLAP40_25_HELI_FAMILY','sourcePages','B36_B37_B41_B42_B51', ...
 'sourceAlpha_deg',a,'sourceMach',Mach,'mastAngle_deg',betaM*180/pi,'flapSetting','40/25', ...
 'mastInterpolation','ASSUMED_PIECEWISE_LINEAR_BETWEEN_SOURCE_NODES', ...
 'containsPylonEffects',true,'fittedToTrim',false);
if betaM~=0,meta.identity='GTRS_WING_PYLON_FLAP40_25_MAST_INTERPOLATED_V9';end
end
