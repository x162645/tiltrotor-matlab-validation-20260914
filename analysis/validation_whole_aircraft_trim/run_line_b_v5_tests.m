function result=run_line_b_v5_tests(outputRoot)
% Source nodes, algebraic checks and conditional external replay; no trim fit.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
n=0;[cl,cd,cm]=gtrs_wing_heli_coefficients(0,.1);check(abs(cl-.749)<1e-12&&abs(cd-.345)<1e-12&&abs(cm+.110)<1e-12);
[cl,cd]=gtrs_wing_heli_coefficients(-8*pi/180,.1);check(abs(cl-.291)<1e-12&&abs(cd-.267)<1e-12);
[cl,cd]=gtrs_wing_heli_coefficients(-90*pi/180,.1);check(cl==0&&cd==1.44);
[cl,~]=gtrs_wing_heli_coefficients(13.6*pi/180,.1);check(abs(cl-1.5)<1e-12);
[P,~]=xv15_helicopter_trim_parameters_v1();mp=mass_properties(0,P);
base=run_line_b_source_tail_replay(outputRoot);speed=[40 60 80 100];ref=[-350.07 -719.31 451.96;-743.88 -1035.99 478.28;-1154.73 -676.32 -322.31;-1523.96 368.16 -2026.30];
rows=[];records={};
for k=1:4
 inp=base.records{3*(k-1)+1};x=inp.x;rl=inp.rotorLeft;rr=inp.rotorRight;
 rl.muLong=rl.mu;rr.muLong=rr.mu;rl.muLat=0;rr.muLat=0;rl.eT=[0;0;-1];rr.eT=rl.eT;u=zeros(7,1);
 [F,M,o]=wing_model_source_family(x,u,0,mp.cgShift,rl,rr,P);[~,~,old]=wing_model(x,u,0,mp.cgShift,rl,rr,P);
 check(o.SslipHalf==old.SslipHalf&&o.SfreeHalf==old.SfreeHalf);
 sumF=zeros(3,1);sumM=zeros(3,1);
 for j=1:4
  d=o.regions{j};od=old.regions{j};check(norm(d.Vlocal-od.Vlocal)<1e-12);
  check(norm(d.M-d.Maero-cross(d.rAC,d.F))<1e-9);sumF=sumF+d.F;sumM=sumM+d.M;
 end
 check(norm(sumF-F)<1e-9&&norm(sumM-M)<1e-9);
 Pbad=P;Pbad.wing.CLalpha=99;Pbad.wing.CL0=99;Pbad.wing.CLmax=.01;Pbad.wing.CD0=99;Pbad.wing.kInduced=99;Pbad.wing.Cm0=99;Pbad.wing.CDnormal=99;
 [Fb,Mb]=wing_model_source_family(x,u,0,mp.cgShift,rl,rr,Pbad);check(isequal(F,Fb)&&isequal(M,Mb));
 sh=[.3;-.5;.7];Ps=P;Ps.wing.xAC=Ps.wing.xAC+sh(1);Ps.wing.zAC=Ps.wing.zAC+sh(3);
 % Common x/z translation invariant; paired y locations remain symmetric.
 [Ft,Mt]=wing_model_source_family(x,u,0,mp.cgShift+[sh(1);0;sh(3)],rl,rr,Ps);check(norm([Ft-F;Mt-M])<1e-8);
 q=[F(1)/4.4482216152605,F(3)/4.4482216152605,M(2)/1.3558179483314];
 rows=[rows;speed(k),q,ref(k,:),q-ref(k,:)];records{k}=o; %#ok<AGROW>
end
expect(@()gtrs_wing_heli_coefficients(41*pi/180,.1),'gtrs_wing_heli_coefficients:OutsideSourceSubset');
expect(@()gtrs_wing_heli_coefficients(0,.21),'gtrs_wing_heli_coefficients:OutsideSourceSubset');
A=array2table(rows,'VariableNames',{'speed_kt','X_lbf','Z_lbf','M_lbfft','refX_lbf','refZ_lbf','refM_lbfft','dX_lbf','dZ_lbf','dM_lbfft'});
writetable(A,fullfile(outputRoot,'V5_SOURCE_INPUT_WING_REPLAY.csv'));disp(A);
result=struct('checksPassed',n,'version',version,'release',version('-release'),'records',{records},'table',A, ...
 'identity','V5_SOURCE_WING_FAMILY_INTERNAL_AND_CONDITIONAL_CHECK','externalAccuracyPassed',false,'coverageAndVelocityUnchanged',true);
save(fullfile(outputRoot,'V5_TEST_RESULTS.mat'),'result');meta=rmfield(result,{'records','table'});
fid=fopen(fullfile(outputRoot,'V5_TEST_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta));clear c;disp(meta);
 function check(b),assert(b,'V5 check failed.');n=n+1;end
 function expect(f,id),try,f();catch ME,check(strcmp(ME.identifier,id));return;end,error('Expected exception absent.');end
end
