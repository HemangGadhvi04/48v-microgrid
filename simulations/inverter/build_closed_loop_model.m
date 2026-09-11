function build_closed_loop_model()
%% Build Closed-Loop Islanded Inverter Model
% Switching-level unipolar H-bridge, variable resistive load, and PI voltage
% regulation using synchronous fundamental-magnitude estimation.

inverter_params;
model_name = 'hbridge_inverter_lc_closed_loop';

if bdIsLoaded(model_name)
    close_system(model_name, 0);
end
if exist([model_name '.slx'], 'file')
    fprintf('Existing generated model %s.slx found. Leaving it unchanged.\n', model_name);
    return;
end

fprintf('Creating Simulink system: %s...\n', model_name);
new_system(model_name);
set_param(model_name, 'SolverType', 'Fixed-step', 'Solver', 'ode3', ...
    'FixedStep', 'T_step', 'StopTime', 'T_sim_control', ...
    'ReturnWorkspaceOutputs', 'on');

%% Fundamental reference and bounded PI controller
add_block('simulink/Sources/Sine Wave', [model_name '/sin_theta'], ...
    'Amplitude', '1', 'Frequency', 'omega_0', 'SampleTime', '0', 'Position', [45 100 120 130]);
add_block('simulink/Sources/Sine Wave', [model_name '/cos_theta'], ...
    'Amplitude', '1', 'Frequency', 'omega_0', 'Phase', 'pi/2', 'SampleTime', '0', 'Position', [45 165 120 195]);
add_block('simulink/Sources/Ramp', [model_name '/Voltage Reference Ramp'], ...
    'Slope', 'V_out_pk_ref / t_soft_start', 'Position', [45 25 125 55]);
add_block('simulink/Discontinuities/Saturation', [model_name '/Voltage Reference Limit'], ...
    'UpperLimit', 'V_out_pk_ref', 'LowerLimit', '0', 'Position', [165 25 225 55]);
add_block('simulink/Math Operations/Sum', [model_name '/Voltage Error'], ...
    'Inputs', '+-', 'Position', [700 25 730 85]);
add_block('simulink/Math Operations/Gain', [model_name '/PI Proportional'], ...
    'Gain', 'Kp_voltage', 'Position', [835 25 900 55]);
add_block('simulink/Math Operations/Gain', [model_name '/PI Integral Gain'], ...
    'Gain', 'Ki_voltage', 'Position', [835 95 900 125]);
add_block('simulink/Discrete/Discrete-Time Integrator', [model_name '/PI Integrator'], ...
    'InitialCondition', '0', 'SampleTime', 'T_step', 'Position', [935 95 990 125]);
add_block('simulink/Math Operations/Sum', [model_name '/PI Sum'], ...
    'Inputs', '++', 'Position', [960 38 990 92]);
add_block('simulink/Discontinuities/Saturation', [model_name '/Modulation Limit'], ...
    'UpperLimit', 'm_max', 'LowerLimit', 'm_min', 'Position', [1025 45 1090 75]);

%% SPWM and ideal H-bridge
add_block('simulink/Sources/Repeating Sequence', [model_name '/20 kHz Triangle Carrier'], ...
    'rep_seq_t', 'carrier_time', 'rep_seq_y', 'carrier_values', 'Position', [1140 145 1235 180]);
add_block('simulink/Math Operations/Product', [model_name '/Modulated Sine Reference'], ...
    'Position', [1140 70 1185 105]);

