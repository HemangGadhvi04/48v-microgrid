function report = validate_solar_grid(result)
% Independent electrical acceptance checks on coupled model outputs.
p=result.parameters; w=result.waveforms;
starts=[0.52 1.02 1.42 1.82 2.22]; ends=starts+0.16;
if p.stop_time<ends(end); error('Validation requires all source-profile events.'); end
here=fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','pv_model'));
pv=struct('I_sc_stc',p.pv_isc,'V_oc_stc',p.pv_voc,'alpha_isc',p.pv_alpha, ...
    'N_s',p.pv_ns,'n_diode',p.pv_n,'R_s',p.pv_rs,'R_sh',p.pv_rsh);
rows=zeros(numel(starts),12);
for n=1:numel(starts)
    use=w.time_s>=starts(n) & w.time_s<ends(n);
    tw=w.time_s(use); vg=w.v_grid_v(use); ig=w.i_grid_a(use);
    [g,temp]=solar_grid_profile(starts(n));
    [vmpp,negative_peak]=fminbnd(@(v) negative_pv_power(v,g,temp,pv),1,p.pv_voc*1.2, ...
        optimset('TolX',1e-9,'Display','off'));
    pmpp=-negative_peak;
    pvmean=mean(w.p_pv_w(use)); pgmean=mean(vg.*ig);
    harmonics=zeros(50,1);
    for h=1:50
        % Rectangular, coherent integer-cycle window; sampling excludes end.
        a=2*mean(ig.*sin(2*pi*p.grid_hz*h*tw));
        b=2*mean(ig.*cos(2*pi*p.grid_hz*h*tw));
        harmonics(h)=hypot(a,b)/sqrt(2);
    end
    thd=norm(harmonics(2:end))/harmonics(1);
    pf=pgmean/(sqrt(mean(vg.^2))*sqrt(mean(ig.^2)));
    rows(n,:)=[g,temp,vmpp,pmpp,pvmean,pvmean/pmpp,pgmean, ...
        mean(w.vdc_v(use)),max(w.vdc_v(use))-min(w.vdc_v(use)),thd,pf,mean(w.saturated(use))];
end
report.cases=array2table(rows,'VariableNames',{'irradiance_w_m2','temperature_degC', ...
    'vmpp_v','available_power_w','pv_power_w','mppt_efficiency','grid_power_w', ...
    'mean_bus_v','bus_ripple_pp_v','current_thd','power_factor','saturation_fraction'});
delta=w.stored_energy_j-result.initial_energy_j;
residual=w.pv_energy_j-w.grid_energy_j-w.loss_energy_j-delta;
report.energy_residual_peak_j=max(abs(residual));
report.energy_residual_relative=report.energy_residual_peak_j/max(1,w.pv_energy_j(end));
report.bus_min_v=min(w.vdc_v); report.bus_max_v=max(w.vdc_v);
report.il_peak_a=max(abs(w.il_dc_a)); report.ig_peak_a=max(abs(w.i_grid_a));
report.pv_energy_j=w.pv_energy_j(end); report.grid_energy_j=w.grid_energy_j(end);
report.loss_energy_j=w.loss_energy_j(end); report.stored_energy_change_j=delta(end);
report.buck_samples=sum(w.duty_a<0.995 & w.duty_b>0.995 & w.time_s>0.5);
report.boost_samples=sum(w.duty_b<0.995 & w.duty_a>0.995 & w.time_s>0.5);
report.checks=struct( ...
    'finite',all(isfinite(w{:,:}),'all'), ...
    'bus_mean',all(abs(rows(:,8)-p.bus_target)<0.01*p.bus_target), ...
    'bus_transient',report.bus_min_v>0.90*p.bus_target && report.bus_max_v<1.10*p.bus_target, ...
    'mppt',all(rows(:,6)>0.98 & rows(:,6)<1.005), ...
    'current_thd',all(rows(:,10)<0.05), ...
    'power_factor',all(rows(:,11)>0.99), ...
    'modulation_margin',all(rows(:,12)<0.01), ...
    'energy_conservation',report.energy_residual_relative<0.001, ...
    'power_export',all(rows(:,7)>0 & rows(:,7)<rows(:,5)+5), ...
    'both_converter_modes',report.buck_samples>100 && report.boost_samples>100, ...
    'inductor_current',report.il_peak_a<p.max_il*1.10, ...
    'grid_current',report.ig_peak_a<1.10*p.max_grid_peak);
report.passed=all(structfun(@(v)logical(v),report.checks));
end

function power=negative_pv_power(v,g,temp,pv)
[~,positive_power]=pv_single_diode(v,g,temp,pv);
power=-positive_power;
end
