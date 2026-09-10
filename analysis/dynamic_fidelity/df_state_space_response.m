function G = df_state_space_response(A,B,C,D,omega)
%DF_STATE_SPACE_RESPONSE SISO C*(jwI-A)^(-1)*B+D，不假定模态稳定。
% 可接后续部件模型线性化结果。当前测试只核验参考多项式的代数实现。
n=size(A,1);
if ~isnumeric(A)||~isnumeric(B)||~isnumeric(C)||~isnumeric(D)|| ...
    n<1||~isequal(size(A),[n,n])||~isequal(size(B),[n,1])|| ...
    ~isequal(size(C),[1,n])||~isscalar(D)|| ...
    ~isreal([A(:);B(:);C(:);D])||any(~isfinite([A(:);B(:);C(:);D]))
    error('df_state_space_response:InvalidSystem','Finite real compatible SISO matrices required.');
end
if ~isnumeric(omega)||~isvector(omega)||isempty(omega)||~isreal(omega)|| ...
    any(~isfinite(omega))||any(omega<=0)
    error('df_state_space_response:InvalidFrequency','Finite positive rad/s frequencies required.');
end
omega=omega(:);G=complex(zeros(size(omega)));I=eye(n);
for k=1:numel(omega)
    R=1i*omega(k)*I-A;
    if rcond(R)<eps,error('df_state_space_response:SingularFrequency','Ill-conditioned resolvent.');end
    G(k)=C*(R\B)+D;
end
end
