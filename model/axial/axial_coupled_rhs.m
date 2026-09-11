function [dz,out,y]=axial_coupled_rhs(z,collective,M)
%AXIAL_COUPLED_RHS Coupled blade/air/body mechanics; all quantities are SI.
% betaDD and wDot solved together, NOT sequentially with inertia omitted.
% NACA TN3044 Eqs15-20; TM88327 Table1 is checked independently in tests.
% T_hub=T_aero-Nb*Sblade*betaDD; the latter is force transmitted to the
% locked-mass hub/body reference, not an extra external force on whole COM.
z=z(:);collective=collective(:);P=M.P;r=P.rotor;n=M.nRotors;c=M.coefficients;
if ~isnumeric(z)||~isnumeric(collective)||numel(z)~=M.n||numel(collective)~=n|| ...
 ~isreal([z;collective])||any(~isfinite([z;collective]))
 error('axial:InvalidState','Finite matching state and actual blade pitch vectors required.');end
if any(abs(collective)>.6),error('axial:OutsideSmallAngleStudy','Pitch exceeds declared 0.6rad study guard.');end
if isempty(M.w),w=0;else,w=z(M.w);end
if isempty(M.vi)
 % Positive normal-flow root of exactly the SAME steady blade/momentum model.
 a=2*P.env.rho*pi*r.R^2;b=-a*w-c.Tv;d=c.Tv*w-c.Ttheta*collective-c.Ttwist;
 disc=b^2-4*a*d;if any(disc<0),error('axial:NoNormalRoot','No real steady momentum root.');end
 if b>=0,vi=-2*d./(b+sqrt(disc));else,vi=(-b+sqrt(disc))/(2*a);end
else,vi=z(M.vi);end
if any(~isfinite(vi))||any(vi<=0)||any(vi-w<=0),error('axial:OutsideNormalFlow','Normal positive axial branch only.');end
if isempty(M.beta),bd=zeros(n,1);b0=zeros(n,1);else,b0=z(M.beta);bd=z(M.rate);end
T=c.Ttheta*collective+c.Ttwist+c.Tv*(vi-w)+c.Trate*bd;
Q=c.Qtheta*collective+c.Qtwist+c.Qv*(vi-w)+c.Qrate*bd;
if any(T<=0),error('axial:NonpositiveThrust','No hidden positive-thrust clamp.');end
if isempty(M.beta)
 if isempty(M.w),wd=0;else,wd=(P.bodyMass*P.env.g-sum(T))/P.bodyMass;end
 bdd=zeros(n,1);b0=(Q-r.Sblade*P.env.g+r.Sblade*wd)/(r.Ib*r.Omega^2);
else
 rhs=r.Nb*(Q-r.Ib*r.Omega^2*b0-r.Sblade*P.env.g);
 if ~isempty(M.w),rhs=[rhs;P.bodyMass*P.env.g-sum(T)];end
 acc=M.massCholesky\(M.massCholesky.'\rhs);bdd=acc(1:n);
 if isempty(M.w),wd=0;else,wd=acc(end);end
end
if any(abs(b0)>.3),error('axial:OutsideSmallAngleStudy','Coning exceeds declared 0.3rad study guard.');end
vDot=zeros(n,1);meta=cell(n,1);
for j=1:n
 pump=bd(j);if strcmp(M.mode,'no_pumping'),pump=0;end
 if ~isempty(M.vi),[vDot(j),meta{j}]=mean_inflow_88327(vi(j),T(j),-w,pump,P,M.law);end
end
dz=zeros(M.n,1);dz(M.vi)=vDot(1:numel(M.vi));
if ~isempty(M.beta),dz(M.beta)=bd;dz(M.rate)=bdd;end
if ~isempty(M.w),dz(M.w)=wd;end
hub=T-r.Nb*r.Sblade*bdd;
if ~isreal(dz)||any(~isfinite(dz)),error('axial:NonfiniteDerivative','Invalid derivative.');end
if nargout<2,return;end
out=struct('aeroThrust',T,'hubThrust',hub,'aeroMomentPerBlade',Q,'vi',vi,'beta',b0,'betaRate',bd, ...
 'betaAcceleration',bdd,'accelerationDown',wd,'wDown',w,'inflow', {meta},'mode',M.mode,'identity',M.identity, ...
 'coningPumpingEnabled',~strcmp(M.mode,'no_pumping'),'dynamicConingEnabled',~isempty(M.beta), ...
 'mechanicalResidual',[r.Ib*bdd-r.Sblade*wd-Q+r.Ib*r.Omega^2*b0+r.Sblade*P.env.g], ...
 'bodyForceResidual',P.bodyMass*(wd-P.env.g)+sum(hub),'source','TN3044_EQ15_20_TM88327_TABLE1', ...
 'evaluationValid',true,'externalAccuracyPassed',false);
% For fixed fixture bodyForceResidual is support reaction, not required zero.
y=[w;wd;T;hub;vi;b0;bd];
end
