function results = run_xv15_wang_closure_v1(outputRoot)
%RUN_XV15_WANG_CLOSURE_V1 Recompute four Wang-style nacelle trims and
% three longitudinal step diagnostics with explicit unit/angle contracts.
if nargin<1 || isempty(outputRoot), outputRoot=fullfile(pwd,'results','xv15_wang_closure_v1'); end
if ~exist(outputRoot,'dir'), mkdir(outputRoot); end
[P,contract]=xv15_helicopter_trim_parameters_v1(); P.trim.display='off'; P.trim.maxIterations=500; P.trim.maxFunctionEvaluations=6000;
modelIdentity='M1_EVIDENCE_V1_PROPAGATION'; d2r=pi/180; knot2mps=0.514444; mps2knot=1/knot2mps;
% Wang i_n is measured from airplane axis; repository betaM from helicopter axis.
inDeg=[90 60 30 0]; betaDeg=90-inDeg; speedMps={ [0.1 10 20], [20 30 40], [30 40 50], [40 50 60] };
rows=[]; reports={}; idx=0;
for k=1:numel(inDeg)
  for j=1:numel(speedMps{k})
    idx=idx+1; V=speedMps{k}(j); cond=struct('name',sprintf('IN%03d_V%06.2f',inDeg(k),V),'V',V,'betaM',betaDeg(k)*d2r,'gamma',0);
    if betaDeg(k)==0, mode='helicopter_longitudinal'; else, mode='conversion_longitudinal'; end
    try
      [x,u,rep]=stage2_trim_longitudinal(modelIdentity,cond,P,struct('mode',mode));
      row=base_row(inDeg(k),betaDeg(k),V,mps2knot,mode,rep); reports{idx}=rep;
      if rep.credible
        row.theta_deg=x(8)/d2r; row.alpha_deg=(x(8)-cond.gamma)/d2r; row.collective_deg=u(1)/d2r;
        row.power_kW=NaN; row.stick_in=NaN; row.delta_lon_pct=NaN;
        if isfield(rep,'allocation') && ~isempty(rep.allocation) && isfield(rep.allocation,'stickIn'), row.stick_in=rep.allocation.stickIn; row.delta_lon_pct=100*row.stick_in/9.6; end
        if isfield(rep.point.eomOut,'rotorLeft'), row.power_kW=2*rep.point.eomOut.rotorLeft.power/1000; end
        row.thrust_total_N=rep.point.eomOut.rotorLeft.thrust+rep.point.eomOut.rotorRight.thrust;
      end
    catch ME
      row=base_row(inDeg(k),betaDeg(k),V,mps2knot,mode,struct('credible',false,'residualNorm',NaN,'physicalStatus',['ERROR_' ME.identifier],'solverConverged',false,'physicalConverged',false,'physicalBranchSupported',false,'atLimit',false,'withinLimits',false)); row.status=[ME.identifier ':' ME.message]; reports{idx}=ME;
    end
    rows=[rows; row]; %#ok<AGROW>
  end
