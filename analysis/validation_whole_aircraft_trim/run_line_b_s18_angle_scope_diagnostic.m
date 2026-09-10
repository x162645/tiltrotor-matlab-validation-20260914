function result=run_line_b_s18_angle_scope_diagnostic(outputRoot)
%RUN_LINE_B_S18_ANGLE_SCOPE_DIAGNOSTIC
% 有界诊断：比较原始CR166537机翼载荷在机体角和V6自由流有效角下，
% 对CR166536 RevA源表升力/阻力系数的解释，以及输出部件范围的未决项。
% 本程序只读取S15已归档输入/载荷并调用现有源表函数；不修改生产参数，
% 不反求面积/增益，不进行整机配平或旋翼回归。
if nargin<1
    outputRoot=fullfile(pwd,'ci_artifacts','s18_angle_scope');
end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
here=fileparts(mfilename('fullpath'));dataRoot=fullfile(here,'data');
D=readtable(fullfile(dataRoot,'CR166537_HELI_4POINT_INPUTS.csv'));
C=readtable(fullfile(dataRoot,'CR166537_HELI_4POINT_LOADS.csv'));
assert(height(D)==4&&height(C)==68,'Expected four archived source cases.');
P0=line_b_coherent_tail_parameters(xv15_helicopter_trim_parameters_v1());
ft=.3048;lbf=4.4482216152605;slug=14.59390294;
rows=zeros(height(D),21);checks=0;t0=tic;
for k=1:height(D)
    s=D(k,:);H=C(C.speed_kt==s.speed_kt,:);
    wing=source_row(H,'WING_FREESTREAM');
    left=source_row(H,'ROTOR_LEFT');right=source_row(H,'ROTOR_RIGHT');
    alphaBody=atan2(s.w_ft_s,s.u_ft_s)*180/pi;
    P=P0;P.env.rho=s.rho_slug_ft3*slug/ft^3;
    P.env.aSound=340;P.rotor.Omega=s.rpm*2*pi/60;
    P.rotor.R=s.rotor_radius_ft*ft;
    fl=left(1:3).'*lbf;fr=right(1:3).'*lbf;
    cf=(norm(fl)+norm(fr))/(P.env.rho*pi*P.rotor.Omega^2*P.rotor.R^4);
    [alphaV6,field]=gtrs_wing_freefield_angle(alphaBody,cf,s.mu);
    [clBody,cdBody]=gtrs_wing_heli_coefficients(alphaBody*pi/180,...
        hypot(s.u_ft_s,s.w_ft_s)*ft/P.env.aSound);
    [clV6,cdV6]=gtrs_wing_heli_coefficients(alphaV6*pi/180,...
        hypot(s.u_ft_s,s.w_ft_s)*ft/P.env.aSound);
    q=s.qbar_psf;S=s.wing_area_ft2;
    clEqBody=(wing(1)*sind(alphaBody)-wing(3)*cosd(alphaBody))/(q*S);
    cdEqBody=(-wing(1)*cosd(alphaBody)-wing(3)*sind(alphaBody))/(q*S);
    clEqV6=(wing(1)*sind(alphaV6)-wing(3)*cosd(alphaV6))/(q*S);
    cdEqV6=(-wing(1)*cosd(alphaV6)-wing(3)*sind(alphaV6))/(q*S);
    % Local source-table branch is monotone from -16 to +12 deg; inversion
    % is a diagnostic angle label, never a parameter update or fit.
    gridDeg=[-16 -12 -8 -4 0 4 8 11 12];
    [clGrid,~,~]=gtrs_wing_heli_coefficients(gridDeg*pi/180,...
        hypot(s.u_ft_s,s.w_ft_s)*ft/P.env.aSound);
    alphaReq=interp1(clGrid,gridDeg,clEqV6,'linear','extrap');
    omitted=source_row(H,'ENGINE_PYLONS')+source_row(H,'JET_THRUST_TOTAL');
    spinner=source_row(H,'HUB_SPINNER');
    sourceAngleLiftDeltaZ=-q*S*(clBody-clV6);
    rows(k,:)=[s.speed_kt,alphaBody,alphaV6,field.deflection_deg, ...
        clEqBody,clEqV6,clBody,clV6,clEqBody-clBody,clEqV6-clV6, ...
        cdEqBody,cdEqV6,cdBody,cdV6,alphaReq,alphaReq-alphaV6, ...
        clEqV6/clV6,sourceAngleLiftDeltaZ,omitted(1),omitted(3),spinner(3)];
    checks=checks+10;
