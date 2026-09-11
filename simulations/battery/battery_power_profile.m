function power_w = battery_power_profile(time_s)
% Positive power discharges the pack; negative power charges it.
if time_s<300
    power_w=200;
elseif time_s<600
    power_w=500;
elseif time_s<900
    power_w=-300;
else
    power_w=400;
end
end
