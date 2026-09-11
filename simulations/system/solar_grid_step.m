function [s,y] = solar_grid_step(s,G,temperature,p)
% One plant integration step; controllers execute only on their own clocks.
% Averaged DC/DC duties; explicit unipolar switching at the inverter.
% No stiff source clamps the DC bus and no MPP oracle drives the controller.
t=s.tick*p.dt;
vg=p.grid_peak*sin(2*pi*p.grid_hz*t);
if G~=s.last_G || temperature~=s.last_T
    tk=temperature+273.15; t0=298.15;
    kb=1.380649e-23; qe=1.602176634e-19;
    a0=p.pv_ns*p.pv_n*kb*t0/qe;
    s.vthermal=p.pv_ns*p.pv_n*kb*tk/qe;
    s.iph=(G/1000)*(p.pv_isc+p.pv_alpha*(tk-t0));
    i00=(p.pv_isc-p.pv_voc/p.pv_rsh)/expm1(p.pv_voc/a0);
    s.i0=i00*(tk/t0)^3*exp(qe*1.121/(p.pv_n*kb)*(1/t0-1/tk));
    s.last_G=G; s.last_T=temperature;
end
ipv=solar_pv_current(s.x(1),s.iph,s.i0,s.vthermal,p.pv_rs,p.pv_rsh);
if mod(s.tick,round(p.control_dt/p.dt))==0
    Ts=p.control_dt;
    % SOGI-PLL: Heun integrator, normalized quadrature error, bounded PI.
    da=p.pll_k*s.omega*(vg-s.pll_a)-s.omega*s.pll_b;
    db=s.omega*s.pll_a;
    ap=s.pll_a+Ts*da; bp=s.pll_b+Ts*db;
    s.pll_a=s.pll_a+Ts/2*(da+p.pll_k*s.omega*(vg-ap)-s.omega*bp);
    s.pll_b=s.pll_b+Ts/2*(db+s.omega*ap);
    amplitude=hypot(s.pll_a,s.pll_b);
    q=(s.pll_a*cos(s.theta)+s.pll_b*sin(s.theta))/max(amplitude,0.1*p.grid_peak);
    wu=2*pi*p.grid_hz+p.pll_kp*q+s.pll_integral;
    s.omega=min(max(wu,2*pi*45),2*pi*55);
    if wu==s.omega || (wu>s.omega && q<0) || (wu<s.omega && q>0)
        s.pll_integral=s.pll_integral+Ts*p.pll_ki*q;
    end
    s.theta=mod(s.theta+Ts*s.omega,2*pi);
    if amplitude>0.7*p.grid_peak && abs(q)<0.04 && abs(s.omega/(2*pi)-p.grid_hz)<0.2
        s.lock_count=s.lock_count+1;
    else
        s.lock_count=0;
    end
    % This test exercises connection only. No current state is erased on opening.
    if s.lock_count*Ts>=0.010; s.connected=true; end
    enabled=s.connected && t>=p.source_enable_time;
    ramp=min(max((t-p.source_enable_time)/p.source_ramp_time,0),1);

    if enabled && mod(s.tick,round(p.mppt_dt/p.dt))==0
        power=s.x(1)*ipv;
        if s.mppt_started && power<s.mppt_previous_power
            s.mppt_direction=-s.mppt_direction;
        end
        s.mppt_previous_power=power; s.mppt_started=true;
        s.mppt_voltage=min(max(s.mppt_voltage+s.mppt_direction,20),57);
    end

    % PV voltage PI commands input current; inner inductor PI commands volts.
    ev=s.x(1)-s.mppt_voltage;
    iu=ipv+p.pv_kp*ev+s.pv_integral;
    i_input=min(max(iu,0),p.max_il)*ramp*double(enabled);
    if enabled && ramp==1 && (iu==i_input || (iu>i_input && ev<0) || (iu<i_input && ev>0))
        s.pv_integral=s.pv_integral+Ts*p.pv_ki*ev;
    end
    duty_in_est=min(1,max(0.1,s.x(3)/max(s.x(1),1)));
    s.il_command=min(i_input/duty_in_est,p.max_il);
    ei=s.il_command-s.x(2);
    vl=p.il_kp*ei+s.il_integral;
    % da*Vp - db*Vdc = requested inductor voltage. Select a valid mode.
    if s.x(1)-s.x(3)>=vl
        s.duty_b=1; raw=(s.x(3)+vl)/max(s.x(1),1);
        s.duty_a=min(max(raw,0),1);
    else
        s.duty_a=1; raw=(s.x(1)-vl)/max(s.x(3),1);
        s.duty_b=min(max(raw,0),1);
    end
    actual_vl=s.duty_a*s.x(1)-s.duty_b*s.x(3);
    s.il_integral=s.il_integral+Ts*(p.il_ki*ei+200*(actual_vl-vl));
    if ~enabled
        s.duty_a=0; s.duty_b=0; s.il_integral=0;
    end

    % Inverter alone regulates bus energy; DC/DC alone regulates PV voltage.
    % Low-pass sensing rejects most 100 Hz single-phase power oscillation.
    alpha=1-exp(-2*pi*p.power_filter_hz*Ts);
    s.power_filtered=s.power_filtered+alpha*(s.duty_b*s.x(2)*s.x(3)-s.power_filtered);
    energy_error=0.5*p.Cdc*(s.x(3)^2-p.bus_target^2);
    s.energy_filtered=s.energy_filtered+alpha*(energy_error-s.energy_filtered);
    pu=s.power_filtered+p.energy_kp*s.energy_filtered+s.bus_integral;
    s.p_command=min(max(pu,0),p.max_power)*double(s.connected);
    if s.connected && (pu==s.p_command || (pu>s.p_command && s.energy_filtered<0) || (pu<s.p_command && s.energy_filtered>0))
        s.bus_integral=s.bus_integral+Ts*p.energy_ki*s.energy_filtered;
    end
    angle=s.theta-p.current_phase_samples*s.omega*Ts;
    s.i_command=min(sqrt(2)*s.p_command/(p.grid_peak/sqrt(2)),p.max_grid_peak)*sin(angle);
    di=(s.i_command-s.old_iref)/Ts; s.old_iref=s.i_command;
    error=s.i_command-s.sample_current;
    s.sample_current=s.x(6); % explicit one-controller-sample ADC delay
    vf=vg+(p.R1+p.R2)*s.i_command+(p.L1+p.L2)*di;
    vu=vf+p.current_kp*error+p.current_kr*(2*p.current_wc*s.res2);
    vmax=p.modulation_max*s.x(3);
    vc=min(max(vu,-vmax),vmax);
    s.saturated=vu~=vc;
    if ~s.saturated || sign(error)~=sign(vu-vc)
        w=2*pi*p.grid_hz;
        d1=s.res2; d2=error-2*p.current_wc*s.res2-w*w*s.res1;
        r1=s.res1+Ts*d1; r2=s.res2+Ts*d2;
        s.res1=s.res1+Ts/2*(d1+r2);
        s.res2=s.res2+Ts/2*(d2+error-2*p.current_wc*r2-w*w*r1);
    end
    s.modulation=vc/max(s.x(3),1);
