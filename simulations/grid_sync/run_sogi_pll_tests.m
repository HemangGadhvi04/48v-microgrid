%% Run SOGI-PLL validation suite
clear; clc;
script_dir=fileparts(mfilename('fullpath'));
cd(script_dir);
pll_params;
build_sogi_pll_model;
sim_out=sim('sogi_pll_validation');

names={'v_grid','theta_actual','f_actual','theta_est','f_est','v_alpha','v_beta','v_q','amplitude'};
for k=1:numel(names)
    ts=sim_out.get(names{k});
    if k==1; t=ts.Time; end
    x.(names{k})=squeeze(ts.Data);
end
phase_error=atan2(sin(x.theta_est-x.theta_actual),cos(x.theta_est-x.theta_actual));
phase_error_deg=rad2deg(phase_error);
cycle_samples=round(1/(f_pll_nom*T_pll));
frequency_cycle_mean=movmean(x.f_est,cycle_samples);
phase_cycle_mean=movmean(phase_error_deg,cycle_samples);

startup_settle=settling_after(t,abs(phase_cycle_mean)<2 & abs(frequency_cycle_mean-x.f_actual)<0.10,0.02,0.005);
freq_settle=settling_after(t,abs(phase_cycle_mean)<2 & abs(frequency_cycle_mean-x.f_actual)<0.10,t_freq_step,0.005);
phase_settle=settling_after(t,abs(phase_cycle_mean)<2,t_phase_jump,0.005);
sag_window=t>=t_sag_start+0.02 & t<t_sag_end;
sag_phase_peak=max(abs(phase_cycle_mean(sag_window)));
final_window=t>=T_pll_sim-0.04;
final_freq_error=abs(mean(x.f_est(final_window)-x.f_actual(final_window)));
final_freq_ripple=std(x.f_est(final_window)-x.f_actual(final_window));

fprintf('\n=== SOGI-PLL Validation ===\n');
fprintf('Startup lock time            : %.2f ms\n',1e3*startup_settle);
fprintf('50 to 52 Hz settling         : %.2f ms\n',1e3*freq_settle);
fprintf('20 degree jump settling      : %.2f ms\n',1e3*phase_settle);
fprintf('Sag steady phase-error peak  : %.3f deg\n',sag_phase_peak);
fprintf('Final mean frequency error   : %.4f Hz\n',final_freq_error);
fprintf('Final frequency ripple RMS   : %.4f Hz\n',final_freq_ripple);

assert(startup_settle < 0.060,'PLL startup lock exceeds three grid cycles.');
assert(freq_settle < 0.060,'PLL frequency-step settling exceeds 60 ms.');
assert(phase_settle < 0.040,'PLL phase-jump settling exceeds 40 ms.');
assert(sag_phase_peak < 4.0,'PLL phase error during sag exceeds 4 degrees.');
assert(final_freq_error < 0.05,'PLL final frequency error exceeds 0.05 Hz.');

results_dir=fullfile(script_dir,'results');
if ~exist(results_dir,'dir'); mkdir(results_dir); end
results=table(t,x.v_grid,x.theta_actual,x.theta_est,x.f_actual,x.f_est,phase_error_deg, ...
    frequency_cycle_mean,phase_cycle_mean,x.v_alpha,x.v_beta,x.v_q,x.amplitude,'VariableNames', ...
    {'time_s','v_grid_v','theta_actual_rad','theta_est_rad','frequency_actual_hz', ...
    'frequency_est_hz','phase_error_deg','frequency_cycle_mean_hz','phase_cycle_mean_deg', ...
    'v_alpha_v','v_beta_v','v_q_pu','amplitude_v'});
writetable(results,fullfile(results_dir,'sogi_pll_waveforms.csv'));
save(fullfile(results_dir,'sogi_pll_metrics.mat'),'startup_settle','freq_settle', ...
    'phase_settle','sag_phase_peak','final_freq_error','final_freq_ripple');

fig=figure('Visible','off','Color','w');
tiledlayout(fig,3,1,'Padding','compact','TileSpacing','compact');
ax=nexttile; plot(t,x.v_grid,'Color',[0 0.35 0.70]); grid on; ylabel('Grid voltage [V]'); title('Disturbed Single-Phase Grid'); ax.XColor='k'; ax.YColor='k';
ax=nexttile; plot(t,x.f_actual,'k--',t,x.f_est,'Color',[0.75 0.2 0],'LineWidth',1.0); grid on; ylabel('Frequency [Hz]'); legend('Actual','PLL','Location','best'); ax.XColor='k'; ax.YColor='k';
ax=nexttile; plot(t,phase_error_deg,'Color',[0.35 0.15 0.65]); grid on; ylabel('Phase error [deg]'); xlabel('Time [s]'); ylim([-25 25]); ax.XColor='k'; ax.YColor='k';
exportgraphics(fig,fullfile(results_dir,'sogi_pll_validation.png'),'Resolution',180);
close(fig);
fprintf('Artifacts written to %s\n',results_dir);

function delay=settling_after(t,good,event_time,hold_time)
start=find(t>=event_time,1,'first'); samples=max(1,round(hold_time/median(diff(t))));
delay=inf;
for k=start:numel(t)-samples
    if all(good(k:k+samples)); delay=t(k)-event_time; return; end
end
end
