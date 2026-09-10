function R=run_line_b_coherent_tail_tests(outputRoot)
% Source arithmetic, manufactured cases and domain tests, not flight validation.
if ~exist(outputRoot,'dir'),mkdir(outputRoot);end
[P,~]=xv15_helicopter_trim_parameters_v1();P=line_b_coherent_tail_parameters(P);
T=gtrs_heli_tail_tables();mp=mass_properties(0,P);n=0;
check(abs(interp1(T.wingAlpha_deg,T.wingDownwash_deg,0)-6.15)<1e-12);
check(abs(interp2(T.etaSpeed_kt,T.etaAlpha_deg,T.eta,60,-8)-1.54)<1e-12);
check(abs(interp2(T.elevator_deg,T.liftAlpha_deg,T.CL,0,0))<1e-12);
check(abs(interp2(T.elevator_deg,T.liftAlpha_deg,T.CL,10,0)-.40825)<1e-12);
check(abs(interp2(T.elevator_deg,T.liftAlpha_deg,T.CL,-10,0)+.40825)<1e-12);
check(abs(interp1(T.dragAlpha_deg,T.CD,0)-.00875)<1e-12);
x=zeros(9,1);x(1)=60*(1852/3600);r=struct('inducedVelocity',10,'F',[0;0;-27000],'mu',x(1)/(P.rotor.Omega*P.rotor.R));
f=rotor_tail_interference_heli(x,0,r,r,P);
check(abs(f.rotorForceCoefficientSum-54000/(P.env.rho*pi*P.rotor.Omega^2*P.rotor.R^4))<1e-12);
[F,M,d]=horizontal_tail_model(x,0,mp.cgShift,P,f);
check(abs(d.qbar-d.qbarFree*.8*1.35)<1e-10);
check(abs(d.wingDownwash_deg-interp1(T.wingAlpha_deg,T.wingDownwash_deg,d.wingFreeAlpha_deg)/sqrt(1-(x(1)/P.env.aSound)^2))<1e-10);
check(norm(M-d.Marm-d.Maero)<1e-10);check(norm(d.Marm-cross(d.rAC,F))<1e-10);
check(~d.legacyDownwashAndIncidenceApplied);
% Doubling rotor-induced velocity changes angle, but NOT qH in source pressure law.
r2=r;r2.inducedVelocity=20;f2=rotor_tail_interference_heli(x,0,r2,r2,P);
[~,~,d2]=horizontal_tail_model(x,0,mp.cgShift,P,f2);
check(d2.alphaEff>d.alphaEff);check(d2.qbar==d.qbar);
% Old effective-angle coefficients must not leak into the new coherent path.
Ps=P;Ps.htail.incidence=123;Ps.htail.downwashAlpha=321;Ps.htail.CLmax=.001;
[Fs,Ms]=horizontal_tail_model(x,0,mp.cgShift,Ps,f);check(isequal(Fs,F)&&isequal(Ms,M));
shift=[1;-.5;.75];Ps=P;Ps.htail.rAC=Ps.htail.rAC+shift;
[Fs,Ms]=horizontal_tail_model(x,0,mp.cgShift+shift,Ps,f);
check(norm([Fs-F;Ms-M])<1e-9);
% Explicit exceptions: no silent unsupported-mode or coefficient extrapolation.
Ps=P;Ps.validation.flapDeg=0;expect(@() horizontal_tail_model(x,0,mp.cgShift,Ps,f),'MissingSourceInputs');
xb=x;xb(5)=.01;expect(@() horizontal_tail_model(xb,0,mp.cgShift,P,f),'SteadyForwardOnly');
expect(@() horizontal_tail_model(x,21*pi/180,mp.cgShift,P,f),'OutsideSourceDomain');
% Synthetic fixed-state traceable family for audit, not scored against GTRS.
rows=[];for v=[40 60 80 100]
 xx=x;xx(1)=v*(1852/3600);rr=r;rr.mu=xx(1)/(P.rotor.Omega*P.rotor.R);
 ff=rotor_tail_interference_heli(xx,0,rr,rr,P);[FF,MM,dd]=horizontal_tail_model(xx,0,mp.cgShift,P,ff);
 rows=[rows;v,dd.wingFreeAlpha_deg,dd.wingDownwash_deg,dd.alphaEff*180/pi,dd.qbar,dd.eta,FF(1),FF(3),MM(2)]; %#ok<AGROW>
end
writetable(array2table(rows,'VariableNames',{'speed_kt','wingAlpha_deg','downwash_deg','tailAlpha_deg','qH_Pa','eta','X_N','Z_N','M_Nm'}),fullfile(outputRoot,'SYNTHETIC_TAIL_COMPONENT_CHECK.csv'));
R=struct('checksPassed',n,'version',version,'release',version('-release'), ...
 'identity','COHERENT_TAIL_V3_INTERNAL_CHECKS','externalValidation',false);
save(fullfile(outputRoot,'COHERENT_TAIL_TESTS.mat'),'R','T');
fid=fopen(fullfile(outputRoot,'COHERENT_TAIL_TESTS.json'),'w');assert(fid>=0);c=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(R));clear c;disp(R);
 function check(tf),assert(tf,'Source/interface check failed.');n=n+1;end
 function expect(fun,suffix)
  try,fun();catch ME,check(strcmp(ME.identifier,['gtrs_horizontal_tail_steady:' suffix]));return;end
  error('Expected exception did not occur.');
 end
end
