function [data, report] = read_full_aircraft_sync_csv(filePath)
%READ_FULL_AIRCRAFT_SYNC_CSV Read and gate a synchronized aircraft record.
% Accepts only explicit SI-unit columns on one common time base. It does
% not infer actuator position from commanded collective or missing outputs.
if nargin < 1 || ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
    error('fullAircraftSync:InvalidPath','filePath must be a scalar text path.');
end
filePath = char(filePath);
if ~isfile(filePath)
    error('fullAircraftSync:MissingFile','Synchronized record not found: %s',filePath);
end
required = {'time_s','collective_actual_rad','nacelle_left_rad','nacelle_right_rad', ...
    'rotor_speed_left_rad_s','rotor_speed_right_rad_s','rotor_thrust_left_N', ...
    'rotor_thrust_right_N','u_m_s','v_m_s','w_m_s','p_rad_s','q_rad_s','r_rad_s', ...
    'phi_rad','theta_rad','psi_rad','altitude_m'};
T = readtable(filePath,'VariableNamingRule','preserve');
names = T.Properties.VariableNames;
missing = required(~ismember(required,names));
if ~isempty(missing)
    error('fullAircraftSync:MissingColumns','Required columns missing: %s',strjoin(missing,', '));
end
values = zeros(height(T),numel(required));
for k = 1:numel(required)
    v = T.(required{k});
    if ~isnumeric(v) || ~isvector(v)
        error('fullAircraftSync:NonNumeric','Column %s must be numeric.',required{k});
    end
    values(:,k) = double(v(:));
end
if isempty(values) || any(~isfinite(values(:)))
    error('fullAircraftSync:Nonfinite','Required columns contain NaN or Inf.');
end
dt = diff(values(:,1));
if any(dt <= 0)
    error('fullAircraftSync:InvalidTime','time_s must be strictly increasing.');
end
if max(dt)-min(dt) > max(1e-6,1e-3*median(dt))
    error('fullAircraftSync:Unsynchronized','time_s spacing is not sufficiently uniform.');
end
data = T;
report = struct('schema','FULL_AIRCRAFT_SYNC_V1', ...
    'requiredColumns',{required(:)},'rows',height(T), ...
    'dtMedian_s',median(dt),'dtMin_s',min(dt),'dtMax_s',max(dt), ...
    'measuredActualCollective',true,'measuredRotorLoads',true, ...
    'commonTimeBase',true,'externalValidationEligible',true);
end
