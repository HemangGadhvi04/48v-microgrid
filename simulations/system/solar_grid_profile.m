function [G,T] = solar_grid_profile(t)
% Tests irradiance reduction/recovery and both converter voltage-ratio modes.
G=1000; T=25;
if t>=0.7; G=600; end
if t>=1.2; G=900; end
if t>=1.6; T=45; end
if t>=2.0; T=10; end
end
