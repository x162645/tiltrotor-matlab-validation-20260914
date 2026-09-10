function result=run_line_b_original_unit_load_audit(outputRoot)
%RUN_LINE_B_ORIGINAL_UNIT_LOAD_AUDIT 原始参考分项与单位面积载荷审计。
% CR166537 Appendix A, PDF100/101,103/104,106/107,109/110. 原文读数只作
% 参考输入/输出载体；不修改旧论文CSV，不将等效系数作为模型参数或拟合目标。
% 此程序只调用既有V6机翼。无新旋翼求解、无整机配平、无生产物理更改。
if nargin<1,outputRoot=fullfile(pwd,'ci_artifacts','original_unit_load');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
here=fileparts(mfilename('fullpath'));dataRoot=fullfile(here,'data');
D=readtable(fullfile(dataRoot,'CR166537_HELI_4POINT_INPUTS.csv'));
C=readtable(fullfile(dataRoot,'CR166537_HELI_4POINT_LOADS.csv'));
assert(height(D)==4&&height(C)==68,'Expected four original cases and 17 load rows each.');
[P0,contract]=xv15_helicopter_trim_parameters_v1();P0=line_b_coherent_tail_parameters(P0);Pbefore=P0;
ft=.3048;lbf=4.4482216152605;slug=14.59390294;checks=0;wingCalls=0;records=cell(4,1);
closure={};omitted={};pressure=[];moments=[];rows=[];control=[];t0=tic;
airframe={'FUSELAGE','WING_TOTAL','ENGINE_PYLONS','HORIZONTAL_TAIL','VERTICAL_TAIL_TOTAL','LANDING_GEAR_TOTAL','JET_THRUST_TOTAL','GROUND_EFFECT'};
rotors={'ROTOR_LEFT','ROTOR_RIGHT','HUB_SPINNER'};
for k=1:height(D)
 s=D(k,:);H=C(C.speed_kt==s.speed_kt,:);check(height(H)==17);
 lhs=loadsum(H,airframe);rhs=loadrow(H,'AIRFRAME_TOTAL');add_closure('AIRFRAME',lhs,rhs,8);
 lhs=loadsum(H,rotors);rhs=loadrow(H,'ROTOR_TOTAL');add_closure('ROTOR',lhs,rhs,3);
 lhs=loadrow(H,'AIRFRAME_TOTAL')+loadrow(H,'ROTOR_TOTAL');rhs=loadrow(H,'AIRCRAFT_TOTAL');add_closure('AIRCRAFT',lhs,rhs,2);
 wi=loadrow(H,'WING_LEFT_IMMERSED')+loadrow(H,'WING_RIGHT_IMMERSED');wf=loadrow(H,'WING_FREESTREAM');wt=loadrow(H,'WING_TOTAL');
 check(all(wi==0));check(isequal(wf,wt));
 omittedAF=loadrow(H,'ENGINE_PYLONS')+loadrow(H,'JET_THRUST_TOTAL');spinner=loadrow(H,'HUB_SPINNER');
 omitted(end+1,:)=[{s.speed_kt},num2cell(omittedAF([1 3 4])),num2cell(spinner([1 3 4]))]; %#ok<AGROW>
 % Check printed qbar against the finite precision of original U/W/rho.
 u=s.u_ft_s;w=s.w_ft_s;rho=s.rho_slug_ft3;hr=s.rho_rounding_halfwidth_slug_ft3;
 q=.5*rho*(u^2+w^2);
 qlo=.5*(rho-hr)*((u-s.u_rounding_halfwidth_ft_s)^2+(abs(w)-s.w_rounding_halfwidth_ft_s)^2);
 qhi=.5*(rho+hr)*((u+s.u_rounding_halfwidth_ft_s)^2+(abs(w)+s.w_rounding_halfwidth_ft_s)^2);
 qok=qlo<=s.qbar_psf+s.qbar_rounding_halfwidth_psf&&qhi>=s.qbar_psf-s.qbar_rounding_halfwidth_psf;check(qok);
 pressure=[pressure;s.speed_kt,q,s.qbar_psf,qlo,qhi,qok]; %#ok<AGROW>
 % Pitch acceleration is independent of Ixx/Ixz at zero p/q/r. Inertia
 % 0.2136E+05 is rounded to10, moment to0.001ft-lbf. Retain signed interval.
 total=loadrow(H,'AIRCRAFT_TOTAL');my=total(4);iyy=s.Iyy_slug_ft2;
 cand=[(my-.0005)/(iyy-5),(my-.0005)/(iyy+5),(my+.0005)/(iyy-5),(my+.0005)/(iyy+5)]*180/pi;
 if s.speed_kt==80,hq=5e-8;else,hq=5e-6;end
 qdot=my/iyy*180/pi;ok=min(cand)<=s.qdot_deg_s2+hq&&max(cand)>=s.qdot_deg_s2-hq;check(ok);
 moments=[moments;s.speed_kt,my,iyy,s.qdot_deg_s2,qdot,min(cand),max(cand),ok]; %#ok<AGROW>
 % Replay original state and DIRECT logged induced velocity; lambda is not
 % treated as pure induced velocity. The logged TIP SPEED is not substituted
 % for Omega*R. Rotor body force rows exclude the separately logged spinner.
 P=P0;P.env.rho=rho*slug/ft^3;P.rotor.Omega=s.rpm*2*pi/60;P.rotor.R=s.rotor_radius_ft*ft;
 P.wing.S=s.wing_area_ft2*ft^2;
 x=zeros(9,1);x(1)=u*ft;x(3)=w*ft;x(8)=s.theta_deg*pi/180;
 fl=loadrow(H,'ROTOR_LEFT');fr=loadrow(H,'ROTOR_RIGHT');
 rl=struct('F',fl(1:3).'*lbf,'mu',s.mu,'muLong',s.mu,'muLat',0,'inducedVelocity',s.induced_ft_s*ft);
 rr=struct('F',fr(1:3).'*lbf,'mu',s.mu,'muLong',s.mu,'muLat',0,'inducedVelocity',s.induced_ft_s*ft);
 U=zeros(7,1);mp=mass_properties(0,P);
 [Fc,Mc,oc]=wing_model_freefield_consistent(x,U,0,mp.cgShift,rl,rr,P);wingCalls=wingCalls+1;
 % Zero coverage is an explicit all-free diagnostic endpoint, NOT an area
 % identified from the source's zero immersed FORCE rows.
 Pfree=P;Pfree.wing.SslipMaxHalf=0;
 [Ff,Mf,of]=wing_model_freefield_consistent(x,U,0,mp.cgShift,rl,rr,Pfree);wingCalls=wingCalls+1;
 check(of.SslipHalf==0&&abs(2*of.SfreeHalf-P.wing.S)<1e-12);
 a=of.freefield.alphaWing_deg*pi/180;[cl,cd,cm]=gtrs_wing_heli_coefficients(a,norm(x(1:3))/P.env.aSound);
 % Independent customary-unit force calculation, not numerical re-fitting.
 L=q*s.wing_area_ft2*cl;drag=q*s.wing_area_ft2*cd;
 fUS=[-drag*cos(a)+L*sin(a);0;-drag*sin(a)-L*cos(a)];
 check(norm(Ff/lbf-fUS)<1e-6);check(abs(of.qbarFree/(lbf/ft^2)-q)<1e-8);
 % Diagnostic inverse under stated full-area/V6-angle assumptions. These
 % quantities NEVER enter gtrs_wing_heli_coefficients, P or a trim objective.
 clEq=(wf(1)*sin(a)-wf(3)*cos(a))/(q*s.wing_area_ft2);
 cdEq=(-wf(1)*cos(a)-wf(3)*sin(a))/(q*s.wing_area_ft2);
 fReconstruct=q*s.wing_area_ft2*[-cdEq*cos(a)+clEq*sin(a);0;-cdEq*sin(a)-clEq*cos(a)];
 check(norm(fReconstruct-wf(1:3).')<1e-10);
 % Isolate old rounded density at the same original state/rotor input.
 Pd=Pfree;Pd.env.rho=P0.env.rho;
 [Fd,Md,od]=wing_model_freefield_consistent(x,U,0,mp.cgShift,rl,rr,Pd);wingCalls=wingCalls+1;
 row=[s.speed_kt,q,of.freefield.alphaWing_deg,cl,cd,clEq,cdEq,clEq-cl,cdEq-cd, ...
  Fc(1)/lbf,Fc(3)/lbf,Mc(2)/(lbf*ft),Ff(1)/lbf,Ff(3)/lbf,Mf(2)/(lbf*ft),wf([1 3 4]), ...
  Fd(1)/lbf,Fd(3)/lbf,Fd(3)/lbf-Ff(3)/lbf,of.freefield.deflection_deg,s.induced_ft_s];
 rows=[rows;row]; %#ok<AGROW>
 alloc=xv15_helicopter_control_allocation(s.stick_in,0,P);
 control=[control;s.speed_kt,s.stick_in,s.elevator_deg,alloc.elevator*180/pi,alloc.elevator*180/pi-s.elevator_deg]; %#ok<AGROW>
 records{k}=struct('originalInput',s,'sourceLoads',H,'P',P,'state',x,'rotorLeft',rl,'rotorRight',rr, ...
  'currentAreaWing',oc,'allFreeWing',of,'oldDensityWing',od,'clEquivalentDiagnosticOnly',clEq,'cdEquivalentDiagnosticOnly',cdEq);
end
check(isequaln(Pbefore,P0));
% Previously used source table entries are explicitly rechecked, not adjusted
% to reproduce derived reference coefficients. B36/B37, betaM=0, flap40/25.
[cl,cd,cm]=gtrs_wing_heli_coefficients([-12 -8 -4 0]*pi/180,.1);
check(max(abs(cl-[.0628 .291 .518 .749]))<1e-12);
check(max(abs(cd-[.253 .267 .307 .345]))<1e-12);check(all(cm==-.110));
A=array2table(rows,'VariableNames',{'speed_kt','qbarSource_psf','v6FreeAlpha_deg','CL_table','CD_table', ...
 'CL_equiv_fullArea_V6angle','CD_equiv_fullArea_V6angle','deltaCL_diagnostic','deltaCD_diagnostic', ...
 'currentAreaX_lbf','currentAreaZ_lbf','currentAreaM_lbfft','allFreeX_lbf','allFreeZ_lbf','allFreeM_lbfft', ...
 'originalWingX_lbf','originalWingZ_lbf','originalWingM_lbfft','oldDensityAllFreeX_lbf','oldDensityAllFreeZ_lbf', ...
 'densityOnlyDeltaZ_lbf','v6Deflection_deg','originalInduced_ft_s'});
S=cell2table(closure,'VariableNames',{'speed_kt','aggregation','maxAbsPrintedDifference','roundingBound','withinRounding', ...
 'deltaX_lbf','deltaY_lbf','deltaZ_lbf','deltaM_lbfft'});
O=cell2table(omitted,'VariableNames',{'speed_kt','omittedAirframeX_lbf','omittedAirframeZ_lbf','omittedAirframeM_lbfft', ...
 'spinnerX_lbf','spinnerZ_lbf','spinnerM_lbfft'});
Q=array2table(pressure,'VariableNames',{'speed_kt','qCalculated_psf','qPrinted_psf','qLowerFromRounding_psf','qUpperFromRounding_psf','roundingOverlap'});
J=array2table(moments,'VariableNames',{'speed_kt','aircraftM_lbfft','Iyy_slug_ft2','qdotOriginal_deg_s2','qdotFromMoment_deg_s2','qdotLower','qdotUpper','roundingOverlap'});
E=array2table(control,'VariableNames',{'speed_kt','originalStick_in','originalElevator_deg','currentMappedElevator_deg','difference_deg'});
writetable(A,fullfile(outputRoot,'UNIT_AREA_SOURCE_COMPARISON.csv'));writetable(S,fullfile(outputRoot,'ORIGINAL_AGGREGATE_CLOSURE.csv'));
writetable(O,fullfile(outputRoot,'ORIGINAL_OMITTED_COMPONENTS.csv'));writetable(Q,fullfile(outputRoot,'ORIGINAL_PRESSURE_ROUNDING.csv'));
writetable(J,fullfile(outputRoot,'ORIGINAL_PITCH_ACCELERATION.csv'));writetable(E,fullfile(outputRoot,'ORIGINAL_CONTROL_MAPPING.csv'));
[~,head]=system('git rev-parse HEAD');
meta=struct('identity','ORIGINAL_REFERENCE_AND_UNIT_AREA_AUDIT','head',strtrim(head),'version',version,'release',version('-release'), ...
 'elapsed_s',toc(t0),'checksPassed',checks,'directWingCalls',wingCalls,'rotorSolves',0,'aircraftTrimSolves',0, ...
 'productionPhysicsChanged',false,'targetFit',false,'equivalentCoefficientsUsedAsInput',false,'referenceRole','ORIGINAL_GTRS_SIMULATION_NOT_FLIGHT_DATA', ...
 'sourcePdfSha256','9a0888d19929747d079e79582c5172f5ea0ac526e14de87a0547b5ee2ae6340a', ...
 'loggedImmersedForcesZero',true,'physicalZeroAreaIdentified',false,'oldThesisCarrierOverwritten',false, ...
 'allSummationsCloseWithinPrintedRounding',all(S.withinRounding),'allPressureRoundingsOverlap',all(Q.roundingOverlap), ...
 'allPitchAccelerationRoundingsOverlap',all(J.roundingOverlap),'externalAccuracyPass',false);
result=struct('meta',meta,'unitArea',A,'aggregation',S,'omitted',O,'pressure',Q,'pitchAcceleration',J,'control',E,'records',{records},'contract',contract);
save(fullfile(outputRoot,'ORIGINAL_UNIT_LOAD_RESULTS.mat'),'result');
fid=fopen(fullfile(outputRoot,'ORIGINAL_UNIT_LOAD_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear c;
disp(A);disp(S);disp(J);disp(meta);
 function check(b),assert(b,'Original-reference audit check failed.');checks=checks+1;end
 function add_closure(name,lhs,rhs,nTerms)
  diff=lhs-rhs;bound=.0005*(nTerms+1)+1e-9;ok=max(abs(diff))<=bound;check(ok);
  closure(end+1,:)=[{s.speed_kt,name,max(abs(diff)),bound,ok},num2cell(diff)];
 end
end
function r=loadrow(T,name)
 mask=strcmp(T.component,name);assert(sum(mask)==1,['Missing/duplicate source component: ' name]);
 r=[T.X_lbf(mask),T.Y_lbf(mask),T.Z_lbf(mask),T.M_lbfft(mask)];
end
function r=loadsum(T,names)
r=zeros(1,4);for j=1:numel(names),r=r+loadrow(T,names{j});end
end
