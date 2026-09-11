function S=build_axial_symmetric(M)
%BUILD_AXIAL_SYMMETRIC Exact invariant-manifold reduction, not empirical fit.
% For N identical noninteracting parallel rotors with identical actual pitch
% and equal initial vi/beta/betaRate, symmetric equations stay symmetric.
% Divide TOTAL mechanical mass by N and retain per-rotor quantities to build
% a four-state equivalent [viCommon,betaCommon,betaRateCommon,w].
% This is a mathematical reduction of this axial model, not another aircraft
% configuration or a claim that differential/pitch/roll modes are negligible.
if ~isstruct(M)||~isfield(M,'identity')||~strcmp(M.mode,'coupled')|| ...
 ~strcmp(M.fixture,'free')||M.nRotors<2
 error('axialSymmetric:UnsupportedModel','Identical multi-rotor coupled free-heave model required.');end
P=M.P;P.nRotors=1;P.bodyMass=P.bodyMass/M.nRotors;
P.identity=[P.identity '_COMMON_MODE_EQUIVALENT'];
small=build_axial_coupled(P,M.law,'coupled','free');
T=zeros(M.n,4);T(M.vi,1)=1;T(M.beta,2)=1;T(M.rate,3)=1;T(M.w,4)=1;
R=T.';R(1:3,:)=R(1:3,:)/M.nRotors;
S=struct('small',small,'full',M,'lift',T,'project',R,'inputLift',ones(M.nRotors,1), ...
 'identity',[M.identity '_EXACT_SYMMETRIC_4STATE'],'n',4,'externalAccuracyPassed',false, ...
 'restriction','COMMON_PITCH_EQUAL_INITIAL_ROTORS_NO_GEOMETRIC_ASYMMETRY', ...
 'source','D04_JOINT_INERTIA_EQUATIONS_IDENTICAL_ROTOR_PERMUTATION_SYMMETRY');
end