end
% Recheck the exact source-table anchors already used by S15; this guards
% against a changed source function without recertifying its output version.
[clA,cdA,cmA]=gtrs_wing_heli_coefficients([-12 -8 -4 0]*pi/180,.1);
assert(max(abs(clA-[.0628 .291 .518 .749]))<1e-12);checks=checks+1;
assert(max(abs(cdA-[.253 .267 .307 .345]))<1e-12);checks=checks+1;
assert(all(cmA==-.110));checks=checks+1;
T=array2table(rows,'VariableNames',{'speed_kt','alphaBody_deg','alphaV6_deg',...
    'V6Deflection_deg','CL_equiv_body','CL_equiv_V6','CL_source_body',...
    'CL_source_V6','deltaCL_body','deltaCL_V6','CD_equiv_body','CD_equiv_V6',...
    'CD_source_body','CD_source_V6','alphaRequiredFromCLV6_deg',...
    'requiredShiftFromV6_deg','areaRatioAtV6','sourceAngleLiftDeltaZ_lbf',...
    'omittedEnginePylonJetX_lbf','omittedEnginePylonJetZ_lbf','sourceSpinnerM_lbfft'});
writetable(T,fullfile(outputRoot,'S18_ANGLE_SCOPE_DIAGNOSTIC.csv'));
meta=struct('identity','S18_ANGLE_SCOPE_DIAGNOSTIC', ...
    'sourcePages','CR166537 PDF100/101,103/104,106/107,109/110; CR166536 A70/B33/B36-B37/B41-B42/B51', ...
    'method','Archived four-point source replay; body-angle versus V6 alpha_WFS; diagnostic inverse only', ...
    'sourceCoeffIdentity','CR166536_REVA_B36_B37_B41_B42_B51', ...
    'outputVersionIdentity','OPEN_NOT_PROVEN_IDENTICAL_TO_CR166536_REVA', ...
    'componentScope','Original WING_FREESTREAM plus separate ENGINE_PYLONS/JET_THRUST_TOTAL; source table containsPylonEffects=true', ...
    'checksPassed',checks,'directWingCalls',0,'rotorSolves',0,'aircraftTrimSolves',0, ...
    'productionPhysicsChanged',false,'targetFit',false,'externalAccuracyPass',false, ...
    'sourcePdfSha256','9a0888d19929747d079e79582c5172f5ea0ac526e14de87a0547b5ee2ae6340a', ...
    'coefficientPdfSha256','a2013a314af5beb0c5e9bc5bbeb26f99be9a8aa63f2ebe07deaaf11d0d44d67d', ...
    'elapsed_s',toc(t0));
save(fullfile(outputRoot,'S18_ANGLE_SCOPE_DIAGNOSTIC.mat'),'T','meta');
fid=fopen(fullfile(outputRoot,'S18_ANGLE_SCOPE_DIAGNOSTIC.json'),'w');assert(fid>=0);
c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear c;
disp(T);disp(meta);
result=struct('table',T,'meta',meta);
end

function r=source_row(T,name)
mask=strcmp(T.component,name);assert(sum(mask)==1,['Missing/duplicate component: ' name]);
r=[T.X_lbf(mask),T.Y_lbf(mask),T.Z_lbf(mask),T.M_lbfft(mask)];
end
