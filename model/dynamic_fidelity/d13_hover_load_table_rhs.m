function [dx,y,detail]=d13_hover_load_table_rhs(x,theta75_report_index_rad,P)
%D13_HOVER_LOAD_TABLE_RHS [vi; upward velocity] m/s, report-index theta rad.
% y=[upward velocity; upward acceleration; total aerodynamic thrust].
% Thrust is a hub-force proxy: no flap inertia/wing download/body attitude.
% Frozen near-hover air-mass laws do not imply full tilted or climbing PP.
validateattributes(x,{'double'},{'real','finite','size',[2 1]});
validateattributes(theta75_report_index_rad,{'double'},{'real','finite','scalar'});
theta=theta75_report_index_rad;
if theta<P.thetaDomain(1)||theta>P.thetaDomain(2)
 error('D13:ThetaDomain','Report-index theta outside 6--11 degrees.');
end
if x(1)<=0,error('D13:FlowDomain','Positive induced velocity required.');end
S=ppval(P.S,theta);e=(x(1)+x(2))/P.Vtip-sqrt(S/2);
if ~isfinite(e)||e<P.eDomain(1)||e>P.eDomain(2)
 error('D13:FlowDomain','Inflow departure outside the declared +/-0.01 domain.');
end
CT=S+P.increment(theta,e);
if ~isfinite(CT)||CT<=0,error('D13:LoadDomain','Nonpositive or invalid thrust.');end
vDot=2*P.scale/P.mass*CT-P.g;
viDot=P.Vtip*P.Omega/P.k*(CT-2*x(1)*(x(1)+x(2))/P.Vtip^2);
dx=[viDot;vDot];y=[x(2);vDot;2*P.scale*CT];
if nargout>2,detail=struct('CT',CT,'staticCT',S,'inflowDeparture',e,'sourceRole',P.role);end
end
