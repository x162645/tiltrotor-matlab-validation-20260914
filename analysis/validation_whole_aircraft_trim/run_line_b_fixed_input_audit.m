function results = run_line_b_fixed_input_audit(outputRoot)
%RUN_LINE_B_FIXED_INPUT_AUDIT Fixed-input component comparison, no trim search.
% Baseline: 9d0c2abce6a3367ec8c46ca7aeb534b45b8ed728.
% Kleinhesselink (2007), Table C-1, printed pp175-182 (PDF pp191-198).
% GTRS is a reference simulation, NOT flight truth. The table has aggregate
% inconsistencies; individual displayed component entries are retained.
% Initial transcription is text checked; image review is tracked separately.
% No production coefficients, gearing, tolerances or rotor physics are changed.

if nargin < 1, outputRoot=fullfile(pwd,'ci_artifacts','line_b_fixed_input'); end
if ~exist(outputRoot,'dir'), mkdir(outputRoot); end
[P,contract]=xv15_helicopter_trim_parameters_v1();
Pbefore=P; mp=mass_properties(0,P); d2r=pi/180;
% Run the primary 60-kt point first, then the existing 40/80/100-kt checks.
speed=[60;40;80;100];
theta=[-5.69;-2.52;-9.35;-12.61];
alpha=[-5.70;-2.52;-9.35;-12.61];
u_ftps=[100.80;67.45;133.20;164.70];
w_ftps=[-10.04;-2.97;-21.93;-36.86];
stick=[5.29;5.07;5.80;6.94]; elev=[2.34;1.27;4.71;10.13];
% Columns: body X [lbf], body Z [lbf], CG pitch M [lbf ft].
rf=[-42.62,-21.25,-2107.49;-15.85,-26.14,-598.52; ...
    -104,44.09,-5308.99;-229.31,196.52,-10466.28];
rh=[-9.95,-78.06,-1665.80;-3.86,-75.39,-1619; ...
    -10.67,31.09,689.59;26.08,320.06,6856.20];
sourcePages=[180;179;181;182];
rows=repmat(empty_row(),0,1); records={}; testCount=0;
for i=1:numel(speed)
    alloc=xv15_helicopter_control_allocation(stick(i),0,P);
    for stateMode=1:2
        x=zeros(9,1); x(8)=theta(i)*d2r;
        if stateMode==1
            x(1)=speed(i)*(1852/3600)*cos(alpha(i)*d2r);
            x(3)=speed(i)*(1852/3600)*sin(alpha(i)*d2r);
            stateLabel='SPEED_ALPHA';
        else
            x(1)=u_ftps(i)*0.3048; x(3)=w_ftps(i)*0.3048;
            stateLabel='TABULATED_UW';
        end
        [F,M,d]=fuselage_model(x,mp.cgShift,P);
        append('fuselage','NO_CONTROL',NaN,F,M,d,rf(i,:));
        [F,M,d]=horizontal_tail_model(x,elev(i)*d2r,mp.cgShift,P);
        append('horizontalTail','REFERENCE_ACTUAL_ELEVATOR',elev(i),F,M,d,rh(i,:));
        [F,M,d]=horizontal_tail_model(x,alloc.elevator,mp.cgShift,P);
        append('horizontalTail','CURRENT_STICK_MAPPING',alloc.elevator/d2r,F,M,d,rh(i,:));
    end
end
assert(isequaln(P,Pbefore),'Audit modified parameter structure.'); testCount=testCount+1;
points=struct2table(rows); writetable(points,fullfile(outputRoot,'FIXED_INPUT_COMPONENTS.csv'));
% Verify the existing gearing against both published columns, not just GTRS.
reference=readtable(fullfile(fileparts(mfilename('fullpath')), ...
    'reference_gtrs_helicopter_trim_kleinhesselink2007.csv'));
calcG=(reference.stick_gtrs_in-4.8)*4.17;
calcM=(reference.stick_mathmodel_in-4.8)*4.17;
control=table(reference.speed_kts,calcG,reference.elevator_gtrs_deg, ...
    calcG-reference.elevator_gtrs_deg,calcM,reference.elevator_mathmodel_deg, ...
    calcM-reference.elevator_mathmodel_deg, ...
    'VariableNames',{'speed_kt','fromGtrsStick_deg','gtrsElevator_deg', ...
    'gtrsDifference_deg','fromMathModelStick_deg','mathModelElevator_deg', ...
    'mathModelDifference_deg'});
writetable(control,fullfile(outputRoot,'CONTROL_MAPPING.csv'));
% Published 60-kt airframe component sum versus the published aggregate.
components60=[-42.62,-21.25,-2107.49;-743.88,-1035.99,478.28; ...
    -9.95,-78.06,-1665.80;-0.8,0,2.26;-0.8,0,2.26];
aggregate60=[-978.84,-1122.49,-3015.29];
sourceClosure=table(sum(components60,1).',aggregate60.', ...
    (aggregate60-sum(components60,1)).', ...
    'RowNames',{'X_lbf','Z_lbf','M_lbfft'}, ...
    'VariableNames',{'componentSum','printedAggregate','unassignedDifference'});
