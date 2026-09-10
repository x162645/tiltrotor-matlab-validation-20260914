function result=run_line_b_coverage_only_envelope(outputRoot)
%RUN_LINE_B_COVERAGE_ONLY_ENVELOPE Bounded diagnosis, NOT a new wing model.
% Continue after V6: can area ALONE explain the same-input wing discrepancy?
% Use existing source-state fixture (Kleinhesselink Table C-1) and exact V6
% coefficients/local velocities. No rotor solve, trim search or source fit.
% For fixed fields the regional forces are affine in covered area a:
% F(a)=sum_sides[(S_half-a)*f_free+a*f_immersed]. Intrinsic V6 moment is
% independent of a. Therefore endpoints bound each component on the whole
% interval 0<=a<=S_half, even beyond the old SslipMaxHalf=4m^2 cap.
% This relaxed interval is a mathematical upper bound, NOT a feasible wake
% footprint assertion. Centroids/fields/coefficients do not change with a.
% No inverse solve for a or recommendation of a fitted coverage parameter.
% Source reference conflicts and U/W rounding remain. Output discrepancies
% are descriptive; a tiny endpoint miss is NOT a physical-accuracy failure.
if nargin<1,outputRoot=fullfile(pwd,'ci_artifacts','coverage_only');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
[P,~]=xv15_helicopter_trim_parameters_v1();P=line_b_coherent_tail_parameters(P);Pbefore=P;
mp=mass_properties(0,P);S=P.wing.S/2;f2N=4.4482216152605;ft2m=.3048;
fixture=run_line_b_source_tail_replay(fullfile(outputRoot,'existing_fixture'));
ref=[-350.07 -719.31 451.96;-743.88 -1035.99 478.28; ...
     -1154.73 -676.32 -322.31;-1523.96 368.16 -2026.30];
speeds=[40 60 80 100];nCheck=0;wingCalls=0;rows=[];details={};trace={};
for k=1:4
 in=fixture.records{3*(k-1)+1};x=in.x;L=in.rotorLeft;R=in.rotorRight;
 L.muLong=L.mu;R.muLong=R.mu;L.muLat=0;R.muLat=0;u=zeros(7,1);
 [Fb,Mb,o]=wing_model_freefield_consistent(x,u,0,mp.cgShift,L,R,P);wingCalls=wingCalls+1;
 check(o.SslipHalf>0&&o.SfreeHalf>0);
 g=(sin(1.386*pi/2)+cos(3.114*pi/2))*(P.wing.muMax-o.muMean)/P.wing.muMax;
 check(g>0&&g<1);areas=[0,o.SslipHalf,S/2,S];states=cell(4,1);
 for j=1:numel(areas)
  a=areas(j);[F,M]=recombine(a,o,S);
  Q=P;Q.wing.SslipMaxHalf=a/g; % forward mapping to a PRESCRIBED test area
  [Fd,Md,od]=wing_model_freefield_consistent(x,u,0,mp.cgShift,L,R,Q);wingCalls=wingCalls+1;
  check(abs(od.SslipHalf-a)<1e-12*max(1,S));
  check(norm(F-Fd)<1e-10*max(1,norm(Fd)));
  check(norm(M-Md)<1e-10*max(1,norm(Md)));
  check(isequal(o.Maero,od.Maero));
  for h=1:4
   a0=o.regions{h};a1=od.regions{h};
   check(isequal(a0.Vlocal,a1.Vlocal)&&a0.alpha==a1.alpha&&a0.qbar==a1.qbar);
   check(a0.CL==a1.CL&&a0.CD==a1.CD);
  end
  states{j}=struct('prescribedArea_m2',a,'F',F,'M',M,'directF',Fd,'directM',Md);
  trace(end+1,:)={speeds(k),a,a/S,F(1)/f2N,F(3)/f2N,M(2)/(f2N*ft2m),norm(F-Fd),norm(M-Md)}; %#ok<AGROW>
 end
 check(norm(states{2}.F-Fb)<1e-10*max(1,norm(Fb)));
 check(norm(states{2}.M-Mb)<1e-10*max(1,norm(Mb)));
 ends=[load_row(states{1}.F,states{1}.M);load_row(states{4}.F,states{4}.M)];
 lo=min(ends,[],1);hi=max(ends,[],1);distance=max(max(lo-ref(k,:),ref(k,:)-hi),0);
 actual=load_row(Fb,Mb);
 rows=[rows;speeds(k),o.SslipHalf,S, ...
   o.regions{1}.alpha*180/pi,o.regions{2}.alpha*180/pi,L.inducedVelocity, ...
   actual,ref(k,:),lo,hi,distance]; %#ok<AGROW>
 details{k}=struct('input',in,'baseline',o,'areaEndpointStates',{states}, ...
   'referenceXZM',ref(k,:),'loXZM',lo,'hiXZM',hi,'componentwiseDistance',distance);
