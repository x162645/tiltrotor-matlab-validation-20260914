function result=run_d05_relative_gate(outputRoot,mainMat)
%RUN_D05_RELATIVE_GATE Read existing 144 FRF records; no ODE/physics rerun.
% Additional scope after finding weak-channel relative errors despite small
% fixed-scale errors. Original 5%-fixed-gain decisions remain immutable.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'analysis','dynamic_fidelity'));
addpath(fullfile(root,'analysis','dynamic_fidelity','qualification'));
raw=load(mainMat,'result');old=raw.result;
assert(strcmp(old.meta.commit,'309d01dfebc928911328e2f28d95fe76c150e5cf'));
assert(old.meta.allChecksPassed&&old.meta.bandDecisions==144);
rows={};records=cell(144,1);checks={};clock=tic;
for k=1:144
 rec=old.records{k};L=old.models{rec.modelIndex}.L;j=rec.output;e=rec.input;band=rec.qualification.band;
 rel=qualify_relative_response(L,e,band,j,.05);w=rec.omega;G=rec.fullResponse;Gr=rec.reducedResponse;
 env=zeros(size(w));gainLower=zeros(size(w));bb=zeros(size(w));
 for i=1:numel(w)
  ix=find(w(i)>=rel.leaves(:,1)-1e-12&w(i)<=rel.leaves(:,2)+1e-12,1);
  assert(isscalar(ix),'Relative intervals must cover entire source grid.');
  env(i)=rel.leaves(ix,4);bb(i)=rel.leaves(ix,5);gainLower(i)=rel.leaves(ix,6);
 end
 ck('reduced gain lower bound agrees with independent samples', ...
  all(abs(Gr)>=gainLower-1e-9*L.gainScales(j)),max(gainLower-abs(Gr))/L.gainScales(j));
 identifiable=abs(G)>rel.responseFloor;actual=nan(size(w));actual(identifiable)=abs(G(identifiable)-Gr(identifiable))./abs(G(identifiable));
 finite=identifiable&isfinite(env);v=max([0;actual(finite)-env(finite)]);
 ck('relative error below interval enclosure',v<1e-8,v);
 if all(identifiable),maxActual=max(actual);else,maxActual=NaN;end
 if rel.qualified
  ck('relative pass cannot hide low-gain response',all(identifiable),sum(identifiable));
  ck('qualified band respects relative budget',maxActual<=.05+1e-8,maxActual);
 end
 original=old.selection(k,:);
 rows(end+1,:)={original.law{1},original.epsilonA,original.input{1},original.output{1},band(1),band(2), ...
  original.qualified,rel.qualified,original.actualErrorOverFixedGainScale,maxActual, ...
  rel.maxRelativeBound,rel.selectedStates,rel.nearZeroOrUnresolvedIntervals,rel.enclosureCalls,rel.maxDepthUsed}; %#ok<AGROW>
 records{k}=struct('qualification',rel,'omega',w,'actualRelativeError',actual,'intervalRelativeBound',env,'fullGainIdentifiable',identifiable);
end
T=cell2table(rows,'VariableNames',{'law','epsilonA','input','output','bandLow_rad_s','bandHigh_rad_s', ...
 'fixedScaleQualified','relativeQualified','actualErrorOverFixedScale','actualMaxRelativeError', ...
 'relativeEnclosure','selectedStatesForRelativeBudget','nearZeroIntervals','enclosureCalls','maxDepthUsed'});
ck('relative criterion makes different decisions',any(T.fixedScaleQualified&~T.relativeQualified),sum(T.fixedScaleQualified&~T.relativeQualified));
% Preidentified example, not a fitted threshold: 10% opposite lift-slope
% mismatch, differential input, 10-30rad/s heave error ~18% of actual response.
a=strcmp(T.law,'pp_mean')&T.epsilonA==.1&strcmp(T.input,'differential')&strcmp(T.output,'accelerationUp')&T.bandLow_rad_s==10;
ck('weak heave channel not mislabelled as five percent relative',sum(a)==1&&T.fixedScaleQualified(a)&&~T.relativeQualified(a)&&T.actualMaxRelativeError(a)>.15,T.actualMaxRelativeError(a));
% Zero exact linear response is not called 0% relative error.
a=T.epsilonA==0&strcmp(T.input,'differential')&strcmp(T.output,'accelerationUp');
ck('zero linear channel not relatively certified',all(~T.relativeQualified(a))&&all(isnan(T.actualMaxRelativeError(a))),sum(a));
L=old.models{1}.L;
expect(@()qualify_relative_response(L,[0;0],[.3,3],1,.05),'d05:InvalidRelativeBudget');
expect(@()qualify_relative_response(L,[1;1],[3,.3],1,.05),'d05:InvalidRelativeBudget');
expect(@()qualify_relative_response(L,[1;1],[.3,3],1,0),'d05:InvalidRelativeBudget');
Ck=cell2table(checks,'VariableNames',{'name','passed','value'});
writetable(T,fullfile(outputRoot,'ABSOLUTE_AND_RELATIVE_QUALIFICATION.csv'));
writetable(Ck,fullfile(outputRoot,'CHECKS.csv'));
[~,head]=system('git rev-parse HEAD');
meta=struct('identity','D05_RELATIVE_RESPONSE_QUALIFICATION_SUPPLEMENT','commit',strtrim(head), ...
 'version',version,'release',version('-release'),'checks',height(Ck),'allChecksPassed',all(Ck.passed), ...
 'cases',height(T),'relativeQualified',sum(T.relativeQualified), ...
 'absoluteQualifiedRelativeRefused',sum(T.fixedScaleQualified&~T.relativeQualified), ...
 'zeroOrUnresolvedResponseRows',sum(isnan(T.actualMaxRelativeError)), ...
 'mainRun',34601330893,'mainCommit',old.meta.commit,'newNonlinearTrajectories',0, ...
 'physicsChanged',false,'originalAbsoluteBudgetChanged',false,'experimentalSamples',0, ...
 'relativeBudget',.05,'elapsed_s',toc(clock),'independentExternalValidationPassed',false, ...
 'claim','SUPPLEMENTARY_SUFFICIENT_MODEL_ERROR_CRITERION_NOT_REPLACEMENT_OF_ORIGINAL_RESULTS');
result=struct('meta',meta,'table',T,'records',{records},'checks',Ck);
save(fullfile(outputRoot,'D05_RELATIVE_RESULTS.mat'),'result');
fid=fopen(fullfile(outputRoot,'RUN_MANIFEST.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(meta),'char');clear c;
disp(T);disp(meta);assert(meta.allChecksPassed,'Relative gate contains retained failures.');
 function ck(name,pass,value),checks(end+1,:)={name,logical(pass),value};if ~pass,fprintf('FAIL %s %.10g\n',name,value);end,end
 function expect(fun,id),try,fun();catch ME,ck(['reject ' id],strcmp(id,ME.identifier),0);return;end,ck(['reject ' id],false,0);end
end
