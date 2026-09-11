function plot_solar_grid(result,report,dest)
w=result.waveforms; t=w.time_s;
fig=figure('Visible','off','Color','white','Position',[100 100 1200 850]);
tiledlayout(fig,4,1,'Padding','compact','TileSpacing','compact');
nexttile; plot(t,w.vdc_v,'Color',[0.05 0.35 0.65]); hold on;
yline(result.parameters.bus_target,'k--'); ylabel('DC bus [V]');
title('Coupled PV to grid: dynamic DC link and switching inverter');
nexttile; plot(t,w.vpv_v,'Color',[0.05 0.35 0.65]); hold on;
plot(t,w.mppt_voltage_v,'--','Color',[0.8 0.25 0.05]); ylabel('PV voltage [V]');
legend('Measured','P&O command','Location','best');
nexttile;
n=round(0.020/median(diff(t)));
plot(t,movmean(w.p_pv_w,[n-1 0]),'Color',[0.05 0.45 0.2]); hold on;
plot(t,movmean(w.p_grid_w,[n-1 0]),'Color',[0.05 0.35 0.65]);
ylabel('Power [W]'); legend('PV, trailing 20 ms mean','Grid, trailing 20 ms mean','Location','best');
nexttile;
plot(t,w.pv_energy_j-w.grid_energy_j-w.loss_energy_j ...
    -(w.stored_energy_j-result.initial_energy_j),'Color',[0.45 0.15 0.6]);
ylabel('Energy residual [J]'); xlabel('Time [s]');
for ax=findall(fig,'Type','axes')'
    set(ax,'Color','white','XColor','black','YColor','black','GridColor',[.7 .7 .7]);
    ax.Title.Color='black'; grid(ax,'on');
end
for leg=findall(fig,'Type','legend')'; set(leg,'Color','white','TextColor','black'); end
exportgraphics(fig,fullfile(dest,'solar_grid_validation.png'),'Resolution',160);
close(fig);
fig=figure('Visible','off','Color','white','Position',[100 100 1100 550]);
tiledlayout(fig,2,1,'Padding','compact');
nexttile; use=t>=0.58 & t<0.62;
plot(t(use),w.i_grid_a(use),'Color',[0.05 0.35 0.65]); hold on;
plot(t(use),w.i_reference_a(use),'k--'); ylabel('Grid current [A]');
legend('Switching plant','Controller reference','Location','best');
title(sprintf('STC current: THD %.2f%%, PF %.4f',100*report.cases.current_thd(1),report.cases.power_factor(1)));
nexttile; plot(t,w.duty_a,'Color',[0.05 0.35 0.65]); hold on;
plot(t,w.duty_b,'Color',[0.8 0.25 0.05]); ylabel('Average duty'); xlabel('Time [s]');
legend('Input leg da','Output leg db','Location','best'); ylim([0 1.05]);
for ax=findall(fig,'Type','axes')'
    set(ax,'Color','white','XColor','black','YColor','black'); ax.Title.Color='black'; grid(ax,'on');
end
for leg=findall(fig,'Type','legend')'; set(leg,'Color','white','TextColor','black'); end
exportgraphics(fig,fullfile(dest,'solar_grid_current_and_duties.png'),'Resolution',160);
close(fig);
end
