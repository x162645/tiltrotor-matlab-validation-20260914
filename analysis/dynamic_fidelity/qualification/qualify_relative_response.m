function result=qualify_relative_response(L,e,band,j,relativeBudget)
%QUALIFY_RELATIVE_RESPONSE Supplement D05 absolute-gain budget, not replace it.
% Let |Gfull-Gred|<=b on an interval and |Gred|>=gmin. If gmin>b,
% relative error to full <= b/(gmin-b). Lower bound uses only reduced FRF
% and the same resolvent variation bound, never full-model FRF for selection.
% Near-zero or insufficient lower bound returns NOT_CERTIFIED; it is not
% silently converted into zero relative error. Exact arithmetic bound,
% double implementation, no outward-rounded interval-arithmetic guarantee.
e=e(:);band=band(:).';
if numel(e)~=2||~isnumeric(e)||~isreal(e)||any(~isfinite(e))||norm(e)==0|| ...
 numel(band)~=2||~isreal(band)||any(~isfinite(band))||band(1)<=0||band(2)<=band(1)|| ...
 ~isscalar(j)||~ismember(j,[1,2])||~isscalar(relativeBudget)||~isreal(relativeBudget)|| ...
 ~isfinite(relativeBudget)||relativeBudget<=0
 error('d05:InvalidRelativeBudget','Valid direction, positive band and relative budget required.');end
edges=logspace(log10(band(1)),log10(band(2)),13);
stack=[edges(1:end-1).',edges(2:end).',zeros(12,1)];leaves=zeros(0,9);calls=0;maxDepth=12;
% Numerical detectability floor, not a measurement uncertainty or pass limit.
responseFloor=1e-10*L.gainScales(j);
while ~isempty(stack)
 seg=stack(end,:);stack(end,:)=[];[rel,b,gmin,kappa,nearzero]=enclose(seg(1:2));calls=calls+1;
 if isfinite(rel)&&rel<=relativeBudget
  leaves(end+1,:)=[seg,rel,b,gmin,kappa,1,nearzero]; %#ok<AGROW>
 else
  wc=mean(seg(1:2));[centerRel,~,~,~,centerNear]=enclose([wc,wc]);calls=calls+1;
  if seg(3)>=maxDepth||centerNear||~isfinite(centerRel)||centerRel>relativeBudget
   leaves(end+1,:)=[seg,rel,b,gmin,kappa,0,nearzero||centerNear]; %#ok<AGROW>
  else
   stack=[stack;seg(1),wc,seg(3)+1;wc,seg(2),seg(3)+1]; %#ok<AGROW>
  end
 end
end
leaves=sortrows(leaves,1);ok=all(leaves(:,8)==1);
result=struct('qualified',ok,'selectedStates',7-3*ok,'relativeBudget',relativeBudget, ...
 'maxRelativeBound',max(leaves(:,4)),'minimumReducedGainLowerBound',min(leaves(:,6)), ...
 'nearZeroOrUnresolvedIntervals',sum(leaves(:,9)>0),'responseFloor',responseFloor, ...
 'enclosureCalls',calls,'maxDepthUsed',max(leaves(:,3)),'leaves',leaves, ...
 'fullFrequencyResponseUsedForSelection',false,'externalValidationPassed',false, ...
 'meaning','SUFFICIENT_LOCAL_LINEAR_RELATIVE_ERROR_TO_FULL_MODEL_NOT_PHYSICAL_ACCURACY');
 function [relative,b,gmin,kappa,nearzero]=enclose(interval)
  wc=mean(interval);h=diff(interval)/2;[bb,m]=d05_error_enclosure(L,e,interval);b=bb(j);kappa=m.kappa;
  R=(1i*wc*eye(4)-L.Ared)\eye(4);nR=norm(R,2);
  gc=(L.Cred(j,:)*R*L.Bred+L.Dred(j,:))*e;nearzero=abs(gc)<=responseFloor;
  relative=Inf;gmin=-Inf;if ~m.valid||h*nR>=1,return;end
  variation=h*nR^2/(1-h*nR)*norm(L.Cred(j,:),2)*norm(L.Bred*e,2);
  gmin=abs(gc)-variation;
  if ~nearzero&&gmin-b>responseFloor,relative=b/(gmin-b);end
 end
end
