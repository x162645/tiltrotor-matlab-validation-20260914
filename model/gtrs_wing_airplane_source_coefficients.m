function [CL,CD,Cm,meta]=gtrs_wing_airplane_source_coefficients(alphaRad,Mach)
%GTRS_WING_AIRPLANE_SOURCE_COEFFICIENTS CR-166536 airplane wing-pylon subset.
% Source: NASA CR-166536 Appendix B, Tables 4-I, 4-III and 4-VIII
% (PDF pp.384-386, printed B-34--B-36).  This is the X_FL1=0/0,
% mast-angle=90 deg (paper i_n=0 deg) branch.  It is deliberately separate
% from gtrs_wing_heli_coefficients, whose X_FL3=40/25 low-Mach family is
% not valid for the airplane branch.  No fitting or extrapolation is done.
% The 0..0.2 column is a source band; 0.4/0.5/0.6 are discrete source
% columns and are linearly interpolated only over their common alpha range.
a=alphaRad*180/pi;
if ~isscalar(Mach)||~isreal(Mach)||~isfinite(Mach)||~isreal(a)||any(~isfinite(a(:)))
    error('gtrs_wing_airplane_source_coefficients:InvalidInput','Finite real alpha and Mach required.');
end
if Mach<0 || Mach>0.6
    error('gtrs_wing_airplane_source_coefficients:OutsideSourceDomain','CR-166536 airplane wing source supports Mach 0..0.2 and 0.4..0.6 only.');
end
% Table 4-I, C_LWP, X_FL1=0/0, mast angle 90 deg.
acl={[-40 -36 -32 -28 -24 -20 -19.5 -16 -15.5 -13 -12 -11 -8 -4 0 4 8 11 12 13 16 17 20 24 28 32 36 40], ...
[-20 -19.5 -16 -15.5 -13 -12 -11 -8 -4 0 4 8 11 12 13 16], ...
[-16 -15.5 -13 -12 -11 -8 -4 0 4 8 11 12], ...
[-16 -15.5 -13 -12 -11 -8 -4 0 4 8 11 12]};
vcl={[-.93 -.84 -.84 -.89 -1.00 -1.15 -1.15 -.95 -.91 -.75 -.67 -.59 -.33 -.04 .38 .72 1.04 1.28 1.37 1.42 1.57 1.57 1.38 1.22 1.20 1.27 1.40 1.46], ...
[-.84 -.86 -.94 -.945 -.85 -.772 -.67 -.37 -.025 .38 .75 1.12 1.41 1.46 1.45 1.32], ...
[-.675 -.68 -.805 -.8 -.78 -.4 -.01 .39 .77 1.16 1.28 1.27], ...
[-.49 -.49 -.5 -.5 -.49 -.41 -.01 .41 .83 1.09 1.12 1.12]};
% Table 4-III, C_DWP, X_FL1=0/0, mast angle 90 deg.
adc={[-40 -36 -32 -28 -24 -20 -16 -12 -8 -4 0 4 8 12 16 20 24 28 32 36 40], ...
[-24 -20 -16 -12 -8 -4 0 4 8 12 16 20 24], ...
[-20 -16 -12 -8 -4 0 4 8 12 16], ...
[-16 -12 -8 -4 0 4 8 12]};
vcd={[.575 .505 .425 .327 .230 .150 .089 .042 .025 .017 .0204 .0418 .072 .118 .171 .247 .354 .493 .600 .660 .705], ...
[.312 .175 .089 .042 .025 .017 .0204 .0418 .072 .128 .194 .305 .500], ...
[.275 .135 .050 .025 .017 .0204 .0418 .082 .168 .289], ...
[.240 .110 .052 .040 .042 .062 .127 .268]};
if Mach<=.2
    k1=1;k2=1;w=0;
elseif Mach>=.4 && Mach<=.6
    grid=[.4 .5 .6]; [~,k2]=min(abs(grid-Mach));
    if Mach<=.5,k1=1;k2=2;else,k1=2;k2=3;end
    w=(Mach-grid(k1))/(grid(k2)-grid(k1));
else
    error('gtrs_wing_airplane_source_coefficients:MachGap','No CR-166536 source column exists for Mach .2..4.');
end
% Interpolate each coefficient only over the alpha intersection of source rows.
CL=interpMach(a,acl,vcl,k1,k2,w,'CL'); CD=interpMach(a,adc,vcd,k1,k2,w,'CD');
% Table 4-VIII gives Cm_WP by mast angle and flap; X_FL1=0/0,mast90=-.025.
Cm=-.025+zeros(size(CL));
meta=struct('identity','GTRS_CR166536_WING_AIRPLANE_XFL1_MAST90', ...
 'sourceTables','CR-166536 Table 4-I/4-III/4-VIII','sourcePages','B34_B36', ...
 'mastAngle_deg',90,'flapSetting','X_FL1=0/0','mach',Mach,'alpha_deg',a, ...
 'fittedToTrim',false,'extrapolated',false,'coefficientRows','CLWP_CDWP_CmWP');
end
function y=interpMach(a,ag,vg,k1,k2,w,label)
lo=max(min(ag{k1}),min(ag{k2})); hi=min(max(ag{k1}),max(ag{k2}));
if any(a(:)<lo-1e-10)||any(a(:)>hi+1e-10)
 error('gtrs_wing_airplane_source_coefficients:OutsideAlphaDomain','%s source alpha intersection is %.1f..%.1f deg.',label,lo,hi);
end
y1=interp1(ag{k1},vg{k1},a,'linear'); y2=interp1(ag{k2},vg{k2},a,'linear'); y=(1-w)*y1+w*y2;
end