spwm_path = [model_name '/Unipolar SPWM Generator'];
add_block('built-in/Subsystem', spwm_path, 'Position', [1270 55 1455 185]);
add_block('simulink/Sources/In1', [spwm_path '/v_ref_pu'], 'Position', [35 35 65 50]);
add_block('simulink/Sources/In1', [spwm_path '/carrier'], 'Position', [35 105 65 120]);
add_block('simulink/Math Operations/Gain', [spwm_path '/Invert Reference'], 'Gain', '-1', 'Position', [105 58 145 88]);
add_block('simulink/Logic and Bit Operations/Relational Operator', [spwm_path '/Leg A Comparator'], 'Operator', '>=', 'Position', [185 30 230 58]);
add_block('simulink/Logic and Bit Operations/Relational Operator', [spwm_path '/Leg B Comparator'], 'Operator', '>=', 'Position', [185 98 230 126]);
add_block('simulink/Sinks/Out1', [spwm_path '/gate_A'], 'Position', [280 35 310 50]);
add_block('simulink/Sinks/Out1', [spwm_path '/gate_B'], 'Position', [280 105 310 120]);
add_line(spwm_path, 'v_ref_pu/1', 'Leg A Comparator/1'); add_line(spwm_path, 'carrier/1', 'Leg A Comparator/2');
add_line(spwm_path, 'v_ref_pu/1', 'Invert Reference/1'); add_line(spwm_path, 'Invert Reference/1', 'Leg B Comparator/1');
add_line(spwm_path, 'carrier/1', 'Leg B Comparator/2'); add_line(spwm_path, 'Leg A Comparator/1', 'gate_A/1'); add_line(spwm_path, 'Leg B Comparator/1', 'gate_B/1');

add_block('simulink/Signal Attributes/Data Type Conversion', [model_name '/gate_A double'], 'OutDataTypeStr', 'double', 'Position', [1490 60 1520 90]);
add_block('simulink/Signal Attributes/Data Type Conversion', [model_name '/gate_B double'], 'OutDataTypeStr', 'double', 'Position', [1490 115 1520 145]);
add_block('simulink/Math Operations/Sum', [model_name '/gate_A_minus_gate_B'], 'Inputs', '+-', 'Position', [1555 75 1585 135]);
add_block('simulink/Math Operations/Gain', [model_name '/Ideal H-Bridge Voltage'], 'Gain', 'Vdc', 'Position', [1625 92 1725 122]);

