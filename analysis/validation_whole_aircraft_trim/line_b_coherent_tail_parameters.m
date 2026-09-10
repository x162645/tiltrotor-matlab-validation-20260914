function P=line_b_coherent_tail_parameters(P)
% Explicit source-coherent tail instance; does not mutate baseline constructor.
T=gtrs_heli_tail_tables();
P.htail.modelIdentity='GTRS_COHERENT_STEADY_HELI_TAIL_V3';
P.htail.S=T.area_m2;P.htail.c=T.chord_m;P.htail.rAC=T.stationBody_m;
P.htail.incidence=0; % true geometric incidence; legacy formula is not evaluated
P.interference.rotorToTailModel='FERGUSON_1988_TABLE_2IA_STEADY_HELI';
P.validation.identity='XV15_SOURCE_MAPPED_COHERENT_TAIL_V3';
P.validation.tailSource='NASA_CR166536_A38_A70_A74_A85_A88_B33_B49_B56_B65';
end
