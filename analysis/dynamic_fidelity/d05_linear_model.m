function L=d05_linear_model(M)
%D05_LINEAR_MODEL Exact derivatives of shared nonlinear polynomial equations.
% No dynamic reference or experimental fit is used. MATLAB tests independently
% differentiate both nonlinear RHS paths and compare the Schur complement.
P=M.P;r=P.rotor;c=M.coefficients;z=M.workpoint.z;v=z(1:2);w=z(7);rate=z(5:6);
Tz=zeros(2,7);Qz=zeros(2,7);Tz(:,1:2)=diag(c.Tv);Qz(:,1:2)=diag(c.Qv);
Tz(:,5:6)=diag(c.Trate);Qz(:,5:6)=diag(c.Qrate);Tz(:,7)=-c.Tv;Qz(:,7)=-c.Qv;
Tu=diag(c.Ttheta);Qu=diag(c.Qtheta);K=zeros(2,7);K(:,3:4)=r.Ib*r.Omega^2*eye(2);
Az=M.massCholesky\(M.massCholesky.'\[r.Nb*(Qz-K);-sum(Tz,1)]);
Au=M.massCholesky\(M.massCholesky.'\[r.Nb*Qu;-sum(Tu,1)]);
V=zeros(2,7);V(:,1:2)=diag(2*v-w+(2/3)*r.R*rate);V(:,5:6)=diag((2/3)*r.R*v);V(:,7)=-v;
Beta=zeros(2,7);Beta(:,5:6)=eye(2);rhoA=P.env.rho*pi*r.R^2;
A=[(Tz-2*rhoA*V)/M.airMass;Beta;Az];B=[Tu/M.airMass;zeros(2,2);Au];
C=[-Az(3,:);Tz(2,:)-Tz(1,:)-r.Nb*r.Sblade*(Az(2,:)-Az(1,:))];
D=[-Au(3,:);Tu(2,:)-Tu(1,:)-r.Nb*r.Sblade*(Au(2,:)-Au(1,:))];
S=diag(M.stateScales);F=S\M.T;Fi=M.Tinv*S;
Q=F*A*Fi;U=F*B;Y=C*Fi;
ac=Q(1:4,1:4);ad=Q(5:7,5:7);acd=Q(1:4,5:7);adc=Q(5:7,1:4);
bc=U(1:4,:);bd=U(5:7,:);cc=Y(:,1:4);cd=Y(:,5:7);
if rcond(ad)<1e-12||max(real(eig(ad)))>=0,error('d05:IneligibleComplement','Eliminated block must be stable and nonsingular.');end
ar=ac-acd*(ad\adc);br=bc-acd*(ad\bd);cr=cc-cd*(ad\adc);dr=D-cd*(ad\bd);
L=struct('A',A,'B',B,'C',C,'D',D,'Ared',ar,'Bred',br,'Cred',cr,'Dred',dr, ...
 'Ac',ac,'Ad',ad,'Acd',acd,'Adc',adc,'Bc',bc,'Bd',bd,'Cc',cc,'Cd',cd, ...
 'transform',F,'inverseTransform',Fi,'stateScales',M.stateScales, ...
 'gainScales',M.gainScales,'modelIdentity',M.identity,'epsilonA',M.epsilonA);
end
