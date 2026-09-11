%% Run Closed-Loop Islanded Inverter Simulation and Transient Analysis

clear; clc;
script_dir = fileparts(mfilename('fullpath'));
cd(script_dir);

inverter_params;
model_name = 'hbridge_inverter_lc_closed_loop';
if ~exist([model_name '.slx'], 'file')
    build_closed_loop_model;
end

fprintf('\nRunning %s for %.3f s...\n', model_name, T_sim_control);
sim_out = sim(model_name);

v_ref_ts = sim_out.get('v_ref_peak');
v_est_ts = sim_out.get('v_peak_est');
m_cmd_ts = sim_out.get('m_cmd');
v_out_ts = sim_out.get('v_out');
i_load_ts = sim_out.get('i_load');
i_L_ts = sim_out.get('i_L');
R_load_ts = sim_out.get('R_load');

t = v_out_ts.Time;
v_ref_peak = squeeze(v_ref_ts.Data);
v_peak_est = squeeze(v_est_ts.Data);
m_cmd = squeeze(m_cmd_ts.Data);
v_out = squeeze(v_out_ts.Data);
i_load = squeeze(i_load_ts.Data);
i_L = squeeze(i_L_ts.Data);
R_load_signal = squeeze(R_load_ts.Data);

[v_rms_pre, ~] = cycle_rms(t, v_out, t_load_step - 0.06, t_load_step - 0.02);
[v_rms_post, ~] = cycle_rms(t, v_out, T_sim_control - 0.06, T_sim_control - 0.02);
[min_rms_step, settling_time_ms] = step_response_metrics(t, v_out, f_grid, t_load_step, V_out_rms_ref);
steady_idx = t >= T_sim_control - 3 / f_grid;
[v1_rms, v_thd_50, harmonic_rms] = harmonic_metrics(t(steady_idx), v_out(steady_idx), f_grid, 50);
p_avg_post = mean(v_out(steady_idx) .* i_load(steady_idx));

fprintf('\n=== Closed-Loop Simulation Metrics ===\n');
fprintf('Voltage target RMS          : %.2f V\n', V_out_rms_ref);
fprintf('Pre-step voltage RMS        : %.2f V\n', v_rms_pre);
fprintf('Post-step voltage RMS       : %.2f V\n', v_rms_post);
fprintf('Minimum one-cycle RMS       : %.2f V\n', min_rms_step);
fprintf('Voltage sag at load step    : %.2f %%\n', 100 * (V_out_rms_ref - min_rms_step) / V_out_rms_ref);
fprintf('2%% settling time            : %.1f ms\n', settling_time_ms);
fprintf('Post-step output THD        : %.2f %%\n', 100 * v_thd_50);
fprintf('Post-step load power        : %.1f W\n', p_avg_post);
fprintf('Final modulation command    : %.3f\n', mean(m_cmd(steady_idx)));

