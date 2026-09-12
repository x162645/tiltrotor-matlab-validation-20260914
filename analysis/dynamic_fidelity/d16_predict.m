function out=d16_predict(p,theta0_deg,amp_deg,duration,k,method,dt,rtol)
% Same known rectangular collective program, fixed hub, equilibrium start.
% Segmented propagation includes every command breakpoint, not query origins.
if nargin<7,dt=.002;end
if nargin<8,rtol=1e-8;end
assert(isreal([k duration dt theta0_deg amp_deg])&&all(isfinite([k duration dt theta0_deg amp_deg]))&&k>0&&duration>0&&dt>0);
theta0=theta0_deg*pi/180;amp=amp_deg*pi/180;on=.2;off=on+duration;finish=duration+1;
assert(theta0>=p.theta(1)&&theta0<=p.theta(end)&&theta0+amp>=p.theta(1)&&theta0+amp<=p.theta(end));
S0=ppval(p.pp,theta0);ls0=sqrt(S0/2);t=(0:dt:finish)';
% Snap floating-point-near grid points to the exact command knots, once.
for knot=[on off finish]
 [distance,ix]=min(abs(t-knot));if distance<1e-12,t(ix)=knot;else,t=[t;knot];end %#ok<AGROW>
end
t=sort(t);assert(all(diff(t)>1e-12));theta=theta0+amp*(t>=on&t<off);S=ppval(p.pp,theta);
b0=interp1(p.bt,p.bv,theta0);a0=ppval(p.dp,theta0)*(1+b0/(4*ls0));
lambda=zeros(size(t));CT=zeros(size(t));state=ls0;bounds=[0 on off finish];
for j=1:3
 low=bounds(j);high=bounds(j+1);th=theta0+amp*(j==2);sj=ppval(p.pp,th);ls=sqrt(sj/2);
 ids=find(t>=low&t<=high);tt=t(ids);elapsed=tt-low;
 switch method
  case {'DIRECT','LUT'}
   opts=odeset('RelTol',rtol,'AbsTol',rtol*1e-3,'MaxStep',.02);
   if strcmp(method,'DIRECT'),baseline=d16_source(th,ls,p);else,baseline=0;end
   [~,ll]=ode45(@(~,l)rhs(l,th,sj,ls,baseline),tt,state,opts);lambda(ids)=ll;state=ll(end);
  case 'LTI_EXACT'
   decay=p.Omega/k*(b0+4*ls0);target=ls0+a0*(th-theta0)/(b0+4*ls0);
   ll=target+(state-target)*exp(-decay*elapsed);lambda(ids)=ll;state=ll(end);
  case 'SCHEDULED_EXACT'
   % Classical aerodynamic tangent + exact scalar momentum (Riccati) flow.
   b=interp1(p.bt,p.bv,th);decay=p.Omega/k*(b+4*ls);e0=state-ls;
   z=exp(-decay*elapsed);den=1+2*e0/(b+4*ls)*(1-z);
   assert(all(den>0),'Outside physical Riccati branch');
   ll=ls+e0*z./den;lambda(ids)=ll;state=ll(end);
  case 'QS'
   lambda(ids)=ls;state=ls;
  otherwise,error('d16:Method','Unsupported prediction method');
 end
end
e=lambda-sqrt(S/2);assert(all(abs(e)<=.01),'Departure outside +/-0.01');
switch method
 case 'DIRECT'
  % Vectorized source output in bounded batches; one baseline per command.
  [uniqueTheta,~,whichTheta]=unique(theta);base=d16_source(uniqueTheta,sqrt(ppval(p.pp,uniqueTheta)/2),p);
  for first=1:128:numel(t)
   ix=first:min(first+127,numel(t));CT(ix)=S(ix)+d16_source(theta(ix),lambda(ix),p)-base(whichTheta(ix));
  end
 case 'LUT',CT=S+p.table(theta,e);
 case 'LTI_EXACT',CT=S0+a0*(theta-theta0)-b0*(lambda-ls0);
 case 'SCHEDULED_EXACT',CT=S-interp1(p.bt,p.bv,theta).*e;
 case 'QS',CT=S;
end
assert(all(isfinite(CT))&&all(CT>0)&&all(isfinite(lambda))&&all(lambda>0));
out=struct('t',t,'theta_rad',theta,'lambda',lambda,'CT',CT,'S',S,'non_eq_CT',CT-S,'delta_CT',CT-S0);
 function dx=rhs(l,th,sj,ls,baseline)
  e=l-ls;assert(isfinite(e)&&abs(e)<=.01&&l>0,'ODE outside contract');
  if strcmp(method,'DIRECT'),ct=sj+d16_source(th,l,p)-baseline;
  else,ct=sj+p.table(th,e);end
  assert(isfinite(ct)&&ct>0,'Nonphysical load');dx=p.Omega/k*(ct-2*l*l);
 end
end
