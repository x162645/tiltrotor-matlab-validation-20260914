function result=run_line_b_flap_local_diagnostic(outputRoot)
% Pure instrumentation of the existing forward rotor; no new trim search.
% Generated analysis copy only adds trace fields and captures existing exits.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
source=fullfile(root,'analysis','stage2_aircraft','m1_evidence_v1_forward_rotor.m');
s=fileread(source);instrumented=strrep(s,'m1_evidence_v1_forward_rotor','line_b_instrumented_rotor');
a=strfind(instrumented,'    function [z,info]=solve_flap');
b=strfind(instrumented,'    function [res,scale]=flap_residual');
assert(numel(a)==1&&numel(b)==1,'Cannot locate exact solver section.');
section=instrumented(a:b-1);
section=replace_one(section,"info=struct('converged',false,'iterations',0,'residualNorm',Inf);", ...
 "info=struct('converged',false,'iterations',0,'residualNorm',Inf,'reason','ITERATION_LIMIT','condition',NaN,'z',z0(:),'vi',viNow);");
section=replace_one(section,'rn=res/scale;', ...
 'rn=res/scale;info.iterations=kk;info.residualNorm=norm(rn);info.z=z;info.rawResidual=res;info.scale=scale;');
section=replace_one(section,'info.converged=true;', 'info.converged=true;info.reason=''CONVERGED'';');
section=replace_one(section,'if any(~isfinite(J(:))) || rcond(J.''*J)<1e-14, return; end', ...
 'info.condition=rcond(J.''*J);info.J=J;if any(~isfinite(J(:))) || info.condition<1e-14, info.reason=''JACOBIAN_GUARD'';return;end');
section=replace_one(section,'if ~accepted, return; end', ...
 'if ~accepted,info.reason=''NO_DESCENT'';info.step=step;info.newtonStep=dz;return;end');
instrumented=[instrumented(1:a-1),section,instrumented(b:end)];
instrumented=replace_one(instrumented,'[zFlap,flapInfo] = solve_flap(vi,zFlap);', ...
 ['[zFlap,flapInfo] = solve_flap(vi,zFlap); ' ...
 'assignin(''base'',''LINE_B_LAST_FLAP_TRACE'',struct(''inner'',flapInfo,''outerIteration'',iter,''vi'',vi,''zFlap'',zFlap));']);
folder=fullfile(outputRoot,'instrumented_source');if ~exist(folder,'dir'),mkdir(folder);end
p=fullfile(folder,'line_b_instrumented_rotor.m');fid=fopen(p,'w');assert(fid>=0);fwrite(fid,instrumented);fclose(fid);
copyfile(source,fullfile(folder,'ORIGINAL_m1_evidence_v1_forward_rotor.m.txt'));
addpath(folder,'-begin');cleanup=onCleanup(@() rmpath(folder));
S=readtable(fullfile(here,'original_baseline_trim_seeds.csv'));rows={};records={};count=0;identityCalls=0;
for speedKt=[60 100]
 [P,~]=xv15_helicopter_trim_parameters_v1();mp=mass_properties(0,P);s0=S(S.speed_kt==speedKt,:);
 base=[s0.theta_rad;s0.collective_rad;s0.stick_in];
 P.rotor.flapInitial=[s0.flapL0;s0.flapL1c;s0.flapL1s];
 % Same physical increments as initial fminsearch simplex, plus negatives.
 d=[2*pi/180;10*pi/180;1]*.00025;probes=[zeros(3,1),diag(d),-diag(d)];
 for j=1:size(probes,2)
  z=base+probes(:,j);x=zeros(9,1);V=speedKt*.514444;
  x(1)=V*cos(z(1));x(3)=V*sin(z(1));x(8)=z(1);
  alloc=xv15_helicopter_control_allocation(z(3),0,P);ctrl=struct('collective',z(2),'cyclicLong',alloc.cyclicLong);
  assignin('base','LINE_B_LAST_FLAP_TRACE',struct());ok=false;err='';F=nan(3,1);M=F;out=struct();identity=NaN;
  try,[F,M,out]=line_b_instrumented_rotor(x,ctrl,0,-1,mp.cgShift,P);ok=true;
  catch ME,err=ME.identifier;end
  trace=evalin('base','LINE_B_LAST_FLAP_TRACE');
  assert(isfield(trace,'inner'),['Probe failed before instrumentation: ' err]);
  if ok && j==1
   [F0,M0,o0]=m1_evidence_v1_forward_rotor(x,ctrl,0,-1,mp.cgShift,P);identityCalls=identityCalls+1;
   identity=max(abs([F-F0;M-M0;out.inducedVelocity-o0.inducedVelocity]));
   assert(identity==0,'Instrumentation changed numeric output.');
  end
  count=count+1;records{count}=struct('speed_kt',speedKt,'probe',j,'z',z,'x',x,'trace',trace,'success',ok,'error',err,'out',out);
  inner=trace.inner;
  rows(count,:)={speedKt,j,ok,probes(1,j)*180/pi,probes(2,j)*180/pi,probes(3,j), ...
   trace.outerIteration,inner.iterations,inner.residualNorm,inner.condition,inner.reason,identity,err};
 end
end
A=cell2table(rows,'VariableNames',{'speed_kt','probe','success','deltaTheta_deg','deltaCollective_deg','deltaStick_in', ...
 'inducedIteration','flapIteration','flapResidual','rcondJtJ','termination','exactIdentityDifference','error'});
writetable(A,fullfile(outputRoot,'LOCAL_FLAP_DIAGNOSTIC.csv'));disp(A);
[~,head]=system('git rev-parse HEAD');result=struct('head',strtrim(head),'table',A,'records',{records}, ...
 'version',version,'newTrimSearches',0,'probeRotorCalls',count,'identityRotorCalls',identityCalls,'solverChanged',false,'physicsChanged',false);
save(fullfile(outputRoot,'LOCAL_FLAP_DIAGNOSTIC.mat'),'result');
end
function s=replace_one(s,a,b)
a=char(a);b=char(b);assert(numel(strfind(s,a))==1,['Expected unique instrumentation anchor: ' a]);s=strrep(s,a,b);
end
