function result = simulate_microgrid_transition(p)
% Dynamic-phasor study of droop sharing, island detection and reconnection.
n = floor(p.stop_time/p.dt)+1;
t = (0:n-1)'*p.dt;
theta = zeros(2,1); theta_grid = 0;
internal_voltage = p.nominal_voltage_rms_v*ones(2,1);
p_filtered = p.grid_connected_p_reference_w;
q_filtered = zeros(2,1);
sync_integral_hz = 0;
breaker_closed = true;
island_detected = false;
island_counter = 0;
reconnect_counter = 0;
reconnect_time = nan;
detection_time = nan;

columns = zeros(n,22);
for k = 1:n
    now = t(k);
    grid_available = now < p.grid_loss_time_s || now >= p.grid_return_time_s;
    if now >= p.grid_loss_time_s && now < p.grid_return_time_s
        breaker_closed = false; % physical loss of source; relay detection follows
    end
    if now < p.load_step_time_s
        load_p = p.initial_load_w; load_q = p.initial_load_var;
    else
        load_p = p.stepped_load_w; load_q = p.stepped_load_var;
    end
    load_admittance = (load_p-1j*load_q)/p.nominal_voltage_rms_v^2;
    grid_voltage = p.nominal_voltage_rms_v*exp(1j*theta_grid);
    inverter_voltage = internal_voltage.*exp(1j*theta);
    numerator = sum(inverter_voltage./p.inverter_impedance_ohm);
    denominator = sum(1./p.inverter_impedance_ohm)+load_admittance;
    if breaker_closed && grid_available
        numerator = numerator + grid_voltage/p.grid_impedance_ohm;
        denominator = denominator + 1/p.grid_impedance_ohm;
    end
    bus_voltage = numerator/denominator;
    inverter_current = (inverter_voltage-bus_voltage)./p.inverter_impedance_ohm;
    inverter_power = bus_voltage.*conj(inverter_current);
    if breaker_closed && grid_available
        grid_current = (grid_voltage-bus_voltage)/p.grid_impedance_ohm;
        grid_power = bus_voltage*conj(grid_current);
    else
        grid_current = 0;
        grid_power = 0;
    end

    alpha = 1-exp(-p.dt/p.power_filter_tau_s);
    p_filtered = p_filtered + alpha*(real(inverter_power)-p_filtered);
    q_filtered = q_filtered + alpha*(imag(inverter_power)-q_filtered);

    frequency_hz = p.nominal_frequency_hz ...
        - p.frequency_droop_hz_per_w.*(p_filtered-p.grid_connected_p_reference_w);
    bus_angle = angle(bus_voltage);
    bus_frequency_hz = mean(frequency_hz);

    if ~grid_available && ~island_detected
        if abs(bus_frequency_hz-p.nominal_frequency_hz) ...
                >= p.islanding_frequency_threshold_hz
            island_counter = island_counter+1;
        else
            island_counter = 0;
        end
        if island_counter*p.dt >= p.islanding_hold_s
            island_detected = true;
            detection_time = now;
        end
    end

    synchronizing = grid_available && ~breaker_closed;
    phase_error = wrap_pi(theta_grid-bus_angle);
    voltage_error = p.nominal_voltage_rms_v-abs(bus_voltage);
    sync_bias_hz = 0;
    sync_voltage_v = 0;
    if synchronizing
        sync_integral_hz = sync_integral_hz+p.sync_ki_hz_per_rad_s*phase_error*p.dt;
        sync_integral_hz = clamp(sync_integral_hz,-p.sync_frequency_limit_hz, ...
            p.sync_frequency_limit_hz);
        sync_bias_hz = clamp(p.sync_kp_hz_per_rad*phase_error+sync_integral_hz, ...
            -p.sync_frequency_limit_hz,p.sync_frequency_limit_hz);
        sync_voltage_v = clamp(p.sync_voltage_gain*voltage_error, ...
            -p.sync_voltage_limit_v,p.sync_voltage_limit_v);
        frequency_hz = frequency_hz+sync_bias_hz;
        bus_frequency_hz = mean(frequency_hz);
        ready = abs(phase_error)*180/pi < p.reconnect_phase_limit_deg ...
            && abs(bus_frequency_hz-p.nominal_frequency_hz) < p.reconnect_frequency_limit_hz ...
            && abs(voltage_error)/p.nominal_voltage_rms_v < p.reconnect_voltage_limit_fraction;
        if ready; reconnect_counter=reconnect_counter+1; else; reconnect_counter=0; end
        if reconnect_counter*p.dt >= p.reconnect_hold_s
            breaker_closed = true;
            reconnect_time = now;
            reconnect_counter = 0;
            sync_integral_hz = 0;
        end
    end

    voltage_command = p.nominal_voltage_rms_v+sync_voltage_v ...
        - p.voltage_droop_v_per_var.*(q_filtered-p.q_reference_var);
    voltage_command = clamp(voltage_command,0.85*p.nominal_voltage_rms_v, ...
        1.10*p.nominal_voltage_rms_v);
    internal_voltage = internal_voltage+p.dt/p.voltage_control_tau_s ...
        .*(voltage_command-internal_voltage);

    columns(k,:) = [real(bus_voltage),imag(bus_voltage),abs(bus_voltage),bus_angle, ...
        frequency_hz',real(inverter_power)',imag(inverter_power)', ...
        abs(inverter_current)',real(grid_power),imag(grid_power),abs(grid_current), ...
        double(grid_available),double(breaker_closed),double(island_detected), ...
        phase_error*180/pi,load_p,load_q,sync_bias_hz];
    theta = mod(theta+2*pi*frequency_hz*p.dt,2*pi);
    theta_grid = mod(theta_grid+2*pi*p.nominal_frequency_hz*p.dt,2*pi);
end

names = {'bus_real_v','bus_imag_v','bus_voltage_rms_v','bus_angle_rad', ...
    'frequency_1_hz','frequency_2_hz','power_1_w','power_2_w', ...
    'reactive_1_var','reactive_2_var','current_1_rms_a','current_2_rms_a', ...
    'grid_power_w','grid_reactive_var','grid_current_rms_a','grid_available', ...
    'breaker_closed','island_detected','phase_error_deg','load_power_w', ...
    'load_reactive_var','sync_bias_hz'};
result.waveforms = array2table([t columns],'VariableNames',[{'time_s'} names]);
result.parameters = p;
result.island_detection_time_s = detection_time;
result.reconnect_time_s = reconnect_time;
end

function y = clamp(x,lo,hi)
y=min(max(x,lo),hi);
end

function angle = wrap_pi(angle)
angle=mod(angle+pi,2*pi)-pi;
end
