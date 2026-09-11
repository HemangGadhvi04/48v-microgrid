%% Validate the project single-diode PV model and export characteristic curves
clear; clc;
script_dir=fileparts(mfilename('fullpath'));
cd(script_dir);
params=pv_default_params();
V=linspace(0,params.V_oc_stc*1.08,700)';
irradiances=[200 400 600 800 1000];
temperatures=[10 25 45 60];

summary=[];
for G=irradiances
    [I,P]=pv_single_diode(V,G,25,params); [pmax,k]=max(P);
    summary=[summary; G 25 I(1) V(find(I>0.01,1,'last')) V(k) I(k) pmax]; %#ok<AGROW>
end
for T=temperatures
    [I,P]=pv_single_diode(V,1000,T,params); [pmax,k]=max(P);
    summary=[summary; 1000 T I(1) V(find(I>0.01,1,'last')) V(k) I(k) pmax]; %#ok<AGROW>
end
summary_table=array2table(summary,'VariableNames', ...
    {'irradiance_w_m2','temperature_degC','isc_a','voc_approx_v','vmp_v','imp_a','pmp_w'});

stc=summary_table(summary_table.irradiance_w_m2==1000 & summary_table.temperature_degC==25,:);
stc=stc(1,:); % condition appears in both the irradiance and temperature sweeps
lowG=summary_table(summary_table.irradiance_w_m2==200 & summary_table.temperature_degC==25,:);
hot=summary_table(summary_table.irradiance_w_m2==1000 & summary_table.temperature_degC==60,:);
assert(stc.pmp_w>480 && stc.pmp_w<520,'STC peak power is not 500 W class.');
assert(lowG.isc_a<0.25*stc.isc_a,'Low-irradiance short-circuit current scaling failed.');
assert(hot.voc_approx_v<stc.voc_approx_v,'Open-circuit voltage must fall as temperature rises.');
assert(all(summary_table.pmp_w>=0) && all(isfinite(summary_table{:,:}),'all'),'PV sweep contains invalid values.');

results_dir=fullfile(script_dir,'results'); if ~exist(results_dir,'dir'); mkdir(results_dir); end
writetable(summary_table,fullfile(results_dir,'pv_validation_summary.csv'));

fig=figure('Visible','off','Color','w'); tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
ax=nexttile; hold on; grid on;
for G=irradiances; [I,~]=pv_single_diode(V,G,25,params); plot(V,I,'LineWidth',1.2,'DisplayName',sprintf('%d W/m^2',G)); end
xlabel('Voltage [V]'); ylabel('Current [A]'); title('PV I-V Curves at 25 degC'); legend('Location','southwest'); ax.Color='w'; ax.XColor='k'; ax.YColor='k';
ax=nexttile; hold on; grid on;
for G=irradiances; [~,P]=pv_single_diode(V,G,25,params); plot(V,P,'LineWidth',1.2,'DisplayName',sprintf('%d W/m^2',G)); end
xlabel('Voltage [V]'); ylabel('Power [W]'); title('PV P-V Curves at 25 degC'); legend('Location','northwest'); ax.Color='w'; ax.XColor='k'; ax.YColor='k';
exportgraphics(fig,fullfile(results_dir,'pv_irradiance_curves.png'),'Resolution',180); close(fig);

fprintf('STC maximum power: %.1f W at %.2f V, %.2f A\n',stc.pmp_w,stc.vmp_v,stc.imp_a);
fprintf('60 degC approximate Voc: %.2f V (25 degC: %.2f V)\n',hot.voc_approx_v,stc.voc_approx_v);
fprintf('Artifacts written to %s\n',results_dir);
