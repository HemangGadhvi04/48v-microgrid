function report = run_battery_validation()
here=fileparts(mfilename('fullpath')); addpath(here);
p=battery_params(); result=simulate_battery(p); report=validate_battery(result);
dest=fullfile(here,'results'); if ~exist(dest,'dir'); mkdir(dest); end
writetable(result.waveforms,fullfile(dest,'battery_waveforms.csv'));
save(fullfile(dest,'battery_validation.mat'),'result','report');
plot_battery(result,dest); disp(report.metrics); disp(report.checks);
assert(report.passed,'Battery validation failed; inspect report.checks.');
fprintf('PASS: bidirectional battery, limits, thermal and energy checks.\n');
end
