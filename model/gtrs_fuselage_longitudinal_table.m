function [Fbody,Mbody,out] = gtrs_fuselage_longitudinal_table(x,cgShift,P)
%GTRS_FUSELAGE_LONGITUDINAL_TABLE CR-166536 longitudinal fuselage tables.
% Tables 3-I, 3-III and 3-V (B-26/B-27; PDF376/377) give equivalent
% flat-plate areas/volumes, not dimensionless coefficients.  This function
% is deliberately limited to the symmetric, zero-rate longitudinal case.
% CSV provenance: data/CR166536_DIGITIZED_TABLES_BATCH4_FUSELAGE_ALPHA.csv.
% It does not infer sideslip derivatives or claim a complete fuselage model.
x=x(:); cgShift=cgShift(:);
if numel(x)~=9||numel(cgShift)~=3||~isreal([x;cgShift])||any(~isfinite([x;cgShift]))
 error('gtrs_fuselage_longitudinal_table:InvalidInput','Finite 9-state and CG required.');
end
if abs(x(2))>1e-9||norm(x(4:6))>1e-9||x(1)<=0
 error('gtrs_fuselage_longitudinal_table:SteadySymmetricOnly','Requires forward zero-rate state.');
end
V=hypot(x(1),x(3)); alpha=atan2(x(3),x(1))*180/pi;
if alpha < -90 || alpha > 90 || V/P.env.aSound >= .2
 error('gtrs_fuselage_longitudinal_table:OutsideSourceDomain','Requires -90<=alpha<=90 and M<0.2.');
end
a=[-90 -80 -70 -60 -50 -40 -36 -32 -28 -24 -20 -16 -12 -8 -4 0 4 8 12 16 20 24 28 32 36 40 50 60 70 80 90];
L=[0 -6 -14 -18 -20 -20 -19 -18 -17 -15 -10.87 -7.25 -3.63 -.01 3.61 7.23 10.85 14.47 18.09 21.71 25.33 28 32 36 40 43 45 40 35 25 0];
D=[116 112 108 100 80 55 45 35 25 20 15.39 10.78 6.17 3 1.8 1.56 1.8 2.3 3.67 5.78 7.89 10 15 20 25 30 50 70 80 90 95];
M=[670 470 270 70 -160 -360 -410 -440 -440 -430 -380 -370 -295 -219 -142.5 -66.5 9.5 85.5 123.5 142.5 133 95 95 133 114 95 20 -50 -130 -210 -300];
ft2=.3048^2;ft3=.3048^3;q=.5*P.env.rho*V^2;
Larea=interp1(a,L,alpha,'linear')*ft2; Darea=interp1(a,D,alpha,'linear')*ft2; Mvol=interp1(a,M,alpha,'linear')*ft3;
Fbody=aero_force_body(q*Darea,0,q*Larea,alpha*pi/180,0);
rAC=P.fuselage.rAC-cgShift; Marm=cross(rAC,Fbody); Maero=[0;q*Mvol;0]; Mbody=Marm+Maero;
out=struct('identity','GTRS_FUSELAGE_TABLES_3I_3III_3V','sourcePages','B26_B27_PDF376_377', ...
 'alpha_deg',alpha,'V_mps',V,'qbar',q,'L_equiv_ft2',Larea/ft2,'D_equiv_ft2',Darea/ft2, ...
 'M_equiv_ft3',Mvol/ft3,'L_N',q*Larea,'D_N',q*Darea,'Maero',Maero,'Marm',Marm, ...
 'F',Fbody,'M',Mbody,'interpolatedSourceTables',true,'targetFitting',false, ...
 'claim','SYMMETRIC_LONGITUDINAL_SOURCE_SUBSET_NOT_COMPLETE_FUSELAGE');
end
