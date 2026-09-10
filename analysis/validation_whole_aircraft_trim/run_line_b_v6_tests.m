function result=run_line_b_v6_tests(outputRoot)
% Source free-field/moment invariants and conditional replay, no trim fitting.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
n=0;[P,~]=xv15_helicopter_trim_parameters_v1();P=line_b_coherent_tail_parameters(P);mp=mass_properties(0,P);
base=run_line_b_source_tail_replay(outputRoot);src=fullfile(outputRoot,'baseline_tail');addpath(src);clean=onCleanup(@()rmpath(src));
ref=[-350.07 -719.31 451.96;-743.88 -1035.99 478.28;-1154.73 -676.32 -322.31;-1523.96 368.16 -2026.30];
speed=[40 60 80 100];rows=[];records=cell(4,1);
for k=1:4
 in=base.records{3*(k-1)+1};x=in.x;rl=in.rotorLeft;rr=in.rotorRight;
 rl.muLong=rl.mu;rr.muLong=rr.mu;rl.muLat=0;rr.muLat=0;u=zeros(7,1);
 [F5,M5,o5]=wing_model_source_family(x,u,0,mp.cgShift,rl,rr,P);
 [F6,M6,o6]=wing_model_freefield_consistent(x,u,0,mp.cgShift,rl,rr,P);
 check(o5.SslipHalf==o6.SslipHalf&&o5.SfreeHalf==o6.SfreeHalf);
 flow=rotor_tail_interference_heli(x,0,rl,rr,P);
 [Ft,Mt,ht]=gtrs_horizontal_tail_steady(x,0,mp.cgShift,P,flow);
 [Fo,Mo,ho]=baseline_gtrs_horizontal_tail_steady(x,0,mp.cgShift,P,flow);
 check(isequal(Ft,Fo)&&isequal(Mt,Mo)&&isequal(ht.alphaEff,ho.alphaEff));
 check(isequal(ht.wingFreeAlpha_deg,o6.freefield.alphaWing_deg));
 q=.5*P.env.rho*(x(1)^2+x(3)^2);expected=q*P.wing.S*P.wing.c*(-.110);
 check(abs(o6.Maero(2)-expected)<1e-10*max(1,abs(expected)));
 sumF=zeros(3,1);sumM=zeros(3,1);
 for j=1:4
  a=o6.regions{j};b=o5.regions{j};check(isequal(a.Vlocal,b.Vlocal)&&a.S==b.S);
  check(norm(a.M-a.Maero-cross(a.rAC,a.F))<1e-9);sumF=sumF+a.F;sumM=sumM+a.M;
  if a.inSlipstream
   check(isequal(a.F,b.F)&&all(a.Maero==0));
  else
   check(abs(a.alpha*180/pi-ht.wingFreeAlpha_deg)<1e-12&&a.qbar==q);
   independent=[-q*a.S*a.CD*cos(a.alpha)+q*a.S*a.CL*sin(a.alpha);0; ...
                -q*a.S*a.CD*sin(a.alpha)-q*a.S*a.CL*cos(a.alpha)];
   check(norm(a.F-independent)<1e-9);
  end
 end
 check(norm(sumF-F6)<1e-9&&norm(sumM-M6)<1e-9);
 shift=[.3;0;-.7];Ps=P;Ps.wing.xAC=Ps.wing.xAC+shift(1);Ps.wing.zAC=Ps.wing.zAC+shift(3);
 [Fs,Ms]=wing_model_freefield_consistent(x,u,0,mp.cgShift+shift,rl,rr,Ps);
 check(norm([Fs-F6;Ms-M6])<1e-8);
 za=rl;zb=rr;za.F=zeros(3,1);zb.F=zeros(3,1);
 [Fz,~,oz]=wing_model_freefield_consistent(x,u,0,mp.cgShift,za,zb,P);
 check(norm(Fz-F5)<1e-9&&oz.freefield.deflection_deg==0);
 a5=[F5(1)/4.4482216152605,F5(3)/4.4482216152605,M5(2)/1.3558179483314];
 a6=[F6(1)/4.4482216152605,F6(3)/4.4482216152605,M6(2)/1.3558179483314];
 rows=[rows;speed(k),o5.regions{1}.alpha*180/pi,o6.freefield.alphaWing_deg,ht.wingFreeAlpha_deg, ...
  o6.freefield.deflection_deg,a5,a6,ref(k,:),a6-ref(k,:)]; %#ok<AGROW>
 records{k}=struct('input',in,'v5',o5,'v6',o6,'tail',ht);
end
check(gtrs_wing_freefield_angle(3,0,.1)==3);
a=gtrs_wing_freefield_angle(0,.02,.1);check(abs(a+.26*.0806*.02/.15^2*57.3)<1e-12);
expect(@()gtrs_wing_freefield_angle(0,-.1,.1),'gtrs_wing_freefield_angle:InvalidInput');
expect(@()gtrs_wing_freefield_angle(0,.1,-.1),'gtrs_wing_freefield_angle:InvalidInput');
expect(@()wing_model_freefield_consistent(x,u,.1,mp.cgShift,rl,rr,P),'wing_model_source_family:SteadyHeliOnly');
A=array2table(rows,'VariableNames',{'speed_kt','v5WingFreeAlpha_deg','v6WingFreeAlpha_deg','tailWingAlpha_deg','deflection_deg', ...
 'v5X_lbf','v5Z_lbf','v5M_lbfft','v6X_lbf','v6Z_lbf','v6M_lbfft','refX_lbf','refZ_lbf','refM_lbfft','dX_lbf','dZ_lbf','dM_lbfft'});
writetable(A,fullfile(outputRoot,'V6_CONDITIONAL_WING_REPLAY.csv'));disp(A);
result=struct('identity','V6_FREEFIELD_IMPLEMENTATION_AND_CONDITIONAL_CHECKS','checksPassed',n, ...
 'version',version,'release',version('-release'),'records',{records},'table',A,'source','CR166536_REVA_A69_A70_A181_B33', ...
 'sourceSharedCorrelation',true,'externalAccuracyPassed',false,'coverageAndImmersedForcesUnchanged',true,'tailRefactorExactIdentity',true);
save(fullfile(outputRoot,'V6_TEST_RESULTS.mat'),'result');meta=rmfield(result,{'records','table'});
fid=fopen(fullfile(outputRoot,'V6_TEST_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta));clear c;
disp(meta);
 function check(b),assert(b,'V6 invariant failed.');n=n+1;end
 function expect(f,id),try,f();catch ME,check(strcmp(ME.identifier,id));return;end,error('Expected domain rejection.');end
end
