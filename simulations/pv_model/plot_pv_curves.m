%% Plot PV Characteristics Curves (I-V and P-V)
% Project: 48V Open-Source Microgrid Research Platform
% Subsystem: Solar PV Array Characterization (Single-Diode Model)

clear; clc; close all;

V_vec = linspace(0, 60, 300);

%% 1. Varying Irradiance at 25 °C
irradiances = [200, 400, 600, 800, 1000]; % [W/m^2]
T_fixed = 25; % [°C]

figure('Name', 'PV Curves vs Irradiance', 'Color', 'w', 'Position', [100 100 900 400]);

subplot(1, 2, 1);
hold on; grid on; box on;
for G = irradiances
    [I, ~] = pv_single_diode(V_vec, G, T_fixed);
    plot(V_vec, I, 'LineWidth', 1.8, 'DisplayName', sprintf('%d W/m^2', G));
end
xlabel('Terminal Voltage V [V]');
ylabel('Current I [A]');
title(sprintf('I-V Characteristics (T = %d °C)', T_fixed));
legend('Location', 'southwest');

subplot(1, 2, 2);
hold on; grid on; box on;
for G = irradiances
    [~, P] = pv_single_diode(V_vec, G, T_fixed);
    plot(V_vec, P, 'LineWidth', 1.8, 'DisplayName', sprintf('%d W/m^2', G));
end
xlabel('Terminal Voltage V [V]');
ylabel('Power P [W]');
title(sprintf('P-V Characteristics (T = %d °C)', T_fixed));
legend('Location', 'northwest');

%% 2. Varying Temperature at 1000 W/m^2
temperatures = [15, 25, 45, 65]; % [°C]
G_fixed = 1000; % [W/m^2]

figure('Name', 'PV Curves vs Temperature', 'Color', 'w', 'Position', [150 150 900 400]);

subplot(1, 2, 1);
hold on; grid on; box on;
for T = temperatures
    [I, ~] = pv_single_diode(V_vec, G_fixed, T);
    plot(V_vec, I, 'LineWidth', 1.8, 'DisplayName', sprintf('%d °C', T));
end
xlabel('Terminal Voltage V [V]');
ylabel('Current I [A]');
title(sprintf('I-V Characteristics (G = %d W/m^2)', G_fixed));
legend('Location', 'southwest');

subplot(1, 2, 2);
hold on; grid on; box on;
for T = temperatures
    [~, P] = pv_single_diode(V_vec, G_fixed, T);
    plot(V_vec, P, 'LineWidth', 1.8, 'DisplayName', sprintf('%d °C', T));
end
xlabel('Terminal Voltage V [V]');
ylabel('Power P [W]');
title(sprintf('P-V Characteristics (G = %d W/m^2)', G_fixed));
legend('Location', 'northwest');

fprintf('Curves generated successfully.\n');
