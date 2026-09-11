function report = run_solar_grid_validation()
% Run and retain electrical evidence, including failed runs for diagnosis.
here=fileparts(mfilename('fullpath'));
addpath(here);
p=solar_grid_params();
fprintf('Running coupled PV/DC-DC/switching-grid model for %.2f s...\n',p.stop_time);
tic; result=simulate_solar_grid(p); elapsed=toc;
report=validate_solar_grid(result);
dest=fullfile(here,'results'); if ~exist(dest,'dir'); mkdir(dest); end
save(fullfile(dest,'solar_grid_validation.mat'),'result','report','elapsed');
writetable(result.waveforms,fullfile(dest,'solar_grid_waveforms.csv'));
writetable(report.cases,fullfile(dest,'solar_grid_metrics.csv'));
disp(report.cases); disp(report.checks);
fprintf('PV %.3f J = grid %.3f J + losses %.3f J + storage change %.3f J\n', ...
    report.pv_energy_j,report.grid_energy_j,report.loss_energy_j,report.stored_energy_change_j);
fprintf('Peak energy residual %.6f J (%.6f%%); elapsed %.1f s\n', ...
    report.energy_residual_peak_j,100*report.energy_residual_relative,elapsed);
plot_solar_grid(result,report,dest);
assert(report.passed,'Coupled-model validation failed; inspect saved report.checks.');
fprintf('PASS: all coupled electrical acceptance checks.\n');
end
