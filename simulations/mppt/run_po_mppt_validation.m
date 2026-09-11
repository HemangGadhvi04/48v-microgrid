%% Dynamic Perturb-and-Observe MPPT validation against swept true MPP
clear; clc;
script_dir=fileparts(mfilename('fullpath'));
cd(script_dir);
addpath(fullfile(script_dir,'..','pv_model'));
params=pv_default_params();

Ts=1e-3; t=(0:Ts:0.95)'; step_v=0.20; v_min=5; v_max=0.98*params.V_oc_stc;
G=1000*ones(size(t)); G(t>=0.30)=600; G(t>=0.60)=900;
T=25*ones(size(t)); T(t>=0.75)=45;
V=zeros(size(t)); I=zeros(size(t)); P=zeros(size(t)); Pmpp=zeros(size(t)); Vmpp=zeros(size(t));
V(1)=30;
state=struct('initialized',false,'previous_voltage',0,'previous_power',0,'direction',step_v);
conditions=unique([G T],'rows');
lookup=zeros(size(conditions,1),2);
Vsweep=linspace(0,params.V_oc_stc*1.05,900);
for c=1:size(conditions,1)
    [~,Psweep]=pv_single_diode(Vsweep,conditions(c,1),conditions(c,2),params);
    [lookup(c,2),k]=max(Psweep); lookup(c,1)=Vsweep(k);
end
for k=1:numel(t)
    [I(k),P(k)]=pv_single_diode(V(k),G(k),T(k),params);
    c=find(conditions(:,1)==G(k)&conditions(:,2)==T(k),1);
    Vmpp(k)=lookup(c,1); Pmpp(k)=lookup(c,2);
    if k<numel(t)
        [V(k+1),state]=po_mppt(V(k),I(k),state,step_v,v_min,v_max);
    end
end
efficiency=P./Pmpp;
windows={t>=0.18&t<0.30,t>=0.48&t<0.60,t>=0.68&t<0.75,t>=0.88};
window_names={'1000Wm2_25C','600Wm2_25C','900Wm2_25C','900Wm2_45C'};
mean_eff=zeros(4,1); voltage_error=zeros(4,1);
for k=1:4
    mean_eff(k)=mean(efficiency(windows{k}));
    voltage_error(k)=mean(abs(V(windows{k})-Vmpp(windows{k})));
end
fprintf('\n=== P&O MPPT Validation ===\n');
for k=1:4; fprintf('%s: %.2f%% efficiency, %.3f V mean error\n',window_names{k},100*mean_eff(k),voltage_error(k)); end

assert(all(mean_eff>0.98),'P&O settled tracking efficiency fell below 98%%.');
assert(all(voltage_error<1.0),'P&O settled mean voltage error exceeded 1 V.');

summary=table(window_names',mean_eff,voltage_error,'VariableNames', ...
    {'condition','mean_tracking_efficiency','mean_voltage_error_v'});
results_dir=fullfile(script_dir,'results'); if ~exist(results_dir,'dir'); mkdir(results_dir); end
writetable(summary,fullfile(results_dir,'po_mppt_summary.csv'));
waveforms=table(t,G,T,V,I,P,Vmpp,Pmpp,efficiency,'VariableNames', ...
    {'time_s','irradiance_w_m2','temperature_degC','pv_voltage_v','pv_current_a', ...
    'pv_power_w','true_vmpp_v','true_pmpp_w','tracking_efficiency'});
writetable(waveforms,fullfile(results_dir,'po_mppt_waveforms.csv'));

fig=figure('Visible','off','Color','w'); tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
ax=nexttile; plot(t,V,'Color',[0 .35 .7],'LineWidth',1.1); hold on; plot(t,Vmpp,'k--','LineWidth',1.1); grid on; ylabel('PV voltage [V]'); legend('P&O','True MPP','Location','best'); title('P&O MPPT Dynamic Validation'); ax.Color='w';ax.XColor='k';ax.YColor='k';
ax=nexttile; plot(t,P,'Color',[.75 .2 0],'LineWidth',1.1); hold on; plot(t,Pmpp,'k--','LineWidth',1.1); grid on; ylabel('PV power [W]'); xlabel('Time [s]'); legend('Extracted','Available','Location','best'); ax.Color='w';ax.XColor='k';ax.YColor='k';
exportgraphics(fig,fullfile(results_dir,'po_mppt_validation.png'),'Resolution',180); close(fig);

fprintf('Artifacts written to %s\n',results_dir);
