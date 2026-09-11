function [dx,out,y]=axial_residualized_rhs(x,u,M)
%AXIAL_RESIDUALIZED_RHS Four physical common states; differential rates residualized.
% x=[mean(vi);mean(beta);mean(betaRate);w]. Both actual pitch inputs supported.
% f_difference=0 is solved analytically. This is classical nonlinear quasi-
% steady residualization, not exact reduction for arbitrary inputs/asymmetry.
% Key common coning dynamics are retained. No hidden integration of 7 states.
x=x(:);u=u(:);P=M.P;r=P.rotor;c=M.coefficients;
if ~isnumeric(x)||~isnumeric(u)||numel(x)~=4||numel(u)~=2||~isreal([x;u])||any(~isfinite([x;u]))
 error('d05:InvalidState','Finite 4-state and 2 actual pitches required.');end
vp=x(1);bp=x(2);rp=x(3);w=x(4);rhoA=P.env.rho*pi*r.R^2;
% Equal apparent masses and rotor geometries make f_vi,left-f_vi,right linear
% in viDifference. No numerical fit or inner nonlinear solver is necessary.
numer=c.Ttheta(1)*u(1)-c.Ttheta(2)*u(2)+c.Ttwist(1)-c.Ttwist(2)+ ...
 (c.Tv(1)-c.Tv(2))*(vp-w)+(c.Trate(1)-c.Trate(2))*rp;
den=4*rhoA*(2*vp-w+(2/3)*r.R*rp)-sum(c.Tv);
if ~isfinite(den)||den<=0,error('d05:ResidualizationDomain','No positive residualization denominator.');end
vDifference=numer/den;v=[vp+vDifference;vp-vDifference];
Ta=c.Ttheta.*u+c.Ttwist+c.Tv.*(v-w)+c.Trate*rp;
Q=c.Qtheta.*u+c.Qtwist+c.Qv.*(v-w)+c.Qrate*rp;
bDifference=(Q(1)-Q(2))/(2*r.Ib*r.Omega^2);beta=[bp+bDifference;bp-bDifference];
if any(abs(u)>.6)||any(abs(beta)>.3),error('d05:OutsideSmallAngle','Outside declared small-angle study.');end
if any(v<=0)||any(v-w<=0),error('d05:OutsideNormalFlow','Positive normal axial flow required.');end
if any(Ta<=0),error('d05:NonpositiveThrust','Positive thrust required.');end
rhs=[2*r.Nb*(mean(Q)-r.Ib*r.Omega^2*bp-r.Sblade*P.env.g);P.bodyMass*P.env.g-sum(Ta)];
acc=M.commonCholesky\(M.commonCholesky.'\rhs);bd=acc(1);wd=acc(2);
vpDot=(sum(Ta)-2*rhoA*sum(v.*(v-w+(2/3)*r.R*rp)))/(2*M.airMass);
dx=[vpDot;rp;bd;wd];hub=Ta-r.Nb*r.Sblade*bd;y=[-wd;hub(2)-hub(1)];
if any(~isfinite([dx;y]))||~isreal([dx;y]),error('d05:InvalidEvaluation','Nonfinite reduced dynamics.');end
if nargout>1
 out=struct('reconstructedState',[v;beta;rp;rp;w],'aeroThrust',Ta,'hubThrust',hub, ...
  'viDifference',vDifference,'coningDifference',bDifference,'wd',wd, ...
  'bodyResidual',P.bodyMass*(wd-P.env.g)+sum(hub), ...
  'claim','NONLINEAR_STATIC_RESIDUALIZATION_NOT_UNCONDITIONAL_DYNAMIC_EQUIVALENCE');
end
end
