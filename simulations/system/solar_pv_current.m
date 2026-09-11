function current = solar_pv_current(voltage,iph,i0,a,rs,rsh)
% Scalar Newton solve of the same single-diode law as pv_single_diode.
% Generation quadrant only; reverse-biased operation is outside this model.
current=iph;
for n=1:25
    e=exp(min(100,(voltage+rs*current)/a));
    residual=iph-i0*(e-1)-(voltage+rs*current)/rsh-current;
    slope=-i0*e*rs/a-rs/rsh-1;
    delta=residual/slope;
    current=current-delta;
    if abs(delta)<1e-10; break; end
end
current=max(0,current);
end
