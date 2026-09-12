function [dx,detail] = pitt_peters_dynamic_inflow(x,loads,kinematics,options)
%PITT_PETERS_DYNAMIC_INFLOW Canonical three-state Pitt--Peters inflow RHS.
%
%   [DX,DETAIL] = PITT_PETERS_DYNAMIC_INFLOW(X,LOADS,KINEMATICS,OPTIONS)
%   evaluates the finite-state dynamic-inflow model in the rotor-disk frame.
%   X is [lambda0; lambdaC; lambdaS], the induced-flow coefficients in
%   lambda(rbar,psi)=lambda0+rbar*lambdaC*cos(psi)+rbar*lambdaS*sin(psi).
%   LOADS is [CT; CMx; CMy], normalized by rho*A*(Omega*R)^2 and
%   rho*A*(Omega*R)^2*R for the moments.  The forcing convention is
%   [CT; -CMy; CMx], matching the Pitt--Peters disk axes used here.
%
%   KINEMATICS.mu is the nonnegative in-plane free-stream ratio and KINEMATICS.mu_z is\r?\n%   the signed free-stream axial ratio (positive into the disk).  KINEMATICS.Omega
%   is rotor speed in rad/s.  The implementation is intentionally restricted
%   to the positive-throughflow branch; vortex-ring, windmill and reverse-flow
%   continuations are rejected rather than silently clipped.
%
%   OPTIONS.m0 selects the uniform-mode apparent-mass convention.  The
%   default 128/(75*pi) is the twisted-rotor Pitt--Peters value.  OPTIONS.m1
%   defaults to 64/(45*pi), the first-harmonic convention used by the cited
%   finite-state formulation.  OPTIONS.rcondMin controls the conditioning
%   gate for the influence matrix and defaults to 1e-10.
%
%   Source basis: Pitt & Peters, Theoretical Prediction of Dynamic-Inflow
%   Derivatives, Vertica 5(1), 1981, and the matrix transcription in
%   NASA TM-88327 (1986), pp. 20--22 (PDF pp. 20--22), Eqs. (119)--(135).
%   This function is a generic method baseline; it contains no XV-15 tuning
%   and has not been externally validated by this repository.

if nargin < 4 || isempty(options), options = struct(); end
if ~isstruct(kinematics) || ~isstruct(options)
    error('pitt_peters:InvalidInput','KINEMATICS and OPTIONS must be structs.');
end
validateattributes(x,{'double'},{'real','finite','vector','numel',3});
validateattributes(loads,{'double'},{'real','finite','vector','numel',3});
x = x(:); loads = loads(:);
required = {'mu','mu_z','Omega'};
for k = 1:numel(required)
    key = required{k};
    if ~isfield(kinematics,key)
        error('pitt_peters:MissingKinematics','Missing kinematics.%s.',key);
    end
    value = kinematics.(key);
    if strcmp(key,'mu')
        validateattributes(value,{'double'},{'real','finite','scalar','nonnegative'});
    else
        validateattributes(value,{'double'},{'real','finite','scalar'});
    end
end
mu = kinematics.mu;
mu_z = kinematics.mu_z;
Omega = kinematics.Omega;
% Omega must be strictly positive even though validateattributes permits zero.
if Omega <= 0
    error('pitt_peters:InvalidKinematics','kinematics.Omega must be positive.');
end
m0 = option_or(options,'m0',128/(75*pi));
m1 = option_or(options,'m1',64/(45*pi));
rcondMin = option_or(options,'rcondMin',1e-10);
validateattributes(m0,{'double'},{'real','finite','scalar','positive'});
validateattributes(m1,{'double'},{'real','finite','scalar','positive'});
validateattributes(rcondMin,{'double'},{'real','finite','scalar','positive'});

lambdaInduced = x(1);
lambdaTotal = mu_z + lambdaInduced;
% This is the same positive-throughflow scope as the repository's source
% mean-inflow baseline.  No absolute-value or momentum continuation is used.
if lambdaInduced <= 0 || lambdaTotal <= 0
    error('pitt_peters:OutsidePositiveThroughflow', ...
        'Positive induced and total throughflow are required.');
end
VT = hypot(mu,lambdaTotal);
Veff = (mu^2 + lambdaTotal*(lambdaTotal + lambdaInduced))/VT;
if ~isfinite(Veff) || Veff <= 0
    error('pitt_peters:OutsidePositiveThroughflow', ...
        'Pitt--Peters effective flow is nonpositive.');
end
cosChi = lambdaTotal/VT;
% Ratio form is numerically safer than acos near hover.  It is only a
% round-off guard; no physical branch is clipped.
cosChi = min(1,max(-1,cosChi));
ratio = (1-cosChi)/(1+cosChi);
if ratio < 0 || ~isfinite(ratio)
    error('pitt_peters:InvalidWakeSkew','Invalid wake-skew ratio.');
end
X = sqrt(ratio);
% Influence matrix in the disk axes.  K maps induced-flow states to load
% coefficients; equation is M/Omega*lambdaDot + K*lambda = forcing.
K0 = [0.5, 0, -15*pi/64*X; ...
      0, 2*(1+X^2), 0; ...
      15*pi/64*X, 0, 2*(1-X^2)];
if rcond(K0) < rcondMin
    error('pitt_peters:IllConditionedInfluence', ...
        'Influence matrix is ill-conditioned at this wake-skew state.');
end
Vdiag = diag([VT,Veff,Veff]);
K = Vdiag / K0;
M = diag([m0,m1,m1]);
forcing = [loads(1); -loads(3); loads(2)];
dx = Omega*(M \ (forcing - K*x));
if any(~isfinite(dx))
    error('pitt_peters:NonfiniteDerivative','Nonfinite inflow derivative.');
end
if nargout > 1
    detail = struct();
    detail.modelIdentity = 'PITT_PETERS_3STATE_GENERIC_POSITIVE_THROUGHFLOW';
    detail.stateNames = {'lambda0','lambdaC','lambdaS'};
    detail.stateDefinition = 'lambda=lambda0+rbar*lambdaC*cos(psi)+rbar*lambdaS*sin(psi)';
    detail.loadingDefinition = '[CT;CMx;CMy] -> [CT;-CMy;CMx]';
    detail.massMatrix = M;
    detail.influenceMatrixK0 = K0;
    detail.influenceMatrixK = K;
    detail.forcing = forcing;
    detail.mu = mu;
    detail.mu_z = mu_z;
    detail.lambdaInduced = lambdaInduced;
    detail.lambdaTotal = lambdaTotal;
    detail.VT = VT;
    detail.Veff = Veff;
    detail.cosChi = cosChi;
    detail.wakeSkewRad = atan2(mu,lambdaTotal);
    detail.X = X;
    detail.m0 = m0;
    detail.m1 = m1;
    detail.Omega = Omega;
    detail.source = 'PittPeters1981_NASA_TM88327_EQ119_135';
    detail.externalValidated = false;
    detail.scope = 'GENERIC_METHOD_BASELINE_POSITIVE_THROUGHFLOW';
end
end

function value = option_or(s,key,defaultValue)
if isfield(s,key) && ~isempty(s.(key))
    value = s.(key);
else
    value = defaultValue;
end
end


