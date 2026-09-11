%% Inverter Parameters & Filter Design Script
% Project: 48V Open-Source Microgrid Research Platform (500W)
% Subsystem: Single-Phase Full-Bridge (H-Bridge) Inverter with LC Filter
% Author: Hemang & Antigravity

clc;
fprintf('=== 48V Microgrid Inverter Parameters Initialized ===\n');

%% 1. DC Source & Power Ratings
Vdc      = 48.0;          % Nominal DC Bus Voltage [V]
P_nom    = 500.0;         % Nominal Active Power [W]
f_grid   = 50.0;          % Fundamental AC Frequency [Hz]
omega_0  = 2 * pi * f_grid; % Fundamental Angular Frequency [rad/s]

%% 2. Modulation Settings (SPWM)
f_sw     = 20000.0;       % Carrier / Switching Frequency [Hz] (20 kHz)
T_sw     = 1 / f_sw;      % Switching Period [s]
m_a      = 0.85;          % Amplitude Modulation Index (0 < m_a <= 1.0)
m_f      = f_sw / f_grid; % Frequency Modulation Ratio (400)

% Expected Output Voltages
V_ac_pk  = m_a * Vdc;             % Peak Fundamental Inverter Voltage [V] (~40.8 V)
V_ac_rms = V_ac_pk / sqrt(2);     % RMS Fundamental Output Voltage [V] (~28.85 V)
I_ac_rms = P_nom / V_ac_rms;      % Nominal RMS Output Current [A] (~17.33 A)
I_ac_pk  = I_ac_rms * sqrt(2);    % Nominal Peak Output Current [A] (~24.51 A)

%% 3. Load Specifications (500W Nominal Resistive Load)
R_load   = (V_ac_rms^2) / P_nom;  % Load Resistance [Ohms] (~1.664 Ohms)
fprintf('Nominal AC RMS Voltage : %.2f V\n', V_ac_rms);
fprintf('Nominal AC RMS Current : %.2f A\n', I_ac_rms);
fprintf('Nominal Load Resistance: %.3f Ohms\n', R_load);

%% 4. LC Output Filter Design
% Current ripple constraint (max 15-25% of peak current)
% For Unipolar SPWM: Delta_IL_max = Vdc / (8 * f_sw * L_f)
target_ripple_ratio = 0.20;       % 20% peak ripple
Delta_IL_target     = target_ripple_ratio * I_ac_pk; % [A]
L_min               = Vdc / (8 * f_sw * Delta_IL_target); % [H]

% Select standard practical inductor value
L_f      = 100e-6;        % Filter Inductor [H] (100 uH)
R_Lf     = 0.015;         % Inductor ESR [Ohms] (15 mOhms)

% Capacitor constraint 1: Reactive power < 5% of P_nom
C_max_var = (0.05 * P_nom) / (omega_0 * V_ac_rms^2); % [F] (~95.6 uF)

% Capacitor constraint 2: Cutoff frequency: 10*f_grid < f_c < 0.2*f_sw
% 500 Hz < f_c < 4000 Hz
C_f      = 47e-6;         % Filter Capacitor [F] (47 uF)
R_Cf_esr = 0.010;         % Capacitor ESR [Ohms] (10 mOhms)

% Passive Damping Resistor in series with Cf to prevent resonance peaking
% R_d ~ (1/3) * (1 / (2*pi*f_c*C_f))
f_c      = 1 / (2 * pi * sqrt(L_f * C_f)); % Cutoff Frequency [Hz]
R_d      = (1 / 3) * (1 / (2 * pi * f_c * C_f)); % Damping Resistance [Ohms] (~0.48 Ohms)
R_d      = 0.50;          % Practical chosen damping resistor [Ohms]

fprintf('\n--- LC Filter Performance ---\n');
fprintf('Inductance (L_f)       : %.1f uH (ESR: %.1f mOhm)\n', L_f * 1e6, R_Lf * 1e3);
fprintf('Capacitance (C_f)      : %.1f uF\n', C_f * 1e6);
fprintf('Cutoff Frequency (f_c) : %.1f Hz (Design range: 500 - 4000 Hz)\n', f_c);
fprintf('Damping Resistor (R_d) : %.2f Ohms\n', R_d);

%% 5. Simulation Solver Parameters
T_step   = 1e-6;          % Max step size for continuous solver / sample time [s] (1 us)
T_sim    = 0.10;          % Simulation duration (5 grid cycles at 50 Hz) [s]

%% 6. Islanded Voltage-Control and Load-Step Parameters
% The closed-loop model regulates the fundamental output voltage by varying
% the SPWM modulation depth. A synchronous sin/cos estimator removes the
% switching ripple before the PI controller sees the measurement.
V_out_rms_ref = V_ac_rms;                  % Controlled AC output target [V RMS]
V_out_pk_ref  = sqrt(2) * V_out_rms_ref;   % Fundamental peak target [V]
m_min         = 0.00;                      % Modulation lower bound
m_max         = 0.95;                      % Modulation upper bound

R_load_half   = (V_out_rms_ref^2) / (0.5 * P_nom); % 250 W initial load [Ohm]
R_load_nom    = (V_out_rms_ref^2) / P_nom;         % 500 W final load [Ohm]
t_load_step   = 0.18;                      % 250 W -> 500 W step time [s]
t_soft_start  = 0.06;                      % Voltage reference ramp duration [s]
T_sim_control = 0.35;                      % Closed-loop run duration [s]

% Exact one-line-cycle moving average for synchronous voltage measurement.
N_line_cycle = round(1 / (f_grid * T_step));
Kp_voltage          = 0.010;               % Proportional gain [1/V]
Ki_voltage          = 1.20;                % Integral gain [1/(V*s)]

%% 7. Derived Simulink Helper Parameters
% Triangle carrier for a normalized unipolar SPWM comparator.
carrier_time   = [0, T_sw / 2, T_sw];
carrier_values = [-1, 1, -1];

% Damped LC filter transfer function from bridge voltage to load voltage.
% Topology: bridge -> Lf + RLf -> output node, with Rload in parallel with
% a series branch of Rd + Cf. The capacitor ESR is lumped into Rd for the
% first switching model.
R_d_total = R_d + R_Cf_esr;
lc_tf_num = [R_load * C_f * R_d_total, R_load];
lc_tf_den = [ ...
    L_f * C_f * (R_load + R_d_total), ...
    L_f + R_Lf * C_f * (R_load + R_d_total) + R_load * C_f * R_d_total, ...
    R_Lf + R_load ...
];

fprintf('\nParameters loaded successfully into workspace.\n');