%% Variable-load damped LC plant
% The plant is a discrete state implementation of the series-L / series-Rd-C
% network, allowing R_load to change without changing block coefficients.
plant_path = [model_name '/Variable Load Damped LC Plant'];
add_block('built-in/Subsystem', plant_path, 'Position', [1780 65 1970 195]);
add_block('simulink/Sources/In1', [plant_path '/v_inv'], 'Position', [30 38 60 52]);
add_block('simulink/Sources/In1', [plant_path '/R_load'], 'Position', [30 125 60 139]);
add_block('simulink/Sources/Constant', [plant_path '/Rd_total'], 'Value', 'R_d_total', 'Position', [30 180 90 210]);
add_block('simulink/Discrete/Unit Delay', [plant_path '/i_L state'], 'X0', '0', 'SampleTime', 'T_step', 'Position', [245 40 290 70]);
add_block('simulink/Discrete/Unit Delay', [plant_path '/v_C state'], 'X0', '0', 'SampleTime', 'T_step', 'Position', [245 150 290 180]);
add_block('simulink/Math Operations/Product', [plant_path '/Rd times iL'], 'Position', [330 40 390 70]);
add_block('simulink/Math Operations/Sum', [plant_path '/vout numerator'], 'Inputs', '++', 'Position', [425 50 455 110]);
add_block('simulink/Math Operations/Sum', [plant_path '/vout denominator'], 'Inputs', '++', 'Position', [425 135 455 195]);
add_block('simulink/Math Operations/Product', [plant_path '/Output Voltage'], 'Inputs', '*/', 'Position', [500 75 550 125]);
add_block('simulink/Math Operations/Gain', [plant_path '/Rlf times iL'], 'Gain', 'R_Lf', 'Position', [330 230 390 260]);
add_block('simulink/Math Operations/Sum', [plant_path '/Inductor Voltage'], 'Inputs', '+--', 'Position', [440 230 470 300]);
add_block('simulink/Math Operations/Gain', [plant_path '/Ts over L'], 'Gain', 'T_step / L_f', 'Position', [510 245 580 275]);
add_block('simulink/Math Operations/Sum', [plant_path '/iL Euler Update'], 'Inputs', '++', 'Position', [625 235 655 295]);
add_block('simulink/Math Operations/Sum', [plant_path '/Capacitor Branch Voltage'], 'Inputs', '+-', 'Position', [610 150 640 210]);
add_block('simulink/Math Operations/Gain', [plant_path '/Capacitor Current'], 'Gain', '1 / R_d_total', 'Position', [680 165 745 195]);
add_block('simulink/Math Operations/Gain', [plant_path '/Ts over C'], 'Gain', 'T_step / C_f', 'Position', [790 165 850 195]);
add_block('simulink/Math Operations/Sum', [plant_path '/vC Euler Update'], 'Inputs', '++', 'Position', [875 150 905 210]);
add_block('simulink/Math Operations/Product', [plant_path '/Load Current'], 'Inputs', '*/', 'Position', [610 65 660 115]);
add_block('simulink/Sinks/Out1', [plant_path '/v_out'], 'Position', [920 92 950 107]);
add_block('simulink/Sinks/Out1', [plant_path '/i_load'], 'Position', [920 135 950 150]);
add_block('simulink/Sinks/Out1', [plant_path '/i_L'], 'Position', [920 42 950 57]);
add_line(plant_path, 'i_L state/1', 'Rd times iL/1'); add_line(plant_path, 'Rd_total/1', 'Rd times iL/2');
add_line(plant_path, 'Rd times iL/1', 'vout numerator/1'); add_line(plant_path, 'v_C state/1', 'vout numerator/2');
add_line(plant_path, 'R_load/1', 'vout denominator/1'); add_line(plant_path, 'Rd_total/1', 'vout denominator/2');
add_line(plant_path, 'vout numerator/1', 'Output Voltage/1'); add_line(plant_path, 'vout denominator/1', 'Output Voltage/2');
add_line(plant_path, 'Output Voltage/1', 'Load Current/1'); add_line(plant_path, 'R_load/1', 'Load Current/2');
add_line(plant_path, 'v_inv/1', 'Inductor Voltage/1'); add_line(plant_path, 'i_L state/1', 'Rlf times iL/1');
add_line(plant_path, 'Rlf times iL/1', 'Inductor Voltage/2'); add_line(plant_path, 'Output Voltage/1', 'Inductor Voltage/3');
add_line(plant_path, 'Inductor Voltage/1', 'Ts over L/1'); add_line(plant_path, 'i_L state/1', 'iL Euler Update/1'); add_line(plant_path, 'Ts over L/1', 'iL Euler Update/2'); add_line(plant_path, 'iL Euler Update/1', 'i_L state/1');
add_line(plant_path, 'Output Voltage/1', 'Capacitor Branch Voltage/1'); add_line(plant_path, 'v_C state/1', 'Capacitor Branch Voltage/2'); add_line(plant_path, 'Capacitor Branch Voltage/1', 'Capacitor Current/1'); add_line(plant_path, 'Capacitor Current/1', 'Ts over C/1'); add_line(plant_path, 'v_C state/1', 'vC Euler Update/1'); add_line(plant_path, 'Ts over C/1', 'vC Euler Update/2'); add_line(plant_path, 'vC Euler Update/1', 'v_C state/1');
add_line(plant_path, 'Output Voltage/1', 'v_out/1'); add_line(plant_path, 'Load Current/1', 'i_load/1'); add_line(plant_path, 'i_L state/1', 'i_L/1');

