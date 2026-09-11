function [bound,meta]=d05_error_enclosure(L,direction,band)
%D05_ERROR_ENCLOSURE Absolute complex-gain error bound on a closed interval.
% Own block-elimination derivation in D05_METHOD.md; classical residualization.
% NOT experimental error, not arbitrary nonlinear-input error, not a proof
% of stability of every eliminated full model. Both linear models are checked.
% Resolvent identity/Neumann bound covers every omega in [lo,hi] in exact
% arithmetic. Implementation uses doubles, not outward-rounded interval math.
e=direction(:);band=band(:);
if ~isnumeric(e)||numel(e)~=2||~isreal(e)||any(~isfinite(e))||norm(e)==0|| ...
 ~isnumeric(band)||numel(band)~=2||any(~isfinite(band))||band(1)<0||band(2)<band(1)
 error('d05:InvalidCertificateInput','Nonzero real 2-input direction and 0<=lo<=hi required.');end
w=mean(band);h=diff(band)/2;s=1i*w;
R=(s*eye(4)-L.Ared)\eye(4);Rd=(s*eye(3)-L.Ad)\eye(3);
nR=norm(R,2);nd=norm(Rd,2);meta=struct('omegaCenter',w,'halfwidth',h,'valid',false,'kappa',Inf,'resolventProduct',h*max(nR,nd));
bound=[Inf;Inf];if ~all(isfinite([R(:);Rd(:)]))||h*max(nR,nd)>=1,return;end
vR=h*nR^2/(1-h*nR);vd=h*nd^2/(1-h*nd);
Delta=Rd+L.Ad\eye(3);nDelta=norm(Delta,2);na=norm(L.Acd,2);nb=norm(L.Adc,2);
K=R*L.Acd*Delta*L.Adc;
kappa=norm(K,2)+na*nb*(vR*nDelta+(nR+vR)*vd);meta.kappa=kappa;
if kappa>=1||~isfinite(kappa),return;end
H=R*L.Bred*e;F=L.Adc*H+L.Bd*e;vF=nb*vR*norm(L.Bred*e,2);
rf=Delta*F;vrf=vd*norm(F,2)+(nDelta+vd)*vF;
q=R*L.Acd*rf;vq=vR*na*norm(rf,2)+(nR+vR)*na*vrf;
Ceff=L.Cred+L.Cd*Delta*L.Adc;
for j=1:2
 cVariation=norm(L.Cd(j,:),2)*vd*nb;
 bound(j)=(norm(Ceff(j,:),2)+cVariation)*(norm(q,2)+vq)/(1-kappa)+ ...
  abs(L.Cd(j,:)*rf)+norm(L.Cd(j,:),2)*vrf;
end
meta.valid=all(isfinite(bound));meta.claim='ABSOLUTE_FRF_BOUND_RELATIVE_TO_SEVEN_STATE_LINEAR_MODEL_ONLY';
end
