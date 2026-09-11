function voltage_v = battery_ocv(soc,p)
% Illustrative OCV curve; replace with characterized cell data before hardware.
soc_points=[0 0.10 0.20 0.50 0.80 0.95 1.00];
cell_voltage=[2.80 3.15 3.25 3.30 3.34 3.40 3.60];
voltage_v=p.series_cells*interp1(soc_points,cell_voltage, ...
    min(max(soc,0),1),'pchip');
end
