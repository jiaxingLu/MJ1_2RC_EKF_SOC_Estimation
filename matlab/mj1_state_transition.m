function xNext = mj1_state_transition(x, currentA, dt, model)
%MJ1_STATE_TRANSITION Exact-discrete 2RC state transition.
%
% State:
%   x = [v1; v2; SOC]
%
% Sign:
%   currentA > 0 charge
%   currentA < 0 discharge

p = mj1_interp_params(model, x(3));

a1 = exp(-dt / p.tau1);
a2 = exp(-dt / p.tau2);
b1 = p.R1 * (1 - a1);
b2 = p.R2 * (1 - a2);

xNext = zeros(3,1);
xNext(1) = a1*x(1) + b1*currentA;
xNext(2) = a2*x(2) + b2*currentA;
xNext(3) = x(3) + currentA*dt/(3600*model.qRefAh);
end
