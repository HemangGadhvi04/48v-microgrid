function [dx,power] = solar_grid_derivative(x,bridge,da,db,connected,vg,s,p)
% KCL/KVL with reciprocal power exchange between every adjacent subsystem.
vp=x(1); il=x(2); vd=x(3); i1=x(4); vc=x(5); ig=x(6);
ipv=solar_pv_current(vp,s.iph,s.i0,s.vthermal,p.pv_rs,p.pv_rsh);
ic=i1-ig;
vn=vc+p.Rd*ic;
dx=zeros(6,1);
dx(1)=(ipv-da*il)/p.Cpv;
dx(2)=(da*vp-db*vd-p.Rdc*il)/p.Ldc;
% Ideal H bridge: input current = bridge state * AC-side current.
dx(3)=(db*il-bridge*i1)/p.Cdc;
dx(4)=(bridge*vd-p.R1*i1-vn)/p.L1;
dx(5)=ic/p.Cac;
if connected; dx(6)=(vn-p.R2*ig-vg)/p.L2; end
loss=p.Rdc*il^2+p.R1*i1^2+p.Rd*ic^2+p.R2*ig^2;
power=[vp*ipv;vg*ig;loss];
end
