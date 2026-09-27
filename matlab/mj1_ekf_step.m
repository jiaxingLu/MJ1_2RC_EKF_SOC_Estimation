function [xPost,PPost,vPost,innovation,K] = mj1_ekf_step( ...
    xPostPrev, PPostPrev, currentPrevA, currentNowA, voltageNowV, ...
    dt, model, Q, R)
%MJ1_EKF_STEP One predict/update step of the SOC-dependent 2RC EKF.
%
% Inputs:
%   xPostPrev    previous posterior state [v1;v2;SOC]
%   PPostPrev    previous posterior covariance 3x3
%   currentPrevA current applied over previous sample interval
%   currentNowA  current used by terminal-voltage measurement equation
%   voltageNowV  measured terminal voltage
%   dt           sample interval [s]
%   model        struct loaded by mj1_load_model
%   Q            3x3 process covariance
%   R            scalar voltage-measurement variance [V^2]

F = mj1_F_jacobian(xPostPrev, currentPrevA, dt, model);

xPred = mj1_state_transition(xPostPrev, currentPrevA, dt, model);
PPred = F*PPostPrev*F.' + Q;

vPred = mj1_measurement(xPred, currentNowA, model);
innovation = voltageNowV - vPred;

H = mj1_H_jacobian(xPred, currentNowA, model);

S = H*PPred*H.' + R;
K = (PPred*H.')/S;

xPost = xPred + K*innovation;
xPost(3) = min(max(xPost(3),model.socMin),model.socMax);

% Joseph covariance update for numerical robustness.
I3 = eye(3);
PPost = (I3-K*H)*PPred*(I3-K*H).' + K*R*K.';
PPost = 0.5*(PPost + PPost.');

vPost = mj1_measurement(xPost, currentNowA, model);
end
