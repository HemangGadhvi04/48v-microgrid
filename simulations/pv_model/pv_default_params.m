function params = pv_default_params()
% Nominal 500 W-class array used by the low-voltage research platform.
params.I_sc_stc = 11.55;      % Short-circuit current at STC [A]
params.V_oc_stc = 58.0;       % Open-circuit voltage at STC [V]
params.I_mp_stc = 10.75;      % Nameplate guide only [A]
params.V_mp_stc = 46.8;       % Nameplate guide only [V]
params.alpha_isc = 0.00055;   % Temperature coefficient of Isc [A/degC]
params.beta_voc  = -0.0032;   % Fractional Voc coefficient [1/degC], metadata
params.N_s       = 96;        % Effective series-cell count
params.n_diode   = 1.25;      % Diode ideality factor
params.R_s       = 0.28;      % Effective series resistance [ohm]
params.R_sh      = 450.0;     % Effective shunt resistance [ohm]
end

