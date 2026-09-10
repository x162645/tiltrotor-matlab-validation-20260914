function result=run_line_b_source_tail_replay(outputRoot)
% Conditional component replay, not whole-aircraft validation.
% All input states, rotor forces/inflow ratios and elevator angles are from
% Kleinhesselink2007 TableC1 PDF191/192/195-198. Tail loads are output-only.
% Source lambda conversion: CR166536 A18/A20/A24/A25 PDF86/88/92/93:
% lambda0=-WHM/(OmegaR); lambda=lambda0+lambda_i; Wi=lambda_i*OmegaR.
% At betaM=0, zero rates/sideslip, WHM=W*cos(phiM). phiM=1deg, B31.
% Thus Wi=lambda*OmegaR+W*cos(1deg); lambda*OmegaR alone is NOT Wi.
% GTRS input/output table rounding and internal inconsistencies retained.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
[P0,~]=xv15_helicopter_trim_parameters_v1();P3=line_b_coherent_tail_parameters(P0);
mp=mass_properties(0,P0);f2N=4.4482216152605;ft2m=.3048;d2r=pi/180;
speed=[40 60 80 100];theta=[-2.52 -5.69 -9.35 -12.61];
u=[67.45 100.80 133.20 164.70];w=[-2.97 -10.04 -21.93 -36.86];
lam=[.0498 .0441 .0525 .0694];mu=[.0875 .1307 .1728 .2136];
de=[1.27 2.34 4.71 10.13];
Fleft=[-24.56 -367.07 -6091.71;-82.60 -303.83 -5931.49; ...
 -137.55 -243.07 -6177.51;-123.95 -212.19 -6898.03];
Fright=Fleft;Fright(:,2)=-Fright(:,2);Fright(2,1)=-82.59;
ref=[-3.86 -75.39 -1619;-9.95 -78.06 -1665.8; ...
 -10.67 31.09 689.59;26.08 320.06 6856.2];
rows=[];records={};
for k=1:4
 x=zeros(9,1);x(1)=u(k)*ft2m;x(3)=w(k)*ft2m;x(8)=theta(k)*d2r;
 vi=lam(k)*P0.rotor.Omega*P0.rotor.R+x(3)*cos(d2r);
 assert(vi>0,'Unexpected negative source-induced velocity.');
 rl=struct('inducedVelocity',vi,'F',Fleft(k,:).'*f2N,'mu',mu(k));
 rr=struct('inducedVelocity',vi,'F',Fright(k,:).'*f2N,'mu',mu(k));
 flow=rotor_tail_interference_heli(x,0,rl,rr,P3);
 for v=1:3
  if v==1,[F,M,d]=horizontal_tail_model(x,de(k)*d2r,mp.cgShift,P0);
  elseif v==2,[F,M,d]=horizontal_tail_model(x,de(k)*d2r,mp.cgShift,P0,flow);
  else,[F,M,d]=horizontal_tail_model(x,de(k)*d2r,mp.cgShift,P3,flow);end
  load=[F(1)/f2N F(3)/f2N M(2)/(f2N*ft2m)];
  ep=NaN;eta=NaN;aw=NaN;
  if v==3,ep=d.wingDownwash_deg;eta=d.eta;aw=d.wingFreeAlpha_deg;end
  rows=[rows;speed(k),v,vi,de(k),load,ref(k,:),load-ref(k,:),d.alphaEff/d2r,d.qbar,ep,eta,aw]; %#ok<AGROW>
  records{end+1}=struct('x',x,'rotorLeft',rl,'rotorRight',rr,'flow',flow,'tail',d); %#ok<AGROW>
 end
end
A=array2table(rows,'VariableNames',{'speed_kt','variant','sourceVi_mps','elevator_deg', ...
 'X_lbf','Z_lbf','M_lbfft','refX_lbf','refZ_lbf','refM_lbfft', ...
 'dX_lbf','dZ_lbf','dM_lbfft','alphaEff_deg','qH_Pa','wingDownwash_deg','eta','wingAlpha_deg'});
writetable(A,fullfile(outputRoot,'SOURCE_INPUT_TAIL_REPLAY.csv'));disp(A);
[~,head]=system('git rev-parse HEAD');
result=struct('table',A,'records',{records},'head',strtrim(head),'version',version, ...
 'release',version('-release'),'identity','SOURCE_INPUT_CONDITIONAL_TAIL_REPLAY', ...
 'variants',{{'V1_ORIGINAL','V2_VELOCITY_ONLY','V3_COHERENT'}}, ...
 'claim','Uses external rotor-state inputs. Not independent rotor/whole-aircraft/flight validation.');
save(fullfile(outputRoot,'SOURCE_INPUT_TAIL_REPLAY.mat'),'result');
end
