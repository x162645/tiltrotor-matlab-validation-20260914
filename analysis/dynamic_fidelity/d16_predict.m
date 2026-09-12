function out=d16_predict(p,theta0_deg,amp_deg,duration,k,method,dt,rtol)
% Same known rectangular collective program, fixed hub, equilibrium start.
% Segmented propagation includes every command breakpoint, not query origins.
if nargin<7,dt=.002;end
if nargin<8,rtol=1e-8;end
assert(isfinite(k)&&k>0&&isfinite(duration)&&duration>0&&dt>0);
theta0=theta0_deg*pi/180;amp=amp_deg*pi/180;on=.2;off=on+duration;finish=duration+1;
assert(theta0>=p.theta(1)&&theta0<=p.theta(end)&&theta0+amp>=p.theta(1)&&theta0+amp<=p.theta(end));
S0=ppval(p.pp,theta0);ls0=sqrt(S0/2);t=(0:dt:finish)';
t=unique([t;on;off;finish]);theta=theta0+amp*(t>=on&t<off);S=ppval(p.pp,theta);
b0=interp1(p.bt,p.bv,theta0);a0=ppval(p.dp,theta0)*(1+b0/(4*ls0));
lambda=zeros(size(t));CT=zeros(size(t));state=ls0;bounds=[0 on off finish];
for j=1:3
 low=bounds(j);high=bounds(j+1);th=theta0+amp*(j==2);sj=ppval(p.pp,th);ls=sqrt(sj/2);
 ids=find(t>=low&t<=high);tt=t(ids);elapsed=tt-low;
 switch method
  case {'DIRECT','LUT'}
   opts=odeset('RelTol',rtol,'AbsTol',rtol*1e-3,'MaxStep',.02);
   [~,ll]=ode45(@(~,l)rhs(l,th,sj,ls),tt,state,opts);lambda(ids)=ll;state=ll(end);
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
for i=1:numel(t)
 e=lambda(i)-sqrt(S(i)/2);assert(abs(e)<=.01,'Departure outside +/-0.01');
 switch method
  case 'DIRECT',CT(i)=S(i)+d16_source(theta(i),lambda(i),p)-d16_source(theta(i),sqrt(S(i)/2),p);
  case 'LUT',CT(i)=S(i)+p.table(theta(i),e);
  case 'LTI_EXACT',CT(i)=S0+a0*(theta(i)-theta0)-b0*(lambda(i)-ls0);
  case 'SCHEDULED_EXACT',CT(i)=S(i)-interp1(p.bt,p.bv,theta(i))*e;
  case 'QS',CT(i)=S(i);
 end
end
assert(all(isfinite(CT))&&all(CT>0)&&all(isfinite(lambda))&&all(lambda>0));
out=struct('t',t,'theta_rad',theta,'lambda',lambda,'CT',CT,'S',S,'non_eq_CT',CT-S,'delta_CT',CT-S0);
 function dx=rhs(l,th,sj,ls)
  e=l-ls;assert(isfinite(e)&&abs(e)<=.01&&l>0,'ODE outside contract');
  if strcmp(method,'DIRECT'),ct=sj+d16_source(th,l,p)-d16_source(th,ls,p);
  else,ct=sj+p.table(th,e);end
  assert(isfinite(ct)&&ct>0,'Nonphysical load');dx=p.Omega/k*(ct-2*l*l);
 end
end
