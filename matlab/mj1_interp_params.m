function p = mj1_interp_params(model, soc)
%MJ1_INTERP_PARAMS Linearly interpolate SOC-dependent MJ1 model parameters.
%
% The estimator is deliberately clamped to the validated v0.2 range
% [17%, 85%] SOC. No parameter extrapolation is performed.

z = min(max(double(soc), model.socMin), model.socMax);

p.OCV = interp1(model.soc, model.ocv, z, "linear");
p.R0  = interp1(model.soc, model.R0,  z, "linear");
p.R1  = interp1(model.soc, model.R1,  z, "linear");
p.C1  = interp1(model.soc, model.C1,  z, "linear");
p.R2  = interp1(model.soc, model.R2,  z, "linear");
p.C2  = interp1(model.soc, model.C2,  z, "linear");

p.tau1 = p.R1 * p.C1;
p.tau2 = p.R2 * p.C2;
end
