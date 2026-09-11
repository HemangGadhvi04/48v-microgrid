function [I, P] = pv_single_diode(V, G, T_degC, params)
% PV_SINGLE_DIODE Solves the 5-parameter single-diode PV model for given voltage(s).
%
% Syntax:
%   [I, P] = pv_single_diode(V, G, T_degC, params)
%
% Inputs:
%   V       - Vector or scalar of terminal voltages [V]
%   G       - Solar irradiance [W/m^2] (Standard Test Conditions = 1000 W/m^2)
%   T_degC  - Cell temperature [°C] (STC = 25 °C)
%   params  - Optional struct with STC parameters (defaults to 500W microgrid array)
%
% Outputs:
%   I       - Terminal current [A]
%   P       - Terminal power [W] (P = V .* I)
%
% Governing Equation:
%   I = I_ph - I_0 * [exp(q*(V + I*Rs) / (n*k*T)) - 1] - (V + I*Rs) / Rsh

%% 1. Default Parameters at Standard Test Conditions (STC: 1000 W/m^2, 25°C)
if nargin < 4 || isempty(params)
    params = pv_default_params();
end

%% 2. Physical Constants
q  = 1.602176634e-19;    % Electron charge [C]
k  = 1.380649e-23;       % Boltzmann constant [J/K]
T_stc = 25 + 273.15;     % STC temperature in Kelvin [K]
T_k   = T_degC + 273.15; % Operating temperature in Kelvin [K]
delta_T = T_k - T_stc;

%% 3. Parameter Adjustments for Operating G and T
V_t = (params.N_s * params.n_diode * k * T_k) / q; % Thermal voltage [V]

% Photocurrent I_ph
I_ph = (G / 1000.0) * (params.I_sc_stc + params.alpha_isc * delta_T);

% Reverse saturation current I_0
% Bandgap energy of silicon Eg(T)
Eg_0 = 1.121; % silicon bandgap reference [eV]
I_0_stc = (params.I_sc_stc - (params.V_oc_stc / params.R_sh)) / ...
          (exp(params.V_oc_stc / ((params.N_s * params.n_diode * k * T_stc) / q)) - 1);
I_0     = I_0_stc * ((T_k / T_stc)^3) * exp((q * Eg_0 / (params.n_diode * k)) * (1/T_stc - 1/T_k));

%% 4. Solve for I(V) using Newton-Raphson Method
I = zeros(size(V));
max_iter = 50;
tol      = 1e-5;

for idx = 1:numel(V)
    v_cell = V(idx);
    
    % Initial guess: I_guess = I_ph
    i_curr = I_ph;
    
    for iter = 1:max_iter
        % f(I) = I_ph - I_0 * (exp((v + I*Rs)/V_t) - 1) - (v + I*Rs)/Rsh - I
        arg_exp = (v_cell + i_curr * params.R_s) / V_t;
        
        % Bound exponential argument to prevent numerical overflow
        if arg_exp > 100
            arg_exp = 100;
        end
        
        exp_val = exp(arg_exp);
        f_val = I_ph - I_0 * (exp_val - 1) - (v_cell + i_curr * params.R_s) / params.R_sh - i_curr;
        
        % Derivative f'(I)
        df_di = -I_0 * (params.R_s / V_t) * exp_val - (params.R_s / params.R_sh) - 1;
        
        % Newton step
        delta_i = f_val / df_di;
        i_curr = i_curr - delta_i;
        
        if abs(delta_i) < tol
            break;
        end
    end
    
    % Negative current clamping for physical diode
    if i_curr < 0
        i_curr = 0;
    end
    I(idx) = i_curr;
end

P = V .* I;

end
