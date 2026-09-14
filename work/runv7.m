cd('C:\Users\86173\Documents\Codex\2026-09-11\yue\work\tiltrotor-matlab'); addpath(fullfile(pwd,'model')); addpath(fullfile(pwd,'analysis')); addpath(fullfile(pwd,'analysis','validation_whole_aircraft_trim')); addpath(fullfile(pwd,'analysis','stage2_aircraft'));
for k=[60 80 100]
 d=fullfile(pwd,'results',sprintf('integration_audit_v7_%d',k)); if ~exist(d,'dir'),mkdir(d);end; r=run_line_b_v7_trim_case(k,d); if isfield(r,'summary'), disp(r.summary); end; end; exit
