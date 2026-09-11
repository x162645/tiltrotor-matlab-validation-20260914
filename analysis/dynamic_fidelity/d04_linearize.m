function L=d04_linearize(M,W,h)
%D04_LINEARIZE Same nonlinear RHS/output, physical input radians.
if nargin<3,h=1e-5;end
[f,~,y]=axial_coupled_rhs(W.z,W.u,M);n=M.n;nu=M.nRotors;ny=numel(y);
A=zeros(n);B=zeros(n,nu);C=zeros(ny,n);D=zeros(ny,nu);
for j=1:n
 d=h*max(1,abs(W.z(j)));p=W.z;m=W.z;p(j)=p(j)+d;m(j)=m(j)-d;
 [fp,~,yp]=axial_coupled_rhs(p,W.u,M);[fm,~,ym]=axial_coupled_rhs(m,W.u,M);
 A(:,j)=(fp-fm)/(2*d);C(:,j)=(yp-ym)/(2*d);
end
for j=1:nu
 p=W.u;m=W.u;p(j)=p(j)+h;m(j)=m(j)-h;
 [fp,~,yp]=axial_coupled_rhs(W.z,p,M);[fm,~,ym]=axial_coupled_rhs(W.z,m,M);
 B(:,j)=(fp-fm)/(2*h);D(:,j)=(yp-ym)/(2*h);
end
L=struct('A',A,'B',B,'C',C,'D',D,'f0',f,'y0',y,'h',h,'modelIdentity',M.identity);
end
