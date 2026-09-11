%% Grid-tie and LCL-filter parameters
% Low-voltage research-bus model. This is not a 230 V utility interface.

Vdc_grid       = 48.0;                 % DC link [V]
P_grid_nom     = 500.0;                % Rated injected power [W]
f_grid_tie     = 50.0;                 % Grid frequency [Hz]
w_grid_tie     = 2*pi*f_grid_tie;      % Grid angular frequency [rad/s]
f_sw_grid      = 20e3;                 % SPWM carrier frequency [Hz]
T_sw_grid      = 1/f_sw_grid;
T_step_grid    = 1e-6;                 % Switching-model step [s]
T_sim_grid     = 0.24;                 % Simulation duration [s]

V_grid_rms     = 0.85*Vdc_grid/sqrt(2);% Low-voltage AC research bus [V RMS]
V_grid_pk      = sqrt(2)*V_grid_rms;

% LCL filter. Grid-side total inductance includes the configurable grid.
L1_lcl         = 150e-6;               % Inverter-side inductance [H]
R1_lcl         = 15e-3;                % Inverter-side winding resistance [ohm]
C_lcl          = 20e-6;                % Filter capacitor [F]
Rd_lcl         = 0.56;                 % Series passive damping [ohm]
L2_lcl         = 75e-6;                % Grid-side filter inductance [H]
R2_lcl         = 15e-3;                % Grid-side winding resistance [ohm]
L_grid         = 20e-6;                % Configurable grid inductance [H]
R_grid         = 50e-3;                % Configurable grid resistance [ohm]
L2_total       = L2_lcl + L_grid;
R2_total       = R2_lcl + R_grid;

f_res_lcl      = sqrt((L1_lcl + L2_total)/(L1_lcl*L2_total*C_lcl))/(2*pi);
Q_cap_50hz     = w_grid_tie*C_lcl*V_grid_rms^2;
f_res_min      = 10*f_grid_tie;
f_res_max      = 0.5*f_sw_grid;

% Breaker closes only after the inverter and grid references are established.
t_breaker      = 0.080;                 % PCC breaker close time [s]
t_injection    = 0.140;                 % Small open-loop voltage step [s]
m_sync         = V_grid_pk/Vdc_grid;    % Nominal synchronized modulation
delta_m_test   = 0.006;                 % Plant-excitation step, not a power controller
m_test         = m_sync + delta_m_test;

carrier_time_grid   = [0 T_sw_grid/2 T_sw_grid];
carrier_values_grid = [-1 1 -1];

assert(f_res_lcl > f_res_min && f_res_lcl < f_res_max, ...
    'LCL resonance %.1f Hz lies outside %.1f to %.1f Hz.', ...
    f_res_lcl, f_res_min, f_res_max);
assert(Q_cap_50hz < 0.05*P_grid_nom, ...
    'Filter capacitor reactive power exceeds 5%% of rated power.');

fprintf('LCL resonance: %.1f Hz\n', f_res_lcl);
fprintf('Capacitor reactive power at 50 Hz: %.2f var (%.2f%% of rating)\n', ...
    Q_cap_50hz, 100*Q_cap_50hz/P_grid_nom);
fprintf('Low-voltage grid model: %.2f V RMS, %.1f Hz\n', V_grid_rms, f_grid_tie);