end
check(isequaln(P,Pbefore));
A=array2table(rows,'VariableNames',{'speed_kt','baselineCoveredAreaPerSide_m2','halfWingArea_m2', ...
 'freeAlpha_deg','immersedAlpha_deg','inducedVelocity_mps', ...
 'baselineX_lbf','baselineZ_lbf','baselineM_lbfft','referenceX_lbf','referenceZ_lbf','referenceM_lbfft', ...
 'minX_lbf','minZ_lbf','minM_lbfft','maxX_lbf','maxZ_lbf','maxM_lbfft', ...
 'referenceDistanceFromXEnvelope_lbf','referenceDistanceFromZEnvelope_lbf','referenceDistanceFromMEnvelope_lbfft'});
B=cell2table(trace,'VariableNames',{'speed_kt','prescribedCoveredArea_m2','fractionHalfWing', ...
 'X_lbf','Z_lbf','M_lbfft','directRecombineForceDifference_N','directRecombineMomentDifference_Nm'});
writetable(A,fullfile(outputRoot,'COVERAGE_ONLY_ENVELOPE.csv'));
writetable(B,fullfile(outputRoot,'AREA_ENDPOINT_REPLAY.csv'));
[~,head]=system('git rev-parse HEAD');
meta=struct('identity','V6_FROZEN_FIELD_COVERAGE_ONLY_ENVELOPE','head',strtrim(head), ...
 'baselinePhysics','38f6ab2bcb42140577c013025cf797ff248df867','version',version,'release',version('-release'), ...
 'checksPassed',nCheck,'wingEvaluations',wingCalls,'sourceCases',4,'prescribedAreasPerCase',4, ...
 'newRotorEvaluations',0,'newTrimSearches',0,'productionPhysicsChanged',false, ...
 'coverageFittedToReference',false,'allPhysicallyPossibleWakeAreasClaimed',false, ...
 'referenceRole','PUBLISHED_GTRS_CONDITIONAL_COMPARISON_WITH_KNOWN_SOURCE_CONFLICTS', ...
 'conclusionScope','Only area changes at frozen fields/coefficients are bounded; no conclusion about re-trimmed aircraft or coupled wake changes.', ...
 'accuracyPassAssigned',false);
result=struct('meta',meta,'summary',A,'evaluations',B,'details',{details});
save(fullfile(outputRoot,'COVERAGE_ONLY_RESULTS.mat'),'result','P');
fid=fopen(fullfile(outputRoot,'COVERAGE_ONLY_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta));clear c;
disp(A(:,{'speed_kt','baselineZ_lbf','referenceZ_lbf','minZ_lbf','maxZ_lbf','referenceDistanceFromZEnvelope_lbf'}));disp(meta);
 function check(tf),assert(tf,'Coverage-envelope implementation check failed.');nCheck=nCheck+1;end
 function v=load_row(F,M),v=[F(1)/f2N,F(3)/f2N,M(2)/(f2N*ft2m)];end
end
function [F,M]=recombine(a,o,S)
F=zeros(3,1);M=o.Maero;
for j=1:4
 r=o.regions{j};if r.inSlipstream,area=a;else,area=S-a;end
 load=(area/r.S)*r.F;F=F+load;M=M+cross(r.rAC,load);
end
end
