function result = simulate_battery(p)
n=floor(p.stop_time/p.dt)+1; t=(0:n-1)'*p.dt;
soc=zeros(n,1); vrc=zeros(n,1); temperature=zeros(n,1);
ocv=zeros(n,1); current=zeros(n,1); terminal_voltage=zeros(n,1);
command_power=zeros(n,1); terminal_power=zeros(n,1); loss_power=zeros(n,1);
soc(1)=p.initial_soc; temperature(1)=p.initial_temperature_c;
for k=1:n
    ocv(k)=battery_ocv(soc(k),p);
    command_power(k)=battery_power_profile(t(k));
    source_voltage=ocv(k)-vrc(k);
    discriminant=source_voltage^2-4*p.r0_ohm*command_power(k);
    assert(discriminant>0,'Requested battery power has no physical current solution.');
    current(k)=(source_voltage-sqrt(discriminant))/(2*p.r0_ohm);
    terminal_voltage(k)=source_voltage-p.r0_ohm*current(k);
    terminal_power(k)=terminal_voltage(k)*current(k);
    loss_power(k)=p.r0_ohm*current(k)^2+vrc(k)^2/p.r1_ohm;
    if k<n
        dsoc=-current(k)/(p.capacity_ah*3600);
        dvrc=(p.r1_ohm*current(k)-vrc(k))/(p.r1_ohm*p.c1_f);
        dtemp=(loss_power(k)-p.thermal_conductance_w_per_k ...
            *(temperature(k)-p.ambient_temperature_c))/p.thermal_capacity_j_per_k;
        predictor=[soc(k);vrc(k);temperature(k)]+p.dt*[dsoc;dvrc;dtemp];
        ocv_predict=battery_ocv(predictor(1),p);
        source_predict=ocv_predict-predictor(2);
        discriminant_predict=source_predict^2-4*p.r0_ohm*battery_power_profile(t(k+1));
        current_predict=(source_predict-sqrt(discriminant_predict))/(2*p.r0_ohm);
        loss_predict=p.r0_ohm*current_predict^2+predictor(2)^2/p.r1_ohm;
        derivative_predict=[-current_predict/(p.capacity_ah*3600); ...
            (p.r1_ohm*current_predict-predictor(2))/(p.r1_ohm*p.c1_f); ...
            (loss_predict-p.thermal_conductance_w_per_k ...
            *(predictor(3)-p.ambient_temperature_c))/p.thermal_capacity_j_per_k];
        next=[soc(k);vrc(k);temperature(k)]+0.5*p.dt ...
            *([dsoc;dvrc;dtemp]+derivative_predict);
        soc(k+1)=next(1); vrc(k+1)=next(2); temperature(k+1)=next(3);
    end
end
chemical_power=ocv.*current;
stored_polarization_energy=0.5*p.c1_f*vrc.^2;
chemical_energy=cumtrapz(t,chemical_power);
terminal_energy=cumtrapz(t,terminal_power);
loss_energy=cumtrapz(t,loss_power);
storage_change=stored_polarization_energy-stored_polarization_energy(1);
energy_residual=chemical_energy-terminal_energy-loss_energy-storage_change;
result.waveforms=table(t,soc,ocv,current,terminal_voltage,command_power, ...
    terminal_power,vrc,temperature,chemical_energy,terminal_energy,loss_energy, ...
    stored_polarization_energy,energy_residual,'VariableNames', ...
    {'time_s','soc','ocv_v','current_a','terminal_voltage_v','command_power_w', ...
    'terminal_power_w','polarization_voltage_v','temperature_c', ...
    'chemical_energy_j','terminal_energy_j','loss_energy_j', ...
    'polarization_energy_j','energy_residual_j'});
result.parameters=p;
end
