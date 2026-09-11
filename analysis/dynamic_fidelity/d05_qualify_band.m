function result=d05_qualify_band(L,direction,band,outputIndex,budgetFraction)
%D05_QUALIFY_BAND Sufficient reduction gate, not experiment/handling-quality pass.
% Scale = fixed nominal direct pitch-load derivative, not a small reference
% response near a zero. Gate does not query the full 7-state frequency response.
% A failed sufficient gate means NOT CERTIFIED, not proved inaccurate.
if ~isscalar(outputIndex)||~ismember(outputIndex,[1,2])||~isscalar(budgetFraction)|| ...
 ~isreal(budgetFraction)||~isfinite(budgetFraction)||budgetFraction<=0
 error('d05:InvalidBudget','Valid output and positive finite budget fraction required.');end
limit=budgetFraction*L.gainScales(outputIndex);edges=logspace(log10(band(1)),log10(band(2)),13);
stack=[edges(1:end-1).',edges(2:end).',zeros(12,1)];leaves=zeros(0,7);calls=0;maxDepth=12;
while ~isempty(stack)
 seg=stack(end,:);stack(end,:)=[];[b,m]=d05_error_enclosure(L,direction,seg(1:2));calls=calls+1;
 if m.valid&&b(outputIndex)<=limit
  leaves(end+1,:)=[seg,b(outputIndex),m.kappa,1,0]; %#ok<AGROW>
 else
  center=mean(seg(1:2));[bc,mc]=d05_error_enclosure(L,direction,[center center]);calls=calls+1;
  if seg(3)>=maxDepth||~mc.valid||bc(outputIndex)>limit
   leaves(end+1,:)=[seg,b(outputIndex),m.kappa,0,bc(outputIndex)]; %#ok<AGROW>
  else
   stack=[stack;seg(1),center,seg(3)+1;center,seg(2),seg(3)+1]; %#ok<AGROW>
  end
 end
end
leaves=sortrows(leaves,1);qualified=all(leaves(:,6)==1);
result=struct('qualified',qualified,'selectedStates',7-3*qualified, ...
 'outputIndex',outputIndex,'direction',direction(:),'band',band,'budgetFraction',budgetFraction, ...
 'absoluteGainBudget',limit,'maxBound',max(leaves(:,4)),'maxKappa',max(leaves(:,5)), ...
 'enclosureCalls',calls,'maxDepthUsed',max(leaves(:,3)),'leaves',leaves, ...
 'externalValidationPassed',false,'fullModelUsedForSelection',false, ...
 'scope','LOCAL_LTI_ZERO_INITIAL_CONDITIONS_AND_SPECIFIED_INPUT_DIRECTION');
end
