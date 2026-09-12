function ct=d16_source(theta,lambda,p)
% Uniform axial blade source. theta actual blade angle at .75R [rad].
assert(isfinite(theta)&&isfinite(lambda)&&lambda>0,'Invalid source query');
w=hypot(p.r,lambda);a=theta+p.twist-atan2(lambda,p.r);ma=w*p.V/p.sound;
switch p.mode
 case 'OFF',[cl,cd,meta]=xv15_c81_section_lookup(a,ma,p.r);
 case 'V4',[cl,cd,meta]=xv15_c81_corrigan_continuous_v4(a,ma,p.r,p.chord,p.R,'CORRIGAN_GENERIC_N1');
 case 'LEGACY_N1',[cl,cd,meta]=xv15_c81_corrigan_stall_delay(a,ma,p.r,p.chord,p.R,'CORRIGAN_GENERIC_N1');
 otherwise,error('d16:Source','Unsupported source identity');
end
assert(meta.alphaClampCount==0&&meta.machClampCount==0,'C81 clamping outside contract');
ct=p.Nb/(2*pi)*sum(p.w.*(p.chord/p.R).*w.*(cl.*p.r-cd.*lambda));
assert(isfinite(ct),'Nonfinite source load');
end
