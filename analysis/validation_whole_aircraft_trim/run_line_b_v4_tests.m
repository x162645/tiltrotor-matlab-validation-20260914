function result=run_line_b_v4_tests(outputRoot)
% Numerics unchanged. Check correction continuity and matched local probes.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
[P0,~]=xv15_helicopter_trim_parameters_v1();P4=P0;
P4.rotor.correctionIdentity='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4';
S=readtable(fullfile(fileparts(mfilename('fullpath')),'original_baseline_trim_seeds.csv'));
mp=mass_properties(0,P0);n=0;rows={};records={};
% Original default core snapshot supplied by CI using git show at baseline.
folder=fullfile(outputRoot,'baseline_core');addpath(folder,'-begin');c=onCleanup(@()rmpath(folder));
for a=[0,30,60]
 for ma=[.3,.759058]
  e=1e-8*pi/180;
  [lo,cdlo]=xv15_c81_corrigan_continuous_v4(a*pi/180-e,ma,.9,.3556,3.81,'CORRIGAN_GENERIC_N1');
  [hi,cdhi]=xv15_c81_corrigan_continuous_v4(a*pi/180+e,ma,.9,.3556,3.81,'CORRIGAN_GENERIC_N1');
  check(abs(hi-lo)<1e-6);check(abs(cdhi-cdlo)<1e-6);
 end
end
for a=[-10,2,6,10,20,29]
 [b,db]=xv15_c81_corrigan_stall_delay(a*pi/180,.3,.9,.3556,3.81,'CORRIGAN_GENERIC_N1');
 [v,dv]=xv15_c81_corrigan_continuous_v4(a*pi/180,.3,.9,.3556,3.81,'CORRIGAN_GENERIC_N1');
 check(abs(v-b)<1e-14);check(isequal(db,dv));
end
for speed=[60 100]
 s=S(S.speed_kt==speed,:);base=[s.theta_rad;s.collective_rad;s.stick_in];
 P0.rotor.flapInitial=[s.flapL0;s.flapL1c;s.flapL1s];P4.rotor.flapInitial=P0.rotor.flapInitial;
 d=[2*pi/180;10*pi/180;1]*.00025;probes=[zeros(3,1),diag(d),-diag(d)];
 for j=1:7
  z=base+probes(:,j);x=zeros(9,1);x(1)=speed*.514444*cos(z(1));x(3)=speed*.514444*sin(z(1));x(8)=z(1);
  a=xv15_helicopter_control_allocation(z(3),0,P0);ctrl=struct('collective',z(2),'cyclicLong',a.cyclicLong);
  oldok=false;newok=false;o0=struct();o4=struct();err0='';err4='';identity=NaN;
  try,[F0,M0,o0]=m1_evidence_v1_forward_rotor(x,ctrl,0,-1,mp.cgShift,P0);oldok=o0.physicalConverged;
  catch ME,err0=ME.identifier;end
  if oldok&&j==1
   [Fb,Mb,ob]=baseline_m1_rotor(x,ctrl,0,-1,mp.cgShift,P0);
   identity=max(abs([F0-Fb;M0-Mb;o0.inducedVelocity-ob.inducedVelocity]));check(identity==0);
  end
  try,[~,~,o4]=m1_evidence_v1_forward_rotor(x,ctrl,0,-1,mp.cgShift,P4);newok=o4.physicalConverged;
  catch ME,err4=ME.identifier;end
  rows(end+1,:)={speed,j,oldok,newok,identity,err0,err4};
  records{end+1}=struct('z',z,'old',o0,'new',o4);
 end
end
A=cell2table(rows,'VariableNames',{'speed_kt','probe','oldSupported','newSupported','defaultIdentityDifference','oldError','newError'});
writetable(A,fullfile(outputRoot,'V4_LOCAL_PROBES.csv'));disp(A);
% Four fixed physical pitch values: small bounded hover regression, not renewed validation.
hr=[];for theta75=[10 12 14 15]
 ctrl=struct('collective',theta75*pi/180-P0.rotor.twistTip*(.75-P0.rotor.rootCut)/(1-P0.rotor.rootCut),'cyclicLong',0);
 P0.rotor.flapInitial=zeros(3,1);P4.rotor.flapInitial=zeros(3,1);
 [~,~,o0]=m1_evidence_v1_forward_rotor(zeros(9,1),ctrl,0,-1,mp.cgShift,P0);
 [~,~,o4]=m1_evidence_v1_forward_rotor(zeros(9,1),ctrl,0,-1,mp.cgShift,P4);
 hr=[hr;theta75,o0.physicalConverged,o4.physicalConverged,o0.thrust,o4.thrust,o0.torque,o4.torque,100*(o4.thrust-o0.thrust)/o0.thrust,100*(o4.torque-o0.torque)/o0.torque]; %#ok<AGROW>
end
H=array2table(hr,'VariableNames',{'theta75_deg','oldSupported','newSupported','oldT_N','newT_N','oldQ_Nm','newQ_Nm','dT_pct','dQ_pct'});
writetable(H,fullfile(outputRoot,'V4_HOVER_REGRESSION.csv'));disp(H);
result=struct('checksPassed',n,'table',A,'records',{records},'hover',H,'version',version, ...
 'release',version('-release'),'solverChanged',false,'externalValidation',false,'allNewLocalProbesSupported',all(A.newSupported));
save(fullfile(outputRoot,'V4_TEST_RESULTS.mat'),'result');
meta=rmfield(result,{'table','records','hover'});fid=fopen(fullfile(outputRoot,'V4_TEST_MANIFEST.json'),'w');assert(fid>=0);cc=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta));clear cc;
check(all(A.newSupported));
 function check(tf),assert(tf,'V4 internal regression/continuity check failed.');n=n+1;end
end
