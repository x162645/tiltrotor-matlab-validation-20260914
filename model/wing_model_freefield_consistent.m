function [Fbody,Mbody,out]=wing_model_freefield_consistent(x,u,betaM,cg,rotL,rotR,P)
%WING_MODEL_FREEFIELD_CONSISTENT V6 source free-field subset on V5 coverage.
% A70/PDF138: q_free, alpha_WFS and M0=q_free*S_W*c_W*Cm.
% A181/PDF249: free-flow forces resolved with alpha_WFS, not alpha_body.
% A69/PDF137: immersed branch contributes lift/drag, not another intrinsic Cm.
% Existing V5 immersed area, local flow and coefficients remain unchanged.
% Not a full GTRS footprint/nonuniform-flow implementation; no target fitting.
[~,~,out]=wing_model_source_family(x,u,betaM,cg,rotL,rotR,P);
x=x(:);
if ~isfield(rotL,'F')||~isfield(rotR,'F')||~isfield(rotL,'mu')||~isfield(rotR,'mu')
 error('wing_model_freefield_consistent:MissingRotorFields','Actual rotor force and mu required.');
end
v=[rotL.F(:);rotR.F(:);rotL.mu;rotR.mu;P.rotor.Omega;P.rotor.R;P.env.rho];
if numel(v)~=11||~isreal(v)||any(~isfinite(v))||any(v(end-2:end)<=0)||any(v(7:8)<0)
 error('wing_model_freefield_consistent:InvalidRotorFields','Finite force/mu and positive rotor/environment scales required.');
end
cf=(norm(rotL.F)+norm(rotR.F))/(P.env.rho*pi*P.rotor.Omega^2*P.rotor.R^4);
[aDeg,field]=gtrs_wing_freefield_angle(atan2(x(3),x(1))*180/pi,cf,.5*(rotL.mu+rotR.mu),betaM);
a=aDeg*pi/180;qFree=.5*P.env.rho*(x(1)^2+x(3)^2);
[CL,CD,Cm,coeff]=gtrs_wing_heli_coefficients(a,norm(x(1:3))/P.env.aSound,betaM);
Fbody=zeros(3,1);Mbody=zeros(3,1);intrinsic=zeros(3,1);
for j=1:4
 r=out.regions{j};r.alphaKinematic=atan2(r.Vlocal(3),r.Vlocal(1));
 if ~r.inSlipstream
  r.alpha=a;r.alphaCoefficient=a;r.alphaResolve=a;r.qbar=qFree;
  r.CL=CL;r.CD=CD;r.Cm=Cm;r.coefficientMeta=coeff;
  r.F=aero_force_body(qFree*r.S*CD,0,qFree*r.S*CL,a,0);
  % Allocate the source total-area free-stream intrinsic moment once, half
  % per symmetric side; it is not q_local*S_region for immersed patches.
  r.Maero=[0;qFree*(P.wing.S/2)*P.wing.c*Cm;0];
 else
  r.alphaCoefficient=r.alpha;r.alphaResolve=r.alpha;
  r.Cm=0;r.Maero=zeros(3,1);
 end
 r.Marm=cross(r.rAC,r.F);r.M=r.Marm+r.Maero;
 out.regions{j}=r;Fbody=Fbody+r.F;Mbody=Mbody+r.M;intrinsic=intrinsic+r.Maero;
end
out.identity='SOURCE_WING_FREEFIELD_CONSISTENT_V6';out.F=Fbody;out.M=Mbody;
out.freefield=field;out.qbarFree=qFree;out.Maero=intrinsic;
out.intrinsicMomentDefinition='Q_FREE_TIMES_TOTAL_WING_AREA_C_CM_ONCE_A70';
out.freefieldAngleDefinition='SAME_A70_EFFECTIVE_ALPHA_AS_TAIL_DOWNWASH';
out.localVelocityModel='V5_IMMERSED_KINEMATICS_RETAINED_FREE_ALPHA_AND_Q_SEPARATE';
out.claim='SOURCE_FREEFIELD_SUBSET_NOT_FULL_GTRS_WAKE_NOT_FLIGHT_VALIDATED';
if betaM~=0,out.identity='SOURCE_WING_FREEFIELD_MAST_ANGLE_V9';end
end
