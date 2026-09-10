function result=run_line_b_source_airframe_replay(outputRoot)
% Conditional wing/fuselage replay continuing the existing source-tail audit.
% Inputs: Kleinhesselink2007 TableC1 PDF191/192/195-198; no rotor solver.
% Uses the previously frozen lambda->Wi conversion, not lambda*OmegaR alone.
% Fuselage source check: CR166536 RevA A44/B26-B28 (PDF112/376-378).
% At beta=0: Lbeta+LBFO=0, Dbeta+DBFO=0, Mbeta+MBFO=0.
% DLANG=-0.5ft^2 remains as printed. Landing-gear pod DPOD=1.15ft^2
% belongs to subsystem7 (B82/PDF432), NOT silently folded into fuselage.
% Source parameter comparison does not establish the exact 2007 GTRS version.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
[P,contract]=xv15_helicopter_trim_parameters_v1();mp=mass_properties(0,P);
% Reuse exact existing input construction; the 12 cheap tail calls also
% preserve an executable reference to the previous conditional audit.
base=run_line_b_source_tail_replay(outputRoot);f2N=4.4482216152605;ft2m=.3048;
speed=[40 60 80 100];refWing=[-350.07 -719.31 451.96;-743.88 -1035.99 478.28; ...
 -1154.73 -676.32 -322.31;-1523.96 368.16 -2026.30];
refFus=[-15.85 -26.14 -598.52;-42.62 -21.25 -2107.49; ...
 -104 44.09 -5308.99;-229.31 196.52 -10466.28];
% Original source table's forward-flow subset, no fitted constants.
aGrid=[-24 -20 -16 -12 -8 -4 0 4 8 12 16 20 24];
Larea=[-15 -10.87 -7.25 -3.63 -.01 3.61 7.23 10.85 14.47 18.09 21.71 25.33 28];
Darea=[20 15.39 10.78 6.17 3 1.8 1.56 1.8 2.3 3.67 5.78 7.89 10];
Mvolume=[-430 -380 -370 -295 -219 -142.5 -66.5 9.5 85.5 123.5 142.5 133 95];
rows=[];sourceRows=[];records=cell(4,1);
for k=1:4
 in=base.records{3*(k-1)+1};x=in.x;rl=in.rotorLeft;rr=in.rotorRight;
 % The existing wing API uses a zero-tilt disk basis and directional mu.
 % beta=0 -> lateral mu=0. Its axis convention is not changed to source1deg.
 rl.muLong=rl.mu;rr.muLong=rr.mu;rl.muLat=0;rr.muLat=0;
 rl.eT=[0;0;-1];rr.eT=rl.eT;uCtrl=zeros(7,1);
 [Fw,Mw,dw]=wing_model(x,uCtrl,0,mp.cgShift,rl,rr,P);
 [Ff,Mf,df]=fuselage_model(x,mp.cgShift,P);
 loadsW=[Fw(1)/f2N,Fw(3)/f2N,Mw(2)/(f2N*ft2m)];
 loadsF=[Ff(1)/f2N,Ff(3)/f2N,Mf(2)/(f2N*ft2m)];
 assert(isreal([Fw;Mw;Ff;Mf])&&all(isfinite([Fw;Mw;Ff;Mf])));
 rows=[rows;speed(k),1,loadsW,refWing(k,:),loadsW-refWing(k,:); ...
  speed(k),2,loadsF,refFus(k,:),loadsF-refFus(k,:)]; %#ok<AGROW>
 a=atan2(x(3),x(1));ad=a*180/pi;q=.5*P.env.rho*norm(x(1:3))^2;
 qImperial=q*ft2m^2/f2N;
 Da=interp1(aGrid,Darea,ad,'linear');La=interp1(aGrid,Larea,ad,'linear');Ma=interp1(aGrid,Mvolume,ad,'linear');
 assert(all(isfinite([Da La Ma])),'Outside source subset.');
 sourceD=q*(Da-.5)*ft2m^2;sourceL=q*La*ft2m^2;
 Fs=aero_force_body(sourceD,0,sourceL,a,0);
 % Moment not scored: source's intrinsic moment reference not yet tied to
 % current equivalent fuselage rAC. Store original M/q only.
 referenceD=-refFus(k,1)*cos(a)-refFus(k,2)*sin(a);
 observedArea=referenceD/qImperial;
 sourceRows=[sourceRows;speed(k),ad,qImperial,Da,Da-.5,observedArea, ...
  observedArea-Da,Fs(1)/f2N,Fs(3)/f2N,La,Ma]; %#ok<AGROW>
 records{k}=struct('input',in,'wing',dw,'fuselage',df,'sourceFuselageForce',Fs, ...
  'sourceLiftArea_ft2',La,'sourceDragArea_ft2',Da-.5,'sourceMomentVolume_ft3',Ma);
end
A=array2table(rows,'VariableNames',{'speed_kt','componentCode','X_lbf','Z_lbf','M_lbfft', ...
 'refX_lbf','refZ_lbf','refM_lbfft','dX_lbf','dZ_lbf','dM_lbfft'});
B=array2table(sourceRows,'VariableNames',{'speed_kt','alpha_deg','q_lbf_ft2','tableDalpha_ft2', ...
 'sourceNetDragArea_ft2','referenceResolvedDragArea_ft2','referenceMinusDalpha_ft2', ...
 'sourceX_lbf','sourceZ_lbf','tableLalpha_ft2','tableMalpha_ft3'});
writetable(A,fullfile(outputRoot,'SOURCE_INPUT_AIRFRAME_REPLAY.csv'));
writetable(B,fullfile(outputRoot,'FUSELAGE_SOURCE_DEFINITION_CHECK.csv'));
[~,head]=system('git rev-parse HEAD');
result=struct('identity','SOURCE_INPUT_WING_FUSELAGE_CONDITIONAL_REPLAY', ...
 'head',strtrim(head),'version',version,'release',version('-release'),'records',{records}, ...
 'table',A,'fuselageSource',B,'contract',contract,'newRotorEvaluations',0,'newTrimSearches',0, ...
 'referenceRole','GTRS_REFERENCE_SIMULATION_WITH_DOCUMENTED_TABLE_CONFLICTS', ...
 'componentCodes',{{'1=wing','2=fuselage'}},'modelChanged',false, ...
 'claim','Wing row may include wing-pylon loads absent from code. No unique causal budget or accuracy PASS.', ...
 'sourceFuselageScope','Original RevA source-only force diagnostic; no unidentified offset added and no promotion.');
save(fullfile(outputRoot,'SOURCE_INPUT_AIRFRAME_REPLAY.mat'),'result','P');
meta=rmfield(result,{'records','table','fuselageSource','contract'});
fid=fopen(fullfile(outputRoot,'AIRFRAME_REPLAY_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta));clear c;
disp(A);disp(B);disp(meta);
end
