function G = df_eval_tf(num,den,delaySeconds,omega)
%DF_EVAL_TF 在s=jw求值，保留符号、不稳定极点、非最小相位零点与纯延迟。
% 无Control System Toolbox依赖；不作minreal、增益拟合或延迟对齐。
if ~isnumeric(num)||~isnumeric(den)||~isvector(num)||~isvector(den)|| ...
    isempty(num)||isempty(den)||~isreal([num(:);den(:)])|| ...
    any(~isfinite([num(:);den(:)]))||den(1)==0||numel(num)>numel(den)
    error('df_eval_tf:InvalidPolynomial','Finite real proper transfer function required.');
end
if ~isscalar(delaySeconds)||~isreal(delaySeconds)||~isfinite(delaySeconds)||delaySeconds<0
    error('df_eval_tf:InvalidDelay','Nonnegative finite delay required.');
end
if ~isnumeric(omega)||~isvector(omega)||isempty(omega)||~isreal(omega)|| ...
    any(~isfinite(omega))||any(omega<=0)
    error('df_eval_tf:InvalidFrequency','Finite positive rad/s frequencies required.');
end
s=1i*omega(:);d=polyval(den,s);
if any(d==0),error('df_eval_tf:SingularFrequency','Pole lies on requested frequency.');end
G=polyval(num,s)./d.*exp(-s*delaySeconds);
if any(~isfinite(G)),error('df_eval_tf:NonfiniteResponse','Nonfinite frequency response.');end
end