%% Load step and synchronous magnitude estimator
add_block('simulink/Sources/Step', [model_name '/Load Step 250W to 500W'], 'Time', 't_load_step', 'Before', 'R_load_half', 'After', 'R_load_nom', 'Position', [1640 190 1725 220]);
add_block('simulink/Math Operations/Product', [model_name '/sin Demodulator'], 'Position', [330 330 375 365]);
add_block('simulink/Math Operations/Product', [model_name '/cos Demodulator'], 'Position', [330 400 375 435]);
add_block('simulink/Discrete/Delay', [model_name '/sin Cycle Delay'], 'DelayLength', 'N_line_cycle', 'InitialCondition', '0', 'SampleTime', 'T_step', 'Position', [415 330 475 360]);
add_block('simulink/Discrete/Delay', [model_name '/cos Cycle Delay'], 'DelayLength', 'N_line_cycle', 'InitialCondition', '0', 'SampleTime', 'T_step', 'Position', [415 400 475 430]);
add_block('simulink/Math Operations/Sum', [model_name '/sin Window Difference'], 'Inputs', '+-', 'Position', [510 330 540 390]);
add_block('simulink/Math Operations/Sum', [model_name '/cos Window Difference'], 'Inputs', '+-', 'Position', [510 400 540 460]);
add_block('simulink/Math Operations/Gain', [model_name '/sin Window Scale'], 'Gain', '1 / N_line_cycle', 'Position', [575 345 635 375]);
add_block('simulink/Math Operations/Gain', [model_name '/cos Window Scale'], 'Gain', '1 / N_line_cycle', 'Position', [575 415 635 445]);
add_block('simulink/Discrete/Unit Delay', [model_name '/sin Average State'], 'X0', '0', 'SampleTime', 'T_step', 'Position', [680 330 725 360]);
add_block('simulink/Discrete/Unit Delay', [model_name '/cos Average State'], 'X0', '0', 'SampleTime', 'T_step', 'Position', [680 400 725 430]);
add_block('simulink/Math Operations/Sum', [model_name '/sin Average Update'], 'Inputs', '++', 'Position', [760 330 790 390]);
add_block('simulink/Math Operations/Sum', [model_name '/cos Average Update'], 'Inputs', '++', 'Position', [760 400 790 460]);
add_block('simulink/Math Operations/Math Function', [model_name '/sin squared'], 'Operator', 'square', 'Position', [825 330 880 360]);
add_block('simulink/Math Operations/Math Function', [model_name '/cos squared'], 'Operator', 'square', 'Position', [825 400 880 430]);
add_block('simulink/Math Operations/Sum', [model_name '/Magnitude Squared'], 'Inputs', '++', 'Position', [915 345 945 405]);
add_block('simulink/Math Operations/Math Function', [model_name '/Square Root'], 'Operator', 'sqrt', 'Position', [970 360 1025 390]);
add_block('simulink/Math Operations/Gain', [model_name '/Estimated Output Peak'], 'Gain', '2', 'Position', [1060 360 1140 390]);

log_names = {'v_ref_peak','v_peak_est','voltage_error','m_cmd','v_ref_pu','v_inv','v_out','i_load','i_L','R_load'};
log_pos = [250 15; 870 330; 850 145; 1110 15; 1190 15; 1620 15; 1995 70; 1995 115; 1995 160; 1745 210];
for k = 1:numel(log_names)
    add_block('simulink/Sinks/To Workspace', [model_name '/log_' log_names{k}], 'VariableName', log_names{k}, 'SaveFormat', 'Timeseries', 'Position', [log_pos(k,1) log_pos(k,2) log_pos(k,1)+85 log_pos(k,2)+25]);
end

