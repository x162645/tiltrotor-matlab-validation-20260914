function P=d13_load_table_model(staticCsv,loadCsv,memory)
%D13_LOAD_TABLE_MODEL Frozen conditional hover instance; not validated XV15.
% Input coordinate: theta75 report index in radians, not measured pitch.
% Classical LUT construction and source assumptions: D13_PLAN_BEFORE_RUN.md.
% Source array hashes deliberately gate this release; changed inputs require
% a named new contract, not silent extrapolation or a carried-over accuracy claim.
if nargin<3,memory='PP_mean';end
if ~strcmp(file_sha(staticCsv),'8bfd600433b0658a413602b5250e899e38394d951911eeb328eb19eeae121e5d')
 error('D13:SourceIdentity','Static data differs from the released source.');
end
h=file_sha(loadCsv);
if strcmp(h,'a36f798b516c88a67d8d0e6dfe0d06d2e24c90a3ad398d27e557416f61bf5233')
 P.method='CLASSICAL_LUT_COARSE';N=21;E=41;
elseif strcmp(h,'0a70e29141f9fd07fef2cf54f8bcd69d5e69a36b729bf990946b7e407eba2410')
 P.method='CLASSICAL_LUT_FINE';N=41;E=81;
else,error('D13:SourceIdentity','Load table differs from both released source arrays.');end
switch memory
 case 'PP_mean',P.k=128/(75*pi);
 case 'CF_TN3044',P.k=.637*4/3;
 otherwise,error('D13:Memory','Unknown memory convention.');
end
P.memory=memory;P.role='SOURCE_CONDITIONED_HOVER_NOT_FLIGHT_VALIDATED';
P.input='theta75_report_index_rad';P.R=3.81;P.Vtip=768*.3048;P.Omega=P.Vtip/P.R;
P.mass=6000;P.rho=1.225;P.g=9.80665;P.scale=P.rho*pi*P.R^2*P.Vtip^2;
S=readtable(staticCsv);P.theta=S.theta75_report_index_deg*pi/180;P.S=pchip(P.theta,S.CT);
D=readtable(loadCsv);assert(height(D)==N*E);tx=sort(unique(D.theta_rad));ex=sort(unique(D.e));
assert(numel(tx)==N&&numel(ex)==E&&all(isfinite(D.delta_CT)));
assert(max(abs(tx([1 end])-P.theta([1 end])))<2e-14);
% Restore the identical mathematical endpoints after decimal CSV rounding.
tx([1 end])=P.theta([1 end]);Z=reshape(D.delta_CT,N,E);
assert(max(abs(Z(:,(E+1)/2)))<1e-14);
P.increment=griddedInterpolant({tx,ex},Z,'linear','none');
P.eDomain=[-.01,.01];P.thetaDomain=P.theta([1 end])';
P.CT0=P.mass*P.g/(2*P.scale);
P.theta0=fzero(@(t)ppval(P.S,t)-P.CT0,P.thetaDomain);
P.x0=[P.Vtip*sqrt(P.CT0/2);0];P.staticSHA=file_sha(staticCsv);P.tableSHA=h;
P.qualification='1pct numerical NRMSE budget on two tested PP pulses only, not entire table domain or CF time histories';
end

function h=file_sha(path)
f=fopen(path,'rb');if f<0,error('D13:SourceFile','Cannot open source file.');end
closeFile=onCleanup(@()fclose(f));bytes=fread(f,Inf,'*uint8'); %#ok<NASGU>
md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
d=typecast(md.digest(),'uint8');h=lower(reshape(dec2hex(d,2)',1,[]));
end
