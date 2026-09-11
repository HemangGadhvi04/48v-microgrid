function [v_command,next] = po_mppt(v_measured,i_measured,state,step_v,v_min,v_max)
%PO_MPPT One Perturb-and-Observe update with explicit serializable state.
power=v_measured*i_measured;
next=state;
if ~state.initialized
    next.previous_voltage=v_measured;
    next.previous_power=power;
    next.direction=abs(step_v);
    next.initialized=true;
else
    delta_power=power-state.previous_power;
    delta_voltage=v_measured-state.previous_voltage;
    % The applied perturbation direction is already stored in state. Keep
    % walking when the last perturbation increased power; reverse only when
    % it reduced power. Multiplying dP by dV here would reverse a correct
    % negative-voltage perturbation on the descending side of the P-V curve.
    if delta_voltage~=0 && delta_power<0
        next.direction=-state.direction;
    end
    next.previous_voltage=v_measured;
    next.previous_power=power;
end
v_command=min(max(v_measured+next.direction,v_min),v_max);
if v_command==v_min; next.direction=abs(next.direction); end
if v_command==v_max; next.direction=-abs(next.direction); end
end
