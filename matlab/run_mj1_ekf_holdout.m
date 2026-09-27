clear; clc; close all;

% Frozen input artifacts generated from the MJ1 v0.2 rebuild.
model = mj1_load_model("mj1_v02_model.mat");
S = load("mj1_holdout_50to17.mat","data");
data = S.data;

t = double(data.time_s(:));
V = double(data.voltage_V(:));
I = double(data.current_A(:));
socRef = double(data.soc_ref(:));

cases = struct( ...
    "name", {"correct_init","minus20pp","plus15pp"}, ...
    "soc0", {socRef(1), max(model.socMin,socRef(1)-0.20), ...
             min(model.socMax,socRef(1)+0.15)} );

% Frozen baseline covariances. Do not retune on the holdout segment.
Q = diag([1e-7,1e-7,1e-9]);
sigmaV = 0.020;   % 20 mV effective measurement uncertainty
R = sigmaV^2;
P0 = diag([0.02^2,0.02^2,0.20^2]);

results = struct();

for c = 1:numel(cases)
    n = numel(t);
    X = zeros(3,n);
    Vhat = zeros(n,1);
    innovation = zeros(n,1);

    z0 = cases(c).soc0;
    p0 = mj1_interp_params(model,z0);

    % The validation window starts under near-constant 1C discharge, so
    % initialize RC states with their steady-current values.
    X(:,1) = [p0.R1*I(1); p0.R2*I(1); z0];
    P = P0;

    Vhat(1) = mj1_measurement(X(:,1),I(1),model);
    innovation(1) = V(1)-Vhat(1);

    for k = 2:n
        dt = t(k)-t(k-1);

        [X(:,k),P,Vhat(k),innovation(k)] = mj1_ekf_step( ...
            X(:,k-1),P,I(k-1),I(k),V(k),dt,model,Q,R);
    end

    socErrPP = 100*(X(3,:).'-socRef);
    voltageErrmV = 1000*(Vhat-V);

    m.SOC_RMSE_pp = sqrt(mean(socErrPP.^2));
    m.SOC_MAE_pp = mean(abs(socErrPP));
    m.SOC_MaxAbs_pp = max(abs(socErrPP));
    m.SOC_FinalError_pp = socErrPP(end);
    m.Voltage_RMSE_mV = sqrt(mean(voltageErrmV.^2));

    results(c).name = cases(c).name;
    results(c).X = X;
    results(c).Vhat = Vhat;
    results(c).innovation = innovation;
    results(c).metrics = m;

    fprintf("\n%s\n",cases(c).name);
    fprintf("  initial SOC error = %+8.3f pp\n",100*(z0-socRef(1)));
    fprintf("  SOC RMSE          = %8.3f pp\n",m.SOC_RMSE_pp);
    fprintf("  SOC MAE           = %8.3f pp\n",m.SOC_MAE_pp);
    fprintf("  final SOC error   = %+8.3f pp\n",m.SOC_FinalError_pp);
    fprintf("  voltage RMSE      = %8.3f mV\n",m.Voltage_RMSE_mV);
end

% Plots
figure("Name","MJ1 v0.2 EKF holdout SOC");
plot(t/60,100*socRef,"LineWidth",1.6); hold on;
for c=1:numel(results)
    plot(t/60,100*results(c).X(3,:),"LineWidth",1.1);
end
xlabel("Time (min)"); ylabel("SOC (%)"); grid on;
legend(["Coulomb-counted reference",{results.name}],"Location","best");
title("MJ1 v0.2 EKF holdout: 50% to 17% SOC");

figure("Name","MJ1 v0.2 EKF holdout voltage");
plot(t/60,V,"LineWidth",1.5); hold on;
plot(t/60,results(1).Vhat,"LineWidth",1.1);
xlabel("Time (min)"); ylabel("Terminal voltage (V)"); grid on;
legend("Measured","EKF posterior","Location","best");
title("MJ1 v0.2 EKF voltage reconstruction");

save("mj1_matlab_ekf_results.mat","results","t","V","I","socRef");
