%% Grid-following current-controller parameters
grid_tie_params;

T_sim_gfl       = 0.46;
T_control_gfl   = 1/f_sw_grid;       % 20 kHz controller/ADC rate
t_power_start   = 0.12;
t_power_ramp    = 0.10;
P_ref_final     = 500.0;
Q_ref_test      = 150.0;
t_q_step        = 0.32;
m_gfl_max       = 0.95;

% Stationary-frame proportional-resonant current controller.
current_bw_hz   = 500.0;
Kp_current      = 0.65;               % [V/A]
Kr_current      = 28.0;               % resonant peak gain [V/A]
wc_current      = 2*pi*5.0;           % resonant damping bandwidth [rad/s]
current_phase_comp_samples = 2.5;     % ADC/control/PWM effective delay

% Embedded SOGI-PLL (same validated structure and sample rate).
k_sogi_gfl      = sqrt(2);
pll_bw_gfl_hz   = 12.0;
Kp_pll_gfl      = 2*0.707*2*pi*pll_bw_gfl_hz;
Ki_pll_gfl      = (2*pi*pll_bw_gfl_hz)^2;
f_pll_min_gfl   = 45.0;
f_pll_max_gfl   = 55.0;
pll_lock_q_max  = 0.04;
pll_lock_hold   = 0.010;

fprintf('GFL target: %.1f W at %.2f V RMS; rated current %.2f A RMS\n', ...
    P_ref_final,V_grid_rms,P_ref_final/V_grid_rms);
