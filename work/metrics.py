import pandas as pd
c=pd.read_csv('results/xv15_40_100_continuation/XV15_40_100KT_CONTINUATION_POINTS.csv'); r=pd.read_csv('analysis/validation_whole_aircraft_trim/reference_gtrs_helicopter_trim_kleinhesselink2007.csv'); m=c[c.credible==1].merge(r[['speed_kts','theta_gtrs_deg','stick_gtrs_in','theta1s_gtrs_deg','elevator_gtrs_deg','thrust_per_rotor_gtrs_lb']],on='speed_kts');
for a,b in [('theta_deg','theta_gtrs_deg'),('stick_in','stick_gtrs_in'),('theta1sRight_deg','theta1s_gtrs_deg'),('elevator_deg','elevator_gtrs_deg'),('meanThrustPerRotor_lb','thrust_per_rotor_gtrs_lb')]: print(a, (m[a]-m[b]).abs().mean(), ((m[a]-m[b])**2).mean()**.5)
print(m[['speed_kts','theta_error_vs_GTRS_deg','stick_error_vs_GTRS_in','theta1s_error_vs_GTRS_deg','elevator_error_vs_GTRS_deg','thrust_error_vs_GTRS_pct']].to_string(index=False))

