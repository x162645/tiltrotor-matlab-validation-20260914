function [A,B]=d04_table1_reference(P,law,fixture)
%D04_TABLE1_REFERENCE Independently transcribed closed expressions.
% NASA TM88327 Table1 printed25/PDF28; fixed-hub Eq9 printed10/PDF13.
% This is a mathematical reference, not new measured data.
% C0 normalized consistently to D03 exact PP mass / printed CF .849;
% paper C0=.639 is only rounded. Rows/columns [vi,beta,betaRate,w].
r=P.rotor;assert(P.nRotors==1&&r.rootCut==0&&r.twistTip==0);
O=r.Omega;R=r.R;N=r.Nb;I=r.Ib;S=r.Sblade;m=P.bodyMass;
gam=P.env.rho*r.liftSlope*r.chord*R^4/I;as=r.liftSlope*N*r.chord/(pi*R);
vbar=sqrt(P.initialThrustPerRotor/(P.env.rho*pi*R^2*(O*R)^2)/2);
if strcmp(law,'pp_mean'),co=1;elseif strcmp(law,'cf_mean'),co=(128/(75*pi))/.849;else,error('Bad law');end
vrow=[-75*pi*O/32*(vbar+as/16)*co,0,-25*pi*O*R/32*(vbar+as/8)*co,75*pi*O/64*(vbar+as/8)*co];
vB=25*pi*O^2*R*as/256*co;
if strcmp(fixture,'fixed')
 A=[vrow(1:3);0 0 1;-O*gam/(6*R),-O^2,-O*gam/8];B=[vB;0;O^2*gam/8];return;
end
D=1-N*S^2/(m*I);
A=[vrow;0 0 1 0; ...
 -O*gam/(D*R)*(1/6-N*S/(4*m*R)),-O^2/D,-O*gam/D*(1/8-N*S/(6*m*R)),O*gam/(D*R)*(1/6-N*S/(4*m*R)); ...
 N*O*gam/(D*R*m)*(I/(4*R)-S/6),-N*S*O^2/(m*D),N*O*gam/(D*m)*(I/(6*R)-S/8),-N*O*gam/(D*m*R)*(I/(4*R)-S/6)];
B=[vB;0;O^2*gam/D*(1/8-N*S/(6*m*R));-N*O^2*gam/(D*m)*(I/(6*R)-S/8)];
end
