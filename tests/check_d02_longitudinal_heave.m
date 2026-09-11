function summary=check_d02_longitudinal_heave()
%CHECK_D02_LONGITUDINAL_HEAVE Fast interface smoke test; full trajectory
% qualification lives in tests/dynamic_fidelity/run_d02_consistency_suite.m.
startup;
P=params_nominal();wp=d02_prepare_workpoint(struct('V',0,'betaMDeg',0),P);
z=wp.dynamicState;u=wp.command;[~,o,y]=d02_rhs(z,u,0,P,'dynamic');
checks=struct('name',{},'pass',{},'detail',{});
checks(end+1)=c('dynamic workpoint accepted',wp.report.pass,'separate rigid/inflow/actuator checks');
checks(end+1)=c('actual inflow correctly labelled',isequal(o.actualInducedVelocity,z(10:11)),'actual state is not target');
zp=z;zp(10:11)=zp(10:11)+.1;[~,p,yp]=d02_rhs(zp,u,0,P,'dynamic');
checks(end+1)=c('inflow state actually changes rotor loads',abs(sum(yp(7:8))-sum(y(7:8)))>1e-3,'fixed body state');
checks(end+1)=c('valid transient is not steady closure',p.evaluationValid&&~p.steadyEquilibriumSatisfied,'distinct semantics');
za=z;za(12)=za(12)+.1*pi/180;[~,~,ya]=d02_rhs(za,u,0,P,'dynamic');
checks(end+1)=c('collective excites thrust',sum(ya(7:8))>sum(y(7:8)),'actual collective perturbation');
za=z;za(13)=za(13)+.1*pi/180;[~,~,ya]=d02_rhs(za,u,0,P,'dynamic');
checks(end+1)=c('cyclic excites pitch moment',abs(ya(13)-y(13))>1e-3,'actual cyclic perturbation');
summary=struct('name','D02.1 interface smoke checks','passed',all([checks.pass]),'checks',checks);
if ~summary.passed,error('check_d02_longitudinal_heave:Failed','Smoke test failed.');end
end
function o=c(n,p,d),o=struct('name',n,'pass',logical(p),'detail',d);end
