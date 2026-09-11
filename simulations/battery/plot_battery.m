function plot_battery(result,dest)
w=result.waveforms;
fig=figure('Visible','off','Color','w'); tiledlayout(fig,4,1,'Padding','compact','TileSpacing','compact');
ax=nexttile; plot(w.time_s,w.command_power_w,'k--',w.time_s,w.terminal_power_w,'LineWidth',1.0); grid on; ylabel('Power [W]'); legend('Command','Terminal','Location','best'); title('Bidirectional 16S LiFePO4 ECM validation'); ax.XColor='k';ax.YColor='k';
ax=nexttile; plot(w.time_s,w.current_a,'LineWidth',1.0); grid on; ylabel('Current [A]'); ax.XColor='k';ax.YColor='k';
ax=nexttile; yyaxis left; plot(w.time_s,w.terminal_voltage_v,'LineWidth',1.0); ylabel('Terminal V'); yyaxis right; plot(w.time_s,100*w.soc,'LineWidth',1.0); ylabel('SOC [%]'); grid on; ax.XColor='k';ax.YColor='k';
ax=nexttile; plot(w.time_s,w.temperature_c,'LineWidth',1.0); grid on; ylabel('Temperature [C]'); xlabel('Time [s]'); ax.XColor='k';ax.YColor='k';
exportgraphics(fig,fullfile(dest,'battery_validation.png'),'Resolution',180); close(fig);
end
