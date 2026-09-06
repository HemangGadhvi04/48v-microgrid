%% Build & Configure Simulink Model for Single-Phase H-Bridge Inverter
% Project: 48V Open-Source Microgrid Research Platform
% Subsystem: H-Bridge Inverter with Unipolar SPWM and LC Filter

% 1. Load Parameters into Base Workspace
inverter_params;

model_name = 'hbridge_inverter_lc';

% Check if model already exists or open new
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

if exist([model_name '.slx'], 'file')
    fprintf('Existing model %s.slx found. Opening...\n', model_name);
    open_system(model_name);
else
    fprintf('Creating new Simulink system: %s...\n', model_name);
    new_system(model_name);
    open_system(model_name);
    
    % Configure Model Solver Settings
    set_param(model_name, 'SolverType', 'Variable-step');
    set_param(model_name, 'Solver', 'ode23tb');
    set_param(model_name, 'MaxStep', num2str(T_step));
    set_param(model_name, 'StopTime', num2str(T_sim));
    
    fprintf('Model configured with ode23tb solver, max step = %e s, stop time = %.2f s.\n', T_step, T_sim);
    fprintf('You can now assemble the Simscape Electrical components:\n');
    fprintf('  - DC Voltage Source (Vdc = 48V)\n');
    fprintf('  - Full-Bridge Inverter (MOSFET/IGBT H-Bridge)\n');
    fprintf('  - Series Inductor (Lf = 100uH, RLf = 15mOhm)\n');
    fprintf('  - Shunt Capacitor Branch (Cf = 47uF + Rd = 0.5 Ohm)\n');
    fprintf('  - Parallel Resistive Load (Rload = 1.665 Ohm, 500W)\n');
    fprintf('  - SPWM Generator Subsystem (50Hz Sine vs 20kHz Carrier)\n');
    
    save_system(model_name);
end
