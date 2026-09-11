function P=d04_paper_case()
%D04_PAPER_CASE Dimensionally equivalent classical benchmark, NOT CH47 identity.
% TM88327 Fig10/15/17: Omega24.085rad/s, tip722.55ft/s, sigma.067,
% CT.0047, gamma8.608, I2700slug*ft2, S144.7slug*ft -> retain S/I.
% a=5.73 comes from TN3044 SYMBOLS (PDF3), NOT an explicit TM88327 value.
% rho=1.225 and g=9.80665 are inherited scale choices. I and mass are DERIVED
% so the listed gamma, CT, geometry and S/I remain. Do not relabel these as
% measured CH47 mass/environment or independent flight identification.
Q=params_nominal();P.env=Q.env;P.nRotors=1;
R=30*.3048;O=24.085;sig=.067;gam=8.608;a=5.73;N=3;c=sig*pi*R/N;
I=P.env.rho*a*c*R^4/gam;S=I*(144.7/2700)/.3048;
P.rotor=struct('R',R,'Omega',O,'Nb',N,'chord',c,'rootCut',0,'twistTip',0, ...
 'liftSlope',a,'Ib',I,'Sblade',S);
P.initialThrustPerRotor=.0047*P.env.rho*pi*R^2*(O*R)^2;
P.bodyMass=P.initialThrustPerRotor/P.env.g;
P.identity='TM88327_NONDIMENSIONAL_RECONSTRUCTION';
P.parameterRole='SOURCE_DIMENSIONLESS_GROUPS_WITH_DECLARED_A_AND_SCALE_CHOICES_NOT_MATCHED_CH47';
end
