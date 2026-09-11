function lin=d02_linearize(wp,mode,stepFactor)
%D02_LINEARIZE A/B/C/D of the SAME RHS and observation equations.
if nargin<3,stepFactor=1;end
if ~isnumeric(stepFactor)||~isscalar(stepFactor)||~isreal(stepFactor)||~isfinite(stepFactor)||stepFactor<=0
 error('d02:InvalidStep','Positive finite scale required.');end
m=d02_layout(mode);if ~isempty(m.vi),z=wp.dynamicState;else,z=wp.quasisteadyState;end
u=wp.command;P=wp.P;beta=wp.trim.betaM;t=tic;
hx=m.stateStep*stepFactor;hu=m.inputStep*stepFactor;
[f0,~,y0]=d02_rhs(z,u,beta,P,mode);ny=numel(y0);A=zeros(m.n);B=zeros(m.n,3);C=zeros(ny,m.n);D=zeros(ny,3);
Af=A;Ab=A;
for j=1:m.n
 zp=z;zm=z;zp(j)=zp(j)+hx(j);zm(j)=zm(j)-hx(j);
 [fp,~,yp]=d02_rhs(zp,u,beta,P,mode);[fm,~,ym]=d02_rhs(zm,u,beta,P,mode);
 A(:,j)=(fp-fm)/(2*hx(j));C(:,j)=(yp-ym)/(2*hx(j));Af(:,j)=(fp-f0)/hx(j);Ab(:,j)=(f0-fm)/hx(j);
end
for j=1:3
 up=u;um=u;up(j)=up(j)+hu(j);um(j)=um(j)-hu(j);
 [fp,~,yp]=d02_rhs(z,up,beta,P,mode);[fm,~,ym]=d02_rhs(z,um,beta,P,mode);
 B(:,j)=(fp-fm)/(2*hu(j));D(:,j)=(yp-ym)/(2*hu(j));
end
if any(~isfinite([A(:);B(:);C(:);D(:)])),error('d02:InvalidJacobian','Nonfinite derivative.');end
lin=struct('A',A,'B',B,'C',C,'D',D,'f0',f0,'y0',y0,'z0',z,'u0',u,'layout',m, ...
 'stateStep',hx,'inputStep',hu,'forwardA',Af,'backwardA',Ab,'elapsed_s',toc(t), ...
 'rhsCalls',1+2*m.n+6,'externalValidationPassed',false);
end
