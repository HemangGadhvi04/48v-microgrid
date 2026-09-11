function result = simulate_solar_grid(p)
% Deterministic MATLAB execution of the same step function used by Simulink.
if nargin==0; p=solar_grid_params(); end
s=solar_grid_initial_state(p);
n=round(p.stop_time/p.dt);
stride=round(10e-6/p.dt); % retain 100 kHz waveforms, integrate faster
assert(stride>=1 && abs(stride*p.dt-10e-6)<1e-12);
Y=zeros(floor(n/stride),24); tt=zeros(size(Y,1),1); GG=tt; TT=tt;
initial_energy=0.5*(p.Cpv*p.initial_pv^2+p.Cdc*p.initial_bus^2);
row=0;
for k=1:n
    [G,T]=solar_grid_profile((k-1)*p.dt);
    [s,y]=solar_grid_step(s,G,T,p);
    if mod(k,stride)==0
        row=row+1; Y(row,:)=y'; tt(row)=k*p.dt; GG(row)=G; TT(row)=T;
    end
end
names={'vpv_v','il_dc_a','vdc_v','i_inverter_a','v_cap_ac_v','i_grid_a', ...
    'v_grid_v','i_reference_a','p_command_w','mppt_voltage_v','duty_a','duty_b', ...
    'modulation','pll_hz','connected','saturated','p_pv_w','p_grid_w','p_loss_w', ...
    'stored_energy_j','pv_energy_j','grid_energy_j','loss_energy_j','il_command_a'};
result.waveforms=[table(tt,GG,TT,'VariableNames',{'time_s','irradiance_w_m2','temperature_degC'}), ...
    array2table(Y,'VariableNames',names)];
result.parameters=p;
result.initial_energy_j=initial_energy;
end
