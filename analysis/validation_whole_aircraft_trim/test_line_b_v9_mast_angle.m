function report=test_line_b_v9_mast_angle(outputRoot,baselineRoot)
% Exact published cells, immutable legacy replay and coordinate invariants.
% No measured power target is read and no power threshold defines success.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
assert(exist(fullfile(baselineRoot,'BASELINE_MANIFEST.json'),'file')==2, ...
 'Run prepare_line_b_v9_baseline.py first.');
addpath(baselineRoot);cleanup=onCleanup(@()rmpath(baselineRoot));
here=fileparts(mfilename('fullpath'));n=0;sourceCells=0;d2r=pi/180;
T=readtable(fullfile(here,'data','CR166536_WING_T4II_VIII.csv'),'TextType','string');
for k=1:height(T)
 if T.flap_setting(k)~="40/25"||T.status(k)~="TRANSCRIBED",continue;end
 a=T.row_value(k);v=T.value(k);b=str2double(T.mast_angle_deg(k));
 if any(T.table_name(k)==["4-II","4-IV"])&&a>=-90&&a<=40
  [cl,cd]=gtrs_wing_heli_coefficients(a*d2r,.1,b*d2r);
  if T.table_name(k)=="4-II",actual=cl;else,actual=cd;end
 elseif startsWith(T.table_name(k),"4-V(")
  actual=gtrs_wing_tail_downwash(a,0,b*d2r);
 elseif T.table_name(k)=="4-VIII"
  [~,~,actual]=gtrs_wing_heli_coefficients(0,.1,a*d2r);
 else,continue;
 end
 check(abs(actual-v)<1e-12);sourceCells=sourceCells+1;
end
check(sourceCells>190);
% Interior interpolation is declared and tested separately from source data.
[cl,cd,cm,meta]=gtrs_wing_heli_coefficients(4*d2r,.1,60*d2r);
check(abs(cl-(.975/3+1.46*2/3))<1e-12);
check(abs(cd-(.394/3+.186*2/3))<1e-12&&abs(cm+.110)<1e-12);
check(contains(meta.mastInterpolation,'ASSUMED'));
check(abs(gtrs_wing_tail_downwash(4,0,45*d2r)-(6.1+6.58)/2)<1e-12);
[aw,f]=gtrs_wing_freefield_angle(3,.02,.1,60*d2r);
check(abs(f.XRW-(.0806+60*.00003341+60^2*.000007386))<1e-15);
check(abs(aw-(3-.26*f.XRW*.02/.15^2*57.3))<1e-12);
check(gtrs_wing_freefield_angle(3,0,.2,60*d2r)==3);
expect(@()gtrs_wing_heli_coefficients(0,.1,-.01),'gtrs_wing_heli_coefficients:OutsideMastDomain');
expect(@()gtrs_wing_heli_coefficients(0,.201,pi/3),'gtrs_wing_heli_coefficients:OutsideSourceSubset');
expect(@()gtrs_wing_tail_downwash(0,.2,pi/3),'gtrs_wing_tail_downwash:OutsideSourceDomain');

