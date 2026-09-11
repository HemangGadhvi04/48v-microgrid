function p = battery_params()
% Parametric 16-series LiFePO4 research-pack equivalent-circuit model.
p.series_cells=16;
p.capacity_ah=20;
p.initial_soc=0.65;
p.initial_temperature_c=25;
p.ambient_temperature_c=25;
p.r0_ohm=0.080;
p.r1_ohm=0.040;
p.c1_f=500;
p.thermal_capacity_j_per_k=9000;
p.thermal_conductance_w_per_k=2.5;
p.maximum_discharge_current_a=15;
p.maximum_charge_current_a=10;
p.minimum_soc=0.10;
p.maximum_soc=0.90;
p.minimum_terminal_voltage_v=40;
p.maximum_terminal_voltage_v=58;
p.dt=0.05;
p.stop_time=1200;
end
