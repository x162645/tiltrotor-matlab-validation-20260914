function results = run_betzina2002_alpha0_quickcheck(outputDir)
%RUN_BETZINA2002_ALPHA0_QUICKCHECK Fast first forward-flight external check.
% Uses Betzina (2002) alpha=0 deg, CT/sigma=0.075, sigma=0.089,
% Mtip=0.691, mu=[0.125 0.15 0.17 0.20].
% Solves only theta75 and longitudinal cyclic to match target CT and beta1c=0.
% beta1s is reported, not fitted away, because the current low-order rotor
% exposes only one longitudinal cyclic control in this symmetric interface.

rootDir=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1 || isempty(outputDir), outputDir=fullfile(rootDir,'results','betzina2002_alpha0_quickcheck'); end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
addpath(fullfile(rootDir,'analysis','stage2_aircraft'));
P=stage2_matched_rotor_parameters();
P.rotor.Omega=0.691*P.env.aSound/P.rotor.R;
sigma=0.089; targetCT=0.075*sigma; muList=[0.125 0.15 0.17 0.20];
seed=[10 0]; rows=table();
for k=1:numel(muList)
    mu=muList(k);
    opts=optimset('Display','off','MaxIter',50,'MaxFunEvals',160,'TolX',2e-5,'TolFun',1e-8);
    [z,J]=fminsearch(@obj,seed,opts);
    e=evalpt(z,mu,P,targetCT);
    % A positive, converged rotor state is not automatically a valid
    % operating-state solution.  The quick check must also satisfy the
    % experimental CT and first-harmonic flapping contracts; otherwise a
    % local fminsearch minimum can be mislabeled as a successful trim.
    e.solutionValid = e.valid && abs((e.CT-targetCT)/targetCT)<=0.005 && ...
        abs(e.beta1c_deg)<=0.1;
    if e.solutionValid, seed=z; end
    targetRelativeError=abs((e.CT-targetCT)/targetCT);
    one=table(mu,targetCT,z(1),z(2),e.CT,e.CQ,e.CQ/sigma,e.beta1c_deg,e.beta1s_deg,e.physicalConverged,e.solutionValid,targetRelativeError,J,{e.status}, ...
      'VariableNames',{'advance_ratio','target_CT','theta75_deg','cyclicLong_deg','CT_model','CQ_model','CQ_over_sigma_model','beta1c_deg','beta1s_deg','physicalConverged','solutionValid','targetRelativeError','objective','status'});
    rows=[rows;one]; %#ok<AGROW>
end
writetable(rows,fullfile(outputDir,'BETZINA2002_ALPHA0_QUICKCHECK.csv'));
results=struct('rows',rows,'allPhysical',all(rows.physicalConverged),'allValid',all(rows.solutionValid), ...
 'maxCTRelativeError',max(abs(rows.CT_model-targetCT)/targetCT),'maxAbsBeta1cDeg',max(abs(rows.beta1c_deg)), ...
 'claimBoundary','ALPHA0_FORWARD_EXTERNAL_QUICKCHECK_NO_PHYSICS_FIT_NOT_FULL_BETZINA_MATRIX');
save(fullfile(outputDir,'BETZINA2002_ALPHA0_QUICKCHECK.mat'),'results');

    function J=obj(z)
        if z(1)<0 || z(1)>25 || z(2)<-15 || z(2)>15, J=1e8; return; end
        ee=evalpt(z,mu,P,targetCT);
        if ~ee.valid, J=1e7; return; end
        r1=(ee.CT-targetCT)/targetCT;
        r2=ee.beta1c_deg/0.1;
        J=r1^2+r2^2;
    end
end

function e=evalpt(z,mu,P,targetCT)
e=struct('valid',false,'CT',NaN,'CQ',NaN,'beta1c_deg',NaN,'beta1s_deg',NaN,'physicalConverged',false,'status','NO_SOLUTION');
try
 R=P.rotor.R; tip=P.rotor.Omega*R; x=zeros(9,1); x(1)=mu*tip;
 x75=(0.75-P.rotor.rootCut)/max(1-P.rotor.rootCut,eps);
 theta75=z(1)*pi/180; ctrl=struct('collective',theta75-P.rotor.twistTip*x75,'cyclicLong',z(2)*pi/180);
 [~,~,out]=m1_evidence_v1_forward_rotor(x,ctrl,0,1,zeros(3,1),P);
 A=pi*R^2; CT=out.thrust/(P.env.rho*A*tip^2); CQ=out.torque/(P.env.rho*A*tip^2*R);
 e.CT=CT; e.CQ=CQ; e.beta1c_deg=out.beta1c*180/pi; e.beta1s_deg=out.beta1s*180/pi;
 e.physicalConverged=out.physicalConverged; e.status=out.physicalStatus;
 e.valid=out.physicalConverged && isfinite(CT) && isfinite(CQ) && CT>0 && CQ>0;
catch ME
 e.status=['ERROR_' ME.identifier];
end
end
