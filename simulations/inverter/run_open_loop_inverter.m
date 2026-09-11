%% Run Open-Loop H-Bridge Inverter Simulation and Basic Waveform Analysis
% Project: 48V Open-Source Microgrid Research Platform
% Requires: MATLAB, Simulink

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
cd(script_dir);

build_simulink_model;

model_name = 'hbridge_inverter_lc_open_loop';
fprintf('\nRunning %s for %.3f s...\n', model_name, T_sim);
sim_out = sim(model_name);

v_inv_ts  = sim_out.get('v_inv');
v_out_ts  = sim_out.get('v_out');
i_load_ts = sim_out.get('i_load');

t = v_out_ts.Time;
v_inv = squeeze(v_inv_ts.Data);
v_out = squeeze(v_out_ts.Data);
i_load = squeeze(i_load_ts.Data);

% Analyze the last three full line cycles after startup.
analysis_start = T_sim - 3 / f_grid;
idx = t >= analysis_start;
t_a = t(idx);
v_inv_a = v_inv(idx);
v_out_a = v_out(idx);
i_load_a = i_load(idx);

[v1_rms, v_thd_50, harmonic_rms] = harmonic_metrics(t_a, v_out_a, f_grid, 50);
[spectrum_hz, spectrum_vpk] = single_sided_spectrum(t_a, v_inv_a);

switching_idx = spectrum_hz >= 1000 & spectrum_hz <= 100000;
switching_freqs = spectrum_hz(switching_idx);
switching_amps = spectrum_vpk(switching_idx);
[sorted_amps, sorted_idx] = sort(switching_amps, 'descend');
top_count = min(8, numel(sorted_idx));
dominant_switching_hz = switching_freqs(sorted_idx(1:top_count));
dominant_switching_vpk = sorted_amps(1:top_count);

i_rms = rms_local(i_load_a);
p_avg = mean(v_out_a .* i_load_a);
v_inv_rms = rms_local(v_inv_a);
v_out_rms = rms_local(v_out_a);

fprintf('\n=== Open-Loop Simulation Metrics ===\n');
fprintf('Bridge voltage RMS          : %.2f V\n', v_inv_rms);
fprintf('Filtered output RMS         : %.2f V\n', v_out_rms);
fprintf('Filtered fundamental RMS    : %.2f V\n', v1_rms);
fprintf('Load current RMS            : %.2f A\n', i_rms);
fprintf('Average load power          : %.1f W\n', p_avg);
fprintf('Voltage THD, 2nd-50th harm. : %.2f %%\n', 100 * v_thd_50);
fprintf('Dominant bridge HF lines    : ');
fprintf('%.0f Hz ', dominant_switching_hz(1:min(4, top_count)));
fprintf('\n');

