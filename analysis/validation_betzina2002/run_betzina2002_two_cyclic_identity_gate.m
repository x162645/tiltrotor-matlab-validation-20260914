function results = run_betzina2002_two_cyclic_identity_gate(outputDir)
%RUN_BETZINA2002_TWO_CYCLIC_IDENTITY_GATE
% Verify that the validation-only two-cyclic adapter reproduces the existing
% Stage-2 forward rotor exactly when lateral cyclic is zero.

rootDir=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1 || isempty(outputDir), outputDir=fullfile(rootDir,'results','betzina2002_two_cyclic_identity_gate'); end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
addpath(fullfile(rootDir,'analysis','stage2_aircraft'));
addpath(fullfile(rootDir,'analysis','validation_betzina2002'));
P=stage2_matched_rotor_parameters();
P.rotor.Omega=0.691*P.env.aSound/P.rotor.R;
muList=[0.125;0.15;0.20];
thetaList=[1.8464;3.6963;3.3244];
cycList=[-0.42422;-1.1902;-1.5296];
rows=table();
for k=1:numel(muList)
    mu=muList(k); theta75=thetaList(k); cyc=cycList(k);
    tip=P.rotor.Omega*P.rotor.R; x=zeros(9,1); x(1)=mu*tip;
    x75=(0.75-P.rotor.rootCut)/max(1-P.rotor.rootCut,eps);
    ctrl=struct('collective',theta75*pi/180-P.rotor.twistTip*x75,'cyclicLong',cyc*pi/180);
    [~,~,legacy]=m1_evidence_v1_forward_rotor(x,ctrl,0,1,zeros(3,1),P);
    ext=betzina2002_two_cyclic_rotor(P,mu,0,theta75,cyc,0);
    A=pi*P.rotor.R^2;
    CTlegacy=legacy.thrust/(P.env.rho*A*tip^2);
    CQlegacy=legacy.torque/(P.env.rho*A*tip^2*P.rotor.R);
    dCT=ext.CT-CTlegacy; dCQ=ext.CQ-CQlegacy;
    db0=ext.beta0-legacy.beta0; db1c=ext.beta1c-legacy.beta1c; db1s=ext.beta1s-legacy.beta1s;
    one=table(mu,theta75,cyc,CTlegacy,ext.CT,CQlegacy,ext.CQ,dCT,dCQ,db0,db1c,db1s, ...
        legacy.physicalConverged,ext.physicalConverged, ...
        'VariableNames',{'advance_ratio','theta75_deg','cyclicLong_deg','CT_legacy','CT_adapter','CQ_legacy','CQ_adapter','dCT','dCQ','dBeta0','dBeta1c','dBeta1s','legacyPhysical','adapterPhysical'});
    rows=[rows;one]; %#ok<AGROW>
end
maxAbs=max(abs([rows.dCT;rows.dCQ;rows.dBeta0;rows.dBeta1c;rows.dBeta1s]));
allPhysical=all(rows.legacyPhysical & rows.adapterPhysical);
pass=allPhysical && maxAbs<=1e-10;
writetable(rows,fullfile(outputDir,'BETZINA2002_TWO_CYCLIC_IDENTITY_GATE.csv'));
summary=table(maxAbs,allPhysical,pass,'VariableNames',{'maxAbsDifference','allPhysical','pass'});
writetable(summary,fullfile(outputDir,'BETZINA2002_TWO_CYCLIC_IDENTITY_GATE_SUMMARY.csv'));
results=struct('rows',rows,'summary',summary,'pass',pass,'claimBoundary','CYCLIC_LAT_ZERO_IDENTITY_ONLY');
save(fullfile(outputDir,'BETZINA2002_TWO_CYCLIC_IDENTITY_GATE.mat'),'results');
end
