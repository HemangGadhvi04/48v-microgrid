%% Run and validate the switching-level LCL/grid-interface model
clear; clc;
script_dir = fileparts(mfilename('fullpath'));
cd(script_dir);
grid_tie_params;
build_lcl_grid_model;

model_name = 'hbridge_lcl_grid_open_loop';
fprintf('Running %s for %.3f s...\n',model_name,T_sim_grid);
sim_out = sim(model_name);

signals = {'v_inv','v_grid','breaker','i1','i_grid','v_pcc','v_cap','m_cmd'};
for k=1:numel(signals)
    ts = sim_out.get(signals{k});
    if k==1; t=ts.Time; end
    data.(signals{k}) = squeeze(ts.Data);
end

% Use the final two complete line cycles before the excitation step so the
% synchronous projection does not leak 50 Hz energy between components.
pre = t >= t_injection-2/f_grid_tie & t < t_injection;
post = t >= T_sim_grid-3/f_grid_tie;
transient = t >= t_breaker & t < t_breaker+0.020;

i_pre_rms = sqrt(mean(data.i_grid(pre).^2));
[i_pre_fund_rms,~,~] = harmonic_metrics(t(pre),data.i_grid(pre),f_grid_tie,10);
i_pre_ripple_rms = sqrt(max(0,i_pre_rms^2-i_pre_fund_rms^2));
i_post_rms = sqrt(mean(data.i_grid(post).^2));
p_post = mean(data.v_grid(post).*data.i_grid(post));
v_pcc_post_rms = sqrt(mean(data.v_pcc(post).^2));
breaker_peak_current = max(abs(data.i_grid(transient)));
[i1_fund_rms,i_thd,harmonic_rms] = harmonic_metrics(t(post),data.i_grid(post),f_grid_tie,50);

% The filter should be nearly idle when equal synchronized voltages are connected.
I_grid_nom = P_grid_nom/V_grid_rms;
assert(i_pre_fund_rms < 0.05*I_grid_nom, ...
    'Synchronized breaker-close fundamental current is too high: %.3f A RMS.',i_pre_fund_rms);
assert(breaker_peak_current < 5.0,'Breaker transient is too high: %.3f A.',breaker_peak_current);
assert(isfinite(i_thd) && i1_fund_rms > 0.25,'Post-step current measurement is invalid.');

fprintf('\n=== LCL/Grid Interface Metrics ===\n');
fprintf('Analytical LCL resonance       : %.1f Hz\n',f_res_lcl);
fprintf('Pre-injection grid current RMS : %.3f A\n',i_pre_rms);
fprintf('Pre-injection fundamental RMS  : %.3f A\n',i_pre_fund_rms);
fprintf('Pre-injection ripple RMS       : %.3f A\n',i_pre_ripple_rms);
fprintf('Breaker-close peak current     : %.3f A\n',breaker_peak_current);
fprintf('Post-step grid current RMS     : %.3f A\n',i_post_rms);
fprintf('Post-step fundamental RMS      : %.3f A\n',i1_fund_rms);
fprintf('Post-step grid-current THD     : %.2f %%\n',100*i_thd);
fprintf('Post-step injected real power  : %.1f W\n',p_post);
fprintf('Post-step PCC voltage RMS      : %.2f V\n',v_pcc_post_rms);

results_dir=fullfile(script_dir,'results');
if ~exist(results_dir,'dir'); mkdir(results_dir); end
waveforms=table(t,data.v_inv,data.v_grid,data.v_pcc,data.i1,data.i_grid, ...
    data.v_cap,data.breaker,data.m_cmd,'VariableNames', ...
    {'time_s','v_inv_v','v_grid_v','v_pcc_v','i_inverter_a','i_grid_a', ...
    'v_cap_v','breaker_closed','modulation_index'});
writetable(waveforms,fullfile(results_dir,'lcl_grid_waveforms.csv'));
harmonics=table((1:50)',harmonic_rms,'VariableNames',{'harmonic_number','grid_current_rms_a'});
writetable(harmonics,fullfile(results_dir,'lcl_grid_harmonics.csv'));
save(fullfile(results_dir,'lcl_grid_metrics.mat'),'i_pre_rms','i_pre_fund_rms', ...
    'i_pre_ripple_rms','i_post_rms', ...
    'breaker_peak_current','i1_fund_rms','i_thd','p_post','v_pcc_post_rms','f_res_lcl');

fig=figure('Visible','off','Color','w');
tiledlayout(fig,3,1,'Padding','compact','TileSpacing','compact');
ax=nexttile; plot(t,data.v_grid,'k',t,data.v_pcc,'Color',[0 0.4 0.75],'LineWidth',0.8); grid on;
xline(t_breaker,'--','Breaker'); xline(t_injection,'--','Excitation'); ylabel('Voltage [V]');
title('Low-Voltage Grid and PCC'); legend('Grid','PCC','Location','best'); ax.XColor='k'; ax.YColor='k';
ax=nexttile; plot(t,data.i_grid,'Color',[0.75 0.2 0],'LineWidth',0.8); grid on;
xline(t_breaker,'--'); xline(t_injection,'--'); ylabel('Grid current [A]'); title('LCL-Filtered Grid Current'); ax.XColor='k'; ax.YColor='k';
ax=nexttile; stairs(t,data.breaker,'k','LineWidth',1.0); hold on; plot(t,data.m_cmd,'Color',[0.45 0.15 0.6]); grid on;
ylabel('Command'); xlabel('Time [s]'); legend('Breaker','Modulation','Location','best'); ax.XColor='k'; ax.YColor='k';
exportgraphics(fig,fullfile(results_dir,'lcl_grid_transient.png'),'Resolution',180);
close(fig);
fprintf('Artifacts written to %s\n',results_dir);

function [fundamental_rms,thd_ratio,harmonic_rms]=harmonic_metrics(t,x,f0,max_harmonic)
duration=t(end)-t(1); harmonic_rms=zeros(max_harmonic,1);
for h=1:max_harmonic
    w=2*pi*f0*h;
    a=(2/duration)*trapz(t,x.*sin(w*t));
    b=(2/duration)*trapz(t,x.*cos(w*t));
    harmonic_rms(h)=hypot(a,b)/sqrt(2);
end
fundamental_rms=harmonic_rms(1);
thd_ratio=sqrt(sum(harmonic_rms(2:end).^2))/fundamental_rms;
end
