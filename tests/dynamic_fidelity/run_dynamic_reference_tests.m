function result = run_dynamic_reference_tests(outputRoot)
%RUN_DYNAMIC_REFERENCE_TESTS 仅测试参照构造和比较器，不运行/验证飞机。
if nargin<1,outputRoot=fullfile(pwd,'ci_artifacts','dynamic_reference');end
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'analysis','dynamic_fidelity'));
ids={'HOVER_Q_ELEVATOR','HOVER_AZ_POWER','CRUISE_Q_ELEVATOR','CRUISE_AZCG_ELEVATOR'};
passed=0;records=cell(4,1);rows={};t0=tic;
for k=1:numel(ids)
    r=df_reference(ids{k});band=r.frequency_band_rad_s;
    w=logspace(log10(band(1)),log10(band(2)),129).';
    G=df_eval_tf(r.numerator,r.denominator,r.delay_s,w);s=1i*w;
    switch k
        case 1
            independent=-2.66*s.*(s-.271).*(s+.508).*exp(-.0656*s)./ ...
                ((s+.105).*(s+1.32).*(s.^2+2*(-.463)*.579*s+.579^2));
        case 2
            independent=-.00980*s.*exp(-.00740*s)./(s+.105);
        case 3
            independent=-7.38*(s+.890).*exp(-.005*s)./(s.^2+2*.536*2.02*s+2.02^2);
        case 4
            independent=-.0230*(s-6.70).*(s+7.59).*exp(-.002*s)./(s.^2+2*.536*2.02*s+2.02^2);
    end
    err1=max(abs(G-independent));check(err1<1e-12*max(1,max(abs(G))));
    den=r.denominator/r.denominator(1);n=numel(den)-1;
    num=[zeros(1,n+1-numel(r.numerator)),r.numerator/r.denominator(1)];
    A=[-den(2:end);eye(n-1),zeros(n-1,1)];B=[1;zeros(n-1,1)];
    D=num(1);C=num(2:end)-D*den(2:end);
    Gss=df_state_space_response(A,B,C,D,w).*exp(-1i*w*r.delay_s);
    err2=max(abs(G-Gss));check(err2<1e-11*max(1,max(abs(G))));
    p=prediction(r,w,G);a=df_compare_frf(r,p);
    check(a.metrics.relative_complex_rmse<1e-14);check(a.metrics.phase_rmse_deg<1e-12);
    check(~a.precision_pass_assigned&&~a.first_principles_validation_ready);
    p.response=2*G;b=df_compare_frf(r,p);
    check(abs(b.metrics.gain_rmse_dB-20*log10(2))<1e-12);
    check(abs(b.metrics.relative_complex_rmse-1)<1e-12);check(b.metrics.phase_rmse_deg<1e-12);
    p.response=-G;b=df_compare_frf(r,p);check(abs(b.metrics.phase_rmse_deg-180)<1e-10);
    check(b.metrics.gain_rmse_dB<1e-12);check(abs(b.metrics.relative_complex_rmse-2)<1e-12);
    p.response=G.*exp(-1i*w*.05);b=df_compare_frf(r,p);
    check(max(abs(b.points.phase_error_deg+w*.05*180/pi))<1e-10);
    check(b.metrics.gain_rmse_dB<1e-12);
    p=prediction(r,w,G);p.input_unit='rad';expect(@()df_compare_frf(r,p),'df_compare_frf:ContractMismatch');
    p=prediction(r,w,G);p.condition_id='UNMATCHED_CONDITION';expect(@()df_compare_frf(r,p),'df_compare_frf:ContractMismatch');
    p=prediction(r,w,G);p.response(5)=NaN;expect(@()df_compare_frf(r,p),'df_compare_frf:InvalidResponse');
    p=prediction(r,w,G);p.response(5)=0;expect(@()df_compare_frf(r,p),'df_compare_frf:UndefinedPhase');
    p=prediction(r,w,G);p.omega_rad_s(1)=band(1)/2;expect(@()df_compare_frf(r,p),'df_compare_frf:OutsideReferenceBand');
    p=prediction(r,w,G);p.omega_rad_s(2)=p.omega_rad_s(1);expect(@()df_compare_frf(r,p),'df_compare_frf:InvalidGrid');
    p=prediction(r,w,G);p.output_id='OTHER_SENSOR_LOCATION';expect(@()df_compare_frf(r,p),'df_compare_frf:ContractMismatch');
    check(abs(sum(a.points.log_frequency_weight)-1)<1e-14);
    tab=table(w,real(G),imag(G),20*log10(abs(G)),unwrap(angle(G))*180/pi, ...
        'VariableNames',{'omega_rad_s','real_response','imag_response','magnitude_dB','phase_unwrapped_deg'});
    writetable(tab,fullfile(outputRoot,[ids{k} '_REFERENCE.csv']));
    records{k}=struct('reference',r,'A',A,'B',B,'C',C,'D',D,'response',G,'identityMetrics',a);
    rows(end+1,:)={ids{k},band(1),band(2),n,r.delay_s,err1,err2};
