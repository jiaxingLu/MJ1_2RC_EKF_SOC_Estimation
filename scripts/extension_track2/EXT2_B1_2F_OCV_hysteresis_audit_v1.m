% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_B1_2F_OCV_hysteresis_audit_v1.m
% MJ1 2RC-EKF EXT2-B1
% B1-2F OCV/SOC Baseline & Charge-Hysteresis Audit v1
%
% PURPOSE
%   Follow B1-2C/B1-2D/B1-2E and test whether the common real-voltage
%   baseline error is consistent with:
%     1) charge-direction OCV / hysteresis behavior,
%     2) a global frozen OCV-LUT offset,
%     3) a remaining dynamic-correction error.
%
% THIS IS DIAGNOSTIC ONLY.
%   - No R2/tau2 fitting.
%   - No online adaptation.
%   - No frozen-model modification.
%   - No B1-2B grid expansion.
%
% PRIMARY EVIDENCE
%   A) low-rate 0.1C DC charge:
%      raw_original/0.1C/NGU/0.1C dc.csv
%
%   B) paired historical 1C full charge / full discharge:
%      raw_original/1C/1C_full_charge.csv
%      raw_original/1C/1C_full_discharge.csv
%
% The three sources are locked by exact path + SHA-256.
%
% SOC AXES
%   Primary:
%     SELF_NORMALIZED
%       charge:    0 -> 100% using measured terminal-full throughput
%       discharge: 100 -> 0% using measured terminal-empty throughput
%
%   Sensitivity:
%     NOMINAL_3P5
%     FROZEN_QREF
%
% PSEUDO-OCV
%   Within frozen LUT support, replay frozen R0/R1/tau1/R2/tau2 on the
%   independently constructed SOC trajectory and remove the modeled
%   electrical polarization:
%
%     OCV_pseudo = Vmeas - R0*I - v1 - v2
%
%   A quasi-steady correction is also reported:
%
%     OCV_qs = Vmeas - I*(R0+R1+R2)
%
%   Agreement between dynamic and quasi-steady correction is a diagnostic.
%
% TARGET SOC
%   30%, 50%, 70%
%
% HYSTERESIS INTERPRETATION BOUNDARY
%   The 1C charge/discharge difference is a pseudo-OCV directional gap
%   after frozen-ECM polarization removal. It is NOT a direct equilibrium
%   hysteresis measurement because the records are finite-rate tests.
%
% AUTODOC
%   After a successful run this script automatically creates/updates:
%     docs/protocols/EXT2_B1_2F_PROTOCOL_v1.md
%     docs/audits/EXT2_B1_2F_EXECUTION_AUDIT_v1.md
%     docs/handoff/EXT2_CURRENT_HANDOFF.md
%     docs/handoff/EXT2_PROJECT_CONTINUITY_CURRENT.md
%
% All numerical evidence is written only to EXT2/results.
%
% MATLAB compatibility:
%   Base MATLAB only. No Statistics/Econometrics Toolbox.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-2F | OCV/SOC Baseline & Charge-Hysteresis Audit v1\n");
fprintf(" Low-rate charge + paired 1C charge/discharge | No adaptation\n");
fprintf("============================================================\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));

if strlength(scriptDir) == 0
    error('EXT2:B12F:RunAsFile', ...
        'Run this script from its saved .m file.');
end

ext2Dir = scriptDir;

[~,folderName] = fileparts(ext2Dir);

if ~strcmpi(string(folderName),"EXT2_dynamic_parameter_identifiability")
    error('EXT2:B12F:WrongFolder', ...
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

profileRoot = fullfile(string(getenv("USERPROFILE")), ...
    'Desktop','MJ1_Experimental_Data_Reconstruction','raw_original');

file01Charge = fullfile(profileRoot,'0.1C','NGU','0.1C dc.csv');
file1CCharge = fullfile(profileRoot,'1C','1C_full_charge.csv');
file1CDischarge = fullfile(profileRoot,'1C','1C_full_discharge.csv');

sha01Charge = ...
    "65a96280e83c7ff3236453f7aab97ab5aaba67d693cd71447a4dcefbb40ea695";

sha1CCharge = ...
    "9df6afbf73b78742e0449803d8f2eae8e9506583b5ff2f5161fabc65934d72f2";

sha1CDischarge = ...
    "df1671e7809ba8d6f20e6ab814eb64cea98d8d98e787e66d575e5aff8088f572";

b12dCommonFile = fullfile( ...
    resultsDir,'EXT2_B1_2D_common_mode_bias_by_SOC_v1.csv');

b12eCapacityFile = fullfile( ...
    resultsDir,'EXT2_B1_2E_capacity_reference_summary_v1.csv');

required = { ...
    modelFile, ...
    file01Charge, ...
    file1CCharge, ...
    file1CDischarge, ...
    b12dCommonFile, ...
    b12eCapacityFile, ...
    fullfile(repoMatlab,'mj1_load_model.m')};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:B12F:MissingInput', ...
            'Required input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

B12D = readtable(b12dCommonFile);
B12E = readtable(b12eCapacityFile);

requiredD = { ...
    'TargetSOC','SharedVoltageCorrection_mV', ...
    'MeanResidualBias_mV','EquivalentSOCShift_pp'};

missingD = setdiff(requiredD,B12D.Properties.VariableNames);

if ~isempty(missingD)
    error('EXT2:B12F:B12DContract', ...
        'B1-2D common-mode table missing variable(s): %s', ...
        strjoin(missingD,', '));
end

fprintf("EXT2 work folder : %s\n",ext2Dir);
fprintf("Results only     : %s\n",resultsDir);
fprintf("Docs AUTO        : %s\n",docsDir);
fprintf("Frozen model     : %s\n\n",modelFile);

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
% 2. PROSPECTIVE CONFIGURATION
% -------------------------------------------------------------------------
cfg.targetSOC = [0.30 0.50 0.70];
cfg.socBandHalfWidth = 0.01; % +/- 1 percentage point

cfg.nominalCapacity_Ah = 3.500;
cfg.frozenCapacity_Ah = model.qRefAh;

cfg.fullVoltage_V = 4.200;
cfg.fullCurrent_A = 0.050;
cfg.fullVoltageTol_V = 0.006;
cfg.fullCurrentTol_A = 0.006;

cfg.emptyVoltage_V = 2.500;
cfg.emptyCurrent_A = -0.025;
cfg.emptyVoltageTol_V = 0.006;
cfg.emptyCurrentTol_A = 0.008;

cfg.anchorSearchTail_s = 900;

% Diagnostic classification thresholds.
cfg.chargeOffsetMin_mV = 20;
cfg.chargeAgreementTol_mV = 10;
cfg.directionalGapMin_mV = 15;
cfg.globalOffsetMin_mV = 20;
cfg.globalGapMax_mV = 10;
cfg.dynamicMismatchAgreement_mV = 20;
cfg.b12dAgreementTol_mV = 15;

cfg.maxDynamicVsQS_mV = 10;

% Axis sensitivity descriptive threshold.
cfg.axisRobustnessTol_mV = 15;

axisNames = ["SELF_NORMALIZED","NOMINAL_3P5","FROZEN_QREF"];

%% ------------------------------------------------------------------------
% 3. SOURCE IDENTITY
% -------------------------------------------------------------------------
assert_sha(file01Charge,sha01Charge,"0.1C DC charge");
assert_sha(file1CCharge,sha1CCharge,"1C full charge");
assert_sha(file1CDischarge,sha1CDischarge,"1C full discharge");

fprintf("Source identity:\n");
fprintf("  0.1C DC charge    : SHA256 PASS\n");
fprintf("  1C full charge    : SHA256 PASS\n");
fprintf("  1C full discharge : SHA256 PASS\n\n");

%% ------------------------------------------------------------------------
% 4. LOAD SOURCES + TERMINAL ANCHORS
% -------------------------------------------------------------------------
D01 = load_ngu_uiv_full(file01Charge);
D1C = load_ngu_uiv_full(file1CCharge);
D1D = load_ngu_uiv_full(file1CDischarge);

idx01Full = find_terminal_anchor_charge(D01,cfg);
idx1CFull = find_terminal_anchor_charge(D1C,cfg);
idx1DEmpty = find_terminal_anchor_discharge(D1D,cfg);

% Truncate to anchor.
D01 = truncate_data(D01,idx01Full);
D1C = truncate_data(D1C,idx1CFull);
D1D = truncate_data(D1D,idx1DEmpty);

Q01_Ah = trapz(D01.t_s,max(D01.I_A,0))/3600;
Q1C_Ah = trapz(D1C.t_s,max(D1C.I_A,0))/3600;
Q1D_Ah = -trapz(D1D.t_s,min(D1D.I_A,0))/3600;

fprintf("Measured terminal-anchor throughput:\n");
fprintf("  0.1C charge    : %.6f Ah\n",Q01_Ah);
fprintf("  1C charge      : %.6f Ah\n",Q1C_Ah);
fprintf("  1C discharge   : %.6f Ah\n\n",Q1D_Ah);

%% ------------------------------------------------------------------------
% 5. BUILD SOC AXES
% -------------------------------------------------------------------------
P = struct([]);

P(1).name = "CHARGE_0P1C";
P(1).direction = "charge";
P(1).currentClass = "0.1C";
P(1).D = D01;
P(1).Qspan_Ah = Q01_Ah;

P(2).name = "CHARGE_1C";
P(2).direction = "charge";
P(2).currentClass = "1C";
P(2).D = D1C;
P(2).Qspan_Ah = Q1C_Ah;

P(3).name = "DISCHARGE_1C";
P(3).direction = "discharge";
P(3).currentClass = "1C";
P(3).D = D1D;
P(3).Qspan_Ah = Q1D_Ah;

for ip = 1:numel(P)

    if P(ip).direction == "charge"
        qCum = cumtrapz(P(ip).D.t_s,max(P(ip).D.I_A,0))/3600;
        qRemain = qCum(end)-qCum;

        P(ip).SOC_SELF_NORMALIZED = ...
            1-qRemain/P(ip).Qspan_Ah;

        P(ip).SOC_NOMINAL_3P5 = ...
            1-qRemain/cfg.nominalCapacity_Ah;

        P(ip).SOC_FROZEN_QREF = ...
            1-qRemain/cfg.frozenCapacity_Ah;

    else
        qOut = -cumtrapz(P(ip).D.t_s,min(P(ip).D.I_A,0))/3600;

        P(ip).SOC_SELF_NORMALIZED = ...
            1-qOut/P(ip).Qspan_Ah;

        P(ip).SOC_NOMINAL_3P5 = ...
            1-qOut/cfg.nominalCapacity_Ah;

        P(ip).SOC_FROZEN_QREF = ...
            1-qOut/cfg.frozenCapacity_Ah;
    end
end

%% ------------------------------------------------------------------------
% 6. PSEUDO-OCV RECONSTRUCTION
% -------------------------------------------------------------------------
rows = struct([]);
ir = 0;

curveBundle = struct([]);
ic = 0;

for ia = 1:numel(axisNames)

    axisName = axisNames(ia);

    for ip = 1:numel(P)

        soc = get_soc_axis(P(ip),axisName);

        t = P(ip).D.t_s(:);
        I = P(ip).D.I_A(:);
        V = P(ip).D.V_V(:);

        % Safe model segment around all target SOCs.
        if P(ip).direction == "charge"
            startMask = soc >= model.socMin & soc <= min(cfg.targetSOC)-cfg.socBandHalfWidth;
            idxStartCandidates = find(startMask);

            if isempty(idxStartCandidates)
                error('EXT2:B12F:ChargeSafeStart', ...
                    'No charge safe-start candidate for %s / %s.', ...
                    char(P(ip).name),char(axisName));
            end

            idxStart = idxStartCandidates(1);
            idxEndCandidates = find( ...
                soc <= max(cfg.targetSOC)+cfg.socBandHalfWidth & ...
                soc >= model.socMin);

            idxEnd = idxEndCandidates(end);

        else
            startMask = soc <= model.socMax & ...
                soc >= max(cfg.targetSOC)+cfg.socBandHalfWidth;

            idxStartCandidates = find(startMask);

            if isempty(idxStartCandidates)
                error('EXT2:B12F:DischargeSafeStart', ...
                    'No discharge safe-start candidate for %s / %s.', ...
                    char(P(ip).name),char(axisName));
            end

            idxStart = idxStartCandidates(1);

            idxEndCandidates = find( ...
                soc >= min(cfg.targetSOC)-cfg.socBandHalfWidth & ...
                soc <= model.socMax);

            idxEnd = idxEndCandidates(end);
        end

        idx = (idxStart:idxEnd).';

        ts = t(idx);
        Is = I(idx);
        Vs = V(idx);
        zs = soc(idx);

        if any(zs < model.socMin) || any(zs > model.socMax)
            error('EXT2:B12F:ModelSupport', ...
                'SOC leaves frozen LUT support for %s / %s.', ...
                char(P(ip).name),char(axisName));
        end

        OCV = interp1(model.soc,model.ocv,zs,'linear');
        R0 = interp1(model.soc,model.R0,zs,'linear');
        R1 = interp1(model.soc,model.R1,zs,'linear');
        C1 = interp1(model.soc,model.C1,zs,'linear');
        R2 = interp1(model.soc,model.R2,zs,'linear');
        C2 = interp1(model.soc,model.C2,zs,'linear');

        tau1 = R1.*C1;
        tau2 = R2.*C2;

        % At the safe-start points these historical full-profile records
        % have already been under near-constant current for a long time.
        % Use steady-current branch initialization rather than zero.
        v10 = R1(1)*Is(1);
        v20 = R2(1)*Is(1);

        v1 = simulate_rc_branch_variable_init( ...
            ts,Is,R1,tau1,v10);

        v2 = simulate_rc_branch_variable_init( ...
            ts,Is,R2,tau2,v20);

        pseudoDynamic = Vs-R0.*Is-v1-v2;
        pseudoQS = Vs-Is.*(R0+R1+R2);

        ic = ic+1;
        curveBundle(ic).Axis = axisName; %#ok<SAGROW>
        curveBundle(ic).Profile = P(ip).name;
        curveBundle(ic).SOC = zs;
        curveBundle(ic).PseudoOCV_Dynamic_V = pseudoDynamic;
        curveBundle(ic).PseudoOCV_QS_V = pseudoQS;
        curveBundle(ic).MeasuredVoltage_V = Vs;
        curveBundle(ic).Current_A = Is;

        for iz = 1:numel(cfg.targetSOC)

            z0 = cfg.targetSOC(iz);

            mask = ...
                abs(zs-z0) <= cfg.socBandHalfWidth;

            if sum(mask) < 20
                error('EXT2:B12F:TargetWindowSamples', ...
                    'Too few samples for %s / %s at SOC %.0f%%.', ...
                    char(P(ip).name),char(axisName),100*z0);
            end

            frozenOCV = interp1(model.soc,model.ocv,z0,'linear');

            pseudoDynMedian = median(pseudoDynamic(mask));
            pseudoQSMedian = median(pseudoQS(mask));
            measuredMedian = median(Vs(mask));

            meanI = mean(Is(mask));
            stdI = std(Is(mask));

            dynOffset_mV = ...
                (pseudoDynMedian-frozenOCV)*1000;

            qsOffset_mV = ...
                (pseudoQSMedian-frozenOCV)*1000;

            dynVsQS_mV = ...
                (pseudoDynMedian-pseudoQSMedian)*1000;

            ir = ir+1;

            rows(ir).Axis = axisName; %#ok<SAGROW>
            rows(ir).Profile = P(ip).name;
            rows(ir).Direction = P(ip).direction;
            rows(ir).CurrentClass = P(ip).currentClass;
            rows(ir).TargetSOC = z0;
            rows(ir).NSamples = sum(mask);
            rows(ir).MeanCurrent_A = meanI;
            rows(ir).StdCurrent_A = stdI;
            rows(ir).MeasuredVoltageMedian_V = measuredMedian;
            rows(ir).FrozenOCV_V = frozenOCV;
            rows(ir).PseudoOCV_Dynamic_V = pseudoDynMedian;
            rows(ir).PseudoOCV_QS_V = pseudoQSMedian;
            rows(ir).DynamicOffsetFromFrozen_mV = dynOffset_mV;
            rows(ir).QSOffsetFromFrozen_mV = qsOffset_mV;
            rows(ir).DynamicMinusQS_mV = dynVsQS_mV;
        end
    end
end

PseudoOCVSummary = struct2table(rows);

%% ------------------------------------------------------------------------
% 7. PRIMARY SELF-NORMALIZED DIRECTIONAL SUMMARY
% -------------------------------------------------------------------------
Tself = PseudoOCVSummary( ...
    string(PseudoOCVSummary.Axis) == "SELF_NORMALIZED",:);

primaryRows = struct([]);

for iz = 1:numel(cfg.targetSOC)

    z0 = cfg.targetSOC(iz);

    low = get_one_row(Tself,"CHARGE_0P1C",z0);
    chg = get_one_row(Tself,"CHARGE_1C",z0);
    dsg = get_one_row(Tself,"DISCHARGE_1C",z0);

    Drow = B12D(abs(B12D.TargetSOC-z0) < 1e-12,:);

    if height(Drow) ~= 1
        error('EXT2:B12F:B12DSOCLookup', ...
            'Expected one B1-2D row at SOC %.0f%%.',100*z0);
    end

    lowOffset = low.DynamicOffsetFromFrozen_mV;
    chgOffset = chg.DynamicOffsetFromFrozen_mV;
    dsgOffset = dsg.DynamicOffsetFromFrozen_mV;

    gap = ...
        (chg.PseudoOCV_Dynamic_V-dsg.PseudoOCV_Dynamic_V)*1000;

    midpoint = 0.5*( ...
        chg.PseudoOCV_Dynamic_V+dsg.PseudoOCV_Dynamic_V);

    frozenMinusMidpoint_mV = ...
        (chg.FrozenOCV_V-midpoint)*1000;

    lowVs1CCharge_mV = ...
        (low.PseudoOCV_Dynamic_V-chg.PseudoOCV_Dynamic_V)*1000;

    chargeOffsetDifference_mV = ...
        abs(lowOffset-chgOffset);

    b12dCorrection = Drow.SharedVoltageCorrection_mV;

    b12dVsLow_mV = abs(b12dCorrection-lowOffset);
    b12dVs1CCharge_mV = abs(b12dCorrection-chgOffset);

    primaryRows(iz).TargetSOC = z0; %#ok<SAGROW>
    primaryRows(iz).FrozenOCV_V = chg.FrozenOCV_V;
    primaryRows(iz).LowRateChargePseudoOCV_V = ...
        low.PseudoOCV_Dynamic_V;
    primaryRows(iz).OneCChargePseudoOCV_V = ...
        chg.PseudoOCV_Dynamic_V;
    primaryRows(iz).OneCDischargePseudoOCV_V = ...
        dsg.PseudoOCV_Dynamic_V;
    primaryRows(iz).LowRateChargeOffset_mV = lowOffset;
    primaryRows(iz).OneCChargeOffset_mV = chgOffset;
    primaryRows(iz).OneCDischargeOffset_mV = dsgOffset;
    primaryRows(iz).ChargeDischargeGap_mV = gap;
    primaryRows(iz).FrozenMinusChargeDischargeMidpoint_mV = ...
        frozenMinusMidpoint_mV;
    primaryRows(iz).LowRateVsOneCCharge_mV = ...
        lowVs1CCharge_mV;
    primaryRows(iz).AbsChargeOffsetDifference_mV = ...
        chargeOffsetDifference_mV;
    primaryRows(iz).B12D_SharedCorrection_mV = ...
        b12dCorrection;
    primaryRows(iz).B12D_vs_LowRateChargeOffset_mV = ...
        b12dVsLow_mV;
    primaryRows(iz).B12D_vs_OneCChargeOffset_mV = ...
        b12dVs1CCharge_mV;
end

PrimaryDirectionalSummary = struct2table(primaryRows);

%% ------------------------------------------------------------------------
% 8. SOC-AXIS ROBUSTNESS
% -------------------------------------------------------------------------
robustRows = struct([]);
irr = 0;

for ip = 1:3

    pName = P(ip).name;

    for iz = 1:numel(cfg.targetSOC)

        z0 = cfg.targetSOC(iz);

        Rself = get_one_row(PseudoOCVSummary, ...
            pName,z0,"SELF_NORMALIZED");

        Rnom = get_one_row(PseudoOCVSummary, ...
            pName,z0,"NOMINAL_3P5");

        Rfrozen = get_one_row(PseudoOCVSummary, ...
            pName,z0,"FROZEN_QREF");

        irr = irr+1;

        robustRows(irr).Profile = pName; %#ok<SAGROW>
        robustRows(irr).TargetSOC = z0;
        robustRows(irr).SelfOffset_mV = ...
            Rself.DynamicOffsetFromFrozen_mV;
        robustRows(irr).Nominal3p5Offset_mV = ...
            Rnom.DynamicOffsetFromFrozen_mV;
        robustRows(irr).FrozenQrefOffset_mV = ...
            Rfrozen.DynamicOffsetFromFrozen_mV;
        robustRows(irr).SelfVsNominalDelta_mV = ...
            abs(Rself.DynamicOffsetFromFrozen_mV- ...
                Rnom.DynamicOffsetFromFrozen_mV);
        robustRows(irr).SelfVsFrozenQrefDelta_mV = ...
            abs(Rself.DynamicOffsetFromFrozen_mV- ...
                Rfrozen.DynamicOffsetFromFrozen_mV);
    end
end

AxisRobustness = struct2table(robustRows);

%% ------------------------------------------------------------------------
% 9. DESCRIPTIVE CLASSIFICATION
% -------------------------------------------------------------------------
medianLowOffset = ...
    median(PrimaryDirectionalSummary.LowRateChargeOffset_mV);

median1CChargeOffset = ...
    median(PrimaryDirectionalSummary.OneCChargeOffset_mV);

median1CDischargeOffset = ...
    median(PrimaryDirectionalSummary.OneCDischargeOffset_mV);

medianDirectionalGap = ...
    median(PrimaryDirectionalSummary.ChargeDischargeGap_mV);

medianChargeAgreement = ...
    median(PrimaryDirectionalSummary.AbsChargeOffsetDifference_mV);

medianB12DvsLow = ...
    median(PrimaryDirectionalSummary.B12D_vs_LowRateChargeOffset_mV);

medianB12Dvs1CCharge = ...
    median(PrimaryDirectionalSummary.B12D_vs_OneCChargeOffset_mV);

medianDynamicVsQS = ...
    median(abs(PseudoOCVSummary.DynamicMinusQS_mV));

medianSelfNominalAxisDelta = ...
    median(AxisRobustness.SelfVsNominalDelta_mV);

chargeDirectionSupported = ...
    medianLowOffset >= cfg.chargeOffsetMin_mV && ...
    median1CChargeOffset >= cfg.chargeOffsetMin_mV && ...
    medianChargeAgreement <= cfg.chargeAgreementTol_mV && ...
    medianDirectionalGap >= cfg.directionalGapMin_mV && ...
    medianB12DvsLow <= cfg.b12dAgreementTol_mV;

globalOCVOffsetSupported = ...
    medianLowOffset >= cfg.globalOffsetMin_mV && ...
    median1CDischargeOffset >= cfg.globalOffsetMin_mV && ...
    abs(medianDirectionalGap) <= cfg.globalGapMax_mV;

dynamicCorrectionMismatch = ...
    abs(medianLowOffset) < 15 && ...
    median1CChargeOffset >= 25;

if chargeDirectionSupported
    descriptiveClass = ...
        "CHARGE_DIRECTION_OCV_HYSTERESIS_CONSISTENT";
elseif globalOCVOffsetSupported
    descriptiveClass = ...
        "GLOBAL_FROZEN_OCV_BASELINE_OFFSET_CONSISTENT";
elseif dynamicCorrectionMismatch || ...
       medianChargeAgreement > cfg.dynamicMismatchAgreement_mV
    descriptiveClass = ...
        "DYNAMIC_CORRECTION_OR_SOC_AXIS_MISMATCH";
else
    descriptiveClass = ...
        "MIXED_OR_INCONCLUSIVE_OCV_HYSTERESIS_EVIDENCE";
end

dynamicVsQSPass = ...
    medianDynamicVsQS <= cfg.maxDynamicVsQS_mV;

axisRobustDescriptive = ...
    medianSelfNominalAxisDelta <= cfg.axisRobustnessTol_mV;

%% ------------------------------------------------------------------------
% 10. CAPACITY / ANCHOR SUMMARY
% -------------------------------------------------------------------------
CapacityAxisSummary = table( ...
    ["0.1C charge";"1C charge";"1C discharge"], ...
    [Q01_Ah;Q1C_Ah;Q1D_Ah], ...
    [D01.V_V(end);D1C.V_V(end);D1D.V_V(end)], ...
    [D01.I_A(end);D1C.I_A(end);D1D.I_A(end)], ...
    'VariableNames', { ...
    'Profile','AnchorThroughput_Ah','AnchorVoltage_V','AnchorCurrent_A'});

%% ------------------------------------------------------------------------
% 11. SAVE NUMERICAL RESULTS
% -------------------------------------------------------------------------
summaryFile = fullfile( ...
    resultsDir,'EXT2_B1_2F_pseudo_OCV_summary_v1.csv');

primaryFile = fullfile( ...
    resultsDir,'EXT2_B1_2F_primary_directional_summary_v1.csv');

axisFile = fullfile( ...
    resultsDir,'EXT2_B1_2F_axis_robustness_v1.csv');

capacityFile = fullfile( ...
    resultsDir,'EXT2_B1_2F_capacity_axis_summary_v1.csv');

writetable(PseudoOCVSummary,summaryFile);
writetable(PrimaryDirectionalSummary,primaryFile);
writetable(AxisRobustness,axisFile);
writetable(CapacityAxisSummary,capacityFile);

curveFile = fullfile( ...
    resultsDir,'EXT2_B1_2F_curve_bundle_v1.mat');

save(curveFile,'curveBundle','cfg','-v7.3');

%% ------------------------------------------------------------------------
% 12. FIGURE — SELF-NORMALIZED PSEUDO-OCV
% -------------------------------------------------------------------------
f = figure('Name','EXT2-B1-2F pseudo OCV','Visible','off');

hold on;

% Frozen OCV.
plot(100*model.soc,model.ocv,'LineWidth',1.8);

labels = {"Frozen OCV","0.1C charge pseudo-OCV", ...
    "1C charge pseudo-OCV","1C discharge pseudo-OCV"};

for ip = 1:3

    idxCurve = find(arrayfun(@(x) ...
        x.Axis == "SELF_NORMALIZED" && ...
        x.Profile == P(ip).name,curveBundle),1);

    Cb = curveBundle(idxCurve);

    plot(100*Cb.SOC,Cb.PseudoOCV_Dynamic_V,'LineWidth',1.1);
end

xlim([17 85]);
xlabel('SOC [%]');
ylabel('Voltage [V]');
title('EXT2-B1-2F | Frozen OCV vs direction-corrected pseudo-OCV');
legend(labels,'Location','best');
grid on;

figureFile = fullfile( ...
    resultsDir,'EXT2_B1_2F_pseudo_OCV_curves_v1.png');

try
    exportgraphics(f,figureFile,'Resolution',180);
catch ME
    warning('EXT2:B12F:PlotExport', ...
        'Could not export pseudo-OCV figure: %s',ME.message);
end

close(f);

%% ------------------------------------------------------------------------
% 13. REPORT
% -------------------------------------------------------------------------
reportFile = fullfile( ...
    resultsDir,'EXT2_B1_2F_OCV_hysteresis_report_v1.txt');

fid = fopen(reportFile,'w');

if fid < 0
    error('EXT2:B12F:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-B1-2F OCV/SOC Baseline & Charge-Hysteresis Audit v1\n");
fprintf(fid,"=============================================================\n\n");

fprintf(fid,"Diagnostic only. No parameter adaptation.\n\n");

fprintf(fid,"Source throughputs:\n");
fprintf(fid,"0.1C charge  = %.9f Ah\n",Q01_Ah);
fprintf(fid,"1C charge    = %.9f Ah\n",Q1C_Ah);
fprintf(fid,"1C discharge = %.9f Ah\n\n",Q1D_Ah);

fprintf(fid,"Primary SELF_NORMALIZED directional summary:\n");

for k = 1:height(PrimaryDirectionalSummary)
    fprintf(fid, ...
        "SOC %.0f%% | frozen %.6f V | 0.1C chg %.6f (%+.2f mV) | 1C chg %.6f (%+.2f mV) | 1C dsg %.6f (%+.2f mV) | chg-dsg gap %+.2f mV | B1-2D correction %.2f mV\n", ...
        100*PrimaryDirectionalSummary.TargetSOC(k), ...
        PrimaryDirectionalSummary.FrozenOCV_V(k), ...
        PrimaryDirectionalSummary.LowRateChargePseudoOCV_V(k), ...
        PrimaryDirectionalSummary.LowRateChargeOffset_mV(k), ...
        PrimaryDirectionalSummary.OneCChargePseudoOCV_V(k), ...
        PrimaryDirectionalSummary.OneCChargeOffset_mV(k), ...
        PrimaryDirectionalSummary.OneCDischargePseudoOCV_V(k), ...
        PrimaryDirectionalSummary.OneCDischargeOffset_mV(k), ...
        PrimaryDirectionalSummary.ChargeDischargeGap_mV(k), ...
        PrimaryDirectionalSummary.B12D_SharedCorrection_mV(k));
end

fprintf(fid,"\nAggregate:\n");
fprintf(fid,"Median 0.1C charge offset          = %+8.3f mV\n",medianLowOffset);
fprintf(fid,"Median 1C charge offset            = %+8.3f mV\n",median1CChargeOffset);
fprintf(fid,"Median 1C discharge offset         = %+8.3f mV\n",median1CDischargeOffset);
fprintf(fid,"Median charge-discharge gap        = %+8.3f mV\n",medianDirectionalGap);
fprintf(fid,"Median |0.1C vs 1C charge|         = %.3f mV\n",medianChargeAgreement);
fprintf(fid,"Median |B1-2D correction - 0.1C|   = %.3f mV\n",medianB12DvsLow);
fprintf(fid,"Median |B1-2D correction - 1C chg| = %.3f mV\n",medianB12Dvs1CCharge);
fprintf(fid,"Median |dynamic - quasi-steady|    = %.3f mV\n",medianDynamicVsQS);
fprintf(fid,"Median SELF vs nominal-axis delta  = %.3f mV\n",medianSelfNominalAxisDelta);
fprintf(fid,"\n");

fprintf(fid,"Dynamic-vs-QS consistency          = %s\n", ...
    pass_text(dynamicVsQSPass));
fprintf(fid,"SELF-vs-nominal axis robustness    = %s\n", ...
    pass_text(axisRobustDescriptive));
fprintf(fid,"Descriptive class                  = %s\n", ...
    descriptiveClass);

fprintf(fid,"\nInterpretation boundary:\n");
fprintf(fid,"The 1C charge/discharge pseudo-OCV gap is direction-sensitive model-corrected evidence, not a direct equilibrium hysteresis measurement.\n");
fprintf(fid,"B1-2B remains FAIL and B2 remains STOP.\n");
fclose(fid);

%% ------------------------------------------------------------------------
% 14. PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);

[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetAuditFile = fullfile( ...
    resultsDir,'EXT2_B1_2F_protected_asset_audit_v1.csv');

writetable(AssetAudit,assetAuditFile);

if ~assetsUnchanged
    error('EXT2:B12F:ProtectedAssetChanged', ...
        'A protected frozen asset changed during B1-2F. STOP.');
end

%% ------------------------------------------------------------------------
% 15. AUTODOC
% -------------------------------------------------------------------------
autodoc_B12F( ...
    protocolDir,auditDir,handoffDir, ...
    Q01_Ah,Q1C_Ah,Q1D_Ah, ...
    PrimaryDirectionalSummary, ...
    medianLowOffset,median1CChargeOffset, ...
    median1CDischargeOffset,medianDirectionalGap, ...
    medianChargeAgreement,medianB12DvsLow, ...
    medianDynamicVsQS,medianSelfNominalAxisDelta, ...
    descriptiveClass,dynamicVsQSPass, ...
    axisRobustDescriptive,assetsUnchanged);

%% ------------------------------------------------------------------------
% 16. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-B1-2F COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Source throughputs:\n");
fprintf("  0.1C charge                   : %.6f Ah\n",Q01_Ah);
fprintf("  1C charge                     : %.6f Ah\n",Q1C_Ah);
fprintf("  1C discharge                  : %.6f Ah\n\n",Q1D_Ah);

fprintf("Primary SELF_NORMALIZED pseudo-OCV:\n");

for k = 1:height(PrimaryDirectionalSummary)
    fprintf("  SOC %.0f%% | frozen %.5f V | 0.1C chg %+7.2f mV | 1C chg %+7.2f mV | 1C dsg %+7.2f mV | gap %+7.2f mV | B1-2D +%.2f mV\n", ...
        100*PrimaryDirectionalSummary.TargetSOC(k), ...
        PrimaryDirectionalSummary.FrozenOCV_V(k), ...
        PrimaryDirectionalSummary.LowRateChargeOffset_mV(k), ...
        PrimaryDirectionalSummary.OneCChargeOffset_mV(k), ...
        PrimaryDirectionalSummary.OneCDischargeOffset_mV(k), ...
        PrimaryDirectionalSummary.ChargeDischargeGap_mV(k), ...
        PrimaryDirectionalSummary.B12D_SharedCorrection_mV(k));
end

fprintf("\nAggregate diagnostics:\n");
fprintf("  Median 0.1C charge offset          : %+7.3f mV\n",medianLowOffset);
fprintf("  Median 1C charge offset            : %+7.3f mV\n",median1CChargeOffset);
fprintf("  Median 1C discharge offset         : %+7.3f mV\n",median1CDischargeOffset);
fprintf("  Median charge-discharge gap        : %+7.3f mV\n",medianDirectionalGap);
fprintf("  Median |0.1C vs 1C charge|         : %.3f mV\n",medianChargeAgreement);
fprintf("  Median |B1-2D correction - 0.1C|   : %.3f mV\n",medianB12DvsLow);
fprintf("  Median |dynamic - quasi-steady|    : %.3f mV\n",medianDynamicVsQS);
fprintf("  Median SELF vs nominal-axis delta  : %.3f mV\n",medianSelfNominalAxisDelta);
fprintf("  Dynamic-vs-QS consistency          : %s\n",pass_text(dynamicVsQSPass));
fprintf("  SELF-vs-nominal axis robustness    : %s\n",pass_text(axisRobustDescriptive));

fprintf("\nDescriptive class:\n  %s\n",descriptiveClass);
fprintf("Protected assets unchanged           : %s\n",pass_text(assetsUnchanged));
fprintf("AUTODOC updated                       : PASS\n");
fprintf("B1-2B remains FAIL / B2 remains STOP.\n\n");

fprintf("Results:\n%s\n",resultsDir);
fprintf("Docs:\n%s\n\n",docsDir);


%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function row = get_one_row(T,profileName,targetSOC,varargin)

mask = ...
    string(T.Profile) == string(profileName) & ...
    abs(T.TargetSOC-targetSOC) < 1e-12;

if ~isempty(varargin)
    axisName = string(varargin{1});
    mask = mask & string(T.Axis) == axisName;
end

row = T(mask,:);

if height(row) ~= 1
    error('EXT2:B12F:RowLookup', ...
        'Expected one row for %s at SOC %.0f%%.', ...
        char(string(profileName)),100*targetSOC);
end
end


function soc = get_soc_axis(P,axisName)

switch char(axisName)
    case 'SELF_NORMALIZED'
        soc = P.SOC_SELF_NORMALIZED;
    case 'NOMINAL_3P5'
        soc = P.SOC_NOMINAL_3P5;
    case 'FROZEN_QREF'
        soc = P.SOC_FROZEN_QREF;
    otherwise
        error('EXT2:B12F:UnknownSOCAxis', ...
            'Unknown SOC axis: %s',char(axisName));
end

soc = soc(:);
end


function idx = find_terminal_anchor_charge(D,cfg)

tailStart = max(D.t_s(1),D.t_s(end)-cfg.anchorSearchTail_s);

cand = find( ...
    D.t_s >= tailStart & ...
    abs(D.V_V-cfg.fullVoltage_V) <= 2*cfg.fullVoltageTol_V & ...
    D.I_A >= 0 & D.I_A <= 0.10);

if isempty(cand)
    error('EXT2:B12F:ChargeAnchorCandidate', ...
        'No terminal charge anchor candidate found.');
end

score = ...
    abs(D.V_V(cand)-cfg.fullVoltage_V)/cfg.fullVoltageTol_V + ...
    abs(D.I_A(cand)-cfg.fullCurrent_A)/cfg.fullCurrentTol_A;

[~,j] = min(score);
idx = cand(j);

if abs(D.V_V(idx)-cfg.fullVoltage_V) > cfg.fullVoltageTol_V || ...
   abs(D.I_A(idx)-cfg.fullCurrent_A) > cfg.fullCurrentTol_A
    error('EXT2:B12F:ChargeAnchorFail', ...
        'Terminal charge anchor failed strict 4.2 V / 50 mA check.');
end
end


function idx = find_terminal_anchor_discharge(D,cfg)

tailStart = max(D.t_s(1),D.t_s(end)-cfg.anchorSearchTail_s);

cand = find( ...
    D.t_s >= tailStart & ...
    abs(D.V_V-cfg.emptyVoltage_V) <= 2*cfg.emptyVoltageTol_V & ...
    D.I_A <= 0 & D.I_A >= -0.10);

if isempty(cand)
    error('EXT2:B12F:DischargeAnchorCandidate', ...
        'No terminal discharge anchor candidate found.');
end

score = ...
    abs(D.V_V(cand)-cfg.emptyVoltage_V)/cfg.emptyVoltageTol_V + ...
    abs(D.I_A(cand)-cfg.emptyCurrent_A)/cfg.emptyCurrentTol_A;

[~,j] = min(score);
idx = cand(j);

if abs(D.V_V(idx)-cfg.emptyVoltage_V) > cfg.emptyVoltageTol_V || ...
   abs(D.I_A(idx)-cfg.emptyCurrent_A) > cfg.emptyCurrentTol_A
    error('EXT2:B12F:DischargeAnchorFail', ...
        'Terminal discharge anchor failed strict 2.5 V / 25 mA check.');
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
    error('EXT2:B12F:RCVectorLength', ...
        't/I/R/tau vectors must have equal length.');
end

v = zeros(N,1);
v(1) = v0;

for k = 1:N-1

    dt = t(k+1)-t(k);

    if dt <= 0
        error('EXT2:B12F:NonPositiveDt', ...
            'Non-positive dt in RC simulation.');
    end

    a = exp(-dt/taubase(k));
    b = Rbase(k)*(1-a);

    v(k+1) = a*v(k)+b*I(k);
end
end


function D = load_ngu_uiv_full(filePath)

txt = fileread(filePath);
lines = splitlines(string(txt));

if isempty(lines)
    error('EXT2:B12F:EmptyProfile', ...
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
    error('EXT2:B12F:NGUHeaderMissing', ...
        'NGU header not found: %s',char(filePath));
end

headers = split(lines(headerIdx),',');
headers = strtrim(erase(headers,'"'));
headers = erase(headers,string(char(65279)));

iT = find(strcmpi(headers,'Timestamp'),1);
iV = find(strcmpi(headers,'U1[V]'),1);
iI = find(strcmpi(headers,'I1[A]'),1);

if isempty(iT) || isempty(iV) || isempty(iI)
    error('EXT2:B12F:NGUColumnsMissing', ...
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
    error('EXT2:B12F:NoValidData', ...
        'Too few valid rows: %s',char(filePath));
end

t = unwrap_elapsed_time(tRaw);
t = t-t(1);

if any(diff(t) <= 0)
    error('EXT2:B12F:NonMonotonicTime', ...
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


function assert_sha(filePath,expectedSHA,label)

actual = sha256_file(filePath);

if ~strcmpi(actual,char(expectedSHA))
    error('EXT2:B12F:SourceHashMismatch', ...
        '%s SHA-256 mismatch. STOP.',char(string(label)));
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
    error('EXT2:B12F:HashOpenFailed', ...
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

    error('EXT2:B12F:HashFailed', ...
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
    error('EXT2:B12F:AssetSnapshotMismatch', ...
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


function autodoc_B12F( ...
    protocolDir,auditDir,handoffDir, ...
    Q01,Q1C,Q1D,Primary, ...
    medLow,medCharge,medDischarge,medGap, ...
    medChargeAgree,medB12DLow,medDynQS,medAxis, ...
    descriptiveClass,dynQSPass,axisPass,assetsUnchanged)

% ---------------------------------------------------------------------
% Protocol
% ---------------------------------------------------------------------
protocolPath = fullfile( ...
    protocolDir,'EXT2_B1_2F_PROTOCOL_v1.md');

protocol = {
'# EXT2-B1-2F Protocol v1 — OCV/SOC Baseline & Charge-Hysteresis Audit'
''
'## Purpose'
''
'Test whether the common real-voltage baseline error is consistent with charge-direction OCV/hysteresis behavior, a global frozen OCV-LUT offset, or residual dynamic-correction mismatch.'
''
'No R2/tau2 fitting, no online adaptation, no frozen-model modification and no B1-2B grid expansion are allowed.'
''
'## Primary sources'
''
'- exact historical 0.1C DC charge'
'- exact historical 1C full charge'
'- exact historical 1C full discharge'
''
'## SOC bases'
''
'- primary: self-normalized measured terminal-anchor throughput'
'- sensitivity: nominal 3.500 Ah'
'- sensitivity: frozen qRef'
''
'## Pseudo-OCV'
''
'`OCV_pseudo = Vmeas - R0*I - v1 - v2`'
''
'Frozen SOC-dependent electrical parameters are used only to remove modeled polarization. A quasi-steady correction is reported independently.'
''
'## Target SOC'
''
'30%, 50%, 70%, using +/-1 percentage point local bands.'
''
'## Claim boundary'
''
'The 1C charge/discharge pseudo-OCV gap is not a direct equilibrium hysteresis measurement. It is finite-rate direction-sensitive evidence after frozen-ECM correction.'
''
'B1-2B remains FAIL and B2 remains STOP.'
};

write_text_lines(protocolPath,protocol);

% ---------------------------------------------------------------------
% Audit
% ---------------------------------------------------------------------
auditPath = fullfile( ...
    auditDir,'EXT2_B1_2F_EXECUTION_AUDIT_v1.md');

audit = {
'# EXT2-B1-2F Execution Audit v1'
''
'## Status'
''
'`CLOSED / DIAGNOSTIC COMPLETE`'
''
'## Source throughput'
''
sprintf('- 0.1C charge: **%.6f Ah**',Q01)
sprintf('- 1C charge: **%.6f Ah**',Q1C)
sprintf('- 1C discharge: **%.6f Ah**',Q1D)
''
'## Primary self-normalized diagnostics'
''
sprintf('- median 0.1C charge pseudo-OCV offset: **%+.3f mV**',medLow)
sprintf('- median 1C charge pseudo-OCV offset: **%+.3f mV**',medCharge)
sprintf('- median 1C discharge pseudo-OCV offset: **%+.3f mV**',medDischarge)
sprintf('- median charge-discharge directional gap: **%+.3f mV**',medGap)
sprintf('- median |0.1C vs 1C charge|: **%.3f mV**',medChargeAgree)
sprintf('- median |B1-2D shared correction - 0.1C offset|: **%.3f mV**',medB12DLow)
sprintf('- median |dynamic - quasi-steady correction|: **%.3f mV**',medDynQS)
sprintf('- median SELF vs nominal-axis delta: **%.3f mV**',medAxis)
''
sprintf('- dynamic-vs-QS consistency: **%s**',pass_text(dynQSPass))
sprintf('- self-vs-nominal axis robustness: **%s**',pass_text(axisPass))
sprintf('- protected frozen assets unchanged: **%s**',pass_text(assetsUnchanged))
''
'## Descriptive class'
''
['`' char(descriptiveClass) '`']
''
'## Per-SOC primary table'
''
'| SOC | 0.1C charge offset | 1C charge offset | 1C discharge offset | charge-discharge gap | B1-2D correction |'
'|---:|---:|---:|---:|---:|---:|'
};

for k = 1:height(Primary)

    audit{end+1} = sprintf( ...
        '| %.0f%% | %+.2f mV | %+.2f mV | %+.2f mV | %+.2f mV | %.2f mV |', ...
        100*Primary.TargetSOC(k), ...
        Primary.LowRateChargeOffset_mV(k), ...
        Primary.OneCChargeOffset_mV(k), ...
        Primary.OneCDischargeOffset_mV(k), ...
        Primary.ChargeDischargeGap_mV(k), ...
        Primary.B12D_SharedCorrection_mV(k)); %#ok<AGROW>
end

audit{end+1} = '';
audit{end+1} = 'B1-2B remains FAIL / B2 remains STOP.';

write_text_lines(auditPath,audit);

% ---------------------------------------------------------------------
% Current handoff
% ---------------------------------------------------------------------
handoffPath = fullfile( ...
    handoffDir,'EXT2_CURRENT_HANDOFF.md');

handoff = {
'# EXT2 Current Handoff'
''
'## Canonical paths'
''
'- work package: `<WORK_PACKAGE_ROOT>`'
'- EXT2: `<EXT2_WORK_ROOT>`'
'- results: `...\EXT2_dynamic_parameter_identifiability\results`'
'- local Git reference: `<REPO_ROOT>`'
'- GitHub remote: `https://github.com/jiaxingLu/MJ1_2RC_EKF_SOC_Estimation`'
'- historical NGU root: `<LOCAL_DATA_ROOT>\raw_original`'
''
'## Stage status'
''
'- EXT2-A1/A1B/A2/A2B: CLOSED'
'- EXT2-B1-1: CLOSED / PASS'
'- EXT2-B1-2A: CLOSED / PASS'
'- EXT2-B1-2B: CLOSED / FAIL'
'- EXT2-B1-2C: CLOSED / baseline-bias dominant'
'- EXT2-B1-2D: CLOSED / qRef-SOC sensitivity strongly reduces baseline'
'- EXT2-B1-2E: CLOSED / effective qRef exceeds independent capacity references'
'- EXT2-B1-2F: CLOSED / DIAGNOSTIC COMPLETE'
''
'## B1-2F result'
''
sprintf('- 0.1C charge throughput: %.6f Ah',Q01)
sprintf('- 1C charge throughput: %.6f Ah',Q1C)
sprintf('- 1C discharge throughput: %.6f Ah',Q1D)
sprintf('- median 0.1C charge pseudo-OCV offset: %+.3f mV',medLow)
sprintf('- median 1C charge pseudo-OCV offset: %+.3f mV',medCharge)
sprintf('- median 1C discharge pseudo-OCV offset: %+.3f mV',medDischarge)
sprintf('- median charge-discharge gap: %+.3f mV',medGap)
sprintf('- descriptive class: `%s`',descriptiveClass)
''
'## Frozen decision'
''
'B1-2B remains FAIL. R2/tau2 online adaptation remains STOPPED.'
''
'## Next-step rule'
''
'Use the B1-2F classification to choose the next diagnostic. Do not expand the failed B1-2B R2/tau2 grid.'
};

write_text_lines(handoffPath,handoff);

% ---------------------------------------------------------------------
% Continuity current
% ---------------------------------------------------------------------
continuityPath = fullfile( ...
    handoffDir,'EXT2_PROJECT_CONTINUITY_CURRENT.md');

continuity = {
'# EXT2 Project Continuity — CURRENT'
''
'## Code structure'
''
'header -> PATHS -> frozen-input preflight -> compatibility/schema checks -> exact source identity -> main analysis -> results -> protected-asset SHA audit -> AUTODOC -> decision/claim boundary -> local functions.'
''
'## Directory structure'
''
'```text'
'EXT2_dynamic_parameter_identifiability/'
'├─ *.m'
'├─ results/'
'└─ docs/'
'   ├─ protocols/'
'   ├─ audits/'
'   └─ handoff/'
'```'
''
'## Current evidence chain'
''
'- B1-1 synthetic R2/tau2 recoverability: PASS'
'- B1-2A SOC/state readiness: PASS'
'- B1-2B real-voltage target consistency: FAIL'
'- B1-2C: baseline bias dominant'
'- B1-2D: SOC-axis/qRef shift strongly reduces baseline'
'- B1-2E: voltage-optimal effective qRef lacks independent physical-capacity support'
sprintf('- B1-2F: %s',descriptiveClass)
''
'## Frozen boundary'
''
'Do not modify frozen MJ1 v0.2 EKF, Bayesian R0 v1.0, EXT1 K4, frozen Simulink assets or released history.'
''
'## AUTODOC'
''
'Current RUN scripts automatically update stage protocol, execution audit and current handoff after successful completion.'
};

write_text_lines(continuityPath,continuity);
end


function write_text_lines(filePath,lines)

fid = fopen(filePath,'w','n','UTF-8');

if fid < 0
    error('EXT2:B12F:DocWriteFailed', ...
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
