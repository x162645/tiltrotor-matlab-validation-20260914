function report=test_cross_angle_component_interfaces()
%TEST_CROSS_ANGLE_COMPONENT_INTERFACES Smoke-test the angle-screen API.
% This test checks only that the source-constrained component interfaces
% accept the four common betaM values and return finite loads.  It is not an
% accuracy or transition-validation test.  Run after startup.m.
P=line_b_coherent_tail_parameters(xv15_helicopter_trim_parameters_v1());
P.wing.coefficientModel='GTRS_FREEFIELD_HELI_V6';
P.aeroExtras.spinnerModel='GTRS_TWO_SPINNERS_STEADY_HELI_V7';
x=[30;0;0;0;0;0;0;0;0]; cg=zeros(3,1);
rotL=struct('inducedVelocity',8,'muLong',.08,'muLat',0,'mu',.08, ...
    'F',[0;0;-5000],'eT',[0;0;-1]);
rotR=rotL;
u=zeros(7,1); angles=[0 30 60 90]; rows=zeros(numel(angles),8);
for k=1:numel(angles)
    beta=angles(k)*pi/180;
    [Fw,Mw,wo]=wing_model_source_family(x,u,beta,cg,rotL,rotR,P);
    flow=rotor_tail_interference_heli(x,beta,rotL,rotR,P);
    [Fs,Ms,so]=gtrs_spinner_steady(x,beta,cg,rotL,rotR,P);
    [Fh,Mh,ho]=gtrs_horizontal_tail_steady(x,0,cg,P,flow);
    vals=[Fw;Mw;Fs;Ms;Fh;Mh];
    assert(isreal(vals)&&all(isfinite(vals)), ...
        'Cross-angle component output must be finite and real.');
    rows(k,:)=[angles(k),wo.SslipHalf,flow.tailInducedSigned_mps, ...
        so.effectiveDragArea_m2,norm(Fw),norm(Fh),norm(Fs),norm(Mh)]; %#ok<AGROW>
end
T=array2table(rows,'VariableNames',{'betaM_deg','wingSlipAreaHalf_m2', ...
    'tailInducedSigned_mps','spinnerEffectiveArea_m2','wingForce_N', ...
    'tailForce_N','spinnerForce_N','tailMoment_Nm'});
report=struct('identity','CROSS_ANGLE_COMPONENT_INTERFACE_SMOKE_V1', ...
    'angles_deg',angles,'checksPassed',numel(angles), ...
    'accuracyValidation',false,'transitionWakeValidation',false,'table',T);
disp(T);
end
