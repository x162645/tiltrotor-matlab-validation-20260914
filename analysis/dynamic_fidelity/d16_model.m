function p=d16_model(root,mode,n,buildTable)
% D16 fixed-hub conditional model. New use, no inherited dynamic validation.
if nargin<3,n=128;end
if nargin<4,buildTable=true;end
assert(any(strcmp(mode,{'OFF','V4','LEGACY_N1'})),'Unsupported source identity');
p.mode=mode;p.n=n;p.R=3.81;p.V=768*.3048;p.Omega=p.V/p.R;p.sound=340;p.Nb=3;
d=readtable(fullfile(root,'docs/research/dynamic_fidelity/evidence_d11/channel/data/OARF_RUN15_EXISTING_STATIC_POINTS.csv'));
p.theta=d.theta75_report_index_deg*pi/180;p.ct=d.CT;p.pp=pchip(p.theta,p.ct);
[br,co,~,ord]=unmkpp(p.pp);p.dp=mkpp(br,co(:,1:ord-1).*(ord-1:-1:1));
edges=[.0875 .2 .25 .55 .8 .95 1];p.r=[];p.w=[];
for j=1:numel(edges)-1
 p.r=[p.r edges(j)+((1:n)-.5)*(edges(j+1)-edges(j))/n]; %#ok<AGROW>
 p.w=[p.w ones(1,n)*(edges(j+1)-edges(j))/n]; %#ok<AGROW>
end
p.chord=14*ones(size(p.r));m=p.r<=.25;p.chord(m)=-18.4615*p.r(m)+18.6154;
p.chord=p.chord*.0254;p.twist=(nasa_metal_twist_deg(p.r)-nasa_metal_twist_deg(.75))*pi/180;
tic;p.bt=linspace(p.theta(1),p.theta(end),41);p.bv=zeros(size(p.bt));
for i=1:numel(p.bt)
 th=p.bt(i);ls=sqrt(ppval(p.pp,th)/2);h=1e-5;
 p.bv(i)=-(d16_source(th,ls+h,p)-d16_source(th,ls-h,p))/(2*h);
end
p.tangent_build_seconds=toc;assert(all(isfinite(p.bv))&&all(p.bv>0));
p.table_build_seconds=0;p.table=[];
if buildTable
 tic;tx=linspace(p.theta(1),p.theta(end),21);ex=linspace(-.01,.01,41);z=zeros(numel(tx),numel(ex));
 for i=1:numel(tx)
  ls=sqrt(ppval(p.pp,tx(i))/2);b0=d16_source(tx(i),ls,p);
  for j=1:numel(ex),z(i,j)=d16_source(tx(i),ls+ex(j),p)-b0;end
 end
 p.table=griddedInterpolant({tx,ex},z,'linear','none');p.table_build_seconds=toc;
 p.table_theta=tx;p.table_e=ex;p.table_values=z;
end
end
