function F = mj1_F_jacobian(x, currentA, dt, model)
%MJ1_F_JACOBIAN Central-difference process Jacobian.

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
end
