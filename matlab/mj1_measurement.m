function voltageV = mj1_measurement(x, currentA, model)
%MJ1_MEASUREMENT Terminal-voltage equation for MJ1 v0.2 2RC ECM.

p = mj1_interp_params(model, x(3));

voltageV = p.OCV + x(1) + x(2) + p.R0*currentA;
end
