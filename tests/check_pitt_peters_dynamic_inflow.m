function report = check_pitt_peters_dynamic_inflow()
%CHECK_PITT_PETERS_DYNAMIC_INFLOW Verify canonical three-state baseline.
% These are equation and numerical-contract checks, not external validation.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'model','inflow'));
cases = struct('name',{},'passed',{},'value',{},'message',{});
Omega = 30;
kin = struct('mu',0,'mu_z',0,'Omega',Omega);
CT0 = 0.08;
x0 = [sqrt(CT0/2);0;0];
[dx0,d0] = pitt_peters_dynamic_inflow(x0,[CT0;0;0],kin);
add_case('hover steady momentum identity',norm(dx0,inf)<1e-12 && ...
    abs(d0.influenceMatrixK(1,1)*x0(1)-CT0)<1e-12 && ...
    abs(d0.Veff-2*x0(1))<1e-12, norm(dx0,inf));
add_case('three-state distribution contract',strcmp(d0.modelIdentity, ...
    'PITT_PETERS_3STATE_GENERIC_POSITIVE_THROUGHFLOW') && ...
    isequal(d0.stateNames,{'lambda0','lambdaC','lambdaS'}),0);
% A thrust step must build the wake state continuously instead of jumping
% to the quasi-steady value.  The target is the hover momentum root.
CT1 = 0.12; t = (0:.002:1).';
[~,xx] = ode45(@(~,x)pitt_peters_dynamic_inflow(x,[CT1;0;0],kin),t,x0, ...
    odeset('RelTol',1e-10,'AbsTol',1e-12,'MaxStep',.01));
target = sqrt(CT1/2);
monotonic = all(diff(xx(:,1)) >= -1e-11);
lagged = abs(xx(1,1)-x0(1)) < 1e-14 && xx(2,1) < target-1e-4;
settled = abs(xx(end,1)-target) < 2e-5 && norm(xx(end,2:3),inf)<1e-10;
add_case('step response has finite wake memory',monotonic && lagged && settled, ...
    max(abs(xx(end,1)-target),norm(xx(end,2:3),inf)));
% Cross-flow case exercises skew coupling and moment channels.
kinF = struct('mu',.25,'mu_z',.04,'Omega',Omega);
xF = [0.11;0;0];
[dxF,dF] = pitt_peters_dynamic_inflow(xF,[.03;.002;-.001],kinF);
add_case('forward-flow skew and moment channels finite', ...
    all(isfinite(dxF)) && dF.cosChi>=0 && dF.cosChi<1 && ...
    abs(dxF(2))+abs(dxF(3))>0, norm(dxF,inf));
% Unsupported continuation must fail closed rather than silently taking abs().
try
    pitt_peters_dynamic_inflow([.1;0;0],[.03;0;0], ...
        struct('mu',.1,'mu_z',-.2,'Omega',Omega));
    rejected = false;
catch ME
    rejected = strcmp(ME.identifier,'pitt_peters:OutsidePositiveThroughflow');
end
add_case('reverse-throughflow continuation rejected',rejected,0);
report.cases = cases;
report.allPassed = all([cases.passed]);
fprintf('\nPitt--Peters three-state baseline checks\n');
for k = 1:numel(cases)
    fprintf('%-48s : %s\n',cases(k).name,ternary(cases(k).passed,'PASS','FAIL'));
    if ~cases(k).passed && ~isempty(cases(k).message),fprintf('  %s\n',cases(k).message);end
end
fprintf('All Pitt--Peters checks passed: %d\n',report.allPassed);
assert(report.allPassed,'Pitt--Peters baseline checks failed.');
    function add_case(name,passed,value)
        cases(end+1,1) = struct('name',name,'passed',logical(passed), ...
            'value',value,'message',ternary(logical(passed),'','equation or numerical contract failed'));
    end
end
function y = ternary(c,a,b)
if c,y=a;else,y=b;end
end

