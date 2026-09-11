function plot_microgrid_transition(result,report,dest)
w=result.waveforms; p=result.parameters;
fig=figure('Visible','off','Color','w');
tiledlayout(fig,4,1,'Padding','compact','TileSpacing','compact');
ax=nexttile; plot(w.time_s,w.bus_voltage_rms_v,'LineWidth',1.1); hold on;
yline(p.nominal_voltage_rms_v,'k--'); grid on; ylabel('PCC V RMS'); title('Grid-forming island and synchronized reconnection'); ax.XColor='k';ax.YColor='k';
ax=nexttile; plot(w.time_s,w.frequency_1_hz,w.time_s,w.frequency_2_hz,'LineWidth',1.0); hold on; yline(50,'k--'); grid on; ylabel('Frequency [Hz]'); legend('Source 1','Source 2','Grid','Location','best'); ax.XColor='k';ax.YColor='k';
ax=nexttile; plot(w.time_s,w.power_1_w,w.time_s,w.power_2_w,w.time_s,w.grid_power_w,'LineWidth',1.0); grid on; ylabel('Power [W]'); legend('Source 1','Source 2','Grid','Location','best'); ax.XColor='k';ax.YColor='k';
ax=nexttile; stairs(w.time_s,w.grid_available,'k','LineWidth',1.0); hold on; stairs(w.time_s,w.breaker_closed,'LineWidth',1.0); plot(w.time_s,w.phase_error_deg/10,'LineWidth',0.8); grid on; ylabel('State / phase÷10'); xlabel('Time [s]'); legend('Grid available','Breaker','Phase error / 10','Location','best'); ax.XColor='k';ax.YColor='k';
exportgraphics(fig,fullfile(dest,'microgrid_transition.png'),'Resolution',180); close(fig);

fig=figure('Visible','off','Color','w');
tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
ax=nexttile; plot(w.time_s,w.reactive_1_var,w.time_s,w.reactive_2_var,'LineWidth',1.0); grid on; ylabel('Q [var]'); legend('Source 1','Source 2','Location','best'); title(sprintf('Droop sharing: P1 %.1f%%, Q1 %.1f%%',100*report.metrics.post_step_active_share_1,100*report.metrics.post_step_reactive_share_1)); ax.XColor='k';ax.YColor='k';
ax=nexttile; plot(w.time_s,w.current_1_rms_a,w.time_s,w.current_2_rms_a,w.time_s,w.grid_current_rms_a,'LineWidth',1.0); grid on; ylabel('RMS current [A]'); xlabel('Time [s]'); legend('Source 1','Source 2','Grid','Location','best'); ax.XColor='k';ax.YColor='k';
exportgraphics(fig,fullfile(dest,'microgrid_sharing_and_current.png'),'Resolution',180); close(fig);
end
