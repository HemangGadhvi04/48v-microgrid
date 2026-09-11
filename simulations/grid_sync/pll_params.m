%% Single-phase SOGI-PLL parameters and validation events
V_pll_rms       = 0.85*48/sqrt(2);  % Low-voltage research grid [V RMS]
V_pll_pk        = sqrt(2)*V_pll_rms;
f_pll_nom       = 50.0;             % Nominal frequency [Hz]
f_pll_step      = 52.0;             % Frequency-step target [Hz]
T_pll           = 50e-6;            % 20 kHz control update [s]
T_pll_sim       = 0.50;              % Test duration [s]

k_sogi          = sqrt(2);          % Critically useful SOGI damping choice
pll_bandwidth_hz = 12.0;            % SRF loop design bandwidth [Hz]
zeta_pll        = 0.707;
w_bw_pll        = 2*pi*pll_bandwidth_hz;
Kp_pll          = 2*zeta_pll*w_bw_pll;
Ki_pll          = w_bw_pll^2;
f_pll_min       = 45.0;
f_pll_max       = 55.0;

t_freq_step     = 0.12;
t_phase_jump    = 0.22;
phase_jump_rad  = deg2rad(20);
t_sag_start     = 0.30;
t_sag_end       = 0.36;
sag_pu          = 0.70;
h5_pu           = 0.03;              % 3% fifth harmonic
h7_pu           = 0.02;              % 2% seventh harmonic
noise_pu        = 0.002;             % deterministic HF disturbance

fprintf('SOGI-PLL: %.1f kHz update, %.1f Hz loop bandwidth\n',1e-3/T_pll,pll_bandwidth_hz);
