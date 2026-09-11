function result = run_d12_source_shape(dataDir,outDir)
%RUN_D12_SOURCE_SHAPE Native MATLAB check of the frozen D11/D12 channel.
% No Control System Toolbox, parameter fit, new state or historical suite.
% The external descriptor is not a matched-input absolute aircraft test.
if exist(outDir,'dir'), error('D12:OutputExists','Use a new output directory.'); end
mkdir(outDir); t0=tic;
source=jsondecode(fileread(fullfile(dataDir,'TM89428_HOVER_AZ_POWER.json')));
assert(~source.absolute_matched_comparison_ready,'D12:SourceRole');
static=readtable(fullfile(dataDir,'OARF_RUN15_EXISTING_STATIC_POINTS.csv'));
c81=readtable(fullfile(dataDir,'C81_EXISTING_SMALL_ANGLE_EXCERPT.csv'));
p=struct('m',6000,'rho',1.225,'g',9.80665,'R',3.81,'Vtip',768*0.3048,'Nb',3);
p.Omega=p.Vtip/p.R; p.scale=p.rho*pi*p.R^2*p.Vtip^2;
ct0=p.m*p.g/(2*p.scale); lambda0=sqrt(ct0/2);
theta=static.theta75_report_index_deg*pi/180;
pp=pchip(theta,static.CT);
assert(ct0>min(static.CT) && ct0<max(static.CT),'D12:TrimSupport');
theta0=fzero(@(x) ppval(pp,x)-ct0,[theta(1),theta(end)],optimset('TolX',1e-13));
[breaks,coef,~,order,dim]=unmkpp(pp);
dpp=mkpp(breaks,coef(:,1:end-1).*(order-1:-1:1),dim);
slope=ppval(dpp,theta0);
cl=c81{:,{'span1','span2','span3','span4'}};
slopes=[(cl(3,:)-cl(1,:))/(4*pi/180);(cl(2,:)-cl(1,:))/(2*pi/180);(cl(3,:)-cl(2,:))/(2*pi/180);(cl(3,:)-cl(1,:))/(4*pi/180)];
variants={'central','left_secant','right_secant','central_no_unknown_root'};
bvals=zeros(4,1);
for j=1:4
    if j==4, root=0.2; else, root=0.0875; end
    edges=[root,0.55,0.8,0.95,1];
    for seg=1:4
        bvals(j)=bvals(j)+slopes(j,seg)*chordIntegral(edges(seg),edges(seg+1),p.R);
    end
    bvals(j)=bvals(j)*p.Nb/(2*pi);
