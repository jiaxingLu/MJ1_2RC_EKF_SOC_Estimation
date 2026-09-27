function [F,H] = mj1_numeric_jacobians(x, currentA, currentNextA, dt, model)
%MJ1_NUMERIC_JACOBIANS Central-difference Jacobians of the scheduled model.
%
% Numerical differentiation is intentional here: R0, R1, C1, R2 and C2
% all vary with SOC, so using H=[1 1 dOCV/dSOC] alone would omit the
% SOC dependence of the scheduled ECM parameters.

epsState = [1e-6; 1e-6; 1e-5];

F = zeros(3,3);
for j = 1:3
    xp = x;
    xm = x;
    xp(j) = xp(j) + epsState(j);
    xm(j) = xm(j) - epsState(j);

    fp = mj1_state_transition(xp, currentA, dt, model);
    fm = mj1_state_transition(xm, currentA, dt, model);
    F(:,j) = (fp - fm)/(2*epsState(j));
end

% H is evaluated at the predicted state; caller supplies x as that state.
H = zeros(1,3);
for j = 1:3
    xp = x;
    xm = x;
    xp(j) = xp(j) + epsState(j);
    xm(j) = xm(j) - epsState(j);

    hp = mj1_measurement(xp, currentNextA, model);
    hm = mj1_measurement(xm, currentNextA, model);
    H(j) = (hp - hm)/(2*epsState(j));
end
end
