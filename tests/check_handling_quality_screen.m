function report = check_handling_quality_screen()
%CHECK_HANDLING_QUALITY_SCREEN Regression checks for preliminary HQ metrics.
% These checks validate arithmetic, candidate selection, and the explicit
% non-certification boundary; they do not establish flight-test compliance.

names = get_state_names_13x10();
n = numel(names);
A = diag([-0.60,-0.20,-0.80,-0.50,-0.80,-0.20,-0.02,-0.40,0, ...
    -1.0,-1.1,-2.0,-2.1]);
% Longitudinal short-period pair (w,q): wn=1.61 rad/s, zeta=0.50.
A([3,5],[3,5]) = [-0.8,-1.4;1.4,-0.8];
% Lateral-directional Dutch-roll pair (v,r): wn=0.825 rad/s, zeta=0.24.
A([2,6],[2,6]) = [-0.2,-0.8;0.8,-0.2];
B = zeros(n,3);
B(4,1) = 0.4; B(5,2) = -0.7; B(6,3) = 0.2;
inputNames = {'aileron';'elevator';'rudder'};

namesOut = {}; passed = []; messages = {};
run_case('identifies dynamic candidate modes',@case_candidates);
run_case('applies transparent screening thresholds',@case_thresholds);
run_case('reports control angular acceleration',@case_controls);
run_case('retains non-certification boundary',@case_boundary);
report.names = namesOut; report.passed = passed; report.messages = messages;
report.allPassed = all(passed);
fprintf('\nPreliminary handling-quality screen checks\n');
fprintf('===========================================\n');
for k = 1:numel(namesOut)
    fprintf('%-48s : %s\n',namesOut{k},ternary(passed(k),'PASS','FAIL'));
    if ~passed(k), fprintf('  %s\n',messages{k}); end
end
fprintf('All passed: %d\n',report.allPassed);

    function out = run_screen()
        out = preliminary_handling_quality_screen(A,B,names,inputNames, ...
            'SYNTHETIC_HQ',struct());
    end
    function case_candidates()
        out = run_screen(); T = out.criteriaTable;
        assert(any(strcmp(T.criteriaId,'SHORT_PERIOD_SCREEN')));
        assert(any(strcmp(T.criteriaId,'DUTCH_ROLL_SCREEN')));
        assert(any(strcmp(T.criteriaId,'ROLL_SUBSIDENCE_SCREEN')));
        assert(any(strcmp(T.criteriaId,'SPIRAL_SCREEN')));
        assert(all(isfinite(out.modeTable.naturalFrequencyRadPerSecond)));
    end
    function case_thresholds()
        out = run_screen(); T = out.criteriaTable;
        assert(strcmp(T.status(strcmp(T.criteriaId,'SHORT_PERIOD_SCREEN')),'SCREEN_PASS'));
        assert(strcmp(T.status(strcmp(T.criteriaId,'DUTCH_ROLL_SCREEN')),'SCREEN_PASS'));
        assert(strcmp(T.status(strcmp(T.criteriaId,'ROLL_SUBSIDENCE_SCREEN')),'SCREEN_PASS'));
        assert(strcmp(T.status(strcmp(T.criteriaId,'SPIRAL_SCREEN')),'SCREEN_PASS'));
        assert(out.screenSummary.allIdentifiedAndPassing);
    end
    function case_controls()
        out = run_screen(); T = out.controlTable;
        assert(height(T) == 3);
        assert(abs(T.initialRollAccelerationPerRad(1)-0.4) < 1e-12);
        assert(abs(T.initialPitchAccelerationPerRad(2)+0.7) < 1e-12);
        assert(all(T.finiteReal));
    end
    function case_boundary()
        out = run_screen();
        assert(contains(out.claimBoundary,'not flight-test validation'));
        assert(contains(out.claimBoundary,'not formal'));
    end
    function run_case(label,fun)
        namesOut{end+1,1} = label;
        try, fun(); passed(end+1,1) = true; messages{end+1,1} = '';
        catch ME, passed(end+1,1) = false; messages{end+1,1} = ME.message;
        end
    end
end

function out = ternary(condition,yesValue,noValue)
if condition, out = yesValue; else, out = noValue; end
end
