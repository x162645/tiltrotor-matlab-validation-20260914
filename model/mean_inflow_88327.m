function [viDot,meta]=mean_inflow_88327(vi,thrust,axialVelocity,coningRate,P,identity)
%MEAN_INFLOW_88327 Source-based axial mean inflow, NOT full Pitt-Peters.
% Chen & Hindson, NASA TM88327 (June1986), printed6-7 / PDF9-10,
% Eqs1,2,4,5. Source v>0 downward, w>0 aircraft downward.
% Here vi=source v, axialVelocity=-source w along rotor thrust axis,
% coningRate=source betaDot>0 cone upward [rad/s]. All inputs are SI.
% CT=T/(rho*pi*R^2*(Omega*R)^2), WITHOUT the production CT factor0.5.
% CT = mbar/Omega*d(vi/(Omega*R))/dt
%      +2*(vi+axialVelocity+(2/3)*R*coningRate)*vi/(Omega*R)^2.
% Dimensional equation: mbar*rho*A*R*viDot = T - 2*rho*A*U*vi.
% Rotation speed cancels only for constant Omega. No fitted time constant.
% pp_mean: mbar=128/(75*pi), exact Eq4; cf_mean: .849, rounded Eq2.
% Mean-only / normal axial flow. No vortex ring, windmill or reverse flow.
% A caller setting coningRate=0 explicitly omits unsteady coning pumping.
values={vi,thrust,axialVelocity,coningRate,P.env.rho,P.rotor.R,P.rotor.Omega};
for k=1:numel(values)
 a=values{k};if ~isnumeric(a)||~isscalar(a)||~isreal(a)||~isfinite(a)
  error('mean_inflow_88327:InvalidInput','Finite real scalar inputs required.');end
end
if vi<0||thrust<=0||P.env.rho<=0||P.rotor.R<=0||P.rotor.Omega<=0
 error('mean_inflow_88327:OutsidePositiveBranch','Positive thrust/rho/R/Omega and nonnegative vi required.');end
if strcmp(identity,'pp_mean'),mbar=128/(75*pi);eq='4,5';
elseif strcmp(identity,'cf_mean'),mbar=.849;eq='1,2';
else,error('mean_inflow_88327:UnknownModel','Expected pp_mean or cf_mean.');end
R=P.rotor.R;rho=P.env.rho;A=pi*R^2;
through=vi+axialVelocity+(2/3)*R*coningRate;
if through<0,error('mean_inflow_88327:ReverseThroughflow','Normal flow only, no abs/clipping continuation.');end
mass=mbar*rho*A*R;momentum=2*rho*A*through*vi;
viDot=(thrust-momentum)/mass;
if nargout<2,return;end
meta=struct('identity',identity,'source','NASA_TM88327_1986_PDF9_10','equations',eq, ...
 'mbar',mbar,'apparentAirMass_kg',mass,'momentumThrust_N',momentum, ...
 'throughSpeed_mps',through,'coningRate_rad_s',coningRate,'constantRotorSpeed',true, ...
 'sourceCoefficientConvention','T_OVER_RHO_A_OMEGAR_SQUARED','fittedTimeConstant',false, ...
 'scope','MEAN_AXIAL_SOURCE_REDUCTION_NOT_FULL_THREE_STATE_PP','externalValidated',false);
end
