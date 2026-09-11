function p = microgrid_transition_params()
% Parameters for two-source grid-forming, islanding and reconnection study.
p.dt = 1e-4;
p.stop_time = 2.30;
p.nominal_frequency_hz = 50;
p.nominal_voltage_rms_v = 28.85;
p.grid_impedance_ohm = 0.05 + 1j*2*pi*50*20e-6;
p.inverter_impedance_ohm = [0.04 + 1j*2*pi*50*250e-6; ...
                            0.06 + 1j*2*pi*50*375e-6];
p.power_rating_w = [300; 200];
p.reactive_rating_var = [180; 120];
p.grid_connected_p_reference_w = 0.4*p.power_rating_w;
p.q_reference_var = [0; 0];
p.frequency_droop_hz_per_w = 1.0./p.power_rating_w;
p.voltage_droop_v_per_var = 1.5./p.reactive_rating_var;
p.power_filter_tau_s = 0.020;
p.voltage_control_tau_s = 0.010;
p.grid_loss_time_s = 0.40;
p.load_step_time_s = 0.72;
p.grid_return_time_s = 1.02;
p.initial_load_w = 400;
p.initial_load_var = 80;
p.stepped_load_w = 500;
p.stepped_load_var = 120;
p.islanding_frequency_threshold_hz = 0.20;
p.islanding_hold_s = 0.020;
p.sync_kp_hz_per_rad = 3.0;
p.sync_ki_hz_per_rad_s = 8.0;
p.sync_frequency_limit_hz = 2.0;
p.sync_voltage_gain = 2.0;
p.sync_voltage_limit_v = 3.0;
p.reconnect_phase_limit_deg = 2.0;
p.reconnect_frequency_limit_hz = 0.10;
p.reconnect_voltage_limit_fraction = 0.02;
p.reconnect_hold_s = 0.050;
p.maximum_source_current_rms_a = [14; 10];
p.maximum_reconnect_grid_current_rms_a = 20.0;
end
