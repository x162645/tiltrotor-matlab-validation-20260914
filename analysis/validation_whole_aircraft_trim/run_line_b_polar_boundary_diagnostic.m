function R=run_line_b_polar_boundary_diagnostic(outputRoot)
% Frozen failed 100kt point from run34475917202 artifact10151502148.
% No rotor trim search, parameter fitting or solver changes. Diagnostic copy
% exposes the exact existing blade-load and flap-residual evaluations only.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
s=fileread(fullfile(root,'analysis','stage2_aircraft','m1_evidence_v1_forward_rotor.m'));
s=strrep(s,'m1_evidence_v1_forward_rotor','line_b_boundary_rotor');
s=replace_one(s,'exactHoverAnchor = norm(Vbody)',sprintf([ ...
 'if isfield(P,''lineBResidualProbe'')\n' ...
 ' z=P.lineBResidualProbe.z;vv=P.lineBResidualProbe.vi;\n' ...
 ' [res,scale]=flap_residual(z,vv);ll=blade_loads(vv,z);\n' ...
 ' Fbody=zeros(3,1);Mbody=zeros(3,1);out=struct(''res'',res,''scale'',scale,''loads'',ll);return;\n' ...
 'end\nexactHoverAnchor = norm(Vbody)']));
s=replace_one(s,'ll.maxAbsAlphaBlade=max(abs(alpha(:)));', ...
 'll.maxAbsAlphaBlade=max(abs(alpha(:)));ll.alpha=alpha;ll.CL=CL;ll.CD=CD;ll.Mach=Mach;ll.mask=meta.applyMask;ll.KL=meta.KL;ll.xSpan=xSpan;ll.chord=chord;');
folder=fullfile(outputRoot,'instrumented_source');if ~exist(folder,'dir'),mkdir(folder);end
fid=fopen(fullfile(folder,'line_b_boundary_rotor.m'),'w');assert(fid>=0);fwrite(fid,s);fclose(fid);
addpath(folder,'-begin');cleanup=onCleanup(@()rmpath(folder));
[P,~]=xv15_helicopter_trim_parameters_v1();mp=mass_properties(0,P);
outer=[-0.08196598845632894;0.6048389729095728;6.427854454921619];
z0=[0.024787827550191353;-0.13563013847267028;-0.014607491139566137];
dz=[-1.2064562242048074e-8;2.2883251219848798e-7;8.403316032151414e-8];
P.lineBResidualProbe.vi=4.90066506326612;
x=zeros(9,1);x(1)=100*.514444*cos(outer(1));x(3)=100*.514444*sin(outer(1));x(8)=outer(1);
alloc=xv15_helicopter_control_allocation(outer(3),0,P);ctrl=struct('collective',outer(2),'cyclicLong',alloc.cyclicLong);
rows=[];records={};steps=[0,2.^-(0:20),-2.^-(0:20)];
for j=1:numel(steps)
 P.lineBResidualProbe.z=z0+steps(j)*dz;
 [~,~,out]=line_b_boundary_rotor(x,ctrl,0,-1,mp.cgShift,P);
 if j==1,base=out;end
 changed=nnz(out.loads.mask~=base.loads.mask);
 rows=[rows;steps(j),norm(out.res/out.scale),norm(out.res-base.res),changed, ...
 out.loads.alpha(6,11)*180/pi,out.loads.CL(6,11),out.loads.mask(6,11),out.loads.Mach(6,11)]; %#ok<AGROW>
 records{j}=out; %#ok<AGROW>
end
A=array2table(rows,'VariableNames',{'newtonStepFraction','residualNorm','rawResidualChange','changedApplyMaskCount','alphaCell_deg','CLCell','correctionApplied','MachCell'});
writetable(A,fullfile(outputRoot,'POLAR_BOUNDARY_RESIDUAL.csv'));disp(A);
[clneg,~,~]=xv15_c81_corrigan_stall_delay(-1e-10,base.loads.Mach(6,11),base.loads.xSpan(11),base.loads.chord(11),P.rotor.R,'CORRIGAN_GENERIC_N1');
[clpos,~,~]=xv15_c81_corrigan_stall_delay(1e-10,base.loads.Mach(6,11),base.loads.xSpan(11),base.loads.chord(11),P.rotor.R,'CORRIGAN_GENERIC_N1');
R=struct('version',version,'table',A,'records',{records},'CLminus',clneg,'CLplus',clpos, ...
 'liftJump',clpos-clneg,'sourceRun',34475917202,'sourceArtifact',10151502148, ...
 'claim','Pointwise correction switch discontinuity diagnostic, not an external validation result.');
save(fullfile(outputRoot,'POLAR_BOUNDARY_DIAGNOSTIC.mat'),'R');disp([clneg clpos clpos-clneg]);
copyfile(which('xv15_c81_corrigan_stall_delay'),outputRoot);
copyfile(which('xv15_c81_section_lookup'),outputRoot);
end
function s=replace_one(s,a,b)
assert(numel(strfind(s,a))==1,['Expected unique anchor: ' a]);s=strrep(s,a,b);
end
