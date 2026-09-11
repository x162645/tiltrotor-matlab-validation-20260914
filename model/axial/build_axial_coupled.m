function M=build_axial_coupled(P,law,mode,fixture)
%BUILD_AXIAL_COUPLED D04 axial rotor-coning/heave benchmark, NOT a V7 replacement.
% Sources: NACA TN3044 (1953) printed6-13/PDF7-14 Eqs2-5,11-20;
% NASA TM88327 (1986) printed8-10,25/PDF11-13,28 Table1 and Eq9.
% Rigid centrally hinged blades, constant Omega, small coning, uniform axial
% inflow, linear section lift, no drag/hinge offset/pitch-flap coupling.
% Preserve independent rotor disks: nRotors is NOT blade count or disk area.
% beta>0 cone upward; w>0 hub translation downward; input actual pitch [rad].
% Normal force uses UP=vi-w+r*betaDot. The positive rate term provides damping.
% Model-specific assumptions are NOT silently applied to production BEMT.
if ~isstruct(P)||~isscalar(P)||~all(isfield(P,{'env','rotor','nRotors','bodyMass','initialThrustPerRotor','identity'}))
 error('axial:InvalidParameters','Explicit scalar parameter contract required.');end
if ~ischar(law)||~any(strcmp(law,{'pp_mean','cf_mean'}))|| ...
 ~ischar(mode)||~any(strcmp(mode,{'coupled','no_pumping','algebraic_coning','quasisteady'}))|| ...
 ~ischar(fixture)||~any(strcmp(fixture,{'fixed','free'}))
 error('axial:InvalidModel','Unknown law, model reduction or fixture.');end
r=P.rotor;fields={'R','Nb','Omega','chord','rootCut','twistTip','liftSlope','Ib','Sblade'};
if ~all(isfield(r,fields)),error('axial:MissingRotorField','Rotor contract incomplete.');end
v=[P.env.rho,P.env.g,P.nRotors,P.bodyMass,P.initialThrustPerRotor];
for j=1:numel(fields),q=r.(fields{j});if ~isnumeric(q)||~isscalar(q)||~isreal(q)||~isfinite(q),error('axial:InvalidParameters','Finite scalar rotor values required.');end;end
if ~isnumeric(v)||~isreal(v)||any(~isfinite(v))||any(v<=0)||P.nRotors~=round(P.nRotors)|| ...
 r.Nb~=round(r.Nb)||r.Nb<1||r.R<=0||r.Omega<=0||r.chord<=0||r.liftSlope<=0||r.Ib<=0||r.Sblade<0||r.rootCut<0||r.rootCut>=1
 error('axial:InvalidParameters','Positive scales and valid blade/disk counts required.');end
R=r.R;r0=r.rootCut*R;c=r.chord;J=zeros(4,1);
for k=1:4,J(k)=c*(R^(k+1)-r0^(k+1))/(k+1);end
% Exact radial integrals for inherited constant chord and linear twist.
Jtw2=r.twistTip/(R-r0)*(J(3)-r0*J(2));Jtw3=r.twistTip/(R-r0)*(J(4)-r0*J(3));
K=.5*P.env.rho*r.liftSlope;N=r.Nb;O=r.Omega;
M.coefficients=struct('Ttheta',N*K*O^2*J(2),'Tv',-N*K*O*J(1), ...
 'Trate',-N*K*O*J(2),'Ttwist',N*K*O^2*Jtw2, ...
 'Qtheta',K*O^2*J(3),'Qv',-K*O*J(2),'Qrate',-K*O*J(3),'Qtwist',K*O^2*Jtw3);
M.P=P;M.law=law;M.mode=mode;M.fixture=fixture;M.nRotors=P.nRotors;M.radialIntegrals=J;
n=P.nRotors;M.vi=[];M.beta=[];M.rate=[];M.w=[];
if any(strcmp(mode,{'coupled','no_pumping'})),M.vi=1:n;M.beta=n+(1:n);M.rate=2*n+(1:n);M.n=3*n;
elseif strcmp(mode,'algebraic_coning'),M.vi=1:n;M.n=n;else,M.n=0;end
if strcmp(fixture,'free'),M.w=M.n+1;M.n=M.n+1;end
% Symmetric dimensional mass matrix: total locked aircraft mass includes blades.
% No added-air mass goes into this mechanical matrix. Positive definiteness
% is a physical admissibility condition, not regularized to get an answer.
if strcmp(fixture,'free')
 E=[N*r.Ib*eye(n),-N*r.Sblade*ones(n,1);-N*r.Sblade*ones(1,n),P.bodyMass];
 [U,flag]=chol(E);if flag~=0,error('axial:InvalidMechanicalMass','Nonpositive blade/body inertia matrix.');end
 M.massMatrix=E;M.massCholesky=U;
else,M.massMatrix=N*r.Ib*eye(n);M.massCholesky=sqrt(N*r.Ib)*eye(n);end
M.identity=['D04_' P.identity '_' upper(mode) '_' upper(fixture) '_' upper(law)];
M.inputNames=arrayfun(@(k)sprintf('actualCollective%d_rad',k),1:n,'UniformOutput',false);
M.outputNames=[{'wDown','accelerationDown'},arrayfun(@(k)sprintf('aeroThrust%d',k),1:n,'UniformOutput',false), ...
 arrayfun(@(k)sprintf('hubThrust%d',k),1:n,'UniformOutput',false),arrayfun(@(k)sprintf('vi%d',k),1:n,'UniformOutput',false), ...
 arrayfun(@(k)sprintf('beta%d',k),1:n,'UniformOutput',false),arrayfun(@(k)sprintf('betaRate%d',k),1:n,'UniformOutput',false)];
M.outputUnits=[{'m/s','m/s2'},repmat({'N'},1,2*n),repmat({'m/s'},1,n),repmat({'rad'},1,n),repmat({'rad/s'},1,n)];
M.domain='AXIAL_POSITIVE_FLOW_SMALL_CONING_NO_TILT_NO_CYCLIC_NO_WAKE_INTERFERENCE';
M.externalAccuracyPassed=false;M.sourceRole='CLASSICAL_COUPLING_BASELINE_NOT_ORIGINAL_METHOD';
end
