function [Fbody,Mbody,out]=gtrs_spinner_steady(x,betaM,cgShift,rotorLeft,rotorRight,P)
%GTRS_SPINNER_STEADY 两桨毂罩的独立阻力载荷，显式稳态对称子模型。
% CR166536 Sep1988 RevA A75/A76 (PDF143/144), B33 (PDF383):
% U_MSP=U*cos(betaM)+W*sin(betaM),
% W_MSP=-mean(Wi)-U*sin(betaM)+W*cos(betaM); qsp=rho*|Vsp|^2/2;
% SD=2*qsp*(1.0+5.5*sin(alphaMast)^3) with source areas in ft^2.
% A232(PDF300): moment arm follows the tilted mast in both x and z.
% alphaMast=atan2(hypot(U_MSP,V),abs(W_MSP)). No fitting to trim outputs.
% Kinematics are steady, zero rates/sideslip, forward velocity.  The
% induced velocity is rotated with betaM using the same thrust-axis
% convention as the rotor backend, which permits angle screening.  The
% spinner area and hub geometry remain the source-mapped low-order values.
% The existing low-order mast/CG geometry is retained, not silently upgraded
% to exact source geometry. No engine-pylon or jet-thrust force is included.
x=x(:);cgShift=cgShift(:);
if numel(x)~=9||numel(cgShift)~=3||~isscalar(betaM)|| ...
 ~isreal([x;cgShift;betaM])||any(~isfinite([x;cgShift;betaM]))
 error('gtrs_spinner_steady:InvalidInput','Finite real state/CG/mast angle required.');
end
if betaM < -1e-12 || betaM > pi/2+1e-12
 error('gtrs_spinner_steady:UnsupportedNacelleAngle','betaM must be in [0,pi/2].');
end
if abs(x(2))>1e-8||norm(x(4:6))>1e-8||x(1)<=0
 error('gtrs_spinner_steady:SteadySymmetricOnly','Only forward symmetric zero-rate states supported.');
end
vi=[rotorLeft.inducedVelocity,rotorRight.inducedVelocity];
if numel(vi)~=2||~isreal(vi)||any(~isfinite(vi))||any(vi<0)
 error('gtrs_spinner_steady:InvalidInflow','Finite nonnegative scalar rotor induced speeds required.');
end
if ~isfield(P.env,'rho')||~isscalar(P.env.rho)||P.env.rho<=0||~isfinite(P.env.rho)
 error('gtrs_spinner_steady:InvalidDensity','Positive density required.');
end
eT=[sin(betaM);0;-cos(betaM)];
v=x(1:3)+mean(vi)*eT;speed=norm(v);q=.5*P.env.rho*speed^2;
% Passive body-to-mast rotation about +body-y; mast-z points opposite eT.
% At betaM=0 it is identity; at pi/2, body forward flow is axial (-mast-z).
bodyToMast=[cos(betaM) 0 sin(betaM);0 1 0;-sin(betaM) 0 cos(betaM)];
vMast=bodyToMast*v;
alphaMast=atan2(hypot(vMast(1),vMast(2)),abs(vMast(3)));
baseArea=1.0*.3048^2;crossArea=5.5*.3048^2;
effectiveArea=2*(baseArea+crossArea*sin(alphaMast)^3);
drag=q*effectiveArea;Fbody=-drag*v/speed;
r=[P.rotor.pivotX+P.rotor.RH_hub*sin(betaM);0; ...
   P.rotor.pivotZ-P.rotor.RH_hub*cos(betaM)]-cgShift;
if ~isreal(r)||any(~isfinite(r)),error('gtrs_spinner_steady:InvalidGeometry','Finite existing hub geometry required.');end
Maero=zeros(3,1);Marm=cross(r,Fbody);Mbody=Marm;
out=struct('identity','GTRS_TWO_SPINNERS_STEADY_HELI_V7_ANGLE_SCREEN', ...
 'betaM_rad',betaM,'betaM_deg',betaM*180/pi,'thrustAxisBody',eT,'F',Fbody,'M',Mbody, ...
 'rAC',r,'Vlocal',v,'VlocalMast',vMast,'bodyToMast',bodyToMast, ...
 'qbar',q,'alphaMast_rad',alphaMast,'effectiveDragArea_m2',effectiveArea, ...
 'drag_N',drag,'meanInduced_mps',mean(vi),'Maero',Maero,'Marm',Marm,'spinnerCount',2, ...
 'source','CR166536_REVA_A75_A76_B33_A232','sourceAreaEach_ft2',[1,5.5], ...
 'geometryRole','EXISTING_LOW_ORDER_HUB_AND_CG_NOT_REIDENTIFIED','targetFitting',false, ...
 'claim','SOURCE_DEFINED_COMPONENT_REFERENCE_CORRELATION_NOT_FLIGHT_VALIDATION');
if betaM~=0,out.identity='GTRS_TWO_SPINNERS_STEADY_MAST_AXES_V9';end
end
