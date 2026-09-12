function report = check_full_aircraft_sync_schema()
%CHECK_FULL_AIRCRAFT_SYNC_SCHEMA Test schema/rejection logic only.
% The temporary synthetic table is not an aircraft validation result.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'validation'));
names = {'time_s','collective_actual_rad','nacelle_left_rad','nacelle_right_rad', ...
    'rotor_speed_left_rad_s','rotor_speed_right_rad_s','rotor_thrust_left_N', ...
    'rotor_thrust_right_N','u_m_s','v_m_s','w_m_s','p_rad_s','q_rad_s','r_rad_s', ...
    'phi_rad','theta_rad','psi_rad','altitude_m'};
t = (0:0.01:0.05).'; z=zeros(size(t)); one=ones(size(t));
S = table(t,z,z,z,100*one,100*one,20*one,20*one,z,z,z,z,z,z,z,z,z,100*one, ...
    'VariableNames',names);
filePath = [tempname,'.csv']; writetable(S,filePath);
cleanup = onCleanup(@()delete_if_exists(filePath)); %#ok<NASGU>
[~,okReport] = read_full_aircraft_sync_csv(filePath);
assert(okReport.externalValidationEligible && okReport.rows == height(S));
S.time_s(3)=S.time_s(2); writetable(S,filePath);
caught=false;
try, read_full_aircraft_sync_csv(filePath); catch err
    caught=strcmp(err.identifier,'fullAircraftSync:InvalidTime');
end
assert(caught,'Non-increasing time must be rejected.');
report=struct('allPassed',true,'schema','FULL_AIRCRAFT_SYNC_V1','syntheticOnly',true);
end
function delete_if_exists(p), if isfile(p), delete(p); end, end
