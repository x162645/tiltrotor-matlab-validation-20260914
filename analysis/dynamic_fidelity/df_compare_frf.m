function result = df_compare_frf(ref,prediction)
%DF_COMPARE_FRF 明确输入/输出/工况后作描述性频响比较，不自动授予验模PASS。
% log(w)区间梯形积分权重，避免某段频率采样密集就获得更大权重。
% 记录复数相对差、增益dB差、圆周相位差；不自动拟合符号、增益或时延。
fields={'condition_id','input_id','output_id','input_unit','output_unit'};
for j=1:numel(fields)
    k=fields{j};
    if ~isfield(prediction,k)||~isfield(ref,k)||~strcmp(prediction.(k),ref.(k))
        error('df_compare_frf:ContractMismatch','Mismatch or missing field: %s',k);
    end
end
if ~isfield(prediction,'model_identity')||isempty(prediction.model_identity)|| ...
    ~isfield(prediction,'evidence_role')||isempty(prediction.evidence_role)
    error('df_compare_frf:MissingIdentity','Candidate identity and evidence role required.');
end
if ~isfield(prediction,'omega_rad_s')||~isfield(prediction,'response')
    error('df_compare_frf:MissingSamples','Rad/s grid and complex response required.');
end
w=prediction.omega_rad_s;G=prediction.response;
if ~isnumeric(w)||~isvector(w)||numel(w)<2||~isreal(w)||any(~isfinite(w))||any(w<=0)||any(diff(w)<=0)
    error('df_compare_frf:InvalidGrid','Strictly increasing positive rad/s grid with >=2 samples required.');
end
w=w(:);
if ~isnumeric(G)||~isvector(G)||numel(G)~=numel(w)||any(~isfinite(G))
    error('df_compare_frf:InvalidResponse','Finite complex vector matching grid required.');
end
G=G(:);band=ref.frequency_band_rad_s;
if w(1)<band(1)*(1-1e-12)||w(end)>band(2)*(1+1e-12)
    error('df_compare_frf:OutsideReferenceBand','No reference extrapolation.');
end
R=df_eval_tf(ref.numerator,ref.denominator,ref.delay_s,w);
if any(abs(R)==0)||any(abs(G)==0)
    error('df_compare_frf:UndefinedPhase','Zero transfer response: phase and relative metrics undefined.');
end
edges=diff(log(w));weights=[edges(1);edges(1:end-1)+edges(2:end);edges(end)]/2;
weights=weights/sum(weights);ratio=G./R;
gain=20*log10(abs(ratio));phase=atan2(imag(ratio),real(ratio))*180/pi;
relative=abs(G-R)./abs(R);
result.points=table(w,real(R),imag(R),real(G),imag(G),gain,phase,relative,weights, ...
    'VariableNames',{'omega_rad_s','reference_real','reference_imag','candidate_real','candidate_imag', ...
    'gain_error_dB','phase_error_deg','relative_complex_error','log_frequency_weight'});
result.metrics=struct('gain_rmse_dB',sqrt(sum(weights.*gain.^2)), ...
    'phase_rmse_deg',sqrt(sum(weights.*phase.^2)), ...
    'relative_complex_rmse',sqrt(sum(weights.*relative.^2)), ...
    'max_abs_gain_error_dB',max(abs(gain)),'max_abs_phase_error_deg',max(abs(phase)), ...
    'min_frequency_rad_s',w(1),'max_frequency_rad_s',w(end),'sample_count',numel(w));
result.case_id=ref.id;result.model_identity=prediction.model_identity;
result.evidence_role=prediction.evidence_role;result.reference_role=ref.evidence_role;
result.precision_pass_assigned=false;
result.first_principles_validation_ready=ref.first_principles_comparison_ready;
result.claim='DESCRIPTIVE_COMPARISON_TO_PUBLISHED_IDENTIFIED_RESPONSE_NOT_FLIGHT_VALIDATION';
end
