function result=run_line_b_spinner_tests(outputRoot)
% Source spinner replay and explicit integration guards before V7 trim.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
here=fileparts(mfilename('fullpath'));D=readtable(fullfile(here,'data','CR166537_HELI_4POINT_INPUTS.csv'));
C=readtable(fullfile(here,'data','CR166537_HELI_4POINT_LOADS.csv'));
[P0,~]=xv15_helicopter_trim_parameters_v1();P0=line_b_coherent_tail_parameters(P0);n=0;rows=[];records=cell(4,1);
for k=1:4
 s=D(k,:);P=P0;P.env.rho=s.rho_slug_ft3*14.59390294/.3048^3;
 x=zeros(9,1);x(1)=s.u_ft_s*.3048;x(3)=s.w_ft_s*.3048;x(8)=s.theta_deg*pi/180;
 r=struct('inducedVelocity',s.induced_ft_s*.3048);mp=mass_properties(0,P);
 [F,M,o]=gtrs_spinner_steady(x,0,mp.cgShift,r,r,P);
 ref=C(C.speed_kt==s.speed_kt&strcmp(C.component,'HUB_SPINNER'),:);check(height(ref)==1);
 % Independent ft/lbf calculation of the published formula.
 v=[s.u_ft_s;0;s.w_ft_s-s.induced_ft_s];vm=norm(v);q=.5*s.rho_slug_ft3*vm^2;
 sd=2*q*(1+5.5*(hypot(v(1),v(2))/vm)^3);fu=-sd*v/vm;
 check(norm(F/4.4482216152605-fu)<1e-6);check(norm(M-cross(o.rAC,F))<1e-9);
 check(abs(dot(F,o.Vlocal)+o.drag_N*norm(o.Vlocal))<1e-8);
 check(o.spinnerCount==2&&o.effectiveDragArea_m2<=13*.3048^2&&o.effectiveDragArea_m2>=2*.3048^2);
 % Zero induced velocity is the source formula, not zero spinner force.
 zr=struct('inducedVelocity',0);[Fz,~,oz]=gtrs_spinner_steady(x,0,mp.cgShift,zr,zr,P);
 check(all(isfinite(Fz))&&norm(Fz)>0&&oz.meanInduced_mps==0);
 xl=x;xl(3)=0;[Fl,~,ol]=gtrs_spinner_steady(xl,0,mp.cgShift,zr,zr,P);
 check(abs(ol.effectiveDragArea_m2-13*.3048^2)<1e-12&&Fl(1)<0&&Fl(3)==0);
 sh=[.41;0;-.27];Ps=P;Ps.rotor.pivotX=Ps.rotor.pivotX+sh(1);Ps.rotor.pivotZ=Ps.rotor.pivotZ+sh(3);
 [Ft,Mt]=gtrs_spinner_steady(x,0,mp.cgShift+sh,r,r,Ps);check(norm([Ft-F;Mt-M])<1e-9);
 rl=struct('inducedVelocity',r.inducedVelocity*.8);rr=struct('inducedVelocity',r.inducedVelocity*1.2);
 [Fa,Ma]=gtrs_spinner_steady(x,0,mp.cgShift,rl,rr,P);[Fb,Mb]=gtrs_spinner_steady(x,0,mp.cgShift,rr,rl,P);
 check(isequal(Fa,Fb)&&isequal(Ma,Mb));
 values=[F(1)/4.4482216152605,F(3)/4.4482216152605,M(2)/1.3558179483314];refs=[ref.X_lbf,ref.Z_lbf,ref.M_lbfft];
 rows=[rows;s.speed_kt,values,refs,values-refs,100*(values-refs)./abs(refs)]; %#ok<AGROW>
 records{k}=struct('state',x,'P',P,'spinner',o,'reference',ref);
