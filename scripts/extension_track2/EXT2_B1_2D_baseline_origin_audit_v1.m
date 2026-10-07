% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_B1_2D_baseline_origin_audit_v1.m
% MJ1 2RC-EKF EXT2-B1
% B1-2D Common-Mode Baseline Origin Audit v1
%
% PURPOSE
%   Follow B1-2C BASELINE_BIAS_DOMINANT evidence and determine whether the
%   ~30-40 mV real-voltage error is:
%     (a) strongly common-mode across current amplitude/frequency,
%     (b) plausibly removable by qRef/SOC-trajectory uncertainty alone,
%     (c) weakly or strongly current-proportional.
%
% THIS IS DIAGNOSTIC ONLY.
%   - No R2/tau2 fitting.
%   - No online adaptation.
%   - No frozen-model modification.
%   - No expansion of the failed B1-2B R2/tau2 search grid.
%
% INPUTS
%   results/EXT2_B1_2A_run_bundle_v1.mat
%   results/EXT2_B1_2C_residual_attribution_v1_1.csv
%
% OUTPUTS
%   All outputs are written only to EXT2/results.
%
% DIAGNOSTIC COMPONENTS
%   1) Common-mode residual bias at SOC 30/50/70 across all 6 profiles.
%   2) Bias dependence on mean charging current (R0-like screening).
%   3) Frozen-OCV slope and equivalent SOC shift needed to explain the
%      common bias if it were purely an SOC/OCV mapping error.
%   4) Global qRef scale sensitivity at the SAME physical time windows:
%        qRef_scale = 0.90 : 0.002 : 1.10
%      SOC is recomputed backwards from the same terminal SOC=1 anchor and
%      the full frozen nominal 2RC model is replayed.
%
% IMPORTANT INTERPRETATION
%   The qRef scan is a sensitivity audit, not parameter identification.
%   If the best qRef scale reaches the scan boundary, do NOT expand the
%   range automatically. That means qRef uncertainty alone is not supported
%   as a clean explanation within this diagnostic range.
%
% MATLAB compatibility
%   Base MATLAB only; no Statistics/Econometrics Toolbox dependency.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-2D | Common-Mode Baseline Origin Audit v1\n");
fprintf(" B1-2C follow-up | qRef/SOC/current screening | No adaptation\n");
fprintf("============================================================\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));

if strlength(scriptDir) == 0
    error('EXT2:B12D:RunAsFile', ...
        'Run this script from its saved .m file.');
end

ext2Dir = scriptDir;
resultsDir = fullfile(ext2Dir,'results');

if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end

expectedExt2Name = "EXT2_dynamic_parameter_identifiability";
[~,actualExt2Name] = fileparts(ext2Dir);

if ~strcmpi(string(actualExt2Name),expectedExt2Name)
    error('EXT2:B12D:WrongFolder', ...
        'This script must live inside %s. Current folder: %s', ...
        char(expectedExt2Name),char(ext2Dir));
end

cfg.repoRoot = ...
    "<REPO_ROOT>";
cfg.githubRemote = ...
    "https://github.com/jiaxingLu/MJ1_2RC_EKF_SOC_Estimation";

repoMatlab = fullfile(cfg.repoRoot,'matlab');
modelFile = fullfile(cfg.repoRoot,'data','mj1_v02_model.mat');

b12aFile = fullfile(resultsDir,'EXT2_B1_2A_run_bundle_v1.mat');
b12cFile = fullfile(resultsDir,'EXT2_B1_2C_residual_attribution_v1_1.csv');

required = { ...
    modelFile, ...
    b12aFile, ...
    b12cFile, ...
    fullfile(repoMatlab,'mj1_load_model.m')};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:B12D:MissingInput', ...
            'Required input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

A = load(b12aFile);
C = readtable(b12cFile);

requiredA = {'profileData','WindowSummary','overallPass'};
missingA = requiredA(~cellfun(@(f) isfield(A,f),requiredA));

if ~isempty(missingA)
    error('EXT2:B12D:B12ABundleContract', ...
        'B1-2A bundle missing: %s',strjoin(missingA,', '));
end

if ~logical(A.overallPass)
    error('EXT2:B12D:B12ANotPassed', ...
        'B1-2A must PASS before B1-2D.');
end

requiredC = { ...
    'CaseID','Band','AmplitudeGroup','TargetSOC', ...
    'NominalAbsoluteRMSE_mV','NominalCenteredRMSE_mV', ...
    'NominalResidualBias_mV','BiasMSEPercent', ...
    'EquivalentACResistanceCorrection_mOhm'};

missingC = setdiff(requiredC,C.Properties.VariableNames);

if ~isempty(missingC)
    error('EXT2:B12D:B12CContract', ...
        'B1-2C residual table missing variable(s): %s', ...
        strjoin(missingC,', '));
end

if height(C) ~= 18
    error('EXT2:B12D:B12CRowCount', ...
        'Expected 18 B1-2C residual rows; found %d.',height(C));
end

profileData = A.profileData;
WindowSummary = A.WindowSummary;

fprintf("EXT2 work folder : %s\n",ext2Dir);
fprintf("Results only     : %s\n",resultsDir);
fprintf("Local Git repo   : %s\n",cfg.repoRoot);
fprintf("Frozen model     : %s\n",modelFile);
fprintf("B1-2A status     : PASS\n");
fprintf("B1-2C rows       : 18\n\n");

%% ------------------------------------------------------------------------
% 1. PROTECTED-ASSET AUDIT
% -------------------------------------------------------------------------
protectedRel = { ...
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
% 2. CONFIGURATION
% -------------------------------------------------------------------------
cfg.qRefScaleGrid = (0.90:0.002:1.10).';
cfg.qRefBoundaryMargin = 0.002;

% Same physical B1-2A windows are retained during the qRef sensitivity scan.
cfg.minWarmupTauMultiple = 15;

% Descriptive common-mode screen only; not an adaptation gate.
cfg.commonModeStd_mV = 5;
cfg.commonModeRange_mV = 10;

%% ------------------------------------------------------------------------
% 3. ADD MEAN CURRENT TO THE B1-2C WINDOW TABLE
% -------------------------------------------------------------------------
MeanCurrent_A = nan(height(C),1);
CurrentRMSCentered_A = nan(height(C),1);

for r = 1:height(C)

    cid = string(C.CaseID(r));
    socTarget = C.TargetSOC(r);

    ip = find(arrayfun(@(p) p.case_id == cid,profileData),1);

    if isempty(ip)
        error('EXT2:B12D:ProfileLookup', ...
            'Could not find profileData for %s.',char(cid));
    end

    P = profileData(ip);

    W = WindowSummary( ...
        WindowSummary.CaseID == cid & ...
        abs(WindowSummary.TargetSOC-socTarget) < 1e-12,:);

    if height(W) ~= 1
        error('EXT2:B12D:WindowLookup', ...
            'Expected one window for %s SOC %.0f%%.', ...
            char(cid),100*socTarget);
    end

    mask = ...
        P.t_s >= W.WindowStart_s-1e-9 & ...
        P.t_s <= W.WindowEnd_s+1e-9;

    Iw = P.I_A(mask);

    MeanCurrent_A(r) = mean(Iw);
    CurrentRMSCentered_A(r) = ...
        sqrt(mean((Iw-mean(Iw)).^2));
end

C.MeanCurrent_A = MeanCurrent_A;
C.CurrentRMSCentered_A = CurrentRMSCentered_A;

%% ------------------------------------------------------------------------
% 4. COMMON-MODE BIAS BY SOC
% -------------------------------------------------------------------------
socTargets = sort(unique(C.TargetSOC));
commonRows = struct([]);

for iz = 1:numel(socTargets)

    z = socTargets(iz);
    T = C(abs(C.TargetSOC-z) < 1e-12,:);

    if height(T) ~= 6
        error('EXT2:B12D:SOCGroupCount', ...
            'Expected six profiles at SOC %.0f%%.',100*z);
    end

    bias = T.NominalResidualBias_mV;
    Imean = T.MeanCurrent_A;

    % bias_mV = intercept_mV + slope_mV_per_A * Imean
    X = [ones(height(T),1),Imean];
    beta = X\bias;

    predicted = X*beta;
    residual = bias-predicted;
    rmseCurrentModel = sqrt(mean(residual.^2));

    biasMean = mean(bias);
    biasStd = std(bias);
    biasRange = max(bias)-min(bias);

    % Correction required by the frozen model is -mean residual bias.
    sharedCorrection_mV = -biasMean;

    % Local frozen OCV slope dV/dSOC.
    hSoc = 0.002;
    zLo = max(model.socMin,z-hSoc);
    zHi = min(model.socMax,z+hSoc);

    ocvLo = interp1(model.soc,model.ocv,zLo,'linear');
    ocvHi = interp1(model.soc,model.ocv,zHi,'linear');
    dOCVdSOC_V_per_frac = (ocvHi-ocvLo)/(zHi-zLo);

    if abs(dOCVdSOC_V_per_frac) > 1e-9
        equivalentSOCShift_frac = ...
            (sharedCorrection_mV/1000)/dOCVdSOC_V_per_frac;
    else
        equivalentSOCShift_frac = NaN;
    end

    commonModePass = ...
        biasStd <= cfg.commonModeStd_mV && ...
        biasRange <= cfg.commonModeRange_mV;

    commonRows(iz).TargetSOC = z; %#ok<SAGROW>
    commonRows(iz).MeanResidualBias_mV = biasMean;
    commonRows(iz).StdResidualBias_mV = biasStd;
    commonRows(iz).RangeResidualBias_mV = biasRange;
    commonRows(iz).SharedVoltageCorrection_mV = sharedCorrection_mV;
    commonRows(iz).MeanCurrentMin_A = min(Imean);
    commonRows(iz).MeanCurrentMax_A = max(Imean);
    commonRows(iz).BiasVsCurrentSlope_mOhm = beta(2);
    commonRows(iz).BiasVsCurrentIntercept_mV = beta(1);
    commonRows(iz).BiasVsCurrentRegressionRMSE_mV = rmseCurrentModel;
    commonRows(iz).OCVSlope_V_per_SOCfraction = dOCVdSOC_V_per_frac;
    commonRows(iz).EquivalentSOCShift_pp = ...
        100*equivalentSOCShift_frac;
    commonRows(iz).CommonModeDescriptivePass = commonModePass;
end

CommonModeSummary = struct2table(commonRows);

%% ------------------------------------------------------------------------
% 5. GROUP / BAND BIAS SUMMARY
% -------------------------------------------------------------------------
groupRows = struct([]);
igrow = 0;

groupKeys = ["A","B","DEV"];

for ig = 1:numel(groupKeys)
    mask = startsWith(string(C.CaseID),groupKeys(ig)+"_");

    T = C(mask,:);

    igrow = igrow+1;
    groupRows(igrow).Category = "AmplitudeGroup"; %#ok<SAGROW>
    groupRows(igrow).Level = groupKeys(ig);
    groupRows(igrow).N = height(T);
    groupRows(igrow).MeanBias_mV = mean(T.NominalResidualBias_mV);
    groupRows(igrow).StdBias_mV = std(T.NominalResidualBias_mV);
    groupRows(igrow).MeanCurrent_A = mean(T.MeanCurrent_A);
end

bandKeys = ["MID","SLOW"];

for ib = 1:numel(bandKeys)
    T = C(string(C.Band) == bandKeys(ib),:);

    igrow = igrow+1;
    groupRows(igrow).Category = "Band";
    groupRows(igrow).Level = bandKeys(ib);
    groupRows(igrow).N = height(T);
    groupRows(igrow).MeanBias_mV = mean(T.NominalResidualBias_mV);
    groupRows(igrow).StdBias_mV = std(T.NominalResidualBias_mV);
    groupRows(igrow).MeanCurrent_A = mean(T.MeanCurrent_A);
end

GroupBiasSummary = struct2table(groupRows);

%% ------------------------------------------------------------------------
% 6. GLOBAL qRef / SOC-TRAJECTORY SENSITIVITY SCAN
%
% Same physical time windows are retained.
% Terminal anchor remains SOC=1.
% Only the qRef used in backward Coulomb counting is scaled.
% Frozen ECM parameters are then evaluated on the resulting SOC trajectory.
% -------------------------------------------------------------------------
nQ = numel(cfg.qRefScaleGrid);

qRows = struct([]);

for iq = 1:nQ

    qScale = cfg.qRefScaleGrid(iq);
    qRefTest = model.qRefAh*qScale;

    totalSSE = 0;
    totalN = 0;
    biases = nan(18,1);
    ibias = 0;
    allValid = true;
    minWarmupMultiple = Inf;
    startSOCList = nan(numel(profileData),1);

    for ip = 1:numel(profileData)

        P = profileData(ip);

        t = P.t_s(:);
        I = P.I_A(:);
        Vmeas = P.V_V(:);
        idxAnchor = P.idx_anchor;

        if idxAnchor < 2 || idxAnchor > numel(t)
            allValid = false;
            break
        end

        tA = t(1:idxAnchor);
        IA = I(1:idxAnchor);

        QcumAh = cumtrapz(tA,IA)/3600;

        soc = nan(size(t));
        soc(1:idxAnchor) = ...
            1 - (QcumAh(end)-QcumAh)/qRefTest;

        startSOCList(ip) = soc(1);

        Wp = WindowSummary(WindowSummary.CaseID == P.case_id,:);
        Wp = sortrows(Wp,'TargetSOC');

        maxWindowEnd = max(Wp.WindowEnd_s);
        earliestWindowStart = min(Wp.WindowStart_s);

        idxMax = find(t <= maxWindowEnd+1e-9,1,'last');
        idxEarliest = find(t >= earliestWindowStart-1e-9,1,'first');

        if isempty(idxMax) || isempty(idxEarliest)
            allValid = false;
            break
        end

        horizon = (1:idxMax).';
        below = horizon(isfinite(soc(horizon)) & ...
            soc(horizon) < model.socMin);

        if isempty(below)
            idxSafe = find(isfinite(soc(1:idxMax)),1,'first');
        else
            idxSafe = below(end)+1;
        end

        if isempty(idxSafe) || idxSafe >= idxEarliest
            allValid = false;
            break
        end

        socSeg = soc(idxSafe:idxMax);

        if any(~isfinite(socSeg)) || ...
           any(socSeg < model.socMin) || ...
           any(socSeg > model.socMax)
            allValid = false;
            break
        end

        tSeg = t(idxSafe:idxMax);
        ISeg = I(idxSafe:idxMax);
        VSeg = Vmeas(idxSafe:idxMax);

        OCV = interp1(model.soc,model.ocv,socSeg,'linear');
        R0 = interp1(model.soc,model.R0,socSeg,'linear');
        R1 = interp1(model.soc,model.R1,socSeg,'linear');
        C1 = interp1(model.soc,model.C1,socSeg,'linear');
        R2 = interp1(model.soc,model.R2,socSeg,'linear');
        C2 = interp1(model.soc,model.C2,socSeg,'linear');

        if any(~isfinite(OCV)) || any(~isfinite(R0)) || ...
           any(~isfinite(R1)) || any(~isfinite(C1)) || ...
           any(~isfinite(R2)) || any(~isfinite(C2))
            allValid = false;
            break
        end

        tau1 = R1.*C1;
        tau2 = R2.*C2;

        v1 = simulate_rc_branch_variable(tSeg,ISeg,R1,tau1);
        v2 = simulate_rc_branch_variable(tSeg,ISeg,R2,tau2);

        Vhat = OCV + v1 + v2 + R0.*ISeg;

        for iw = 1:height(Wp)

            mask = ...
                tSeg >= Wp.WindowStart_s(iw)-1e-9 & ...
                tSeg <= Wp.WindowEnd_s(iw)+1e-9;

            if sum(mask) < 600
                allValid = false;
                break
            end

            r = Vhat(mask)-VSeg(mask);

            totalSSE = totalSSE + sum(r.^2);
            totalN = totalN + numel(r);

            ibias = ibias+1;
            biases(ibias) = mean(r)*1000;

            % Nominal tau2 only; this is qRef sensitivity, not R2/tau2 scan.
            zTarget = Wp.TargetSOC(iw);
            R2t = interp1(model.soc,model.R2,zTarget,'linear');
            C2t = interp1(model.soc,model.C2,zTarget,'linear');
            tau2t = R2t*C2t;

            history_s = Wp.WindowStart_s(iw)-tSeg(1);
            warmupMultiple = history_s/tau2t;
            minWarmupMultiple = min(minWarmupMultiple,warmupMultiple);

            if warmupMultiple < cfg.minWarmupTauMultiple
                allValid = false;
                break
            end
        end

        if ~allValid
            break
        end
    end

    if allValid && totalN > 0 && ibias == 18
        pooledRMSE_mV = sqrt(totalSSE/totalN)*1000;
        medianAbsBias_mV = median(abs(biases));
        meanBias_mV = mean(biases);
        maxAbsBias_mV = max(abs(biases));
        startSOCMin = min(startSOCList);
        startSOCMax = max(startSOCList);
    else
        pooledRMSE_mV = NaN;
        medianAbsBias_mV = NaN;
        meanBias_mV = NaN;
        maxAbsBias_mV = NaN;
        startSOCMin = NaN;
        startSOCMax = NaN;
        minWarmupMultiple = NaN;
    end

    qRows(iq).QrefScale = qScale; %#ok<SAGROW>
    qRows(iq).Qref_Ah = qRefTest;
    qRows(iq).Valid = allValid && totalN > 0 && ibias == 18;
    qRows(iq).PooledRMSE_mV = pooledRMSE_mV;
    qRows(iq).MedianAbsWindowBias_mV = medianAbsBias_mV;
    qRows(iq).MeanWindowBias_mV = meanBias_mV;
    qRows(iq).MaxAbsWindowBias_mV = maxAbsBias_mV;
    qRows(iq).BackwardStartSOC_Min = startSOCMin;
    qRows(iq).BackwardStartSOC_Max = startSOCMax;
    qRows(iq).MinWarmupTau2Multiple = minWarmupMultiple;
end

QrefSensitivity = struct2table(qRows);

validMask = QrefSensitivity.Valid & ...
    isfinite(QrefSensitivity.PooledRMSE_mV);

if ~any(validMask)
    error('EXT2:B12D:NoValidQrefScale', ...
        'No qRef scale passed frozen-SOC-support/warmup checks.');
end

validIdx = find(validMask);
[bestRMSE,jBestLocal] = min(QrefSensitivity.PooledRMSE_mV(validMask));
idxBest = validIdx(jBestLocal);

bestQrefScale = QrefSensitivity.QrefScale(idxBest);
bestQref_Ah = QrefSensitivity.Qref_Ah(idxBest);
bestMedianAbsBias = QrefSensitivity.MedianAbsWindowBias_mV(idxBest);
bestMeanBias = QrefSensitivity.MeanWindowBias_mV(idxBest);

[~,idxNom] = min(abs(QrefSensitivity.QrefScale-1));

if ~QrefSensitivity.Valid(idxNom)
    error('EXT2:B12D:NominalQrefInvalid', ...
        'Nominal qRef scale 1.000 failed the B1-2D support/warmup checks.');
end

nominalQrefRMSE = QrefSensitivity.PooledRMSE_mV(idxNom);
nominalMedianAbsBias = QrefSensitivity.MedianAbsWindowBias_mV(idxNom);

qrefBoundaryRisk = ...
    bestQrefScale <= min(cfg.qRefScaleGrid)+cfg.qRefBoundaryMargin || ...
    bestQrefScale >= max(cfg.qRefScaleGrid)-cfg.qRefBoundaryMargin;

qrefRMSEImprovement_mV = nominalQrefRMSE-bestRMSE;
qrefBiasImprovement_mV = nominalMedianAbsBias-bestMedianAbsBias;

%% ------------------------------------------------------------------------
% 7. DESCRIPTIVE INTERPRETATION
% -------------------------------------------------------------------------
commonModeAll = all(CommonModeSummary.CommonModeDescriptivePass);

% Current-proportional screening:
% if a shared resistance error were the dominant baseline source, bias would
% vary strongly with mean current. Here we summarize the fitted slope effect
% across the actual current span at each SOC.
CommonModeSummary.CurrentSpanBiasEffect_mV = ...
    abs(CommonModeSummary.BiasVsCurrentSlope_mOhm) .* ...
    (CommonModeSummary.MeanCurrentMax_A-CommonModeSummary.MeanCurrentMin_A);

medianCurrentSpanEffect = ...
    median(CommonModeSummary.CurrentSpanBiasEffect_mV);

medianSharedCorrection = ...
    median(CommonModeSummary.SharedVoltageCorrection_mV);

if qrefBoundaryRisk
    qrefInterpretation = "BEST_QREF_AT_SCAN_BOUNDARY";
elseif bestMedianAbsBias <= 0.5*nominalMedianAbsBias
    qrefInterpretation = "QREF_STRONGLY_REDUCES_BASELINE";
else
    qrefInterpretation = "QREF_ONLY_PARTIALLY_REDUCES_BASELINE";
end

if commonModeAll && ...
   medianCurrentSpanEffect < 0.25*medianSharedCorrection
    baselineInterpretation = ...
        "COMMON_MODE_NOT_PRIMARILY_CURRENT_PROPORTIONAL";
else
    baselineInterpretation = ...
        "MIXED_OR_CURRENT_DEPENDENT_BASELINE";
end

%% ------------------------------------------------------------------------
% 8. SAVE RESULTS
% -------------------------------------------------------------------------
commonFile = fullfile( ...
    resultsDir,'EXT2_B1_2D_common_mode_bias_by_SOC_v1.csv');
groupFile = fullfile( ...
    resultsDir,'EXT2_B1_2D_group_bias_summary_v1.csv');
qrefFile = fullfile( ...
    resultsDir,'EXT2_B1_2D_qref_sensitivity_v1.csv');
windowFile = fullfile( ...
    resultsDir,'EXT2_B1_2D_window_bias_with_current_v1.csv');

writetable(CommonModeSummary,commonFile);
writetable(GroupBiasSummary,groupFile);
writetable(QrefSensitivity,qrefFile);
writetable(C,windowFile);

reportFile = fullfile( ...
    resultsDir,'EXT2_B1_2D_baseline_origin_report_v1.txt');

fid = fopen(reportFile,'w');

if fid < 0
    error('EXT2:B12D:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-B1-2D Common-Mode Baseline Origin Audit v1\n");
fprintf(fid,"===================================================\n\n");

fprintf(fid,"Diagnostic only. No R2/tau2 fit or adaptation.\n\n");

fprintf(fid,"Common-mode bias by SOC:\n");
for k = 1:height(CommonModeSummary)
    fprintf(fid, ...
        "SOC %.0f%% | mean bias %+8.3f mV | std %.3f | range %.3f | shared correction %+8.3f mV | current-span effect %.3f mV | equiv SOC shift %+6.3f pp\n", ...
        100*CommonModeSummary.TargetSOC(k), ...
        CommonModeSummary.MeanResidualBias_mV(k), ...
        CommonModeSummary.StdResidualBias_mV(k), ...
        CommonModeSummary.RangeResidualBias_mV(k), ...
        CommonModeSummary.SharedVoltageCorrection_mV(k), ...
        CommonModeSummary.CurrentSpanBiasEffect_mV(k), ...
        CommonModeSummary.EquivalentSOCShift_pp(k));
end

fprintf(fid,"\nAll SOC levels common-mode descriptive PASS = %s\n", ...
    pass_text(commonModeAll));
fprintf(fid,"Median current-span bias effect = %.3f mV\n", ...
    medianCurrentSpanEffect);
fprintf(fid,"Median shared correction        = %.3f mV\n", ...
    medianSharedCorrection);
fprintf(fid,"Baseline interpretation         = %s\n", ...
    baselineInterpretation);

fprintf(fid,"\nqRef sensitivity:\n");
fprintf(fid,"Nominal qRef                   = %.6f Ah\n",model.qRefAh);
fprintf(fid,"Nominal pooled RMSE            = %.3f mV\n",nominalQrefRMSE);
fprintf(fid,"Nominal median |window bias|   = %.3f mV\n",nominalMedianAbsBias);
fprintf(fid,"Best qRef scale in scan        = %.3f\n",bestQrefScale);
fprintf(fid,"Best qRef                      = %.6f Ah\n",bestQref_Ah);
fprintf(fid,"Best pooled RMSE               = %.3f mV\n",bestRMSE);
fprintf(fid,"Best median |window bias|      = %.3f mV\n",bestMedianAbsBias);
fprintf(fid,"Best mean window bias          = %+8.3f mV\n",bestMeanBias);
fprintf(fid,"qRef RMSE improvement          = %.3f mV\n",qrefRMSEImprovement_mV);
fprintf(fid,"qRef bias improvement          = %.3f mV\n",qrefBiasImprovement_mV);
fprintf(fid,"qRef boundary hit/risk         = %s\n",yes_no(qrefBoundaryRisk));
fprintf(fid,"qRef interpretation            = %s\n",qrefInterpretation);

fprintf(fid,"\nClaim boundary:\n");
fprintf(fid,"B1-2D does not identify a new parameter or reopen B2.\n");
fprintf(fid,"If qRef is insufficient, independent OCV/charge-hysteresis/SOC-anchor evidence is required next.\n");
fclose(fid);

%% ------------------------------------------------------------------------
% 9. PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);
[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetAuditFile = fullfile( ...
    resultsDir,'EXT2_B1_2D_protected_asset_audit_v1.csv');
writetable(AssetAudit,assetAuditFile);

if ~assetsUnchanged
    error('EXT2:B12D:ProtectedAssetChanged', ...
        'A protected frozen asset changed during B1-2D. STOP.');
end

%% ------------------------------------------------------------------------
% 10. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-B1-2D COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Common-mode bias by SOC:\n");
for k = 1:height(CommonModeSummary)
    fprintf("  SOC %.0f%% | mean bias %+7.2f mV | std %.2f | range %.2f | shared correction %+7.2f mV | current-span effect %.2f mV | equiv SOC shift %+5.2f pp\n", ...
        100*CommonModeSummary.TargetSOC(k), ...
        CommonModeSummary.MeanResidualBias_mV(k), ...
        CommonModeSummary.StdResidualBias_mV(k), ...
        CommonModeSummary.RangeResidualBias_mV(k), ...
        CommonModeSummary.SharedVoltageCorrection_mV(k), ...
        CommonModeSummary.CurrentSpanBiasEffect_mV(k), ...
        CommonModeSummary.EquivalentSOCShift_pp(k));
end

fprintf("\nGroup means:\n");
for k = 1:height(GroupBiasSummary)
    fprintf("  %-14s %-5s | mean bias %+7.2f mV | mean I %.3f A\n", ...
        GroupBiasSummary.Category(k), ...
        GroupBiasSummary.Level(k), ...
        GroupBiasSummary.MeanBias_mV(k), ...
        GroupBiasSummary.MeanCurrent_A(k));
end

fprintf("\nBaseline screening:\n");
fprintf("  All SOC common-mode screen       : %s\n",pass_text(commonModeAll));
fprintf("  Median current-span bias effect  : %.3f mV\n",medianCurrentSpanEffect);
fprintf("  Median shared correction         : %.3f mV\n",medianSharedCorrection);
fprintf("  Interpretation                   : %s\n",baselineInterpretation);

fprintf("\nqRef/SOC sensitivity:\n");
fprintf("  Nominal qRef                     : %.6f Ah\n",model.qRefAh);
fprintf("  Nominal pooled RMSE              : %.3f mV\n",nominalQrefRMSE);
fprintf("  Nominal median |window bias|     : %.3f mV\n",nominalMedianAbsBias);
fprintf("  Best qRef scale [0.90,1.10]      : %.3f\n",bestQrefScale);
fprintf("  Best qRef                        : %.6f Ah\n",bestQref_Ah);
fprintf("  Best pooled RMSE                 : %.3f mV\n",bestRMSE);
fprintf("  Best median |window bias|        : %.3f mV\n",bestMedianAbsBias);
fprintf("  qRef scan boundary hit/risk      : %s\n",yes_no(qrefBoundaryRisk));
fprintf("  qRef interpretation              : %s\n",qrefInterpretation);

fprintf("\nProtected assets unchanged         : %s\n",pass_text(assetsUnchanged));
fprintf("B1-2B remains FAIL / B2 remains STOP.\n");
fprintf("B1-2D is diagnostic only.\n\n");

fprintf("Saved under:\n%s\n\n",resultsDir);


%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function v = simulate_rc_branch_variable(t,I,Rbase,taubase)
t = t(:);
I = I(:);
Rbase = Rbase(:);
taubase = taubase(:);

N = numel(t);

if numel(I) ~= N || numel(Rbase) ~= N || numel(taubase) ~= N
    error('EXT2:B12D:RCVectorLength', ...
        't/I/R/tau vectors must have equal length.');
end

v = zeros(N,1);

for k = 1:N-1

    dt = t(k+1)-t(k);

    if dt <= 0
        error('EXT2:B12D:NonPositiveDt', ...
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
    error('EXT2:B12D:HashOpenFailed', ...
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
    error('EXT2:B12D:HashFailed', ...
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

snap = table(Path,Exists,Bytes,SHA256, ...
    'VariableNames',{'Path','Exists','Bytes','SHA256'});
end


function [ok,audit] = compare_asset_snapshots_hash(a,b)

if height(a) ~= height(b) || any(a.Path ~= b.Path)
    error('EXT2:B12D:AssetSnapshotMismatch', ...
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
    a.Path,a.Exists,b.Exists,a.Bytes,b.Bytes,a.SHA256,b.SHA256,Unchanged, ...
    'VariableNames', { ...
    'Path','ExistsBefore','ExistsAfter','BytesBefore','BytesAfter', ...
    'SHA256Before','SHA256After','Unchanged'});

ok = all(Unchanged);
end


function s = yes_no(tf)

if tf
    s = 'YES';
else
    s = 'NO';
end
end


function s = pass_text(tf)

if tf
    s = 'PASS';
else
    s = 'FAIL';
end
end
