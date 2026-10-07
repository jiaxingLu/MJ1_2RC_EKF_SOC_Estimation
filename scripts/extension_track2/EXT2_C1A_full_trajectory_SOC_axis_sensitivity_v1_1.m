% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_C1A_full_trajectory_SOC_axis_sensitivity_v1.m
% MJ1 2RC-EKF EXT2-C
% C1A Full-Trajectory SOC-Axis Sensitivity Audit v1.1
%
% PURPOSE
%   Diagnose whether the C1 full-trajectory transfer failure is materially
%   driven by the SOC/capacity-axis convention.
%
%   Rebuild the 0.1C-derived charge-baseline correction independently on
%   THREE pre-existing SOC conventions, then validate each convention on
%   the exact same 1C full-charge holdout:
%
%       1) FROZEN_QREF     : qRef = model.qRefAh = 3.335 Ah
%       2) NOMINAL_3P5     : qRef = 3.500 Ah
%       3) SELF_NORMALIZED : each trajectory normalized by its own measured
%                            positive charge throughput to terminal-full
%
% IMPORTANT
%   - No free qRef optimization.
%   - No SOC-shift fitting.
%   - No R2/tau2 fitting.
%   - No hysteresis-state fitting.
%   - No EKF modification.
%   - No frozen-model modification.
%
% DEVELOPMENT / HOLDOUT
%   Development source:
%       raw_original/0.1C/NGU/0.1C dc.csv
%
%   Holdout:
%       raw_original/1C/1C_full_charge.csv
%
%   For EACH axis, the correction curve is rebuilt only from the 0.1C
%   source, then applied unchanged to the 1C holdout.
%
% SCIENTIFIC QUESTION
%   Does switching among already pre-registered SOC-axis conventions
%   resolve the severe 17-30% overcorrection observed in C1?
%
% PRIMARY DIAGNOSTICS
%   For each SOC axis:
%   - full-trajectory frozen/corrected RMSE, MAE, bias, MaxAbs
%   - centered RMSE
%   - four SOC bins: 17-30 / 30-50 / 50-70 / 70-85%
%   - correction-curve range
%
% C1 PARITY
%   FROZEN_QREF must reproduce C1 v1.1 numerical evidence within 0.05 mV.
%
% PRE-REGISTERED DESCRIPTIVE CLASSIFICATION
%
%   SOC_AXIS_MAPPING_STRONGLY_CONTRIBUTES
%     if a non-FROZEN axis:
%       - reduces corrected full RMSE by >=20% vs FROZEN_QREF, AND
%       - reduces corrected 17-30% RMSE by >=10 mV, AND
%       - achieves corrected 17-30% RMSE <=15 mV.
%
%   SOC_AXIS_MAPPING_PARTIALLY_CONTRIBUTES
%     if a non-FROZEN axis:
%       - reduces corrected full RMSE by >=10% vs FROZEN_QREF, OR
%       - reduces corrected 17-30% RMSE by >=10 mV,
%     but does not satisfy the strong criterion.
%
%   SOC_AXIS_MAPPING_NOT_PRIMARY
%     if FROZEN_QREF remains best or non-FROZEN improvements are below
%     the partial thresholds.
%
% CLAIM BOUNDARY
%   SELF_NORMALIZED is a sensitivity convention, NOT independent physical
%   SOC ground truth. B1-2J remains HPPC_SOC_PROVENANCE_INCONCLUSIVE.
%   C1A may identify an important SOC-axis confounder, but cannot declare
%   any tested axis to be the physically correct SOC scale.
%
% AUTODOC
%   Successful execution automatically updates:
%     docs/protocols/EXT2_C1A_PROTOCOL_v1_1.md
%     docs/audits/EXT2_C1A_EXECUTION_AUDIT_v1_1.md
%     docs/handoff/EXT2_CURRENT_HANDOFF.md
%     docs/handoff/EXT2_PROJECT_CONTINUITY_CURRENT.md
%
% MATLAB compatibility:
%   Base MATLAB only.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-C1A | Full-Trajectory SOC-Axis Sensitivity Audit v1.1\n");
fprintf(" 0.1C development -> 1C holdout | 3 pre-registered SOC axes\n");
fprintf("============================================================\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));

if strlength(scriptDir) == 0
    error('EXT2:C1A:RunAsFile', ...
        'Run this script from its saved .m file.');
end

ext2Dir = scriptDir;

[~,folderName] = fileparts(ext2Dir);

if ~strcmpi(string(folderName),"EXT2_dynamic_parameter_identifiability")
    error('EXT2:C1A:WrongFolder', ...
        'This script must live in EXT2_dynamic_parameter_identifiability.');
end

resultsDir = fullfile(ext2Dir,'results');
docsDir = fullfile(ext2Dir,'docs');
protocolDir = fullfile(docsDir,'protocols');
auditDir = fullfile(docsDir,'audits');
handoffDir = fullfile(docsDir,'handoff');

dirs = {resultsDir,docsDir,protocolDir,auditDir,handoffDir};

for k = 1:numel(dirs)
    if ~exist(dirs{k},'dir')
        mkdir(dirs{k});
    end
end

cfg.repoRoot = ...
    "<REPO_ROOT>";

repoMatlab = fullfile(cfg.repoRoot,'matlab');
modelFile = fullfile(cfg.repoRoot,'data','mj1_v02_model.mat');

dataRoot = fullfile(string(getenv("USERPROFILE")), ...
    'Desktop','MJ1_Experimental_Data_Reconstruction','raw_original');

devFile = fullfile(dataRoot,'0.1C','NGU','0.1C dc.csv');
holdoutFile = fullfile(dataRoot,'1C','1C_full_charge.csv');

devSHA = ...
    "65a96280e83c7ff3236453f7aab97ab5aaba67d693cd71447a4dcefbb40ea695";

holdoutSHA = ...
    "9df6afbf73b78742e0449803d8f2eae8e9506583b5ff2f5161fabc65934d72f2";

c1BundleFile = fullfile( ...
    resultsDir,'EXT2_C1_run_bundle_v1_1.mat');

required = { ...
    modelFile, ...
    devFile, ...
    holdoutFile, ...
    c1BundleFile, ...
    fullfile(repoMatlab,'mj1_load_model.m')};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:C1A:MissingInput', ...
            'Required input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

C1ref = load(c1BundleFile);

requiredC1 = {'FullMetrics','BinMetrics','descriptiveClass','c1Pass'};
missingC1 = requiredC1(~cellfun(@(f) isfield(C1ref,f),requiredC1));

if ~isempty(missingC1)
    error('EXT2:C1A:C1BundleContract', ...
        'C1 bundle missing field(s): %s',strjoin(missingC1,', '));
end

fprintf("EXT2 root        : %s\n",ext2Dir);
fprintf("Results          : %s\n",resultsDir);
fprintf("Docs AUTO        : %s\n",docsDir);
fprintf("Frozen model     : %s\n",modelFile);
fprintf("Development      : %s\n",devFile);
fprintf("Holdout          : %s\n",holdoutFile);
fprintf("C1 reference     : %s\n\n",c1BundleFile);

%% ------------------------------------------------------------------------
% 1. PROTECTED-ASSET AUDIT
% -------------------------------------------------------------------------
protectedRel = { ...
    'data/mj1_v02_model.mat'
    'data/MJ1_2RC_v02_LUT_17to85pct_dt1s.csv'
    'matlab/mj1_ekf_step.m'
    'matlab/mj1_state_transition.m'
    'matlab/mj1_measurement.m'
    'matlab/mj1_interp_params.m'
    'matlab/ope_r0_bayes_online_core_v2.m'
    'matlab/ope_excitation_gate_online_v2.m'
    'matlab/ope_r0_bayes_rolling_k4_core_v1.m'
    };

protectedBefore = snapshot_assets_hash(cfg.repoRoot,protectedRel);

%% ------------------------------------------------------------------------
% 2. SOURCE IDENTITY
% -------------------------------------------------------------------------
if ~strcmpi(sha256_file(devFile),char(devSHA))
    error('EXT2:C1A:DevelopmentHashMismatch', ...
        '0.1C development-source SHA-256 mismatch.');
end

if ~strcmpi(sha256_file(holdoutFile),char(holdoutSHA))
    error('EXT2:C1A:HoldoutHashMismatch', ...
        '1C holdout-source SHA-256 mismatch.');
end

fprintf("Source identity:\n");
fprintf("  0.1C development : SHA256 PASS\n");
fprintf("  1C holdout       : SHA256 PASS\n\n");

%% ------------------------------------------------------------------------
% 3. PRE-REGISTERED CONFIGURATION
% -------------------------------------------------------------------------
cfg.axes = ["FROZEN_QREF","NOMINAL_3P5","SELF_NORMALIZED"];

cfg.nominalCapacity_Ah = 3.500;

cfg.fullVoltage_V = 4.200;
cfg.fullCurrent_A = 0.050;
cfg.fullVoltageTol_V = 0.006;
cfg.fullCurrentTol_A = 0.006;
cfg.anchorSearchTail_s = 900;

cfg.correctionBandHalfWidth_SOC = 0.005;
cfg.minDevelopmentSamplesPerNode = 100;
cfg.minHoldoutSamples = 1000;
cfg.minBinSamples = 300;

cfg.socEdges = [0.17 0.30 0.50 0.70 0.85];

cfg.parityTolerance_mV = 0.05;

cfg.strongFullRMSEGain_pct = 20;
cfg.partialFullRMSEGain_pct = 10;
cfg.strongLowBinGain_mV = 10;
cfg.partialLowBinGain_mV = 10;
cfg.strongLowBinMaxRMSE_mV = 15;

%% ------------------------------------------------------------------------
% 4. LOAD RAW SOURCES + TERMINAL FULL ANCHORS
% -------------------------------------------------------------------------
Ddev = load_ngu_uiv_full(devFile);
Dhold = load_ngu_uiv_full(holdoutFile);

idxDevAnchor = find_terminal_anchor_charge(Ddev,cfg);
idxHoldAnchor = find_terminal_anchor_charge(Dhold,cfg);

Ddev = truncate_data(Ddev,idxDevAnchor);
Dhold = truncate_data(Dhold,idxHoldAnchor);

Qdev_Ah = trapz(Ddev.t_s,max(Ddev.I_A,0))/3600;
Qhold_Ah = trapz(Dhold.t_s,max(Dhold.I_A,0))/3600;

fprintf("Terminal-anchor throughputs:\n");
fprintf("  0.1C development : %.6f Ah\n",Qdev_Ah);
fprintf("  1C holdout       : %.6f Ah\n\n",Qhold_Ah);

%% ------------------------------------------------------------------------
% 5. MAIN THREE-AXIS AUDIT
% -------------------------------------------------------------------------
axisRows = struct([]);
binRows = struct([]);
curveRows = struct([]);
trajectoryBundle = struct([]);

iaxrow = 0;
ibinrow = 0;
icurve = 0;
itraj = 0;

for ia = 1:numel(cfg.axes)

    axisName = cfg.axes(ia);

    % ---------------------------------------------------------------------
    % Development SOC axis
    % ---------------------------------------------------------------------
    zDev = build_soc_axis( ...
        Ddev,axisName,model.qRefAh,cfg.nominalCapacity_Ah,Qdev_Ah);

    idxDev0 = find(zDev >= model.socMin,1,'first');
    idxDev1 = find(zDev <= model.socMax,1,'last');

    if isempty(idxDev0) || isempty(idxDev1) || idxDev0 >= idxDev1
        error('EXT2:C1A:DevelopmentSupport', ...
            'No valid 17-85%% development support for %s.',char(axisName));
    end

    idxDev = (idxDev0:idxDev1).';

    tDev = Ddev.t_s(idxDev);
    IDev = Ddev.I_A(idxDev);
    VDev = Ddev.V_V(idxDev);
    zDevS = zDev(idxDev);

    if min(zDevS) > model.socMin+0.002 || ...
       max(zDevS) < model.socMax-0.002
        error('EXT2:C1A:DevelopmentCoverage', ...
            'Development source does not span frozen support for %s.', ...
            char(axisName));
    end

    OCVDev = interp1(model.soc,model.ocv,zDevS,'linear');
    R0Dev = interp1(model.soc,model.R0,zDevS,'linear');
    R1Dev = interp1(model.soc,model.R1,zDevS,'linear');
    C1Dev = interp1(model.soc,model.C1,zDevS,'linear');
    R2Dev = interp1(model.soc,model.R2,zDevS,'linear');
    C2Dev = interp1(model.soc,model.C2,zDevS,'linear');

    tau1Dev = R1Dev.*C1Dev;
    tau2Dev = R2Dev.*C2Dev;

    v10Dev = R1Dev(1)*IDev(1);
    v20Dev = R2Dev(1)*IDev(1);

    v1Dev = simulate_rc_branch_variable_init( ...
        tDev,IDev,R1Dev,tau1Dev,v10Dev);

    v2Dev = simulate_rc_branch_variable_init( ...
        tDev,IDev,R2Dev,tau2Dev,v20Dev);

    pseudoDev = VDev-R0Dev.*IDev-v1Dev-v2Dev;
    deltaDev = pseudoDev-OCVDev;

    SOCNode = model.soc(:);
    DeltaChargeOCV_V = nan(numel(SOCNode),1);
    DeltaChargeOCV_mV = nan(numel(SOCNode),1);
    DevelopmentSamples = zeros(numel(SOCNode),1);

    for k = 1:numel(SOCNode)

        mask = ...
            abs(zDevS-SOCNode(k)) <= ...
            cfg.correctionBandHalfWidth_SOC;

        DevelopmentSamples(k) = sum(mask);

        if DevelopmentSamples(k) < cfg.minDevelopmentSamplesPerNode
            error('EXT2:C1A:DevelopmentNodeSamples', ...
                '%s: only %d samples near SOC %.1f%%; %d required.', ...
                char(axisName),DevelopmentSamples(k), ...
                100*SOCNode(k),cfg.minDevelopmentSamplesPerNode);
        end

        DeltaChargeOCV_V(k) = median(deltaDev(mask));
        DeltaChargeOCV_mV(k) = 1000*DeltaChargeOCV_V(k);

        icurve = icurve+1;
        curveRows(icurve).Axis = axisName; %#ok<SAGROW>
        curveRows(icurve).SOC = SOCNode(k);
        curveRows(icurve).FrozenOCV_V = model.ocv(k);
        curveRows(icurve).DeltaChargeOCV_V = DeltaChargeOCV_V(k);
        curveRows(icurve).DeltaChargeOCV_mV = DeltaChargeOCV_mV(k);
        curveRows(icurve).CorrectedChargeOCV_V = ...
            model.ocv(k)+DeltaChargeOCV_V(k);
        curveRows(icurve).DevelopmentSamples = DevelopmentSamples(k);
    end

    % ---------------------------------------------------------------------
    % Holdout SOC axis
    % ---------------------------------------------------------------------
    zHold = build_soc_axis( ...
        Dhold,axisName,model.qRefAh,cfg.nominalCapacity_Ah,Qhold_Ah);

    idxHold0 = find(zHold >= model.socMin,1,'first');
    idxHold1 = find(zHold <= model.socMax,1,'last');

    if isempty(idxHold0) || isempty(idxHold1) || idxHold0 >= idxHold1
        error('EXT2:C1A:HoldoutSupport', ...
            'No valid 17-85%% holdout support for %s.',char(axisName));
    end

    idxHold = (idxHold0:idxHold1).';

    t = Dhold.t_s(idxHold);
    I = Dhold.I_A(idxHold);
    V = Dhold.V_V(idxHold);
    z = zHold(idxHold);

    if numel(z) < cfg.minHoldoutSamples
        error('EXT2:C1A:HoldoutSamples', ...
            '%s: only %d holdout samples.',char(axisName),numel(z));
    end

    OCV = interp1(model.soc,model.ocv,z,'linear');
    R0 = interp1(model.soc,model.R0,z,'linear');
    R1 = interp1(model.soc,model.R1,z,'linear');
    C1 = interp1(model.soc,model.C1,z,'linear');
    R2 = interp1(model.soc,model.R2,z,'linear');
    C2 = interp1(model.soc,model.C2,z,'linear');

    tau1 = R1.*C1;
    tau2 = R2.*C2;

    v10 = R1(1)*I(1);
    v20 = R2(1)*I(1);

    v1 = simulate_rc_branch_variable_init(t,I,R1,tau1,v10);
    v2 = simulate_rc_branch_variable_init(t,I,R2,tau2,v20);

    VhatFrozen = OCV+v1+v2+R0.*I;

    deltaHold = interp1( ...
        SOCNode,DeltaChargeOCV_V,z,'linear');

    if any(~isfinite(deltaHold))
        error('EXT2:C1A:CorrectionInterpolation', ...
            '%s correction interpolation returned NaN.',char(axisName));
    end

    VhatCorrected = VhatFrozen+deltaHold;

    rFrozen = VhatFrozen-V;
    rCorrected = VhatCorrected-V;

    M = compute_metrics( ...
        z,I,rFrozen,rCorrected);

    iaxrow = iaxrow+1;

    axisRows(iaxrow).Axis = axisName; %#ok<SAGROW>
    axisRows(iaxrow).DevelopmentThroughput_Ah = Qdev_Ah;
    axisRows(iaxrow).HoldoutThroughput_Ah = Qhold_Ah;
    axisRows(iaxrow).HoldoutSOC_Min = min(z);
    axisRows(iaxrow).HoldoutSOC_Max = max(z);
    axisRows(iaxrow).HoldoutSamples = numel(z);
    axisRows(iaxrow).CorrectionMin_mV = min(DeltaChargeOCV_mV);
    axisRows(iaxrow).CorrectionMax_mV = max(DeltaChargeOCV_mV);
    axisRows(iaxrow).MaxAdjacentCorrectionJump_mV = ...
        max(abs(diff(DeltaChargeOCV_mV)));

    axisRows(iaxrow).FrozenRMSE_mV = M.FrozenRMSE_mV;
    axisRows(iaxrow).CorrectedRMSE_mV = M.CorrectedRMSE_mV;
    axisRows(iaxrow).RMSEImprovement_pct = M.RMSEImprovement_pct;
    axisRows(iaxrow).FrozenMAE_mV = M.FrozenMAE_mV;
    axisRows(iaxrow).CorrectedMAE_mV = M.CorrectedMAE_mV;
    axisRows(iaxrow).FrozenMeanBias_mV = M.FrozenMeanBias_mV;
    axisRows(iaxrow).CorrectedMeanBias_mV = M.CorrectedMeanBias_mV;
    axisRows(iaxrow).FrozenMaxAbs_mV = M.FrozenMaxAbs_mV;
    axisRows(iaxrow).CorrectedMaxAbs_mV = M.CorrectedMaxAbs_mV;
    axisRows(iaxrow).FrozenCenteredRMSE_mV = M.FrozenCenteredRMSE_mV;
    axisRows(iaxrow).CorrectedCenteredRMSE_mV = M.CorrectedCenteredRMSE_mV;

    % SOC bins.
    for ib = 1:numel(cfg.socEdges)-1

        lo = cfg.socEdges(ib);
        hi = cfg.socEdges(ib+1);

        if ib < numel(cfg.socEdges)-1
            mask = z >= lo & z < hi;
        else
            mask = z >= lo & z <= hi;
        end

        if sum(mask) < cfg.minBinSamples
            error('EXT2:C1A:BinSamples', ...
                '%s: only %d samples in %.0f-%.0f%% SOC bin.', ...
                char(axisName),sum(mask),100*lo,100*hi);
        end

        MB = compute_metrics( ...
            z(mask),I(mask),rFrozen(mask),rCorrected(mask));

        ibinrow = ibinrow+1;

        binRows(ibinrow).Axis = axisName; %#ok<SAGROW>
        binRows(ibinrow).SOC_Low = lo;
        binRows(ibinrow).SOC_High = hi;
        binRows(ibinrow).NSamples = sum(mask);
        binRows(ibinrow).FrozenRMSE_mV = MB.FrozenRMSE_mV;
        binRows(ibinrow).CorrectedRMSE_mV = MB.CorrectedRMSE_mV;
        binRows(ibinrow).RMSEImprovement_pct = MB.RMSEImprovement_pct;
        binRows(ibinrow).FrozenMAE_mV = MB.FrozenMAE_mV;
        binRows(ibinrow).CorrectedMAE_mV = MB.CorrectedMAE_mV;
        binRows(ibinrow).FrozenMeanBias_mV = MB.FrozenMeanBias_mV;
        binRows(ibinrow).CorrectedMeanBias_mV = MB.CorrectedMeanBias_mV;
        binRows(ibinrow).FrozenMaxAbs_mV = MB.FrozenMaxAbs_mV;
        binRows(ibinrow).CorrectedMaxAbs_mV = MB.CorrectedMaxAbs_mV;
        binRows(ibinrow).FrozenCenteredRMSE_mV = MB.FrozenCenteredRMSE_mV;
        binRows(ibinrow).CorrectedCenteredRMSE_mV = MB.CorrectedCenteredRMSE_mV;
        binRows(ibinrow).Improved = ...
            MB.CorrectedRMSE_mV < MB.FrozenRMSE_mV;
    end

    itraj = itraj+1;
    trajectoryBundle(itraj).Axis = axisName; %#ok<SAGROW>
    trajectoryBundle(itraj).Time_s = t;
    trajectoryBundle(itraj).SOC = z;
    trajectoryBundle(itraj).Current_A = I;
    trajectoryBundle(itraj).MeasuredVoltage_V = V;
    trajectoryBundle(itraj).FrozenVoltage_V = VhatFrozen;
    trajectoryBundle(itraj).CorrectedVoltage_V = VhatCorrected;
    trajectoryBundle(itraj).FrozenResidual_mV = 1000*rFrozen;
    trajectoryBundle(itraj).CorrectedResidual_mV = 1000*rCorrected;
    trajectoryBundle(itraj).AppliedCorrection_mV = 1000*deltaHold;
end

AxisSummary = struct2table(axisRows);
BinSummary = struct2table(binRows);
CorrectionCurves = struct2table(curveRows);

%% ------------------------------------------------------------------------
% 6. C1 FROZEN_QREF PARITY
% -------------------------------------------------------------------------
Aref = AxisSummary( ...
    string(AxisSummary.Axis) == "FROZEN_QREF",:);

Bref = BinSummary( ...
    string(BinSummary.Axis) == "FROZEN_QREF",:);

if height(Aref) ~= 1 || height(Bref) ~= 4
    error('EXT2:C1A:FrozenRows', ...
        'Unexpected FROZEN_QREF summary dimensions.');
end

c1Full = C1ref.FullMetrics;
c1Bins = C1ref.BinMetrics;

fullParityValues = [ ...
    abs(Aref.FrozenRMSE_mV-c1Full.FrozenRMSE_mV(1)), ...
    abs(Aref.CorrectedRMSE_mV-c1Full.CorrectedRMSE_mV(1)), ...
    abs(Aref.FrozenMAE_mV-c1Full.FrozenMAE_mV(1)), ...
    abs(Aref.CorrectedMAE_mV-c1Full.CorrectedMAE_mV(1)), ...
    abs(Aref.FrozenMeanBias_mV-c1Full.FrozenMeanBias_mV(1)), ...
    abs(Aref.CorrectedMeanBias_mV-c1Full.CorrectedMeanBias_mV(1))];

maxFullParity_mV = max(fullParityValues);

binParity = zeros(4,2);

for ib = 1:4

    rowA = Bref( ...
        abs(Bref.SOC_Low-c1Bins.SOC_Low(ib)) < 1e-12 & ...
        abs(Bref.SOC_High-c1Bins.SOC_High(ib)) < 1e-12,:);

    if height(rowA) ~= 1
        error('EXT2:C1A:BinParityLookup', ...
            'Could not match FROZEN_QREF C1 bin %.0f-%.0f%%.', ...
            100*c1Bins.SOC_Low(ib),100*c1Bins.SOC_High(ib));
    end

    binParity(ib,1) = ...
        abs(rowA.FrozenRMSE_mV-c1Bins.FrozenRMSE_mV(ib));

    binParity(ib,2) = ...
        abs(rowA.CorrectedRMSE_mV-c1Bins.CorrectedRMSE_mV(ib));
end

maxBinParity_mV = max(binParity(:));
maxParity_mV = max([maxFullParity_mV,maxBinParity_mV]);

parityPass = maxParity_mV <= cfg.parityTolerance_mV;

if ~parityPass
    error('EXT2:C1A:C1ParityFail', ...
        'FROZEN_QREF does not reproduce C1 v1.1; max metric delta %.6f mV.', ...
        maxParity_mV);
end

fprintf("C1 FROZEN_QREF parity: PASS | max metric delta = %.6g mV\n\n", ...
    maxParity_mV);

%% ------------------------------------------------------------------------
% 7. PRE-REGISTERED AXIS COMPARISON / CLASSIFICATION
% -------------------------------------------------------------------------
frozenAxis = AxisSummary( ...
    string(AxisSummary.Axis) == "FROZEN_QREF",:);

frozenLow = BinSummary( ...
    string(BinSummary.Axis) == "FROZEN_QREF" & ...
    abs(BinSummary.SOC_Low-0.17) < 1e-12 & ...
    abs(BinSummary.SOC_High-0.30) < 1e-12,:);

if height(frozenAxis) ~= 1 || height(frozenLow) ~= 1
    error('EXT2:C1A:FrozenReferenceLookup', ...
        'Could not obtain FROZEN_QREF reference rows.');
end

[~,idxBest] = min(AxisSummary.CorrectedRMSE_mV);
bestAxis = string(AxisSummary.Axis(idxBest));

bestAxisRow = AxisSummary(idxBest,:);

bestLow = BinSummary( ...
    string(BinSummary.Axis) == bestAxis & ...
    abs(BinSummary.SOC_Low-0.17) < 1e-12 & ...
    abs(BinSummary.SOC_High-0.30) < 1e-12,:);

if height(bestLow) ~= 1
    error('EXT2:C1A:BestLowBinLookup', ...
        'Could not obtain best-axis low-SOC row.');
end

fullGainVsFrozen_pct = ...
    100*(frozenAxis.CorrectedRMSE_mV-bestAxisRow.CorrectedRMSE_mV) / ...
    frozenAxis.CorrectedRMSE_mV;

lowBinGainVsFrozen_mV = ...
    frozenLow.CorrectedRMSE_mV-bestLow.CorrectedRMSE_mV;

bestIsNonFrozen = bestAxis ~= "FROZEN_QREF";

strongCriterion = ...
    bestIsNonFrozen && ...
    fullGainVsFrozen_pct >= cfg.strongFullRMSEGain_pct && ...
    lowBinGainVsFrozen_mV >= cfg.strongLowBinGain_mV && ...
    bestLow.CorrectedRMSE_mV <= cfg.strongLowBinMaxRMSE_mV;

partialCriterion = ...
    bestIsNonFrozen && ...
    ( ...
    fullGainVsFrozen_pct >= cfg.partialFullRMSEGain_pct || ...
    lowBinGainVsFrozen_mV >= cfg.partialLowBinGain_mV ...
    );

if strongCriterion

    descriptiveClass = ...
        "SOC_AXIS_MAPPING_STRONGLY_CONTRIBUTES";

elseif partialCriterion

    descriptiveClass = ...
        "SOC_AXIS_MAPPING_PARTIALLY_CONTRIBUTES";

else

    descriptiveClass = ...
        "SOC_AXIS_MAPPING_NOT_PRIMARY";
end

%% ------------------------------------------------------------------------
% 8. SAVE NUMERICAL EVIDENCE
% -------------------------------------------------------------------------
axisOut = fullfile( ...
    resultsDir,'EXT2_C1A_axis_summary_v1_1.csv');

binOut = fullfile( ...
    resultsDir,'EXT2_C1A_SOC_bin_summary_v1_1.csv');

curveOut = fullfile( ...
    resultsDir,'EXT2_C1A_correction_curves_v1_1.csv');

writetable(AxisSummary,axisOut);
writetable(BinSummary,binOut);
writetable(CorrectionCurves,curveOut);

bundleOut = fullfile( ...
    resultsDir,'EXT2_C1A_run_bundle_v1_1.mat');

save(bundleOut, ...
    'cfg','AxisSummary','BinSummary','CorrectionCurves', ...
    'trajectoryBundle','parityPass','maxParity_mV', ...
    'bestAxis','fullGainVsFrozen_pct','lowBinGainVsFrozen_mV', ...
    'strongCriterion','partialCriterion','descriptiveClass','-v7.3');

%% ------------------------------------------------------------------------
% 9. FIGURES
% -------------------------------------------------------------------------
f1 = figure('Name','EXT2-C1A corrected RMSE by SOC bin','Visible','off');

hold on;

for ia = 1:numel(cfg.axes)

    T = BinSummary(string(BinSummary.Axis) == cfg.axes(ia),:);
    T = sortrows(T,'SOC_Low');

    x = 100*0.5*(T.SOC_Low+T.SOC_High);

    plot(x,T.CorrectedRMSE_mV,'-o','LineWidth',1.2);
end

xlabel('SOC-bin midpoint [%]');
ylabel('Corrected RMSE [mV]');
title('EXT2-C1A | corrected holdout RMSE vs SOC-axis convention');
legend(cellstr(cfg.axes),'Location','best');
grid on;

fig1 = fullfile( ...
    resultsDir,'EXT2_C1A_corrected_RMSE_by_SOC_axis_v1_1.png');

try
    exportgraphics(f1,fig1,'Resolution',180);
catch
    saveas(f1,fig1);
end

close(f1);

f2 = figure('Name','EXT2-C1A full trajectory residuals','Visible','off');

hold on;

for ia = 1:numel(trajectoryBundle)
    T = trajectoryBundle(ia);

    plot(100*T.SOC,T.CorrectedResidual_mV,'LineWidth',0.9);
end

yline(0,'--');
xlabel('SOC [%]');
ylabel('Corrected residual [mV]');
title('EXT2-C1A | corrected residual across SOC-axis conventions');
legend(cellstr(cfg.axes),'Location','best');
grid on;

fig2 = fullfile( ...
    resultsDir,'EXT2_C1A_corrected_residual_by_SOC_axis_v1_1.png');

try
    exportgraphics(f2,fig2,'Resolution',180);
catch
    saveas(f2,fig2);
end

close(f2);

%% ------------------------------------------------------------------------
% 10. REPORT
% -------------------------------------------------------------------------
reportFile = fullfile( ...
    resultsDir,'EXT2_C1A_SOC_axis_sensitivity_report_v1_1.txt');

fid = fopen(reportFile,'w');

if fid < 0
    error('EXT2:C1A:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-C1A Full-Trajectory SOC-Axis Sensitivity Audit v1.1\n");
fprintf(fid,"==========================================================\n\n");

fprintf(fid,"No free qRef/SOC-shift optimization. Three pre-existing axes only.\n");
fprintf(fid,"Development: exact 0.1C charge. Holdout: exact 1C full charge.\n\n");

fprintf(fid,"C1 FROZEN_QREF parity max metric delta = %.9g mV | %s\n\n", ...
    maxParity_mV,pass_text(parityPass));

fprintf(fid,"Axis summaries:\n");

for k = 1:height(AxisSummary)

    fprintf(fid, ...
        "%s | frozen RMSE %.3f | corrected RMSE %.3f mV | imp %.2f %% | corrected bias %+.3f mV | centered %.3f -> %.3f mV | correction %.2f...%.2f mV\n", ...
        AxisSummary.Axis(k), ...
        AxisSummary.FrozenRMSE_mV(k), ...
        AxisSummary.CorrectedRMSE_mV(k), ...
        AxisSummary.RMSEImprovement_pct(k), ...
        AxisSummary.CorrectedMeanBias_mV(k), ...
        AxisSummary.FrozenCenteredRMSE_mV(k), ...
        AxisSummary.CorrectedCenteredRMSE_mV(k), ...
        AxisSummary.CorrectionMin_mV(k), ...
        AxisSummary.CorrectionMax_mV(k));
end

fprintf(fid,"\nSOC-bin corrected RMSE:\n");

for k = 1:height(BinSummary)

    fprintf(fid, ...
        "%s | %.0f-%.0f%% | %.3f -> %.3f mV | improvement %.2f %% | bias %+.3f -> %+.3f mV\n", ...
        BinSummary.Axis(k), ...
        100*BinSummary.SOC_Low(k), ...
        100*BinSummary.SOC_High(k), ...
        BinSummary.FrozenRMSE_mV(k), ...
        BinSummary.CorrectedRMSE_mV(k), ...
        BinSummary.RMSEImprovement_pct(k), ...
        BinSummary.FrozenMeanBias_mV(k), ...
        BinSummary.CorrectedMeanBias_mV(k));
end

fprintf(fid,"\nBest axis by corrected full RMSE = %s\n",bestAxis);
fprintf(fid,"Full corrected-RMSE gain vs FROZEN_QREF = %.3f %%\n", ...
    fullGainVsFrozen_pct);
fprintf(fid,"17-30%% corrected-RMSE gain vs FROZEN_QREF = %.3f mV\n", ...
    lowBinGainVsFrozen_mV);
fprintf(fid,"Strong criterion = %s\n",pass_text(strongCriterion));
fprintf(fid,"Partial criterion = %s\n",pass_text(partialCriterion));
fprintf(fid,"Descriptive class = %s\n",descriptiveClass);

fprintf(fid,"\nClaim boundary:\n");
fprintf(fid,"C1A is an SOC-axis sensitivity audit. SELF_NORMALIZED is not independent physical SOC ground truth. B1-2J remains HPPC_SOC_PROVENANCE_INCONCLUSIVE.\n");
fprintf(fid,"No tested SOC axis is authorized as a replacement frozen-model axis by this audit alone.\n");
fclose(fid);

%% ------------------------------------------------------------------------
% 11. PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);

[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetOut = fullfile( ...
    resultsDir,'EXT2_C1A_protected_asset_audit_v1_1.csv');

writetable(AssetAudit,assetOut);

if ~assetsUnchanged
    error('EXT2:C1A:ProtectedAssetChanged', ...
        'A protected frozen asset changed during C1A. STOP.');
end

%% ------------------------------------------------------------------------
% 12. AUTODOC
% -------------------------------------------------------------------------
autodoc_C1A( ...
    protocolDir,auditDir,handoffDir, ...
    AxisSummary,BinSummary, ...
    parityPass,maxParity_mV, ...
    bestAxis,fullGainVsFrozen_pct,lowBinGainVsFrozen_mV, ...
    strongCriterion,partialCriterion,descriptiveClass, ...
    assetsUnchanged);

%% ------------------------------------------------------------------------
% 13. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-C1A COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("C1 FROZEN_QREF parity:\n");
fprintf("  max metric delta                  : %.6g mV\n",maxParity_mV);
fprintf("  parity                            : %s\n\n",pass_text(parityPass));

fprintf("Axis summaries:\n");

for k = 1:height(AxisSummary)

    fprintf("  %-16s | frozen RMSE %6.2f | corrected %6.2f mV | imp %7.2f %% | bias %+7.2f mV | centered %6.2f -> %6.2f\n", ...
        AxisSummary.Axis(k), ...
        AxisSummary.FrozenRMSE_mV(k), ...
        AxisSummary.CorrectedRMSE_mV(k), ...
        AxisSummary.RMSEImprovement_pct(k), ...
        AxisSummary.CorrectedMeanBias_mV(k), ...
        AxisSummary.FrozenCenteredRMSE_mV(k), ...
        AxisSummary.CorrectedCenteredRMSE_mV(k));
end

fprintf("\n17-30%% low-SOC bin:\n");

for ia = 1:numel(cfg.axes)

    T = BinSummary( ...
        string(BinSummary.Axis) == cfg.axes(ia) & ...
        abs(BinSummary.SOC_Low-0.17) < 1e-12 & ...
        abs(BinSummary.SOC_High-0.30) < 1e-12,:);

    fprintf("  %-16s | RMSE %6.2f -> %6.2f mV | bias %+7.2f -> %+7.2f mV\n", ...
        cfg.axes(ia), ...
        T.FrozenRMSE_mV, ...
        T.CorrectedRMSE_mV, ...
        T.FrozenMeanBias_mV, ...
        T.CorrectedMeanBias_mV);
end

fprintf("\nAxis comparison:\n");
fprintf("  Best axis by corrected full RMSE : %s\n",bestAxis);
fprintf("  Full gain vs FROZEN_QREF         : %.2f %%\n", ...
    fullGainVsFrozen_pct);
fprintf("  17-30%% gain vs FROZEN_QREF       : %.3f mV\n", ...
    lowBinGainVsFrozen_mV);
fprintf("  Strong criterion                 : %s\n", ...
    pass_text(strongCriterion));
fprintf("  Partial criterion                : %s\n", ...
    pass_text(partialCriterion));

fprintf("\nDescriptive class:\n  %s\n",descriptiveClass);
fprintf("B1-2J HPPC SOC provenance          : INCONCLUSIVE\n");
fprintf("R2/tau2 continuous adaptation      : CLOSED\n");
fprintf("Protected assets unchanged         : %s\n", ...
    pass_text(assetsUnchanged));
fprintf("AUTODOC updated                     : PASS\n\n");

fprintf("Results:\n%s\n",resultsDir);
fprintf("Docs:\n%s\n\n",docsDir);


%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function z = build_soc_axis(D,axisName,qFrozen,qNominal,qSelf)

qCum = cumtrapz(D.t_s,max(D.I_A,0))/3600;
qRemain = qCum(end)-qCum;

switch char(axisName)

    case 'FROZEN_QREF'
        qDen = qFrozen;

    case 'NOMINAL_3P5'
        qDen = qNominal;

    case 'SELF_NORMALIZED'
        qDen = qSelf;

    otherwise
        error('EXT2:C1A:UnknownAxis', ...
            'Unknown SOC axis: %s',char(axisName));
end

z = 1-qRemain/qDen;
z = z(:);
end


function M = compute_metrics(z,I,r0,r1)

z = z(:);
I = I(:);
r0 = r0(:);
r1 = r1(:);

if numel(z) ~= numel(I) || ...
   numel(z) ~= numel(r0) || ...
   numel(z) ~= numel(r1)
    error('EXT2:C1A:MetricVectorLength', ...
        'Metric vectors must have equal length.');
end

M = struct();

M.NSamples = numel(z);
M.SOC_Min = min(z);
M.SOC_Max = max(z);
M.MeanCurrent_A = mean(I);

M.FrozenRMSE_mV = sqrt(mean(r0.^2))*1000;
M.CorrectedRMSE_mV = sqrt(mean(r1.^2))*1000;

if M.FrozenRMSE_mV > eps
    M.RMSEImprovement_pct = ...
        100*(M.FrozenRMSE_mV-M.CorrectedRMSE_mV) / ...
        M.FrozenRMSE_mV;
else
    M.RMSEImprovement_pct = 0;
end

M.FrozenMAE_mV = mean(abs(r0))*1000;
M.CorrectedMAE_mV = mean(abs(r1))*1000;

M.FrozenMeanBias_mV = mean(r0)*1000;
M.CorrectedMeanBias_mV = mean(r1)*1000;

M.FrozenMaxAbs_mV = max(abs(r0))*1000;
M.CorrectedMaxAbs_mV = max(abs(r1))*1000;

c0 = r0-mean(r0);
c1 = r1-mean(r1);

M.FrozenCenteredRMSE_mV = sqrt(mean(c0.^2))*1000;
M.CorrectedCenteredRMSE_mV = sqrt(mean(c1.^2))*1000;
end


function D = load_ngu_uiv_full(filePath)

txt = fileread(filePath);
lines = splitlines(string(txt));

if isempty(lines)
    error('EXT2:C1A:EmptyProfile', ...
        'Empty profile: %s',char(filePath));
end

if strlength(lines(1)) > 0
    lines(1) = erase(lines(1),string(char(65279)));
end

mask = contains(lower(lines),'timestamp') & ...
       contains(lower(lines),'u1[v]') & ...
       contains(lower(lines),'i1[a]');

headerIdx = find(mask,1,'first');

if isempty(headerIdx)
    error('EXT2:C1A:NGUHeaderMissing', ...
        'NGU header not found: %s',char(filePath));
end

headers = split(lines(headerIdx),',');
headers = strtrim(erase(headers,'"'));
headers = erase(headers,string(char(65279)));

iT = find(strcmpi(headers,'Timestamp'),1);
iV = find(strcmpi(headers,'U1[V]'),1);
iI = find(strcmpi(headers,'I1[A]'),1);

if isempty(iT) || isempty(iV) || isempty(iI)
    error('EXT2:C1A:NGUColumnsMissing', ...
        'Timestamp/U1[V]/I1[A] missing: %s',char(filePath));
end

dataLines = lines(headerIdx+1:end);
dataLines(strlength(strtrim(dataLines)) == 0) = [];

n = numel(dataLines);
tRaw = nan(n,1);
V = nan(n,1);
I = nan(n,1);

for k = 1:n

    tok = split(dataLines(k),',');

    if numel(tok) < max([iT iV iI])
        continue
    end

    tRaw(k) = parse_time_token(tok(iT));
    V(k) = str2double(strtrim(erase(tok(iV),'"')));
    I(k) = str2double(strtrim(erase(tok(iI),'"')));
end

valid = isfinite(tRaw) & isfinite(V) & isfinite(I);

tRaw = tRaw(valid);
V = V(valid);
I = I(valid);

if numel(tRaw) < 2
    error('EXT2:C1A:NoValidData', ...
        'Too few valid rows: %s',char(filePath));
end

t = unwrap_elapsed_time(tRaw);
t = t-t(1);

if any(diff(t) <= 0)
    error('EXT2:C1A:NonMonotonicTime', ...
        'Timestamps are not strictly increasing: %s',char(filePath));
end

D = struct();
D.t_s = t(:);
D.V_V = V(:);
D.I_A = I(:);
end


function t = parse_time_token(token)

s = strtrim(erase(string(token),'"'));
t = NaN;

if contains(s,' ')
    p = split(s);
    s = p(end);
end

parts = split(s,':');

if numel(parts) == 3

    h = str2double(parts(1));
    m = str2double(parts(2));
    sec = str2double(parts(3));

    if all(isfinite([h m sec]))
        t = 3600*h+60*m+sec;
    end

elseif numel(parts) == 2

    m = str2double(parts(1));
    sec = str2double(parts(2));

    if all(isfinite([m sec]))
        t = 60*m+sec;
    end

else

    v = str2double(s);

    if isfinite(v)
        t = v;
    end
end
end


function tOut = unwrap_elapsed_time(tIn)

tOut = tIn(:);
offset = 0;

for k = 2:numel(tOut)

    current = tOut(k)+offset;
    prev = tOut(k-1);

    if current <= prev

        candidates = [60,3600,24*3600];
        added = NaN;

        for c = candidates

            if current+c > prev && ...
               abs((current+c)-prev) < 10

                added = c;
                break
            end
        end

        if isfinite(added)
            offset = offset+added;
            current = tOut(k)+offset;
        end
    end

    tOut(k) = current;
end
end


function idx = find_terminal_anchor_charge(D,cfg)

tailStart = max(D.t_s(1), ...
    D.t_s(end)-cfg.anchorSearchTail_s);

cand = find( ...
    D.t_s >= tailStart & ...
    abs(D.V_V-cfg.fullVoltage_V) <= ...
        2*cfg.fullVoltageTol_V & ...
    D.I_A >= 0 & D.I_A <= 0.10);

if isempty(cand)
    error('EXT2:C1A:ChargeAnchorCandidate', ...
        'No terminal full-charge anchor candidate found.');
end

score = ...
    abs(D.V_V(cand)-cfg.fullVoltage_V)/cfg.fullVoltageTol_V + ...
    abs(D.I_A(cand)-cfg.fullCurrent_A)/cfg.fullCurrentTol_A;

[~,j] = min(score);
idx = cand(j);

if abs(D.V_V(idx)-cfg.fullVoltage_V) > cfg.fullVoltageTol_V || ...
   abs(D.I_A(idx)-cfg.fullCurrent_A) > cfg.fullCurrentTol_A

    error('EXT2:C1A:ChargeAnchorFail', ...
        'Terminal 4.2 V / 50 mA anchor failed strict check.');
end
end


function D2 = truncate_data(D,idx)

D2 = D;
D2.t_s = D.t_s(1:idx);
D2.V_V = D.V_V(1:idx);
D2.I_A = D.I_A(1:idx);
end


function v = simulate_rc_branch_variable_init(t,I,Rbase,taubase,v0)

t = t(:);
I = I(:);
Rbase = Rbase(:);
taubase = taubase(:);

N = numel(t);

if numel(I) ~= N || ...
   numel(Rbase) ~= N || ...
   numel(taubase) ~= N
    error('EXT2:C1A:RCVectorLength', ...
        't/I/R/tau vectors must have equal length.');
end

v = zeros(N,1);
v(1) = v0;

for k = 1:N-1

    dt = t(k+1)-t(k);

    if dt <= 0
        error('EXT2:C1A:NonPositiveDt', ...
            'Non-positive dt in RC simulation.');
    end

    a = exp(-dt/taubase(k));
    b = Rbase(k)*(1-a);

    v(k+1) = a*v(k)+b*I(k);
end
end


function h = sha256_file(filePath)

cmd = sprintf('certutil -hashfile "%s" SHA256',char(filePath));
[status,out] = system(cmd);

if status == 0

    token = regexp(out,'[0-9A-Fa-f]{64}','match','once');

    if ~isempty(token)
        h = lower(token);
        return
    end
end

fid = fopen(filePath,'rb');

if fid < 0
    error('EXT2:C1A:HashOpenFailed', ...
        'Could not open for SHA-256: %s',char(filePath));
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

try

    md = java.security.MessageDigest.getInstance('SHA-256');

    while true

        bytes = fread(fid,1024*1024,'*uint8');

        if isempty(bytes)
            break
        end

        md.update(typecast(bytes(:),'int8'));
    end

    digest = md.digest();
    u = typecast(digest,'uint8');

    h = lower(reshape(dec2hex(u,2).',1,[]));

catch ME

    error('EXT2:C1A:HashFailed', ...
        'SHA-256 failed for %s: %s',char(filePath),ME.message);
end
end


function snap = snapshot_assets_hash(rootDir,relPaths)

n = numel(relPaths);

Path = strings(n,1);
Exists = false(n,1);
Bytes = nan(n,1);
SHA256 = strings(n,1);

for k = 1:n

    p = fullfile(rootDir,relPaths{k});

    Path(k) = string(p);
    Exists(k) = isfile(p);

    if Exists(k)

        d = dir(p);
        Bytes(k) = d.bytes;
        SHA256(k) = string(sha256_file(p));

    else

        SHA256(k) = "";
    end
end

snap = table( ...
    Path,Exists,Bytes,SHA256, ...
    'VariableNames',{'Path','Exists','Bytes','SHA256'});
end


function [ok,audit] = compare_asset_snapshots_hash(a,b)

if height(a) ~= height(b) || any(a.Path ~= b.Path)
    error('EXT2:C1A:AssetSnapshotMismatch', ...
        'Protected asset snapshot structure mismatch.');
end

Unchanged = false(height(a),1);

for k = 1:height(a)

    if ~a.Exists(k) && ~b.Exists(k)

        Unchanged(k) = true;

    elseif a.Exists(k) && b.Exists(k)

        Unchanged(k) = ...
            a.Bytes(k) == b.Bytes(k) && ...
            strcmpi(a.SHA256(k),b.SHA256(k));

    else

        Unchanged(k) = false;
    end
end

audit = table( ...
    a.Path,a.Exists,b.Exists,a.Bytes,b.Bytes, ...
    a.SHA256,b.SHA256,Unchanged, ...
    'VariableNames', { ...
    'Path','ExistsBefore','ExistsAfter','BytesBefore','BytesAfter', ...
    'SHA256Before','SHA256After','Unchanged'});

ok = all(Unchanged);
end


function autodoc_C1A( ...
    protocolDir,auditDir,handoffDir, ...
    AxisSummary,BinSummary, ...
    parityPass,maxParity, ...
    bestAxis,fullGain,lowGain, ...
    strongCriterion,partialCriterion,descriptiveClass, ...
    assetsUnchanged)

protocolPath = fullfile( ...
    protocolDir,'EXT2_C1A_PROTOCOL_v1_1.md');

protocol = {
'# EXT2-C1A Protocol v1.1 — Full-Trajectory SOC-Axis Sensitivity Audit'
''
'## Purpose'
''
'Determine whether the C1 full-trajectory transfer failure is materially driven by SOC/capacity-axis convention.'
''
'## Pre-registered axes'
''
'- FROZEN_QREF = 3.335 Ah'
'- NOMINAL_3P5 = 3.500 Ah'
'- SELF_NORMALIZED = each trajectory normalized by its own measured terminal-anchor charge throughput'
''
'For each axis the 0.1C correction is rebuilt independently and applied unchanged to the 1C full-charge holdout.'
''
'## Prohibitions'
''
'No free qRef optimization, SOC-shift fitting, R2/tau2 fitting, hysteresis-state fitting, EKF modification or frozen-model modification.'
''
'## Classification'
''
'STRONGLY_CONTRIBUTES: non-frozen best axis improves full corrected RMSE by >=20%, improves 17-30% corrected RMSE by >=10 mV, and achieves <=15 mV low-bin RMSE.'
''
'PARTIALLY_CONTRIBUTES: non-frozen best axis improves full corrected RMSE by >=10% or improves 17-30% corrected RMSE by >=10 mV, without satisfying the strong rule.'
''
'NOT_PRIMARY: otherwise.'
''
'## Claim boundary'
''
'SELF_NORMALIZED is a sensitivity convention, not independent physical SOC ground truth. B1-2J remains HPPC_SOC_PROVENANCE_INCONCLUSIVE.'
};

write_text_lines(protocolPath,protocol);

auditPath = fullfile( ...
    auditDir,'EXT2_C1A_EXECUTION_AUDIT_v1_1.md');

audit = {
'# EXT2-C1A Execution Audit v1.1'
''
'## Status'
''
'`CLOSED / SOC-AXIS SENSITIVITY COMPLETE`'
''
'Implementation note: C1A v1 stopped after source/anchor preflight and the three-axis calculation because the loaded C1 reference struct was named `C1`, creating a MATLAB variable-name collision with C1-related numeric model variables. v1.1 renames only the reference bundle to `C1ref`; all scientific inputs, three SOC-axis definitions, metrics, parity tolerance and classification thresholds are unchanged.'
''
sprintf('- C1 FROZEN_QREF parity: **%s**',pass_text(parityPass))
sprintf('- max C1 parity metric delta: **%.6g mV**',maxParity)
''
'## Full-trajectory axis comparison'
''
'| Axis | Frozen RMSE | Corrected RMSE | Improvement | Corrected bias | Corrected centered RMSE |'
'|---|---:|---:|---:|---:|---:|'
};

for k = 1:height(AxisSummary)

    audit{end+1} = sprintf( ...
        '| %s | %.2f mV | %.2f mV | %.2f%% | %+.2f mV | %.2f mV |', ...
        AxisSummary.Axis(k), ...
        AxisSummary.FrozenRMSE_mV(k), ...
        AxisSummary.CorrectedRMSE_mV(k), ...
        AxisSummary.RMSEImprovement_pct(k), ...
        AxisSummary.CorrectedMeanBias_mV(k), ...
        AxisSummary.CorrectedCenteredRMSE_mV(k)); %#ok<AGROW>
end

audit{end+1} = '';
audit{end+1} = '## 17-30% bin';
audit{end+1} = '';
audit{end+1} = '| Axis | Frozen RMSE | Corrected RMSE | Frozen bias | Corrected bias |';
audit{end+1} = '|---|---:|---:|---:|---:|';

for k = 1:height(BinSummary)

    if abs(BinSummary.SOC_Low(k)-0.17) < 1e-12 && ...
       abs(BinSummary.SOC_High(k)-0.30) < 1e-12

        audit{end+1} = sprintf( ...
            '| %s | %.2f mV | %.2f mV | %+.2f mV | %+.2f mV |', ...
            BinSummary.Axis(k), ...
            BinSummary.FrozenRMSE_mV(k), ...
            BinSummary.CorrectedRMSE_mV(k), ...
            BinSummary.FrozenMeanBias_mV(k), ...
            BinSummary.CorrectedMeanBias_mV(k)); %#ok<AGROW>
    end
end

audit{end+1} = '';
audit{end+1} = sprintf('- best axis: **%s**',bestAxis);
audit{end+1} = sprintf('- full corrected-RMSE gain vs FROZEN_QREF: **%.2f%%**',fullGain);
audit{end+1} = sprintf('- 17-30%% corrected-RMSE gain vs FROZEN_QREF: **%.3f mV**',lowGain);
audit{end+1} = sprintf('- strong criterion: **%s**',pass_text(strongCriterion));
audit{end+1} = sprintf('- partial criterion: **%s**',pass_text(partialCriterion));
audit{end+1} = '';
audit{end+1} = ['Descriptive class: `' char(descriptiveClass) '`'];
audit{end+1} = '';
audit{end+1} = sprintf('Protected frozen assets unchanged: **%s**',pass_text(assetsUnchanged));
audit{end+1} = '';
audit{end+1} = 'B1-2J remains HPPC_SOC_PROVENANCE_INCONCLUSIVE. No tested axis is authorized as physical ground truth by C1A.';

write_text_lines(auditPath,audit);

handoffPath = fullfile( ...
    handoffDir,'EXT2_CURRENT_HANDOFF.md');

handoff = {
'# EXT2 Current Handoff'
''
'## Canonical paths'
''
'- EXT2: `<EXT2_WORK_ROOT>`'
'- results: `...\EXT2_dynamic_parameter_identifiability\results`'
'- local Git reference: `<REPO_ROOT>`'
'- GitHub remote: `https://github.com/jiaxingLu/MJ1_2RC_EKF_SOC_Estimation`'
''
'## Evidence chain'
''
'- B1-2H local/window independent charge-baseline correction: PASS'
'- B1-2I R2/tau2 confounder-controlled consistency: FAIL; continuous dynamic adaptation CLOSED'
'- B1-2J HPPC SOC provenance: INCONCLUSIVE'
'- C1 full-trajectory charge-baseline transfer: FAIL / PARTIAL support'
sprintf('- C1A SOC-axis sensitivity: `%s`',descriptiveClass)
''
'## C1A result'
''
sprintf('- best tested axis by corrected full RMSE: %s',bestAxis)
sprintf('- full corrected-RMSE gain vs FROZEN_QREF: %.2f%%',fullGain)
sprintf('- 17-30%% corrected-RMSE gain vs FROZEN_QREF: %.3f mV',lowGain)
sprintf('- C1 parity: %s',pass_text(parityPass))
''
'## Claim boundary'
''
'C1A is a sensitivity audit. SELF_NORMALIZED and NOMINAL_3P5 are not established physical SOC ground truth. No frozen SOC axis is replaced by this stage.'
''
'R2/tau2 continuous adaptation remains CLOSED.'
};

write_text_lines(handoffPath,handoff);

continuityPath = fullfile( ...
    handoffDir,'EXT2_PROJECT_CONTINUITY_CURRENT.md');

continuity = {
'# EXT2 Project Continuity — CURRENT'
''
'## Structure'
''
'header -> PATHS -> frozen/source checks -> pre-registered analysis -> results -> protected SHA audit -> AUTODOC -> claim boundary -> local functions.'
''
'## Current technical position'
''
'- B1-2H demonstrated strong local/window transfer of an independently derived charging-baseline correction.'
'- C1 showed incomplete full-trajectory transfer, with severe low-SOC overcorrection under FROZEN_QREF.'
'- B1-2J could not independently close HPPC absolute-SOC provenance.'
sprintf('- C1A SOC-axis diagnosis: %s',descriptiveClass)
''
'## Frozen boundary'
''
'Do not modify frozen MJ1 v0.2 EKF, Bayesian R0 v1.0, EXT1 K4, frozen Simulink assets or released history.'
''
'## AUTODOC'
''
'RUN scripts update protocol, execution audit and current handoff automatically.'
};

write_text_lines(continuityPath,continuity);
end


function write_text_lines(filePath,lines)

fid = fopen(filePath,'w','n','UTF-8');

if fid < 0
    error('EXT2:C1A:DocWriteFailed', ...
        'Could not open documentation file: %s',char(filePath));
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

for k = 1:numel(lines)
    fprintf(fid,'%s\n',char(string(lines{k})));
end
end


function s = pass_text(tf)

if tf
    s = 'PASS';
else
    s = 'FAIL';
end
end
