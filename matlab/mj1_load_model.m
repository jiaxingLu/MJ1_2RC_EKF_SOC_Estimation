function model = mj1_load_model(modelFile)
%MJ1_LOAD_MODEL Load the frozen MJ1 v0.2 lookup-table model.
%
% Current sign convention:
%   I > 0  charging
%   I < 0  discharging

if nargin < 1
    modelFile = "mj1_v02_model.mat";
end

S = load(modelFile, "model");
model = S.model;

% Force row vectors / scalar doubles for predictable downstream behavior.
fields = ["soc","ocv","R0","R1","C1","R2","C2"];
for k = 1:numel(fields)
    name = fields(k);
    model.(name) = double(model.(name)(:)).';
end

model.qRefAh = double(model.qRefAh);
model.socMin = double(model.socMin);
model.socMax = double(model.socMax);
end