end

% Evaluate bridge at integration-interval midpoint to reduce PWM quantization.
carrier=1-4*abs(mod((t+0.5*p.dt)*p.switching_hz,1)-0.5);
bridge=double(s.modulation>=carrier)-double(-s.modulation>=carrier);
[dx,power0]=solar_grid_derivative(s.x,bridge,s.duty_a,s.duty_b,s.connected,vg,s,p);
xp=s.x+p.dt*dx;
vg_next=p.grid_peak*sin(2*pi*p.grid_hz*(t+p.dt));
[dxp,power1]=solar_grid_derivative(xp,bridge,s.duty_a,s.duty_b,s.connected,vg_next,s,p);
s.x=s.x+p.dt/2*(dx+dxp);
ep=p.dt/2*(power0+power1);
s.e_pv=s.e_pv+ep(1); s.e_grid=s.e_grid+ep(2); s.e_loss=s.e_loss+ep(3);
s.tick=s.tick+1;
energy=0.5*(p.Cpv*s.x(1)^2+p.Ldc*s.x(2)^2+p.Cdc*s.x(3)^2 ...
    +p.L1*s.x(4)^2+p.Cac*s.x(5)^2+p.L2*s.x(6)^2);
y=[s.x; vg_next; s.i_command; s.p_command; s.mppt_voltage; ...
    s.duty_a; s.duty_b; s.modulation; s.omega/(2*pi); double(s.connected); ...
    double(s.saturated); power1(1); power1(2); power1(3); energy; ...
    s.e_pv; s.e_grid; s.e_loss; s.il_command];
end
