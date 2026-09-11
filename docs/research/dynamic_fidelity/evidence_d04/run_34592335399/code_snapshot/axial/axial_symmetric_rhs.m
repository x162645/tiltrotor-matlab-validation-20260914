function [dz,out,y]=axial_symmetric_rhs(z,commonCollective,S)
%AXIAL_SYMMETRIC_RHS Exact common-motion equations with explicit scalar input.
% Does not run the 7-state parent to manufacture a fast-model timing result.
if ~isnumeric(commonCollective)||~isscalar(commonCollective)||~isreal(commonCollective)||~isfinite(commonCollective)
 error('axialSymmetric:NoncommonInput','One finite scalar common actual pitch is required.');end
[dz,one]=axial_coupled_rhs(z,commonCollective,S.small);
if nargout<2,return;end
n=S.full.nRotors;out=one;
for f={'aeroThrust','hubThrust','vi','beta','betaRate','betaAcceleration'}
 out.(f{1})=repmat(one.(f{1}),n,1);
end
out.identity=S.identity;out.totalHubThrust=n*one.hubThrust;
out.bodyForceResidual=S.full.P.bodyMass*(one.accelerationDown-S.full.P.env.g)+out.totalHubThrust;
out.reductionRestriction=S.restriction;
y=[one.wDown;one.accelerationDown;out.aeroThrust;out.hubThrust;out.vi;out.beta;out.betaRate];
end
