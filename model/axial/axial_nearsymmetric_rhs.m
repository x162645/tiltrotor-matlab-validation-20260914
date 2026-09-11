function [dz,out,y]=axial_nearsymmetric_rhs(z,u,M)
%AXIAL_NEARSYMMETRIC_RHS Seven-state extension of the unchanged D04 equations.
% Actual pitches [left;right] in rad; no actuator dynamics or fitted gains.
z=z(:);u=u(:);P=M.P;r=P.rotor;c=M.coefficients;
if ~isnumeric(z)||~isnumeric(u)||numel(z)~=7||numel(u)~=2||~isreal([z;u])||any(~isfinite([z;u]))
 error('d05:InvalidState','Finite 7-state and 2 actual pitches required.');end
v=z(1:2);beta=z(3:4);rate=z(5:6);w=z(7);
if any(abs(u)>.6)||any(abs(beta)>.3),error('d05:OutsideSmallAngle','Outside declared small-angle study.');end
if any(v<=0)||any(v-w<=0),error('d05:OutsideNormalFlow','Positive normal axial flow required.');end
Ta=c.Ttheta.*u+c.Ttwist+c.Tv.*(v-w)+c.Trate.*rate;
Q=c.Qtheta.*u+c.Qtwist+c.Qv.*(v-w)+c.Qrate.*rate;
if any(Ta<=0),error('d05:NonpositiveThrust','Positive thrust required; no clipping.');end
rhs=[r.Nb*(Q-r.Ib*r.Omega^2*beta-r.Sblade*P.env.g);P.bodyMass*P.env.g-sum(Ta)];
acc=M.massCholesky\(M.massCholesky.'\rhs);bdd=acc(1:2);wd=acc(3);
vd=zeros(2,1);for j=1:2,vd(j)=mean_inflow_88327(v(j),Ta(j),-w,rate(j),P,M.law);end
dz=[vd;rate;bdd;wd];hub=Ta-r.Nb*r.Sblade*bdd;
y=[-wd;hub(2)-hub(1)];
if any(~isfinite([dz;y]))||~isreal([dz;y]),error('d05:InvalidEvaluation','Nonfinite dynamics.');end
if nargout>1
 out=struct('aeroThrust',Ta,'hubThrust',hub,'vi',v,'beta',beta,'rate',rate,'bdd',bdd,'wd',wd, ...
  'bodyResidual',P.bodyMass*(wd-P.env.g)+sum(hub), ...
  'bladeResidual',r.Ib*bdd-r.Sblade*wd-Q+r.Ib*r.Omega^2*beta+r.Sblade*P.env.g);
end
end
