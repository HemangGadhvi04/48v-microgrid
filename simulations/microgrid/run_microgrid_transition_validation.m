function report = run_microgrid_transition_validation()
here=fileparts(mfilename('fullpath')); addpath(here);
p=microgrid_transition_params();
result=simulate_microgrid_transition(p);
report=validate_microgrid_transition(result);
dest=fullfile(here,'results'); if ~exist(dest,'dir'); mkdir(dest); end
writetable(result.waveforms,fullfile(dest,'microgrid_transition_waveforms.csv'));
save(fullfile(dest,'microgrid_transition_validation.mat'),'result','report');
plot_microgrid_transition(result,report,dest);
disp(report.metrics); disp(report.checks);
assert(report.passed,'Microgrid transition validation failed; inspect report.checks.');
fprintf('PASS: droop sharing, island detection, synchronization and reconnection checks.\n');
end
