function report = check_full_aircraft_sync_schema()
%CHECK_FULL_AIRCRAFT_SYNC_SCHEMA Test schema/rejection logic only.
% The temporary synthetic table is not an aircraft validation result.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'validation'));
names = {'time_s','collective_actual_rad','diff_collective_actual_rad', ...
    'cyclic_long_actual_rad','diff_cyclic_actual_rad','lateral_cyclic_actual_rad', ...
    'aileron_actual_rad','elevator_actual_rad','rudder_actual_rad', ...
    'nacelle_torque_left_Nm','nacelle_torque_right_Nm', ...
    'nacelle_left_rad','nacelle_right_rad', ...
    'rotor_speed_left_rad_s','rotor_speed_right_rad_s','rotor_thrust_left_N', ...
    'rotor_thrust_right_N','u_m_s','v_m_s','w_m_s','p_rad_s','q_rad_s','r_rad_s', ...
    'phi_rad','theta_rad','psi_rad','altitude_m'};
t = (0:0.01:0.05).'; z=zeros(size(t)); one=ones(size(t));
vars = repmat({z},1,numel(names));
vars{1}=t; vars{14}=100*one; vars{15}=100*one;
vars{16}=20*one; vars{17}=20*one; vars{27}=100*one;
S = table(vars{:},'VariableNames',names);
filePath = [tempname,'.csv'];
writetable(S,filePath);
[~,okReport] = read_full_aircraft_sync_csv(filePath);
assert(okReport.externalValidationEligible && okReport.rows == height(S));
S.time_s(3)=S.time_s(2); writetable(S,filePath);
caught = false;
try
    read_full_aircraft_sync_csv(filePath);
catch err
    caught=strcmp(err.identifier,'fullAircraftSync:InvalidTime');
end
assert(caught,'Non-increasing time must be rejected.');
delete_if_exists(filePath);
report=struct('allPassed',true,'schema','FULL_AIRCRAFT_SYNC_V1','syntheticOnly',true);
end
function delete_if_exists(p)
if isfile(p)
    delete(p);
end
end