end
expect(@()gtrs_spinner_steady(x,.1,mp.cgShift,r,r,P),'gtrs_spinner_steady:SteadyHeliOnly');
xb=x;xb(5)=.01;expect(@()gtrs_spinner_steady(xb,0,mp.cgShift,r,r,P),'gtrs_spinner_steady:SteadyHeliOnly');
xb=x;xb(2)=1;expect(@()gtrs_spinner_steady(xb,0,mp.cgShift,r,r,P),'gtrs_spinner_steady:SteadyHeliOnly');
nr=struct('inducedVelocity',-1);expect(@()gtrs_spinner_steady(x,0,mp.cgShift,nr,r,P),'gtrs_spinner_steady:InvalidInflow');
% One existing model seed: default stack versus immutable pre-spinner copy.
P=P0;P.rotor.correctionIdentity='CORRIGAN_POSITIVE_LIFT_WASHOUT_V4';P.wing.coefficientModel='GTRS_FREEFIELD_HELI_V6';
S=readtable(fullfile(here,'original_baseline_trim_seeds.csv'));S=S(S.speed_kt==60,:);
x=zeros(9,1);x(1)=60*.514444*cos(S.theta_rad);x(3)=60*.514444*sin(S.theta_rad);x(8)=S.theta_rad;
P.stage2Numerics.flapInitialLeft=[S.flapL0;S.flapL1c;S.flapL1s];P.stage2Numerics.flapInitialRight=[S.flapR0;S.flapR1c;S.flapR1s];
a=xv15_helicopter_control_allocation(S.stick_in,0,P);u=[S.collective_rad;0;a.cyclicLong;0;0;a.elevator;0];
basedir=fullfile(outputRoot,'baseline_sum');addpath(basedir);cleanup=onCleanup(@()rmpath(basedir));
[F0,M0,i0]=stage2_total_forces_moments('M1_CONTINUOUS_CORRIGAN_V4',x,u,0,P);
[Fold,Mold,old]=baseline_stage2_total_forces_moments('M1_CONTINUOUS_CORRIGAN_V4',x,u,0,P);
check(isequal(F0,Fold)&&isequal(M0,Mold));check(i0.physicalConverged&&old.physicalConverged);
check(~isfield(i0,'hubSpinner')&&numel(i0.components)==6);
P.aeroExtras.spinnerModel='GTRS_TWO_SPINNERS_STEADY_HELI_V7';
[F1,M1,i1]=stage2_total_forces_moments('M1_CONTINUOUS_CORRIGAN_V4',x,u,0,P);
check(norm(F1-F0-i1.hubSpinner.F)<1e-9&&norm(M1-M0-i1.hubSpinner.M)<1e-9);
check(isequal(i0.rotorLeft.F,i1.rotorLeft.F)&&isequal(i0.rotorRight.F,i1.rotorRight.F));
check(isequal(i0.wing.F,i1.wing.F)&&isequal(i0.horizontalTail.F,i1.horizontalTail.F));
check(numel(i1.components)==7&&strcmp(i1.components{7}.name,'hubSpinner'));
f=zeros(3,1);m=zeros(3,1);for k=1:numel(i1.components),f=f+i1.components{k}.F;m=m+i1.components{k}.M;end
check(norm(F1-f)<1e-9&&norm(M1-m)<1e-9);
P.aeroExtras.spinnerModel='UNKNOWN';expect(@()stage2_total_forces_moments('M1_CONTINUOUS_CORRIGAN_V4',x,u,0,P),'stage2_total_forces_moments:UnknownSpinnerModel');
A=array2table(rows,'VariableNames',{'speed_kt','Xmodel_lbf','Zmodel_lbf','Mmodel_lbfft','Xref_lbf','Zref_lbf','Mref_lbfft', ...
 'dX_lbf','dZ_lbf','dM_lbfft','Xerror_pct','Zerror_pct','Merror_pct'});
writetable(A,fullfile(outputRoot,'SPINNER_SOURCE_COMPARISON.csv'));
meta=struct('identity','SPINNER_SOURCE_MODEL_AND_INTEGRATION_TESTS','checksPassed',n,'version',version,'release',version('-release'), ...
 'legacyStackExactIdentity',true,'independentFlightValidation',false,'targetFitting',false,'externalAccuracyPassAssigned',false, ...
 'source','CR166536_A75_A76_B33_A232_AND_CR166537_ORIGINAL_OUTPUT', ...
 'geometryCaveat','Current rounded low-order hub/CG retained; source mean force can be closer than pitching moment');
result=struct('meta',meta,'comparison',A,'records',{records},'integrationOld',i0,'integrationNew',i1);
save(fullfile(outputRoot,'SPINNER_TEST_RESULTS.mat'),'result');
fid=fopen(fullfile(outputRoot,'SPINNER_TEST_MANIFEST.json'),'w');assert(fid>=0);cl=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear cl;
disp(A);disp(meta);
 function check(b),assert(b,'Spinner test failed.');n=n+1;end
 function expect(f,id),try,f();catch ME,check(strcmp(ME.identifier,id));return;end,error('Expected source-domain error did not occur.');end
end
