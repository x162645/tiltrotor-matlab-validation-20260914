function report=test_gtrs_wing_airplane_source_coefficients()
%TEST_GTRS_WING_AIRPLANE_SOURCE_COEFFICIENTS Source-table regression checks.
% Checks exact cells, interpolation inside source brackets and domain bounds.
report=struct('identity','GTRS_CR166536_WING_AIRPLANE_XFL1_SOURCE_TEST','passed',false);
[cl,cd,cm,meta]=gtrs_wing_airplane_source_coefficients(0,.1);
assert(abs(cl-.38)<1e-12 && abs(cd-.0204)<1e-12 && abs(cm+.025)<1e-12);
[cl,cd]=gtrs_wing_airplane_source_coefficients(0,.4);
assert(abs(cl-.38)<1e-12 && abs(cd-.0204)<1e-12);
[cl,cd]=gtrs_wing_airplane_source_coefficients(4*pi/180,.5);
assert(abs(cl-.77)<1e-12 && abs(cd-.0418)<1e-12);
[cl,cd]=gtrs_wing_airplane_source_coefficients(4*pi/180,.3);
assert(abs(cl-(.72+.75)/2)<1e-12 && abs(cd-.0418)<1e-12);
try
 gtrs_wing_airplane_source_coefficients(20*pi/180,.6); error('test:ExpectedError','Unsupported alpha was accepted.');
catch ME
 assert(strcmp(ME.identifier,'gtrs_wing_airplane_source_coefficients:OutsideAlphaDomain'));
end
assert(strcmp(meta.sourceTables,'CR-166536 Table 4-I/4-III/4-VIII'));
report.passed=true; report.samples=3; report.source=meta.sourceTables;
end
