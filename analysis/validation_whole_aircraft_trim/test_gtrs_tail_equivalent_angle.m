function report=test_gtrs_tail_equivalent_angle()
% Checks independently hand-calculated A85/A86 equivalent-angle results.
[cl,cd,m]=gtrs_horizontal_tail_source_coefficients(0,10,.4);
a=.965*.518*10;
assert(abs(m.alphaEquivalent_deg-a)<1e-12);
assert(abs(cl-.0775*a)<1e-10);
assert(abs(cd-(.015+.005*(a-4)))<1e-10);
[lo,~,~]=gtrs_horizontal_tail_source_coefficients(0,10,.1);
assert(abs(lo-.40825)<1e-10);
[z,~,~]=gtrs_horizontal_tail_source_coefficients(0,0,.3);
assert(abs(z)<1e-10);
[p,~,~]=gtrs_horizontal_tail_source_coefficients(0,.001,.4);
[n,~,~]=gtrs_horizontal_tail_source_coefficients(0,-.001,.4);
assert(abs((p-n)/.002-(.0775*.965*.518))<1e-8);
[~,~,m]=gtrs_horizontal_tail_source_coefficients(0,20,.4);
assert(abs(m.Ke-(.965-.24*5/15))<1e-12);
report=struct('passed',true,'source','CR166536 A85/A86 and T5-I..IV',...
 'claim','COEFFICIENT_IMPLEMENTATION_CHECK_NOT_AIRCRAFT_VALIDATION');
disp(report);
end
