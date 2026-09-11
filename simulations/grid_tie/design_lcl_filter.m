%% Analyze and export the selected LCL filter response
clear; clc;
script_dir = fileparts(mfilename('fullpath'));
cd(script_dir);
grid_tie_params;

frequency_hz = logspace(log10(10), log10(1e6), 2400)';
s = 1j*2*pi*frequency_hz;

Z1 = R1_lcl + s*L1_lcl;
Z2 = R2_total + s*L2_total;
Zc = Rd_lcl + 1./(s*C_lcl);

% With the grid-voltage source set to zero, solve the passive network.
Z_parallel = (Z2.*Zc)./(Z2 + Zc);
v_pcc_over_vinv = Z_parallel./(Z1 + Z_parallel);
ig_over_vinv = v_pcc_over_vinv./Z2;

current_gain_db = 20*log10(abs(ig_over_vinv));
current_phase_deg = unwrap(angle(ig_over_vinv))*180/pi;
[~, resonance_index] = max(abs(v_pcc_over_vinv));
measured_resonance_hz = frequency_hz(resonance_index);

results_dir = fullfile(script_dir, 'results');
if ~exist(results_dir, 'dir'); mkdir(results_dir); end

response = table(frequency_hz, current_gain_db, current_phase_deg, ...
    abs(v_pcc_over_vinv), 'VariableNames', ...
    {'frequency_hz','grid_current_gain_db_a_per_v','grid_current_phase_deg','pcc_voltage_gain'});
writetable(response, fullfile(results_dir, 'lcl_frequency_response.csv'));

fig = figure('Visible','off','Color','w');
tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
ax = nexttile;
semilogx(frequency_hz,current_gain_db,'LineWidth',1.2,'Color',[0.00 0.33 0.65]); hold on;
xline(f_grid_tie,'--','50 Hz'); xline(f_res_lcl,'--','f_{res}'); xline(f_sw_grid,'--','f_{sw}');
grid on; ylabel('|I_g/V_{inv}| [dB A/V]'); title('LCL Grid-Current Plant');
ax.XColor='k'; ax.YColor='k';
ax = nexttile;
semilogx(frequency_hz,current_phase_deg,'LineWidth',1.2,'Color',[0.65 0.18 0.00]); hold on;
xline(f_res_lcl,'--','f_{res}'); xline(f_sw_grid,'--','f_{sw}');
grid on; ylabel('Phase [deg]'); xlabel('Frequency [Hz]');
ax.XColor='k'; ax.YColor='k';
exportgraphics(fig,fullfile(results_dir,'lcl_frequency_response.png'),'Resolution',180);
close(fig);

save(fullfile(results_dir,'lcl_design.mat'), 'L1_lcl','R1_lcl','C_lcl','Rd_lcl', ...
    'L2_lcl','R2_lcl','L_grid','R_grid','f_res_lcl','Q_cap_50hz', ...
    'measured_resonance_hz');

fprintf('Analytical LCL resonance: %.1f Hz\n', f_res_lcl);
fprintf('Peak PCC response occurs at: %.1f Hz\n', measured_resonance_hz);
fprintf('Artifacts written to %s\n', results_dir);