writetable(sourceClosure,fullfile(outputRoot,'SOURCE_AGGREGATE_DIFFERENCE_60KT.csv'),'WriteRowNames',true);
[~,head]=system('git rev-parse HEAD');
meta=struct('identity','LINE_B_FIXED_INPUT_COMPONENT_AUDIT_V1', ...
    'baseline','9d0c2abce6a3367ec8c46ca7aeb534b45b8ed728', ...
    'head',strtrim(head),'matlabVersion',version,'matlabRelease',version('-release'), ...
    'computer',computer,'utc',char(datetime('now','TimeZone','UTC')), ...
    'componentEvaluations',numel(rows),'internalChecksPassed',testCount, ...
    'newTrimSearches',0,'newRotorEvaluations',0,'productionPhysicsChanged',false, ...
    'referenceRole','PUBLISHED_GTRS_REFERENCE_SIMULATION_NOT_FLIGHT_TRUTH', ...
    'referenceImageReview','PENDING_INDEPENDENT_IMAGE_REVIEW', ...
    'claim','Descriptive discrepancies only; no external accuracy PASS assigned.');
fid=fopen(fullfile(outputRoot,'RUN_MANIFEST.json'),'w'); assert(fid>=0);
c=onCleanup(@() fclose(fid)); fwrite(fid,jsonencode(meta),'char'); clear c;
results=struct('points',points,'records',{records},'control',control, ...
    'sourceClosure',sourceClosure,'meta',meta,'contract',contract);
save(fullfile(outputRoot,'FIXED_INPUT_RESULTS.mat'),'results','P');
disp(points(strcmp(points.stateMode,'SPEED_ALPHA'), ...
    {'speed_kt','component','controlMode','elevator_deg','alphaEff_deg', ...
    'X_lbf','Z_lbf','M_lbfft','dX_lbf','dZ_lbf','dM_lbfft'}));
disp(control); disp(sourceClosure); disp(meta);

    function append(comp,controlMode,elevatorDeg,F,M,d,ref)
        assert(isreal([F;M]) && all(isfinite([F;M])),'Nonfinite component load.');
        assert(norm(M-d.Maero-d.Marm)<1e-9*max(1,norm(M)),'Moment split failed.');
        assert(norm(d.Marm-cross(d.rAC,F))<1e-9*max(1,norm(M)),'Force arm failed.');
        % Translation of both datum positions and CG must leave all loads invariant.
        shift=[1.125;-0.875;0.625]; Ps=P;
        if strcmp(comp,'fuselage')
            Ps.fuselage.rAC=Ps.fuselage.rAC+shift;
            [Ft,Mt]=fuselage_model(x,mp.cgShift+shift,Ps);
        else
            Ps.htail.rAC=Ps.htail.rAC+shift;
            [Ft,Mt]=horizontal_tail_model(x,elevatorDeg*d2r,mp.cgShift+shift,Ps);
        end
        assert(norm([Ft-F;Mt-M])<1e-9*max(1,norm([F;M])),'Datum invariance failed.');
        testCount=testCount+4;
        r=empty_row(); r.speed_kt=speed(i); r.component=comp; r.stateMode=stateLabel;
        r.controlMode=controlMode; r.elevator_deg=elevatorDeg;
        r.theta_deg=theta(i); r.alpha_deg=atan2(x(3),x(1))/d2r;
        r.V_mps=norm(x(1:3)); r.qbar_Pa=d.qbar;
        r.rX_m=d.rAC(1); r.rZ_m=d.rAC(3); r.CL=d.CL; r.CD=d.CD;
        if isfield(d,'alphaEff'), r.alphaEff_deg=d.alphaEff/d2r; end
        r.X_lbf=F(1)/4.4482216152605; r.Z_lbf=F(3)/4.4482216152605;
        r.M_lbfft=M(2)/(4.4482216152605*0.3048);
        r.Maero_lbfft=d.Maero(2)/(4.4482216152605*0.3048);
        r.Marm_lbfft=d.Marm(2)/(4.4482216152605*0.3048);
        r.referenceX_lbf=ref(1); r.referenceZ_lbf=ref(2); r.referenceM_lbfft=ref(3);
        r.dX_lbf=r.X_lbf-ref(1); r.dZ_lbf=r.Z_lbf-ref(2); r.dM_lbfft=r.M_lbfft-ref(3);
        r.sourcePrintedPage=sourcePages(i); r.sourcePdfPage=sourcePages(i)+16;
        rows(end+1,1)=r; records{end+1,1}=struct('x',x,'F',F,'M',M,'data',d);
    end
end
function r=empty_row()
r=struct('speed_kt',NaN,'component','','stateMode','','controlMode','', ...
    'elevator_deg',NaN,'theta_deg',NaN,'alpha_deg',NaN,'V_mps',NaN, ...
    'qbar_Pa',NaN,'rX_m',NaN,'rZ_m',NaN,'alphaEff_deg',NaN,'CL',NaN,'CD',NaN, ...
    'X_lbf',NaN,'Z_lbf',NaN,'M_lbfft',NaN,'Maero_lbfft',NaN,'Marm_lbfft',NaN, ...
    'referenceX_lbf',NaN,'referenceZ_lbf',NaN,'referenceM_lbfft',NaN, ...
    'dX_lbf',NaN,'dZ_lbf',NaN,'dM_lbfft',NaN,'sourcePrintedPage',NaN,'sourcePdfPage',NaN);
end