P=line_b_coherent_tail_parameters(xv15_helicopter_trim_parameters_v1());
x=zeros(9,1);x(1)=30;cg=[.1;0;-.2];zero=struct('inducedVelocity',0);
[~,~,heli]=gtrs_spinner_steady(x,0,cg,zero,zero,P);
[~,~,plane]=gtrs_spinner_steady(x,pi/2,cg,zero,zero,P);
check(abs(heli.effectiveDragArea_m2-13*.3048^2)<1e-12);
check(abs(plane.effectiveDragArea_m2-2*.3048^2)<1e-12);
for b=[0 30 60 90]*d2r
 r=struct('inducedVelocity',5);
 [F,M,s]=gtrs_spinner_steady(x,b,cg,r,r,P);
 check(norm(s.bodyToMast*s.bodyToMast.'-eye(3),'fro')<1e-12);
 check(abs(norm(s.VlocalMast)-norm(s.Vlocal))<1e-12);
 check(abs(s.VlocalMast(1)-30*cos(b))<1e-12);
 check(abs(s.VlocalMast(3)-(-5-30*sin(b)))<1e-12);
 check(abs(dot(F,s.Vlocal)+s.drag_N*norm(s.Vlocal))<1e-8);
 check(norm(M-cross(s.rAC,F))<1e-10);
 expected=[P.rotor.pivotX;0;P.rotor.pivotZ]+P.rotor.RH_hub*[sin(b);0;-cos(b)]-cg;
 check(norm(s.rAC-expected)<1e-12);
 shift=[.41;0;-.27];Ps=P;Ps.rotor.pivotX=Ps.rotor.pivotX+shift(1);Ps.rotor.pivotZ=Ps.rotor.pivotZ+shift(3);
 [Fs,Ms]=gtrs_spinner_steady(x,b,cg+shift,r,r,Ps);
 check(norm([Fs-F;Ms-M])<1e-9);
end
% Source axis-aligned flow must have the base area at a conversion angle.
x(1:3)=30*[sin(pi/3);0;-cos(pi/3)];
[~,~,axial]=gtrs_spinner_steady(x,pi/3,cg,zero,zero,P);
check(abs(axial.effectiveDragArea_m2-2*.3048^2)<1e-12);

% Compare helicopter endpoint against the actual pre-fix code, not a copy
% of the new equations. Check wing, tail and spinner loads bit for bit.
for speed=[40 60 80 100]
 x=zeros(9,1);x(1)=speed*(1852/3600);mp=mass_properties(0,P);
 r=struct('inducedVelocity',8,'mu',x(1)/(P.rotor.Omega*P.rotor.R), ...
  'muLong',x(1)/(P.rotor.Omega*P.rotor.R),'muLat',0,'F',[0;0;-25000]);
 flow=rotor_tail_interference_heli(x,0,r,r,P);
 [F,M]=gtrs_spinner_steady(x,0,mp.cgShift,r,r,P);
 [Fo,Mo]=baseline_gtrs_spinner_steady(x,0,mp.cgShift,r,r,P);
 check(isequal(F,Fo)&&isequal(M,Mo));
 [F,M,w]=wing_model_freefield_consistent(x,zeros(7,1),0,mp.cgShift,r,r,P);
 [Fo,Mo]=baseline_wing_model_freefield_consistent(x,zeros(7,1),0,mp.cgShift,r,r,P);
 check(isequal(F,Fo)&&isequal(M,Mo));
 [F,M,h]=gtrs_horizontal_tail_steady(x,0,mp.cgShift,P,flow);
 [Fo,Mo]=baseline_gtrs_horizontal_tail_steady(x,0,mp.cgShift,P,flow);
 check(isequal(F,Fo)&&isequal(M,Mo));
 check(w.freefield.alphaWing_deg==h.wingFreeAlpha_deg);
end
test_wing_empty_patch_domain();test_cross_angle_component_interfaces();
report=struct('identity','V9_MAST_ANGLE_SOURCE_AND_REGRESSION', ...
 'checksPassed',n,'sourceCells',sourceCells,'helicopterLegacyBitwiseEqual',true, ...
 'baselineCommit','7f672db177256fa6f89b4df5f369ba33a49fc920', ...
 'matlabVersion',version,'matlabRelease',version('-release'),'flightValidated',false);
save(fullfile(outputRoot,'V9_COMPONENT_TESTS.mat'),'report');
fid=fopen(fullfile(outputRoot,'V9_COMPONENT_TESTS.json'),'w');assert(fid>=0);
c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(report),'char');clear c;disp(report);
 function check(tf),assert(tf,'V9 component check %d failed.',n+1);n=n+1;end
 function expect(fun,id)
  try,fun();catch ME,check(strcmp(ME.identifier,id));return;end
  error('V9:ExpectedError','Expected %s.',id);
 end
end
