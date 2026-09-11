function W=axial_workpoint(M)
%AXIAL_WORKPOINT Analytical trim of this declared axial benchmark.
% Thrust is force-balance input for trim, NOT a scored prediction of thrust.
P=M.P;r=P.rotor;c=M.coefficients;n=M.nRotors;
T=P.initialThrustPerRotor*ones(n,1);
if strcmp(M.fixture,'free')&&abs(sum(T)-P.bodyMass*P.env.g)>1e-10*P.bodyMass*P.env.g
 error('axial:IncompatibleTrimInput','Initial thrust allocation does not balance weight.');end
v=sqrt(T/(2*P.env.rho*pi*r.R^2));u=(T-c.Ttwist-c.Tv*v)/c.Ttheta;
b=(c.Qtheta*u+c.Qtwist+c.Qv*v-r.Sblade*P.env.g)/(r.Ib*r.Omega^2);
z=zeros(M.n,1);z(M.vi)=v(1:numel(M.vi));if ~isempty(M.beta),z(M.beta)=b;end
[f,o,y]=axial_coupled_rhs(z,u,M);W=struct('z',z,'u',u,'f',f,'y',y,'out',o,'identity',M.identity, ...
 'trimRole','WEIGHT_CONSTRAINT_NOT_EXTERNAL_THRUST_PREDICTION');
end
