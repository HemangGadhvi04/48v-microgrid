function summary = run_phase1_validation()
%RUN_PHASE1_VALIDATION Execute every retained Phase 1 acceptance test.
% Each legacy runner executes in the base workspace because some are scripts
% that intentionally clear their caller. This function retains orchestration
% state and writes a machine-readable pass/fail summary.

root = fileparts(fileparts(mfilename('fullpath')));
simulation_root = fullfile(root, 'simulations');

names = {
    'Open-loop inverter'
    'Closed-loop islanded inverter'
    'LCL grid interface'
    'SOGI-PLL'
    'Grid-following inverter'
    'PV source'
    'P&O MPPT'
    'Coupled solar-to-grid'
};

commands = {
    runner(fullfile(simulation_root, 'inverter', 'run_open_loop_inverter.m'))
    runner(fullfile(simulation_root, 'inverter', 'run_closed_loop_inverter.m'))
    runner(fullfile(simulation_root, 'grid_tie', 'run_lcl_grid_model.m'))
    runner(fullfile(simulation_root, 'grid_sync', 'run_sogi_pll_tests.m'))
    runner(fullfile(simulation_root, 'grid_tie', 'run_grid_following_model.m'))
    runner(fullfile(simulation_root, 'pv_model', 'run_pv_validation.m'))
    runner(fullfile(simulation_root, 'mppt', 'run_po_mppt_validation.m'))
    sprintf("addpath('%s'); run_solar_grid_validation();", ...
        escape_quotes(fullfile(simulation_root, 'system')))
};

passed = false(size(names));
elapsed_s = nan(size(names));
message = strings(size(names));

fprintf('\n=== Phase 1 Regression Suite ===\n');
for k = 1:numel(names)
    fprintf('\n[%d/%d] %s\n', k, numel(names), names{k});
    started = tic;
    try
        evalin('base', commands{k});
        passed(k) = true;
        message(k) = "PASS";
    catch exception
        message(k) = string(exception.message);
    end
    elapsed_s(k) = toc(started);
    fprintf('%s (%.1f s)\n', message(k), elapsed_s(k));
end

summary = table(string(names), passed, elapsed_s, message, ...
    'VariableNames', {'stage', 'passed', 'elapsed_s', 'message'});
results_dir = fullfile(simulation_root, 'results');
if ~exist(results_dir, 'dir'); mkdir(results_dir); end
writetable(summary, fullfile(results_dir, 'phase1_regression_summary.csv'));
save(fullfile(results_dir, 'phase1_regression_summary.mat'), 'summary');

disp(summary);
assert(all(passed), 'Phase 1 regression suite failed. Inspect summary.message.');
fprintf('PASS: all %d Phase 1 validation stages completed.\n', numel(names));
end

function command = runner(path)
command = sprintf("run('%s');", escape_quotes(path));
end

function value = escape_quotes(value)
value = strrep(value, "'", "''");
end
