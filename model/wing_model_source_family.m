function [Fbody,Mbody,out]=wing_model_source_family(x,uCtrl,betaM,cgShift,rotorLeft,rotorRight,P)
%WING_MODEL_SOURCE_FAMILY One controlled low-order model variant.
% Replaces only CL/CD/Cm family with source wing-pylon tables. Retains the
% existing Eq16 covered area, Eq17 local velocity, geometry and force assembly.
% This is NOT the complete GTRS wake footprint or wing-pylon implementation.
% The betaM argument follows the repository convention (0 deg helicopter,
% 90 deg airplane).  The original V5 implementation was accidentally
% guarded to betaM=0; the coverage and local-flow equations below are
% already parameterised by betaM, so the guard is removed here to permit
% controlled angle screening.  This remains a source-constrained subset,
% not a claim of validated transition aerodynamics.
% Deliberately does not infer new coverage parameters from TableC1 loads.
x=x(:);cgShift=cgShift(:);uCtrl=uCtrl(:);
if numel(x)~=9||numel(cgShift)~=3||numel(uCtrl)~=7||any(~isfinite([x;cgShift;uCtrl]))||~isreal([x;cgShift;uCtrl])
 error('wing_model_source_family:InvalidInput','Expected finite real inputs.');
end
if ~isscalar(betaM)||~isfinite(betaM)||~isreal(betaM)||betaM < -1e-12||betaM > pi/2+1e-12
 error('wing_model_source_family:UnsupportedNacelleAngle','betaM must be in [0,pi/2].');
end
if abs(x(2))>1e-8||norm(x(4:6))>1e-8||abs(uCtrl(5))>1e-12||x(1)<=0
 error('wing_model_source_family:SteadySymmetricOnly','Only forward symmetric zero-rate/aileron use.');
end
if ~isfield(P,'validation')||P.validation.flapDeg~=40
 error('wing_model_source_family:WrongFlapCase','Requires declared flap40 case.');
end
S_half=P.wing.S/2;muMean=.5*(hypot(rotorLeft.muLong,rotorLeft.muLat)+hypot(rotorRight.muLong,rotorRight.muLat));
if ~(isfinite(P.wing.muMax)&&P.wing.muMax>0),error('wing_model_source_family:BadAreaParameter','Invalid muMax.');end
arg=pi/2-betaM;angleRaw=sin(1.386*arg)+cos(3.114*arg);muRaw=(P.wing.muMax-muMean)/P.wing.muMax;
raw=P.wing.SslipMaxHalf*angleRaw*muRaw;upper=min(P.wing.SslipMaxHalf,S_half);Ss=min(max(raw,0),upper);Sf=S_half-Ss;
Fbody=zeros(3,1);Mbody=zeros(3,1);regions=cell(4,1);idx=0;
for side=[-1,1]
 if side<0,rot=rotorLeft;else,rot=rotorRight;end
 for immersed=[false,true]
  idx=idx+1;
  if immersed,S=Ss;y=side*P.wing.ySlipAC;vi=rot.inducedVelocity;else,S=Sf;y=side*P.wing.yFreeAC;vi=0;end
  if ~(isfinite(vi)&&vi>=0),error('wing_model_source_family:BadInflow','Positive-thrust inflow required.');end
  r=[P.wing.xAC;y;P.wing.zAC]-cgShift;Vrigid=x(1:3)+cross(x(4:6),r);
  dv=vi*[sin(betaM);0;-cos(betaM)];Vloc=Vrigid+dv;V=norm(Vloc);a=atan2(Vloc(3),Vloc(1));
  [CL,CD,Cm,meta]=gtrs_wing_heli_coefficients(a,V/P.env.aSound);
  q=.5*P.env.rho*V^2;F=aero_force_body(q*S*CD,0,q*S*CL,a,0);
  Mi=[0;q*S*P.wing.c*Cm;0];Ma=cross(r,F);M=Mi+Ma;
  Fbody=Fbody+F;Mbody=Mbody+M;
  regions{idx}=struct('side',side,'inSlipstream',immersed,'S',S,'rAC',r,'Vlocal',Vloc,'VrigidLocal',Vrigid, ...
   'alpha',a,'qbar',q,'CL',CL,'CD',CD,'Cm',Cm,'Maero',Mi,'Marm',Ma,'F',F,'M',M,'coefficientMeta',meta);
 end
end
out=struct('identity','SOURCE_WING_COEFFICIENT_FAMILY_LOW_ORDER_WAKE_V5_ANGLE_SCREEN', ...
 'betaM_rad',betaM,'betaM_deg',betaM*180/pi,'SslipHalf',Ss,'SfreeHalf',Sf, ...
 'SslipRawHalf',raw,'SslipUpperHalf',upper,'muMean',muMean,'regions',{regions},'F',Fbody,'M',Mbody, ...
 'coverageModel','EXISTING_NUAA_EQ16_UNCHANGED','localVelocityModel','EXISTING_NUAA_EQ17_UNCHANGED', ...
 'legacyTanhOrInducedDragAdded',false,'claim','SOURCE_COEFFICIENTS_NOT_COMPLETE_GTRS_WING_NOT_FLIGHT_VALIDATED');
end
