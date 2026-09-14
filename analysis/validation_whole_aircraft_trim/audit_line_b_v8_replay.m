function rows=audit_line_b_v8_replay(pointFile,outputDir)
% Re-evaluate an accepted continuation point with cold and tracked flap seeds.
% State, controls and physical parameters are fixed; no target data are read.
S=load(pointFile); assert(S.rec.row.numericallyAccepted);
if ~exist(outputDir,'dir'),mkdir(outputDir);end
z=S.rec.z; V=S.rec.row.speed_mps; beta=S.rec.row.betaM_deg*pi/180;
x=zeros(9,1); x(1)=V*cos(z(1));x(3)=V*sin(z(1));x(8)=z(1);
rows=struct([]);details=cell(2,1);
for k=1:2
 P=S.P;
 if k==1 && isfield(P,'stage2Numerics'),P=rmfield(P,'stage2Numerics');end
 if k==2
  P.stage2Numerics.flapInitialLeft=S.rec.point.eomOut.rotorLeft.zFlap;
  P.stage2Numerics.flapInitialRight=S.rec.point.eomOut.rotorRight.zFlap;
 end
 if strcmp(S.rec.mode,'airplane_independent_elevator'),u=[z(2);0;0;0;0;z(3);0];
 else,a=xv15_gtrs_control_allocation_source(z(3),beta,P);u=[z(2);0;a.cyclicLong;0;0;a.elevator;0];end
 [dx,out]=stage2_tiltrotor_eom('M1_CONTINUOUS_CORRIGAN_V4',x,u,beta,P);
 r=dx([1 3 5]);r(1:2)=r(1:2)/P.env.g;
 row=struct('trackedFlapSeed',k==2,'residualNorm',norm(r),...
  'maxXdotChange',max(abs(dx-S.rec.point.xdot)),...
  'physicalConverged',out.physicalConverged,'physicalBranchSupported',out.physicalBranchSupported,...
  'alphaClampCount',out.rotorLeft.alphaClampCount+out.rotorRight.alphaClampCount,...
  'power_kW',(out.rotorLeft.torque+out.rotorRight.torque)*P.rotor.Omega/1000);
 if k==1,rows=row;else,rows(k,1)=row;end
 details{k}=out;
end
writetable(struct2table(rows),fullfile(outputDir,'FIXED_STATE_REPLAY.csv'));
save(fullfile(outputDir,'FIXED_STATE_REPLAY.mat'),'rows','details','pointFile');disp(struct2table(rows));
end
