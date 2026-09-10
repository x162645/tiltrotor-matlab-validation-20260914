function result=run_line_b_tail_replay(outputRoot)
% Tests the explicit velocity interface and original GTRS coupling, no fitting.
% No trim or rotor solver is run here. Synthetic inflow tests are verification,
% NOT external validation. Source-table facts are checked against transcribed nodes.
[P,~]=xv15_helicopter_trim_parameters_v1(); mp=mass_properties(0,P);
d2r=pi/180; x=zeros(9,1); x(1)=60*(1852/3600)*cos(-8*d2r);
x(3)=60*(1852/3600)*sin(-8*d2r); r=struct('inducedVelocity',10);
f=rotor_tail_interference_heli(x,0,r,r,P);
assert(abs(f.wakeRatio+.73)<1e-12); assert(abs(f.additionalRelativeVelocityBody_mps(3)-7.3)<1e-12);
[F0,M0,d0]=horizontal_tail_model(x,2*d2r,mp.cgShift,P);
z=struct('additionalRelativeVelocityBody_mps',zeros(3,1));
[Fz,Mz,dz]=horizontal_tail_model(x,2*d2r,mp.cgShift,P,z);
assert(isequal(F0,Fz)&&isequal(M0,Mz));
assert(isequal(d0.alphaEff,dz.alphaEff)&&isequal(d0.qbar,dz.qbar));
[F1,M1,d1]=horizontal_tail_model(x,2*d2r,mp.cgShift,P,f);
assert(d1.alphaEff>d0.alphaEff); assert(norm(M1-d1.Maero-d1.Marm)<1e-9);
assert(all(isfinite([F1;M1]))); assert(norm(d1.Marm-cross(d1.rAC,F1))<1e-9);
% Disabled explicit channel is tested above without altering the legacy function path.
% Domain guards are fail-visible, not extrapolation or clipping.
expect_error(@() rotor_tail_interference_heli(x,pi/4,r,r,P),'UnsupportedMode');
xb=x;xb(2)=1;expect_error(@() rotor_tail_interference_heli(xb,0,r,r,P),'SteadySymmetricOnly');
xb=x;xb(5)=.01;expect_error(@() rotor_tail_interference_heli(xb,0,r,r,P),'SteadySymmetricOnly');
xb=x;xb(1)=100;expect_error(@() rotor_tail_interference_heli(xb,0,r,r,P),'OutsideDeclaredDomain');
rr=struct('inducedVelocity',-1);expect_error(@() rotor_tail_interference_heli(x,0,rr,r,P),'InvalidRotorInflow');
% Check every selected original speed node at alpha=-8: [40 60 80 100].
vg=[40 60 80 100]; gg=[-.46 -.73 -1.05 -.80];
for k=1:4
    xt=x; xt(1)=vg(k)*(1852/3600)*cos(-8*d2r);xt(3)=vg(k)*(1852/3600)*sin(-8*d2r);
    flow=rotor_tail_interference_heli(xt,0,r,r,P);assert(abs(flow.wakeRatio-gg(k))<1e-12);
end
result=struct('identity','TAIL_LOCAL_FLOW_INTERFACE_AND_SOURCE_TABLE_TESTS', ...
    'checksPassed',17,'release',version('-release'),'version',version, ...
    'sourceTable','NASA_CR166536_B22','zeroChannelExactLegacyIdentity',true, ...
    'externalValidation',false,'noTargetFit',true);
fid=fopen(fullfile(outputRoot,'TAIL_INTERFACE_TESTS.json'),'w');assert(fid>=0);
c=onCleanup(@() fclose(fid));fwrite(fid,jsonencode(result),'char');clear c;
save(fullfile(outputRoot,'TAIL_INTERFACE_TESTS.mat'),'result','f','d0','d1');disp(result);
end
function expect_error(fun,suffix)
try
    fun();
catch ME
    assert(strcmp(ME.identifier,['rotor_tail_interference_heli:' suffix]), ...
        ['Unexpected error: ' ME.identifier]);return;
end
error('Expected domain error did not occur.');
end