%% Top-level routing
add_line(model_name, 'Voltage Reference Ramp/1', 'Voltage Reference Limit/1'); add_line(model_name, 'Voltage Reference Limit/1', 'Voltage Error/1'); add_line(model_name, 'Voltage Reference Limit/1', 'log_v_ref_peak/1');
add_line(model_name, 'Voltage Error/1', 'PI Proportional/1'); add_line(model_name, 'Voltage Error/1', 'PI Integral Gain/1'); add_line(model_name, 'Voltage Error/1', 'log_voltage_error/1');
add_line(model_name, 'PI Proportional/1', 'PI Sum/1'); add_line(model_name, 'PI Integral Gain/1', 'PI Integrator/1'); add_line(model_name, 'PI Integrator/1', 'PI Sum/2'); add_line(model_name, 'PI Sum/1', 'Modulation Limit/1'); add_line(model_name, 'Modulation Limit/1', 'log_m_cmd/1');
add_line(model_name, 'Modulation Limit/1', 'Modulated Sine Reference/1'); add_line(model_name, 'sin_theta/1', 'Modulated Sine Reference/2'); add_line(model_name, 'Modulated Sine Reference/1', 'Unipolar SPWM Generator/1'); add_line(model_name, 'Modulated Sine Reference/1', 'log_v_ref_pu/1'); add_line(model_name, '20 kHz Triangle Carrier/1', 'Unipolar SPWM Generator/2');
add_line(model_name, 'Unipolar SPWM Generator/1', 'gate_A double/1'); add_line(model_name, 'Unipolar SPWM Generator/2', 'gate_B double/1'); add_line(model_name, 'gate_A double/1', 'gate_A_minus_gate_B/1'); add_line(model_name, 'gate_B double/1', 'gate_A_minus_gate_B/2'); add_line(model_name, 'gate_A_minus_gate_B/1', 'Ideal H-Bridge Voltage/1'); add_line(model_name, 'Ideal H-Bridge Voltage/1', 'Variable Load Damped LC Plant/1'); add_line(model_name, 'Ideal H-Bridge Voltage/1', 'log_v_inv/1');
add_line(model_name, 'Load Step 250W to 500W/1', 'Variable Load Damped LC Plant/2'); add_line(model_name, 'Load Step 250W to 500W/1', 'log_R_load/1');
add_line(model_name, 'Variable Load Damped LC Plant/1', 'sin Demodulator/1'); add_line(model_name, 'Variable Load Damped LC Plant/1', 'cos Demodulator/1'); add_line(model_name, 'sin_theta/1', 'sin Demodulator/2'); add_line(model_name, 'cos_theta/1', 'cos Demodulator/2');
add_line(model_name, 'sin Demodulator/1', 'sin Cycle Delay/1'); add_line(model_name, 'cos Demodulator/1', 'cos Cycle Delay/1'); add_line(model_name, 'sin Demodulator/1', 'sin Window Difference/1'); add_line(model_name, 'cos Demodulator/1', 'cos Window Difference/1'); add_line(model_name, 'sin Cycle Delay/1', 'sin Window Difference/2'); add_line(model_name, 'cos Cycle Delay/1', 'cos Window Difference/2'); add_line(model_name, 'sin Window Difference/1', 'sin Window Scale/1'); add_line(model_name, 'cos Window Difference/1', 'cos Window Scale/1'); add_line(model_name, 'sin Average State/1', 'sin Average Update/1'); add_line(model_name, 'cos Average State/1', 'cos Average Update/1'); add_line(model_name, 'sin Window Scale/1', 'sin Average Update/2'); add_line(model_name, 'cos Window Scale/1', 'cos Average Update/2'); add_line(model_name, 'sin Average Update/1', 'sin Average State/1'); add_line(model_name, 'cos Average Update/1', 'cos Average State/1'); add_line(model_name, 'sin Average State/1', 'sin squared/1'); add_line(model_name, 'cos Average State/1', 'cos squared/1'); add_line(model_name, 'sin squared/1', 'Magnitude Squared/1'); add_line(model_name, 'cos squared/1', 'Magnitude Squared/2'); add_line(model_name, 'Magnitude Squared/1', 'Square Root/1'); add_line(model_name, 'Square Root/1', 'Estimated Output Peak/1'); add_line(model_name, 'Estimated Output Peak/1', 'Voltage Error/2'); add_line(model_name, 'Estimated Output Peak/1', 'log_v_peak_est/1');
add_line(model_name, 'Variable Load Damped LC Plant/1', 'log_v_out/1'); add_line(model_name, 'Variable Load Damped LC Plant/2', 'log_i_load/1'); add_line(model_name, 'Variable Load Damped LC Plant/3', 'log_i_L/1');

Simulink.BlockDiagram.arrangeSystem(model_name);
save_system(model_name);
fprintf('Model saved: %s.slx\n', model_name);
fprintf('Load step: %.1f W to %.1f W at %.3f s.\n', 0.5 * P_nom, P_nom, t_load_step);
end
