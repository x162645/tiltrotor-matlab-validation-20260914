function M=build_axial_nearsymmetric(P,law,epsilonA)
%BUILD_AXIAL_NEARSYMMETRIC D05: D04 mechanics, explicit opposite lift-slope changes.
% Sources: inherited D04 TN3044 Eq2-5/11-20 and TM88327 Eq9/Table1.
% Only sectional liftSlope becomes a*(1+epsilonA), a*(1-epsilonA).
% epsilonA is an ASSUMED numerical contrast, NOT a measured tolerance or fit.
% Geometry, Ib, S, locked mass, Omega and added-air mass remain identical.
% This is an axial two-rotor method benchmark, NOT a full tiltrotor model.
if ~isnumeric(epsilonA)||~isscalar(epsilonA)||~isreal(epsilonA)||~isfinite(epsilonA)||abs(epsilonA)>.3
 error('d05:InvalidAsymmetry','Finite scalar |epsilonA|<=0.3 required.');end
if ~isfield(P,'nRotors')||P.nRotors~=2,error('d05:TwoRotorsRequired','Exactly two identical mechanical rotors required.');end
M=build_axial_coupled(P,law,'coupled','free');M.base=M;
M.epsilonA=epsilonA;M.slopeFactors=[1+epsilonA;1-epsilonA];
fields=fieldnames(M.coefficients);
for j=1:numel(fields),M.coefficients.(fields{j})=M.slopeFactors*M.coefficients.(fields{j});end
r=P.rotor;M.commonMass=[2*r.Nb*r.Ib,-2*r.Nb*r.Sblade;-2*r.Nb*r.Sblade,P.bodyMass];
[M.commonCholesky,flag]=chol(M.commonMass);if flag,error('d05:InvalidMass','Common mechanical mass not positive definite.');end
M.airMass=rho_area(P)*r.R*mass_coefficient(law);
M.T=[.5 .5 0 0 0 0 0;0 0 .5 .5 0 0 0;0 0 0 0 .5 .5 0;0 0 0 0 0 0 1; ...
 .5 -.5 0 0 0 0 0;0 0 .5 -.5 0 0 0;0 0 0 0 .5 -.5 0];
M.Tinv=M.T\eye(7);
v=sqrt(P.initialThrustPerRotor/(2*rho_area(P)));c=M.coefficients;
u=(P.initialThrustPerRotor-c.Ttwist-c.Tv*v)./c.Ttheta;
beta=(c.Qtheta.*u+c.Qtwist+c.Qv*v-r.Sblade*P.env.g)/(r.Ib*r.Omega^2);
M.workpoint=struct('z',[v;v;beta;0;0;0],'u',u);M.workpoint.common=M.T(1:4,:)*M.workpoint.z;
% Physical nondimensionalization held fixed for all epsilonA and input cases.
M.stateScales=[v;v/(r.Omega*r.R);v/r.R;v;v;v/(r.Omega*r.R);v/r.R];
M.gainScales=[2*M.base.coefficients.Ttheta/P.bodyMass;2*M.base.coefficients.Ttheta];
M.outputNames={'accelerationUp','hubForceRightMinusLeft'};
M.outputUnits={'m/s2','N'};M.inputUnits={'rad','rad'};
M.identity=['D05_AXIAL_AERO_ASYMMETRY_' upper(law)];
M.claim='MODEL_TO_MODEL_STATE_RETENTION_NOT_EXPERIMENTAL_VALIDATION';
end
function a=rho_area(P),a=P.env.rho*pi*P.rotor.R^2;end
function m=mass_coefficient(law)
if strcmp(law,'pp_mean'),m=128/(75*pi);elseif strcmp(law,'cf_mean'),m=.849;else,error('d05:InvalidLaw','Unsupported law.');end
end
