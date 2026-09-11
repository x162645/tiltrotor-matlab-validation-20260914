function [dz,out,y]=d02_rhs(z,command,betaM,P,mode)
%D02_RHS Explicit induced-state / algebraically eliminated inflow pair.
% dynamic retains the assumed target-minus-state law from21a699a.
% pp_mean/cf_mean select the source axial reductions in NASA TM88327.
% Actuator taus remain assumptions in every mode. No fit to external curves.
% Quasisteady has no dummy inflow states and uses the same load functions.
if nargin<5,mode='dynamic';end
m=d02_layout(mode);z=z(:);command=command(:);
if ~isnumeric(z)||~isnumeric(command)||numel(z)~=m.n||numel(command)~=3|| ...
 ~isreal([z;command])||any(~isfinite([z;command]))
 error('d02:InvalidState','Finite real state and three commands required.');
end
if ~isnumeric(betaM)||~isscalar(betaM)||~isreal(betaM)||~isfinite(betaM)||abs(betaM)>1e-12
 error('d02:UnsupportedMode','This reviewed prototype is restricted to fixed helicopter-mode mast.');
end
if ~isfield(P,'d02')||~isfield(P.d02,'inflowTimeConstant')||~isfield(P.d02,'actuatorTimeConstant')
 error('d02:MissingTimeConstants','Explicit assumed D02 constants required.');
end
ti=P.d02.inflowTimeConstant;ta=P.d02.actuatorTimeConstant(:);
if ~isnumeric(ti)||~isscalar(ti)||~isreal(ti)||~isfinite(ti)||ti<=0|| ...
 ~isnumeric(ta)||numel(ta)~=3||~isreal(ta)||any(~isfinite(ta))||any(ta<=0)
 error('d02:InvalidTimeConstants','Finite positive tau and three actuator constants required.');
end
x=z(1:9);act=z(m.act);
limits=[P.control.collectiveLim;P.control.cyclicLim;P.control.elevatorLim];
if any(command<limits(:,1))||any(command>limits(:,2))||any(act<limits(:,1))||any(act>limits(:,2))
 error('d02:ControlOutsideDomain','Do not silently use clipped commands or hidden actuator states.');
end
u=[act(1);0;act(2);0;0;act(3);0];
if isempty(m.vi),vi=[];else,vi=z(m.vi);end
clock=tic;[xdot,e]=tiltrotor_eom(x,u,betaM,P,vi);modelSeconds=toc(clock);
if ~e.evaluationValid
 error('d02:InvalidLoadEvaluation','Load evaluation outside supported branch: %s',e.physicalStatus);
end
L=e.components.rotorLeft;R=e.components.rotorRight;
actual=[L.inducedVelocity;R.inducedVelocity];target=[L.inducedVelocityTarget;R.inducedVelocityTarget];
actDot=(command-act)./ta;
% Third row of 3-2-1 body-to-NED rotation, independent of yaw.
down=[-sin(x(8)),sin(x(7))*cos(x(8)),cos(x(7))*cos(x(8))];
vUp=-down*x(1:3);aDown=down*(e.Ftotal/e.massProperties.mass);
specific=e.FaeroProp/e.massProperties.mass;
sourceMeta={};
if isempty(m.vi)
 dz=[xdot;actDot;vUp];
elseif strcmp(mode,'dynamic')
 dz=[xdot;(target-actual)/ti;actDot;vUp];
else
 % Source Eq5 axial subset. State/loads/actuators unchanged. No target fit.
 % Neglect coning pumping because blade flap states are still quasisteady;
 % do not label this the complete coupled-inflow/flapping model of the paper.
 rr={L,R};dvi=zeros(2,1);
 for k=1:2
  rotor=rr{k};through=actual(k)+rotor.Vaxial;
  crossflow=hypot(rotor.Vlong,rotor.Vlat);
  % Predeclared LOCAL TEST bound: neglecting crossflow in momentum flux
  % differs by <=sqrt(1+.02^2)-1. Not a source validation envelope.
  if through<=0||crossflow/through>.02||norm(x(4:6))/P.rotor.Omega>1e-3
   error('d03:OutsideNearAxialTestScope','Only near-hover axial normal-flow subset; no silent extension.');
  end
  [dvi(k),sourceMeta{k}]=mean_inflow_88327(actual(k),rotor.thrust,rotor.Vaxial,0,P,mode);
  sourceMeta{k}.coningPumpingOmitted=true;
  sourceMeta{k}.crossflowRatio=crossflow/through;
  sourceMeta{k}.normalMomentumOmissionBound=sqrt(1+(crossflow/through)^2)-1;
 end
 dz=[xdot;dvi;actDot;vUp];
end
if ~isreal(dz)||any(~isfinite(dz)),error('d02:NonfiniteDerivative','Invalid dynamic derivative.');end
if nargout<2,return;end
out=e;out.inflowLaw=mode;out.sourceInflow=sourceMeta;out.actualInducedVelocity=actual;out.targetInducedVelocity=target;
out.dynamicDerivativeValid=true;out.steadyEquilibriumSatisfied=e.steadyEquilibriumSatisfied;
out.actuatorState=act;out.command=command;out.heightRateUp=vUp;
out.inertialAccelerationDown=aDown;out.inertialAccelerationBody=e.Ftotal/e.massProperties.mass;
out.velocityDerivativeBody=xdot(1:3);out.specificForceBody=specific;
out.work=struct('modelSeconds',modelSeconds,'flapSeconds',L.work.flapSeconds+R.work.flapSeconds, ...
 'rotorSeconds',L.work.rotorSeconds+R.work.rotorSeconds,'bladeLoadCalls',L.work.bladeLoadCalls+R.work.bladeLoadCalls, ...
 'flapSolveCalls',L.work.flapSolveCalls+R.work.flapSolveCalls);
if nargout<3,return;end
y=[x(5);x(8);x(3);vUp;aDown;specific(3);L.thrust;R.thrust;actual; ...
 e.FaeroProp(1);e.FaeroProp(3);e.Mtotal(2);z(m.height)];
end
