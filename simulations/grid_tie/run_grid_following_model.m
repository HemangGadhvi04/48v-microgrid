%% Run full switching-level grid-following current-control milestone
clear; clc;
script_dir=fileparts(mfilename('fullpath'));
cd(script_dir);
grid_following_params;
build_grid_following_model;
sim_out=sim('hbridge_lcl_grid_following');

names={'p_ref','q_ref','v_ref_pu','i_ref','theta_est','f_est','locked','saturated', ...
    'v_inv','v_grid','breaker','i1','i_grid','v_pcc','v_cap'};
for k=1:numel(names)
    raw.(names{k})=sim_out.get(names{k});
end
t=raw.i_grid.Time;
for k=1:numel(names)
    ts=raw.(names{k}); values=squeeze(ts.Data);
    if numel(ts.Time)==numel(t) && all(ts.Time==t)
        x.(names{k})=values;
    else
        x.(names{k})=interp1(ts.Time,values,t,'previous','extrap');
    end
end

steady=t>=t_q_step-3/f_grid_tie & t<t_q_step;
reactive=t>=T_sim_gfl-3/f_grid_tie;
close_event=find(x.breaker>0.5,1,'first');
assert(~isempty(close_event),'PLL never authorized breaker closure.');
close_time=t(close_event);
close_window=t>=close_time & t<close_time+0.02;

v_rms=sqrt(mean(x.v_grid(steady).^2));
i_rms=sqrt(mean(x.i_grid(steady).^2));
p_injected=mean(x.v_grid(steady).*x.i_grid(steady));
apparent=v_rms*i_rms;
power_factor=p_injected/apparent;
tracking_error_rms=sqrt(mean((x.i_ref(steady)-x.i_grid(steady)).^2));
saturation_fraction=mean(x.saturated(steady)>0.5);
breaker_peak=max(abs(x.i_grid(close_window)));
[i_fund_rms,i_thd,harmonic_rms]=harmonic_metrics(t(steady),x.i_grid(steady),f_grid_tie,50);
[p_reactive,q_reactive]=pq_metrics(t(reactive),x.v_grid(reactive),x.i_grid(reactive),f_grid_tie);

assert(p_injected>0.90*P_ref_final && p_injected<1.05*P_ref_final, ...
    'Injected power %.1f W is outside the 90-105%% acceptance band.',p_injected);
assert(power_factor>0.99,'Power factor %.4f is below 0.99.',power_factor);
assert(i_thd<0.05,'Grid-current THD %.2f%% exceeds 5%%.',100*i_thd);
assert(saturation_fraction<0.01,'Steady modulation saturation exceeds 1%%.');
assert(breaker_peak<5.0,'Synchronized breaker transient exceeds 5 A.');
assert(p_reactive>0.90*P_ref_final && p_reactive<1.05*P_ref_final, ...
    'Real power changed excessively during reactive-power injection.');
assert(q_reactive>0.90*Q_ref_test && q_reactive<1.10*Q_ref_test, ...
    'Reactive power %.1f var is outside the 90-110%% acceptance band.',q_reactive);

fprintf('\n=== Grid-Following Inverter Metrics ===\n');
fprintf('PLL-authorized breaker close : %.2f ms\n',1e3*close_time);
fprintf('Injected real power          : %.1f W\n',p_injected);
fprintf('Grid current RMS/fundamental : %.2f / %.2f A\n',i_rms,i_fund_rms);
fprintf('Power factor                 : %.4f\n',power_factor);
fprintf('Grid-current THD             : %.2f %%\n',100*i_thd);
fprintf('Current tracking error RMS   : %.3f A\n',tracking_error_rms);
fprintf('Steady saturation fraction   : %.3f %%\n',100*saturation_fraction);
fprintf('Breaker-close peak current   : %.3f A\n',breaker_peak);
fprintf('Reactive-test P / Q           : %.1f W / %.1f var\n',p_reactive,q_reactive);

results_dir=fullfile(script_dir,'results'); if ~exist(results_dir,'dir'); mkdir(results_dir); end
waveforms=table(t,x.p_ref,x.q_ref,x.v_grid,x.v_pcc,x.i_ref,x.i_grid,x.i1,x.v_ref_pu, ...
    x.theta_est,x.f_est,x.locked,x.breaker,x.saturated,'VariableNames', ...
    {'time_s','power_reference_w','reactive_reference_var','v_grid_v','v_pcc_v','i_reference_a','i_grid_a', ...
    'i_inverter_a','voltage_reference_pu','theta_est_rad','frequency_est_hz', ...
    'pll_locked','breaker_closed','modulation_saturated'});
writetable(waveforms,fullfile(results_dir,'grid_following_waveforms.csv'));
harmonics=table((1:50)',harmonic_rms,'VariableNames',{'harmonic_number','grid_current_rms_a'});
writetable(harmonics,fullfile(results_dir,'grid_following_harmonics.csv'));
save(fullfile(results_dir,'grid_following_metrics.mat'),'close_time','p_injected','i_rms', ...
    'i_fund_rms','power_factor','i_thd','tracking_error_rms','saturation_fraction', ...
    'breaker_peak','p_reactive','q_reactive');

fig=figure('Visible','off','Color','w'); tiledlayout(fig,3,1,'Padding','compact','TileSpacing','compact');
ax=nexttile; plot(t,x.v_grid,'k',t,x.v_pcc,'Color',[0 .4 .75]); grid on; ylabel('Voltage [V]'); title('Grid-Following Inverter'); legend('Grid','PCC','Location','best'); ax.XColor='k';ax.YColor='k';
ax=nexttile; plot(t,x.i_ref,'k--',t,x.i_grid,'Color',[.75 .2 0]); grid on; ylabel('Current [A]'); legend('Reference','Grid','Location','best'); ax.XColor='k';ax.YColor='k';
ax=nexttile; plot(t,x.p_ref,'Color',[.35 .15 .65]); hold on; plot(t,x.q_ref,'Color',[0 .5 .2]); yline(p_injected,'--','Measured unity-PF P'); grid on; ylabel('P [W], Q [var]'); xlabel('Time [s]'); legend('P ref','Q ref','Location','best'); ax.XColor='k';ax.YColor='k';
exportgraphics(fig,fullfile(results_dir,'grid_following_validation.png'),'Resolution',180); close(fig);
fprintf('Artifacts written to %s\n',results_dir);

function [fundamental_rms,thd_ratio,harmonic_rms]=harmonic_metrics(t,x,f0,max_harmonic)
duration=t(end)-t(1); harmonic_rms=zeros(max_harmonic,1);
for h=1:max_harmonic
    w=2*pi*f0*h; a=(2/duration)*trapz(t,x.*sin(w*t)); b=(2/duration)*trapz(t,x.*cos(w*t));
    harmonic_rms(h)=hypot(a,b)/sqrt(2);
end
fundamental_rms=harmonic_rms(1); thd_ratio=sqrt(sum(harmonic_rms(2:end).^2))/fundamental_rms;
end

function [p,q]=pq_metrics(t,v,i,f0)
duration=t(end)-t(1); w=2*pi*f0;
v_sin=(2/duration)*trapz(t,v.*sin(w*t));
v_cos=(2/duration)*trapz(t,v.*cos(w*t));
i_sin=(2/duration)*trapz(t,i.*sin(w*t));
i_cos=(2/duration)*trapz(t,i.*cos(w*t));
p=0.5*(v_sin*i_sin+v_cos*i_cos);
q=0.5*(v_cos*i_sin-v_sin*i_cos);
end
