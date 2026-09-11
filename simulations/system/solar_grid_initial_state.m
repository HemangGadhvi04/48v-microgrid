function s = solar_grid_initial_state(p)
% All energy storage and controller memory are explicit for replay and reset.
% x = [PV capacitor V; DC/DC inductor A; bus capacitor V;
%      inverter inductor A; AC capacitor V; grid inductor A].
s.x=[p.initial_pv;0;p.initial_bus;0;0;0];
s.tick=0;
s.pll_a=0; s.pll_b=0; s.theta=0; s.omega=2*pi*p.grid_hz;
s.pll_integral=0; s.lock_count=0; s.connected=false;
s.pv_integral=0; s.il_integral=0; s.bus_integral=0;
s.res1=0; s.res2=0; s.old_iref=0; s.sample_current=0;
s.duty_a=0; s.duty_b=0; s.modulation=0;
s.power_filtered=0; s.energy_filtered=0; s.p_command=0; s.i_command=0;
s.il_command=0; s.mppt_voltage=p.initial_mppt;
s.mppt_previous_power=0; s.mppt_direction=p.mppt_step; s.mppt_started=false;
s.saturated=false;
s.e_pv=0; s.e_grid=0; s.e_loss=0;
s.last_G=-1; s.last_T=-1000; s.iph=0; s.i0=0; s.vthermal=1;
end