end
h=df_reference(ids{1});check(sum(real(roots(h.denominator))>0)==2);
h=df_reference(ids{4});check(any(abs(roots(h.numerator)-6.70)<1e-12));
check(abs((pi/180)*(180/pi)-1)<1e-15);
expect(@()df_reference('FAKE_CASE'),'df_reference:UnknownCase');
expect(@()df_eval_tf([1],[1,1],-.1,[1,2]),'df_eval_tf:InvalidDelay');
expect(@()df_eval_tf([1],[1,1],0,[0,1]),'df_eval_tf:InvalidFrequency');
expect(@()df_state_space_response(0,1,1,0,[0,1]),'df_state_space_response:InvalidFrequency');
summary=cell2table(rows,'VariableNames',{'case_id','band_min_rad_s','band_max_rad_s','rational_order','delay_s','factorPolynomialMaxDifference','stateSpaceMaxDifference'});
writetable(summary,fullfile(outputRoot,'REFERENCE_RECONSTRUCTION_SUMMARY.csv'));
[~,head]=system('git rev-parse HEAD');
meta=struct('identity','D01_PUBLISHED_DYNAMIC_REFERENCE_AND_COMPARATOR_TESTS','commit',strtrim(head), ...
    'version',version,'release',version('-release'),'computer',computer,'checksPassed',passed, ...
    'referenceCount',4,'frequencySamplesPerReference',129,'elapsed_s',toc(t0), ...
    'newAircraftModelEvaluations',0,'newTrimSearches',0,'externalFlightValidationExecuted',false, ...
    'newModelLeadingPerformanceDemonstrated',false, ...
    'evidenceRole','REFERENCE_RECONSTRUCTION_AND_SYNTHETIC_SOFTWARE_TESTS_ONLY');
result=struct('meta',meta,'summary',summary,'records',{records});
save(fullfile(outputRoot,'DYNAMIC_REFERENCE_TEST_RESULTS.mat'),'result');
fid=fopen(fullfile(outputRoot,'RUN_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear c;
disp(summary);disp(meta);
    function check(b),assert(b,'Dynamic reference check failed.');passed=passed+1;end
    function expect(fun,id)
        try,fun();catch ME,check(strcmp(ME.identifier,id));return;end
        error('Expected error not raised: %s',id);
    end
end
function p=prediction(r,w,G)
p=struct('model_identity','SYNTHETIC_TEST_ONLY','evidence_role','SOFTWARE_UNIT_TEST', ...
    'condition_id',r.condition_id,'input_id',r.input_id,'output_id',r.output_id, ...
    'input_unit',r.input_unit,'output_unit',r.output_unit,'omega_rad_s',w,'response',G);
end
