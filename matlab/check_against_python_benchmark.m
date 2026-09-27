clear; clc;

if ~isfile("mj1_matlab_ekf_results.mat")
    error("Run run_mj1_ekf_holdout.m first.");
end

S = load("mj1_matlab_ekf_results.mat","results");
results = S.results;

% Frozen values from the Python v0.2 benchmark.
expected = struct();
expected.correct_init = [2.445, -0.025, 10.185];
expected.minus20pp    = [2.509, -0.025, 10.928];
expected.plus15pp     = [2.455, -0.025, 11.190];

fprintf("Python-to-MATLAB benchmark comparison\n");
fprintf("Tolerance is intentionally loose enough for small interpolation / numerical differences.\n\n");

for k=1:numel(results)
    name = results(k).name;
    expv = expected.(name);
    got = [ ...
        results(k).metrics.SOC_RMSE_pp, ...
        results(k).metrics.SOC_FinalError_pp, ...
        results(k).metrics.Voltage_RMSE_mV];

    diffv = got-expv;

    fprintf("%s\n",name);
    fprintf("  SOC RMSE diff     = %+8.4f pp\n",diffv(1));
    fprintf("  final SOC diff    = %+8.4f pp\n",diffv(2));
    fprintf("  voltage RMSE diff = %+8.4f mV\n\n",diffv(3));

    assert(abs(diffv(1)) < 0.25, "SOC RMSE differs too much from frozen Python benchmark.");
    assert(abs(diffv(2)) < 0.25, "Final SOC differs too much from frozen Python benchmark.");
    assert(abs(diffv(3)) < 2.0, "Voltage RMSE differs too much from frozen Python benchmark.");
end

disp("PASS: MATLAB reference implementation is numerically consistent with the frozen Python benchmark.");
