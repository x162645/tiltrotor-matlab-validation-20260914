function report=test_wing_empty_patch_domain()
% Zero area must not constrain the source domain of a real wing patch.
P=xv15_helicopter_trim_parameters_v1();P.wing.SslipMaxHalf=0;
x=zeros(9,1);x(1)=30;u=zeros(7,1);cg=zeros(3,1);beta=pi/3;
r=struct('muLong',.05,'muLat',0,'inducedVelocity',0);
[F0,M0]=wing_model_source_family(x,u,beta,cg,r,r,P);
r.inducedVelocity=100; % Empty patch locally exceeds source Mach0.2.
[F1,M1,o]=wing_model_source_family(x,u,beta,cg,r,r,P);
assert(isequal(F0,F1)&&isequal(M0,M1));
assert(o.regions{2}.S==0&&all(o.regions{2}.F==0));
assert(strcmp(o.regions{2}.coefficientMeta.identity,'EMPTY_PATCH_NO_COEFFICIENT_EVALUATION'));
P.wing.SslipMaxHalf=1;rejected=false;
try,wing_model_source_family(x,u,beta,cg,r,r,P);
catch ME,rejected=strcmp(ME.identifier,'gtrs_wing_heli_coefficients:OutsideSourceSubset');end
assert(rejected,'A nonempty patch must still enforce its source domain.');
report=struct('passed',true,'claim','EMPTY_AREA_DOMAIN_FIX_NOT_EXTERNAL_VALIDATION');disp(report);
end
