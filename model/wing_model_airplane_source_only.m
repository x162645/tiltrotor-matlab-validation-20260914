function [Fbody,Mbody,out]=wing_model_airplane_source_only(x,uCtrl,betaM,cgShift,rotorLeft,rotorRight,P)
%WING_MODEL_AIRPLANE_SOURCE_ONLY CR-166536 X_FL1=0/0 airplane wing subset.
% Analysis-only branch. Requires betaM=pi/2 and P.validation.flapDeg=0.
% Tail/rotor source compatibility is not implied by this function.
x=x(:); cgShift=cgShift(:); uCtrl=uCtrl(:);
if numel(x)~=9 || numel(uCtrl)~=7 || numel(cgShift)~=3 || x(1)<=0 || abs(x(2))>1e-8 || norm(x(4:6))>1e-8 || abs(uCtrl(5))>1e-12
 error('wing_model_airplane_source_only:InvalidState','Only steady symmetric forward state is supported.');
end
if abs(betaM-pi/2)>1e-10,error('wing_model_airplane_source_only:WrongAngle','Requires internal betaM=90 deg.');end
if ~isfield(P,'validation') || P.validation.flapDeg~=0,error('wing_model_airplane_source_only:WrongFlapCase','Requires X_FL1=0/0 flap declaration.');end
S_half=P.wing.S/2; muMean=.5*(hypot(rotorLeft.muLong,rotorLeft.muLat)+hypot(rotorRight.muLong,rotorRight.muLat));
arg=pi/2-betaM; muRaw=(P.wing.muMax-muMean)/P.wing.muMax;
raw=P.wing.SslipMaxHalf*(sin(1.386*arg)+cos(3.114*arg))*muRaw; upper=min(P.wing.SslipMaxHalf,S_half); Ss=min(max(raw,0),upper); Sf=S_half-Ss;
Fbody=zeros(3,1); Mbody=zeros(3,1); regions=cell(4,1); idx=0;
for side=[-1,1]
 if side<0,rot=rotorLeft;else,rot=rotorRight;end
 for immersed=[false,true]
  idx=idx+1; if immersed,S=Ss;y=side*P.wing.ySlipAC;vi=rot.inducedVelocity;else,S=Sf;y=side*P.wing.yFreeAC;vi=0;end
  r=[P.wing.xAC;y;P.wing.zAC]-cgShift; Vrigid=x(1:3)+cross(x(4:6),r); Vloc=Vrigid+vi*[sin(betaM);0;-cos(betaM)]; V=norm(Vloc); a=atan2(Vloc(3),Vloc(1));
  [CL,CD,Cm,meta]=gtrs_wing_airplane_source_coefficients(a,V/P.env.aSound); q=.5*P.env.rho*V^2; F=aero_force_body(q*S*CD,0,q*S*CL,a,0); Mi=[0;q*S*P.wing.c*Cm;0]; M=cross(r,F)+Mi;
  Fbody=Fbody+F; Mbody=Mbody+M; regions{idx}=struct('side',side,'inSlipstream',immersed,'S',S,'rAC',r,'Vlocal',Vloc,'alpha',a,'qbar',q,'CL',CL,'CD',CD,'Cm',Cm,'F',F,'M',M,'coefficientMeta',meta);
 end
end
out=struct('identity','GTRS_CR166536_WING_AIRPLANE_XFL1_SOURCE_ONLY','betaM_deg',betaM*180/pi,'flapSetting','X_FL1=0/0','SslipHalf',Ss,'SfreeHalf',Sf,'regions',{regions},'F',Fbody,'M',Mbody,'claim','ANALYSIS_ONLY_WING_SOURCE_NO_FULL_AIRPLANE_VALIDATION');
end