end
trimTable=struct2table(rows); writetable(trimTable,fullfile(outputRoot,'XV15_WANG_STYLE_TRIM_POINTS.csv'));
% Dynamic step diagnostics at i_n=90,60,0. Use a fixed +0.5 in stick for i_n=90;
% for other angles use +1 deg direct cyclic command. This is a model-input diagnostic,
% not a claim of Tischler flight-test input identity.
stepRows=[]; stepCfg=[90 60 0]; stepV=[10 30 50];
for k=1:numel(stepCfg)
  in=stepCfg(k); bd=90-in; V=stepV(k); mask=trimTable.i_n_deg==in & abs(trimTable.speed_mps-V)<1e-9;
  if ~any(mask), mask=find(trimTable.i_n_deg==in,1); end
  if isempty(mask)||~trimTable.credible(mask), stepRows=[stepRows; step_row(in,bd,V,'NO_CREDIBLE_TRIM',NaN,NaN,NaN,NaN)]; continue; end
  % Re-solve to obtain state/control structures (reports retained in order).
  cond=struct('name',sprintf('STEP_IN%03d',in),'V',V,'betaM',bd*d2r,'gamma',0); mode=char(trimTable.mode(mask));
  try
    [x,u,rep]=stage2_trim_longitudinal(modelIdentity,cond,P,struct('mode',mode));
    if ~rep.credible, stepRows=[stepRows; step_row(in,bd,V,'TRIM_NOT_CREDIBLE',NaN,NaN,NaN,NaN)]; continue; end
    uStep=u; inputContract='DIRECT_CYCLIC_1DEG';
    if bd==0 && isfield(rep,'allocation') && ~isempty(rep.allocation)
      uStep(3)=u(3)+0.5*rep.allocation.cyclicGearing_rad_per_in; inputContract='STICK_PLUS_0P5IN';
    else, uStep(3)=u(3)+1*d2r; end
    opts=odeset('RelTol',2e-5,'AbsTol',1e-7,'MaxStep',0.03);
    [t,X]=ode45(@(tt,xx) stage2_tiltrotor_eom(modelIdentity,xx,uStep,bd*d2r,P),[0 5],x,opts);
    q=X(:,5); theta=X(:,8); stepRows=[stepRows; step_row(in,bd,V,inputContract,theta(end)-x(8),max(abs(q)),max(abs(theta-x(8))),t(find(abs(q)==max(abs(q)),1)))];
    % Save one trace per configuration.
    writematrix([t,X(:,5),X(:,8)],fullfile(outputRoot,sprintf('STEP_IN%03d_TRACE.csv',in)));
  catch ME
    stepRows=[stepRows; step_row(in,bd,V,['ERROR_' ME.identifier],NaN,NaN,NaN,NaN)];
  end
end
stepTable=struct2table(stepRows); writetable(stepTable,fullfile(outputRoot,'XV15_WANG_STYLE_STEP_DIAGNOSTICS.csv'));
% Unit/coordinate contract and summary.
fid=fopen(fullfile(outputRoot,'XV15_WANG_STYLE_CONTRACT.md'),'w'); fprintf(fid,['# XV-15 Wang-style closure contract\n\n' ...
 '文献短舱角 `i_n` 从飞机轴定义；仓库 `betaM` 从直升机轴定义，因此 `betaM_deg=90-i_n_deg`。\n' ...
 '速度：`V_mps=0.514444*V_kt`；功率：`P_kW=P_W/1000`；总距/周期变距/升降舵均在模型内用弧度，输出转换为度。\n' ...
 '纵向杆位百分比仅在有杆位接口的直升机模式给出，采用 `100*stick_in/9.6`（全行程合同）；其他构型的直接周期变距阶跃不冒充文献杆位百分比。\n' ...
 'CR-166537 的四个 40/60/80/100 kt 点是参考仿真输出，不是飞行原始数据；本次四构型结果用于定义检查与失败定位。\n' ...
 '动态表是统一模型输入下的 5 s 阶跃诊断，尚未声称复现 TM-89428 的真实试验输入、滤波和传感器时基。\n']); fclose(fid);
results=struct('trim',trimTable,'steps',stepTable,'contract',contract,'angleMapping','betaM_deg=90-i_n_deg','modelIdentity',modelIdentity); save(fullfile(outputRoot,'XV15_WANG_STYLE_RESULTS.mat'),'results'); disp(trimTable); disp(stepTable);
end
function r=base_row(i,b,V,m2k,mode,rep)
r=struct('i_n_deg',i,'betaM_deg',b,'speed_mps',V,'speed_kt',V*m2k,'mode',mode,'credible',false,'solverConverged',false,'physicalConverged',false,'physicalBranchSupported',false,'withinLimits',false,'atLimit',false,'residualNorm',NaN,'status','','theta_deg',NaN,'alpha_deg',NaN,'collective_deg',NaN,'stick_in',NaN,'delta_lon_pct',NaN,'power_kW',NaN,'thrust_total_N',NaN);
fn=fieldnames(rep); for k=1:numel(fn), if isfield(r,fn{k}), r.(fn{k})=rep.(fn{k}); end, end
if isfield(rep,'physicalStatus'), r.status=rep.physicalStatus; end
end
function r=step_row(i,b,V,c,dth,maxq,maxth,tq), r=struct('i_n_deg',i,'betaM_deg',b,'speed_mps',V,'input_contract',c,'delta_theta_final_deg',dth*180/pi,'max_abs_q_deg_s',maxq*180/pi,'max_abs_delta_theta_deg',maxth*180/pi,'time_of_max_q_s',tq); end