end
laws={'PP_mean','CF_TN3044'}; kvals=[128/(75*pi),.637*4/3];
w=unique([logspace(log10(.1),log10(3),513),1]).'; w(1)=.1;w(end)=3;
s=1i*w;anchor=1;
assert(all(w>=source.frequency_band_rad_s(1) & w<=source.frequency_band_rad_s(2)),'D12:Band');
metrics=table(); checkNames={}; checkValues=[]; checkLimits=[]; systems=struct([]); idx=0;
for il=1:2
    k=kvals(il);
    for ib=1:4
        b=bvals(ib); H=2*p.scale/p.m; Q=p.Omega/k; d=H*b/p.Vtip;
        alpha=slope*(1+b/(4*lambda0)); z=4*Q*lambda0;
        A=[-Q*(b+4*lambda0),-Q*(b+2*lambda0);-d,-d];
        B=[p.Vtip*Q*alpha;H*alpha];C=[0,1;A(2,:)];D=[0;B(2)];
        den=[1,Q*(b+4*lambda0)+d,2*Q*lambda0*d];
        num=-H*alpha/p.g*[1,z,0];
        ss=struct('A',A,'B',B,'C',C,'D',D);
        full=evalSS(ss,w);analytic=polyval(num,s)./polyval(den,s);
        err=max(abs(-full(:,2)/p.g-analytic)./abs(analytic));
        addCheck(sprintf('%s/%s/analytic_ss',laws{il},variants{ib}),err,5e-11);
        requiredNum=(-source.numerator(1)*p.g/(H*alpha))*den;
        requiredDen=conv(source.denominator(:).',[1,z]);
        required=polyval(requiredNum,s)./polyval(requiredDen,s).*exp(-s*source.delay_s);
        ref=sourceFRF(source,w,true);
        err=max(abs(required.*(-full(:,2)/p.g)./ref-1));
        addCheck(sprintf('%s/%s/required_map_identity_not_actuator',laws{il},variants{ib}),err,5e-11);
        assert(all(real(roots(requiredDen))<0) && numel(requiredNum)<=numel(requiredDen),'D12:Map');
        Ar=A(2,2)-A(2,1)/A(1,1)*A(1,2);
        Br=B(2)-A(2,1)/A(1,1)*B(1);
        qs=struct('A',Ar,'B',Br,'C',[1;Ar],'D',[0;Br]);
        bt=velocityBT(A,B);
        contenders={ss,qs,bt};methodNames={'FULL_2','PHYSICAL_QS_1','BT_V_KINEMATIC_1'};
        idx=idx+1;systems(idx).law=laws{il};systems(idx).b_variant=variants{ib};
        systems(idx).b=b;systems(idx).k=k;systems(idx).ss=ss;systems(idx).qs=qs;systems(idx).bt=bt;
        systems(idx).num=num;systems(idx).den=den;
        systems(idx).required_map_num=requiredNum;systems(idx).required_map_den=requiredDen;
        for im=1:3
            sys=contenders{im};h=evalSS(sys,w);h=-h(:,2)/p.g;
            ha=evalSS(sys,anchor);ha=-ha(2)/p.g;
            kin=max([max(abs(sys.D(1,:))),max(abs(sys.C(2,:)-sys.C(1,:)*sys.A)),max(abs(sys.D(2,:)-sys.C(1,:)*sys.B))]);
            addCheck(sprintf('%s/%s/%s/kinematics',laws{il},variants{ib},methodNames{im}),kin,1e-10);
            invErr=max(abs((h*(-2.7*pi/180*p.g))/(ha*(-2.7*pi/180*p.g))-h/ha));
            addCheck(sprintf('%s/%s/%s/constant_gain_invariance',laws{il},variants{ib},methodNames{im}),invErr,1e-12);
            for includeDelay=[true,false]
                ref=sourceFRF(source,w,includeDelay);ra=sourceFRF(source,anchor,includeDelay);
                ratio=(h/ha)./(ref/ra); e=abs(ratio-1);q=abs(h./ref);
                vals=[max(e),sqrt(trapz(log(w),e.^2)/(log(w(end))-log(w(1)))),max(abs(20*log10(abs(ratio)))),max(abs(angle(ratio)*180/pi)),(max(q)-min(q))/(max(q)+min(q)),max(q)/min(q)];
                one=table(laws(il),variants(ib),methodNames(im),513,numel(w),includeDelay,.1,3,1,vals(1),vals(2),vals(3),vals(4),vals(5),vals(6),...
                    'VariableNames',{'law','b_variant','method','base_grid_n','actual_grid_n','source_delay_included','frequency_lo','frequency_hi','anchor_rad_s','normalized_complex_max','normalized_complex_log_rms','normalized_gain_max_abs_db','normalized_phase_max_abs_deg','any_constant_gain_amplitude_lower_bound','magnitude_ratio_span'});
                metrics=[metrics;one]; %#ok<AGROW>
            end
        end
    end
end
checks=table(checkNames(:),checkValues(:),checkLimits(:),checkValues(:)<=checkLimits(:),...
    'VariableNames',{'check','value','limit','passed'});
writetable(metrics,fullfile(outDir,'NATIVE_SOURCE_SHAPE_METRICS.csv'));
writetable(table(variants(:),bvals,'VariableNames',{'variant','b'}),fullfile(outDir,'NATIVE_REFERENCE_B.csv'));
writetable(checks,fullfile(outDir,'NATIVE_CHECKS.csv'));
result=struct('parameters',p,'source',source,'theta0_rad',theta0,'ct0',ct0,'lambda0',lambda0,'static_slope_per_rad',slope,'omega',w,'systems',systems,'metrics',metrics,'checks',checks);
save(fullfile(outDir,'D12_NATIVE_RESULTS.mat'),'result','-v7');
manifest=struct('status','MATLAB_EXECUTED_NOT_YET_EXTERNAL_READ_BACK','matlab_version',version,'matlab_release',version('-release'),'computer',computer,'commit',getenv('GITHUB_SHA'),'run_id',getenv('GITHUB_RUN_ID'),'elapsed_seconds',toc(t0),'checks_passed',height(checks),'new_physical_parameters_fitted',0,'new_experimental_observations',0,'absolute_aircraft_validation',false,'scope','D12 source-shape and D11 channel implementation only, not execution of all D06-D11 packages');
fid=fopen(fullfile(outDir,'NATIVE_MANIFEST.json'),'w');assert(fid>0);guard=onCleanup(@() fclose(fid));fprintf(fid,'%s\n',jsonencode(manifest));clear guard;
disp(metrics(strcmp(metrics.b_variant,'central') & metrics.source_delay_included,:));
fprintf('D12_NATIVE_CHECKS_PASSED %d\n',height(checks));
    function addCheck(name,val,lim)
        checkNames{end+1}=name;checkValues(end+1)=val;checkLimits(end+1)=lim;
        assert(isfinite(val) && val<=lim,'D12:NumericalCheck','%s failed with %.17g',name,val);
    end
end
function val=chordIntegral(lo,hi,R)
val=0;
if lo<.25
    h=min(hi,.25);f=@(x) -18.4615*x.^3/3+18.6154*x.^2/2;
    val=val+.0254/R*(f(h)-f(lo));
end
if hi>.25,l=max(lo,.25);val=val+14*.0254/R*(hi^2-l^2)/2;end
end
function H=evalSS(sys,w)
w=w(:);H=zeros(numel(w),size(sys.C,1));
for j=1:numel(w),H(j,:)=(sys.C*((1i*w(j)*eye(size(sys.A))-sys.A)\sys.B)+sys.D).';end
end
function G=sourceFRF(src,w,delay)
w=w(:);assert(all(isfinite(w) & w>=src.frequency_band_rad_s(1) & w<=src.frequency_band_rad_s(2)),'D12:SourceBand');
s=1i*w;G=polyval(src.numerator(:).',s)./polyval(src.denominator(:).',s);
if delay,G=G.*exp(-s*src.delay_s);end
end
function reduced=velocityBT(A,B)
Cv=[0,1];n=size(A,1);assert(all(real(eig(A))<0),'D12:BTStable');
Lp=kron(eye(n),A)+kron(A,eye(n));Lq=kron(eye(n),A.')+kron(A.',eye(n));
P=reshape(-Lp\reshape(B*B.',[],1),n,n);Q=reshape(-Lq\reshape(Cv.'*Cv,[],1),n,n);
S=chol((P+P.')/2,'lower');R=chol((Q+Q.')/2,'lower');[U,Z,V]=svd(R.'*S);d=diag(Z);
T=S*V*diag(1./sqrt(d));Ti=diag(1./sqrt(d))*U.'*R.';
assert(max(max(abs(Ti*T-eye(n))))<1e-9,'D12:BalanceInverse');
Ab=Ti*A*T;Bb=Ti*B;Cb=Cv*T;Ar=Ab(1,1);Br=Bb(1);Cr=Cb(1);
reduced=struct('A',Ar,'B',Br,'C',[Cr;Cr*Ar],'D',[0;Cr*Br]);
end