results_dir = fullfile(script_dir, 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

waveforms = table(t, v_out, i_load, i_L, v_peak_est, v_ref_peak, m_cmd, R_load_signal, ...
    'VariableNames', {'time_s','v_out_v','i_load_a','i_inductor_a','v_peak_est_v','v_ref_peak_v','modulation_index','r_load_ohm'});
writetable(waveforms, fullfile(results_dir, 'closed_loop_waveforms.csv'));
harmonics = table((1:50)', harmonic_rms, 'VariableNames', {'harmonic_number','v_out_rms_v'});
writetable(harmonics, fullfile(results_dir, 'closed_loop_harmonics.csv'));

fig = figure('Visible', 'off', 'Color', 'w');
tiledlayout(fig, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
ax = nexttile;
plot(t, v_out, 'Color', [0.00 0.33 0.65], 'LineWidth', 0.9); hold on;
xline(t_load_step, '--', 'Load step', 'Color', [0.35 0.35 0.35]);
style_axes(ax); ylabel('V_{out} [V]'); title('Closed-Loop Filtered Output Voltage');
ax = nexttile;
plot(t, i_load, 'Color', [0.65 0.18 0.00], 'LineWidth', 0.9); hold on;
xline(t_load_step, '--', 'Load step', 'Color', [0.35 0.35 0.35]);
style_axes(ax); ylabel('I_{load} [A]'); title('Load Current: 250 W to 500 W');
ax = nexttile;
plot(t, v_peak_est / sqrt(2), 'Color', [0.10 0.50 0.20], 'LineWidth', 1.1); hold on;
plot(t, v_ref_peak / sqrt(2), '--', 'Color', [0.10 0.10 0.10], 'LineWidth', 0.9);
xline(t_load_step, '--', 'Color', [0.35 0.35 0.35]);
style_axes(ax); ylabel('V_{RMS} [V]'); xlabel('Time [s]'); title('Synchronous Voltage Estimate and Reference');
legend('Estimated', 'Reference', 'Location', 'southeast');
exportgraphics(fig, fullfile(results_dir, 'closed_loop_load_step.png'), 'Resolution', 160);
close(fig);

window_idx = t >= t_load_step - 0.03 & t <= t_load_step + 0.08;
fig = figure('Visible', 'off', 'Color', 'w');
tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
ax = nexttile;
plot(t(window_idx) * 1000, v_peak_est(window_idx) / sqrt(2), 'Color', [0.10 0.50 0.20], 'LineWidth', 1.1); hold on;
yline(V_out_rms_ref, '--', 'Reference', 'Color', [0.1 0.1 0.1]);
xline(t_load_step * 1000, '--', 'Load step', 'Color', [0.35 0.35 0.35]);
style_axes(ax); ylabel('V_{RMS} [V]'); title('Voltage Regulation Through Load Step');
ax = nexttile;
plot(t(window_idx) * 1000, m_cmd(window_idx), 'Color', [0.45 0.15 0.60], 'LineWidth', 1.1); hold on;
xline(t_load_step * 1000, '--', 'Load step', 'Color', [0.35 0.35 0.35]);
style_axes(ax); ylabel('Modulation Index'); xlabel('Time [ms]'); title('PI Controller Command');
exportgraphics(fig, fullfile(results_dir, 'closed_loop_regulation_detail.png'), 'Resolution', 160);
close(fig);

save(fullfile(results_dir, 'closed_loop_metrics.mat'), 'v_rms_pre', 'v_rms_post', ...
    'min_rms_step', 'settling_time_ms', 'v1_rms', 'v_thd_50', 'p_avg_post', 'V_out_rms_ref');
fprintf('\nArtifacts written to %s\n', results_dir);

function [v_rms, t_center] = cycle_rms(t, v, start_time, end_time)
    idx = t >= start_time & t <= end_time;
    v_rms = sqrt(mean(v(idx).^2));
    t_center = mean(t(idx));
end

function [minimum_rms, settling_ms] = step_response_metrics(t, v, f0, step_time, target_rms)
    cycle = 1 / f0;
    sample_times = (step_time:0.001:(t(end) - cycle))';
    rms_values = zeros(size(sample_times));
    for k = 1:numel(sample_times)
        idx = t >= sample_times(k) & t < sample_times(k) + cycle;
        rms_values(k) = sqrt(mean(v(idx).^2));
    end
    minimum_rms = min(rms_values);
    in_band = abs(rms_values - target_rms) <= 0.02 * target_rms;
    settle_index = find(arrayfun(@(k) all(in_band(k:end)), 1:numel(in_band)), 1, 'first');
    if isempty(settle_index)
        settling_ms = NaN;
    else
        settling_ms = 1000 * (sample_times(settle_index) - step_time);
    end
end

function [fundamental_rms, thd_ratio, harmonic_rms] = harmonic_metrics(t, x, f0, max_harmonic)
    duration = t(end) - t(1);
    harmonic_rms = zeros(max_harmonic, 1);
    for harmonic = 1:max_harmonic
        omega = 2 * pi * f0 * harmonic;
        a = (2 / duration) * trapz(t, x .* sin(omega * t));
        b = (2 / duration) * trapz(t, x .* cos(omega * t));
        harmonic_rms(harmonic) = hypot(a, b) / sqrt(2);
    end
    fundamental_rms = harmonic_rms(1);
    thd_ratio = sqrt(sum(harmonic_rms(2:end).^2)) / fundamental_rms;
end

function style_axes(ax)
    grid(ax, 'on'); ax.Color = 'w'; ax.XColor = 'k'; ax.YColor = 'k';
    ax.GridColor = [0.75 0.75 0.75]; ax.FontName = 'Helvetica'; ax.FontSize = 10;
    ax.Title.Color = 'k'; ax.XLabel.Color = 'k'; ax.YLabel.Color = 'k';
end
