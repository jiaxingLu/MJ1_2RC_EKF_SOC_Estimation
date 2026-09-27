function H = mj1_H_jacobian(xPred, currentA, model)
%MJ1_H_JACOBIAN Central-difference measurement Jacobian.

epsState = [1e-6; 1e-6; 1e-5];
H = zeros(1,3);

for j = 1:3
    xp = xPred;
    xm = xPred;
    xp(j) = xp(j) + epsState(j);
    xm(j) = xm(j) - epsState(j);

    hp = mj1_measurement(xp, currentA, model);
    hm = mj1_measurement(xm, currentA, model);
    H(j) = (hp - hm)/(2*epsState(j));
end
end