results_dir = fullfile(script_dir, 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

waveform_table = table(t, v_inv, v_out, i_load, ...
    'VariableNames', {'time_s', 'v_inv_v', 'v_out_v', 'i_load_a'});
writetable(waveform_table, fullfile(results_dir, 'open_loop_waveforms.csv'));

harmonic_table = table((1:50)', harmonic_rms, ...
    'VariableNames', {'harmonic_number', 'v_out_rms_v'});
writetable(harmonic_table, fullfile(results_dir, 'open_loop_harmonics.csv'));

spectrum_table = table(spectrum_hz(:), spectrum_vpk(:), ...
    'VariableNames', {'frequency_hz', 'bridge_voltage_peak_v'});
writetable(spectrum_table, fullfile(results_dir, 'open_loop_bridge_spectrum.csv'));

fig = figure('Visible', 'off', 'Color', 'w');
tiledlayout(fig, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

ax = nexttile;
plot(t, v_inv, 'Color', [0.15 0.15 0.15], 'LineWidth', 0.8);
style_axes(ax);
ylabel('V_{inv} [V]');
title('Unipolar SPWM H-Bridge Output');

ax = nexttile;
plot(t, v_out, 'Color', [0.00 0.33 0.65], 'LineWidth', 1.0);
style_axes(ax);
ylabel('V_{out} [V]');
title('Damped LC Filtered Output');

ax = nexttile;
plot(t, i_load, 'Color', [0.65 0.18 0.00], 'LineWidth', 1.0);
style_axes(ax);
ylabel('I_{load} [A]');
xlabel('Time [s]');
title('Resistive Load Current');

exportgraphics(fig, fullfile(results_dir, 'open_loop_waveforms.png'), 'Resolution', 160);
close(fig);

detail_idx = t >= 0.040 & t <= 0.042;
fig = figure('Visible', 'off', 'Color', 'w');
tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

ax = nexttile;
stairs(t(detail_idx) * 1000, v_inv(detail_idx), 'Color', [0.15 0.15 0.15], 'LineWidth', 0.8);
style_axes(ax);
ylabel('V_{inv} [V]');
title('Switching Detail: 2 ms Window');

ax = nexttile;
plot(t(detail_idx) * 1000, v_out(detail_idx), 'Color', [0.00 0.33 0.65], 'LineWidth', 1.0);
style_axes(ax);
ylabel('V_{out} [V]');
xlabel('Time [ms]');
title('Filtered Ripple Detail');

exportgraphics(fig, fullfile(results_dir, 'open_loop_switching_detail.png'), 'Resolution', 160);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w');
tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

ax = nexttile;
bar(1:50, harmonic_rms, 'FaceColor', [0.00 0.33 0.65], 'EdgeColor', 'none');
style_axes(ax);
xlim([1 50]);
ylabel('RMS Voltage [V]');
title('Filtered Output Harmonics');

ax = nexttile;
spectrum_plot_idx = spectrum_hz <= 100000;
plot(spectrum_hz(spectrum_plot_idx) / 1000, spectrum_vpk(spectrum_plot_idx), ...
    'Color', [0.15 0.15 0.15], 'LineWidth', 0.8);
style_axes(ax);
xlabel('Frequency [kHz]');
ylabel('Peak Voltage [V]');
title('Bridge Voltage Spectrum');

exportgraphics(fig, fullfile(results_dir, 'open_loop_spectrum.png'), 'Resolution', 160);
close(fig);

save(fullfile(results_dir, 'open_loop_metrics.mat'), ...
    'v1_rms', 'v_thd_50', 'i_rms', 'p_avg', 'v_inv_rms', 'v_out_rms', ...
    'dominant_switching_hz', 'dominant_switching_vpk');

fprintf('\nArtifacts written to %s\n', results_dir);

function value = rms_local(x)
    value = sqrt(mean(x(:) .^ 2));
end

function [fundamental_rms, thd_ratio, harmonic_rms] = harmonic_metrics(t, x, f0, max_harmonic)
    x = x(:);
    t = t(:);
    duration = t(end) - t(1);

    harmonic_rms = zeros(max_harmonic, 1);
    for harmonic = 1:max_harmonic
        omega = 2 * pi * f0 * harmonic;
        a = (2 / duration) * trapz(t, x .* sin(omega * t));
        b = (2 / duration) * trapz(t, x .* cos(omega * t));
        harmonic_rms(harmonic) = hypot(a, b) / sqrt(2);
    end

    fundamental_rms = harmonic_rms(1);
    thd_ratio = sqrt(sum(harmonic_rms(2:end) .^ 2)) / fundamental_rms;
end

function [frequency_hz, peak_amplitude] = single_sided_spectrum(t, x)
    t = t(:);
    x = x(:) - mean(x(:));
    sample_time = median(diff(t));
    sample_rate = 1 / sample_time;
    n = numel(x);

    spectrum = fft(x);
    two_sided = abs(spectrum / n);
    one_sided = two_sided(1:floor(n / 2) + 1);
    one_sided(2:end-1) = 2 * one_sided(2:end-1);

    frequency_hz = sample_rate * (0:floor(n / 2)) / n;
    peak_amplitude = one_sided;
end

function style_axes(ax)
    grid(ax, 'on');
    ax.Color = 'w';
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = [0.75 0.75 0.75];
    ax.MinorGridColor = [0.85 0.85 0.85];
    ax.FontName = 'Helvetica';
    ax.FontSize = 10;
    ax.Title.Color = 'k';
    ax.XLabel.Color = 'k';
    ax.YLabel.Color = 'k';
end
