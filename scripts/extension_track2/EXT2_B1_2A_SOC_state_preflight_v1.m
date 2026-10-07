% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_B1_2A_SOC_state_preflight_v1.m
% MJ1 2RC-EKF EXT2-B1
% B1-2A Real-Voltage Preflight / SOC-State Reconstruction
%
% PURPOSE
%   Establish whether the six frozen MID/SLOW DC-AC experiments contain
%   enough independently anchored state information for a scientifically
%   defensible real-voltage R2/tau2 target-consistency scan (B1-2B).
%
% THIS SCRIPT DOES NOT FIT R2 OR tau2.
% THIS SCRIPT DOES NOT ADAPT ANY PARAMETER.
%
% CORE IDEA
%   The full NGU records contain the 4.2 V CV tail approaching ~50 mA.
%   The project defines that terminal condition as SOC = 1. Therefore:
%
%       SOC(t) = 1 - integral_t^t_anchor I(lambda)dlambda
%                      / (3600*qRefAh_frozen)
%
%   is reconstructed backwards from the measured terminal anchor.
%
%   This avoids estimating absolute SOC from loaded terminal voltage or
%   OCV inversion. OCV inversion is deliberately NOT used here.
%
% B1-2B PREPARATION
%   - Six exact A2/B1 source files are frozen by path + SHA-256.
%   - Frozen qRefAh is used for Coulomb counting.
%   - The frozen model is not evaluated below its validated SOC support.
%   - A model-simulation start is identified at SOC = model.socMin.
%   - Candidate 700 s measured-voltage windows are centered near
%     SOC = 30%, 50%, 70%.
%       * MID (~70 s): ~10 cycles/window
%       * SLOW (~700 s): ~1 cycle/window
%   - The full raw current history from model.socMin to each window is kept
%     available so RC-state initialization can wash out before fitting.
%
% PASS CLAIM
%   A B1-2A PASS means only:
%     1) terminal SOC=1 anchor is supported in all six records;
%     2) backward Coulomb-counted SOC trajectories are available;
%     3) 30/50/70% windows lie inside conservative AC-active and model-
%        validated regions;
%     4) sufficient pre-window dynamic history exists.
%
%   It does NOT mean R2/tau2 are consistent with measured voltage.
%
% OUTPUT POLICY
%   New files only under:
%     EXT2_dynamic_parameter_identifiability/results/
%
% MATLAB compatibility:
%   - legacy char/cell 'VariableNames' syntax
%   - scalar char error(identifier,format,...) messages
%
% Frozen boundary:
%   MJ1 v0.2 EKF, Bayesian R0 v1.0, EXT1 K4 and Simulink assets unchanged.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-2A | Real-Voltage SOC/State Preflight v1\n");
fprintf(" Terminal SOC=1 anchor | Backward Coulomb counting | No fitting\n");
fprintf("============================================================\n\n");
fprintf("MATLAB table compatibility: legacy char/cell VariableNames mode\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS — keep the established EXT2 project structure
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));
if strlength(scriptDir) == 0
    error('EXT2:B12A:RunAsFile', ...
        'Run this script from its saved .m file, not from an unsaved editor buffer.');
end

ext2Dir = scriptDir;
workRoot = string(fileparts(ext2Dir));
resultsDir = fullfile(ext2Dir,'results');

if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end

expectedExt2Name = "EXT2_dynamic_parameter_identifiability";
[~,actualExt2Name] = fileparts(ext2Dir);
if ~strcmpi(string(actualExt2Name),expectedExt2Name)
    error('EXT2:B12A:WrongFolder', ...
        'This script must live inside %s. Current folder: %s', ...
        char(expectedExt2Name),char(ext2Dir));
end

cfg.repoRoot = ...
    "<REPO_ROOT>";
cfg.githubRemote = ...
    "https://github.com/jiaxingLu/MJ1_2RC_EKF_SOC_Estimation";

repoMatlab = fullfile(cfg.repoRoot,'matlab');
modelFile = fullfile(cfg.repoRoot,'data','mj1_v02_model.mat');

required = { ...
    modelFile, ...
    fullfile(repoMatlab,'mj1_load_model.m'), ...
    fullfile(repoMatlab,'mj1_interp_params.m')};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:B12A:MissingFrozenInput', ...
            'Required frozen input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

requiredModelFields = {'soc','ocv','R0','R1','C1','R2','C2', ...
    'qRefAh','socMin','socMax'};
for k = 1:numel(requiredModelFields)
    if ~isfield(model,requiredModelFields{k})
        error('EXT2:B12A:ModelFieldMissing', ...
            'Frozen model missing field: %s',requiredModelFields{k});
    end
end

% Compatibility preflight before file processing.
try
    Tcompat = table((1:2).',(3:4).', ...
        'VariableNames',{'A','B'}); %#ok<NASGU>
catch ME
    error('EXT2:B12A:TableCompatibility', ...
        'MATLAB table compatibility preflight failed: %s',ME.message);
end

fprintf("EXT2 work folder : %s\n",ext2Dir);
fprintf("Results only     : %s\n",resultsDir);
fprintf("Local Git repo   : %s\n",cfg.repoRoot);
fprintf("GitHub remote    : %s\n",cfg.githubRemote);
fprintf("Frozen model     : %s\n",modelFile);
fprintf("Frozen qRefAh    : %.9f Ah\n",model.qRefAh);
fprintf("Frozen SOC range : %.3f %% ... %.3f %%\n\n", ...
    100*model.socMin,100*model.socMax);

%% ------------------------------------------------------------------------
% 1. FROZEN / PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedRel = { ...
    'matlab/mj1_ekf_step.m'
    'matlab/mj1_state_transition.m'
    'matlab/mj1_measurement.m'
    'matlab/mj1_interp_params.m'
    'matlab/ope_r0_bayes_online_core_v2.m'
    'matlab/ope_excitation_gate_online_v2.m'
    'ope_r0_bayes_online_core_v2.m'
    'ope_excitation_gate_online_v2.m'
    'model/MJ1_2RC_EKF_v02_S2_A1d_AutonomousGate.slx'
    'MJ1_2RC_EKF_v02_S2_A1d_AutonomousGate.slx'
    'matlab/ope_r0_bayes_rolling_k4_core_v1.m'
    'ope_r0_bayes_rolling_k4_core_v1.m'
    'model/MJ1_2RC_EKF_EXT1_K4_Integrated_v1.slx'
    'MJ1_2RC_EKF_EXT1_K4_Integrated_v1.slx'
    };

protectedBefore = snapshot_assets_hash(cfg.repoRoot,protectedRel);

%% ------------------------------------------------------------------------
% 2. B1-2A PROSPECTIVE PROTOCOL — frozen before results are viewed
% -------------------------------------------------------------------------
cfg.anchorVoltage_V = 4.200;
cfg.anchorCurrent_A = 0.050;

% Terminal SOC=1 anchor tolerances.
cfg.anchorVoltageTol_V = 0.005;       % 4.195 ... 4.205 V
cfg.anchorCurrentTol_A = 0.005;       % 45 ... 55 mA
cfg.anchorSearchTail_s = 600;
cfg.anchorMaxDistanceFromEnd_s = 120;

% Data integrity.
cfg.maxMedianDtError_s = 0.05;
cfg.maxAllowedGap_s = 2.1;
cfg.maxAllowedGapCount = 2;

% Conservative AC-confirmation rule. All six frozen profiles have
% sinusoidal current that crosses below zero while AC is active.
cfg.negativeCurrentThreshold_A = -0.020;
cfg.minConfirmedACCyles = 5;

% Target windows for B1-2B.
cfg.targetSOC = [0.30 0.50 0.70];
cfg.fitWindowDuration_s = 700;
cfg.halfFitWindow_s = cfg.fitWindowDuration_s/2;
cfg.targetSOCCenterTol = 0.003;       % 0.3 percentage point
cfg.minHistoryTau2Multiple = 20;

% Diagnostic only: start SOC is not used as an anchor.
cfg.startSOCPlausibleRange = [-0.15 0.20];

% Expected periods are source-identity sanity metadata.
% MID/SLOW period tolerances deliberately wider than the audit precision.
cfg.midPeriodTol_s = 2;
cfg.slowPeriodTol_s = 10;

%% ------------------------------------------------------------------------
% 3. EXACT A2/B1 SOURCE MANIFEST
% -------------------------------------------------------------------------
userProfile = string(getenv("USERPROFILE"));
profileRoot = fullfile(userProfile,'Desktop', ...
    'MJ1_Experimental_Data_Reconstruction','raw_original');

if ~isfolder(profileRoot)
    error('EXT2:B12A:ProfileRootMissing', ...
        'Read-only historical profile root not found: %s',char(profileRoot));
end

fprintf("Read-only frozen profile root:\n  %s\n\n",profileRoot);

profileDefs = make_profile_def( ...
    "A_MID_02p03","MID","0.2C+0.3C","FILE_0035", ...
    "0.2C/NGU/处理后0.2+0.3 1tau.csv", ...
    "d6a8551be57f8ab78949a1ea11529dde8f70411d20db5437553a5d64d2234b4b", ...
    70.0);

profileDefs(end+1) = make_profile_def( ...
    "A_SLOW_02p03","SLOW","0.2C+0.3C","FILE_0037", ...
    "0.2C/NGU/处理后0.2+0.3C 10tau.csv", ...
    "170436214c515fc0a2fe5423b2422f45ecdd9b0e680f821f20997e36d5eaccef", ...
    700.0);

profileDefs(end+1) = make_profile_def( ...
    "B_MID_03p04","MID","0.3C+0.4C","FILE_0093", ...
    "0.3C/NGU/处理后0.3+0.4C 1tau.csv", ...
    "260d45543c057f5021b1e8282873f4a0dbe67597afc2675c3b442343e3fbc3b8", ...
    70.0);

profileDefs(end+1) = make_profile_def( ...
    "B_SLOW_03p04","SLOW","0.3C+0.4C","FILE_0092", ...
    "0.3C/NGU/处理后0.3+0.4C 10tau.csv", ...
    "21ed81dffb7aa4fcee303931c436373ecff84aa6592add7149de455d0375044f", ...
    700.0);

profileDefs(end+1) = make_profile_def( ...
    "DEV_MID_03p07","MID","0.3C+0.7C","FILE_0140", ...
    "0.3C/处理后/处理后 0.3+0.7 (切换).csv", ...
    "7a69b86c1ea840d176af01f7e1c41b2c2798b01a15a6bcfc4d934186ea1e6f1d", ...
    70.0);

profileDefs(end+1) = make_profile_def( ...
    "DEV_SLOW_03p07","SLOW","0.3C+0.7C","FILE_0159", ...
    "0.3C/处理后/处理后0.3+0.7 10 tau.csv", ...
    "536c429b12e1b6909f59c1588eeb92f57296367eecd9dc1776744d850b16675a", ...
    700.0);

% Fail-fast source schema contract.
requiredDefFields = {'case_id','band','amplitude_group','source_file_id', ...
    'relative_path','expected_sha256','expected_period_s'};
for k = 1:numel(profileDefs)
    missingDefFields = requiredDefFields( ...
        ~cellfun(@(f) isfield(profileDefs(k),f),requiredDefFields));
    if ~isempty(missingDefFields)
        error('EXT2:B12A:ProfileDefContract', ...
            'Profile definition %d missing field(s): %s', ...
            k,strjoin(missingDefFields,', '));
    end
end
fprintf("Source-definition field contract: PASS\n\n");

%% ------------------------------------------------------------------------
% 4. MAIN PREFLIGHT
% -------------------------------------------------------------------------
profileSummaryRows = struct([]);
windowRows = struct([]);
trajectoryTables = cell(numel(profileDefs),1);
profileData = struct([]);

iprofRow = 0;
iwinRow = 0;

for ip = 1:numel(profileDefs)

    def = profileDefs(ip);
    filePath = fullfile(profileRoot,replace(def.relative_path,'/',filesep));

    if ~isfile(filePath)
        error('EXT2:B12A:FrozenProfileMissing', ...
            'Frozen source %s (%s) not found at: %s', ...
            char(def.case_id),char(def.source_file_id),char(filePath));
    end

    actualSHA = sha256_file(filePath);
    if ~strcmpi(actualSHA,char(def.expected_sha256))
        error('EXT2:B12A:FrozenProfileHashMismatch', ...
            ['Frozen source identity mismatch for %s (%s).\n' ...
             'Expected SHA-256: %s\nActual SHA-256:   %s\nPath: %s\nSTOP.'], ...
            char(def.case_id),char(def.source_file_id), ...
            char(def.expected_sha256),actualSHA,char(filePath));
    end

    D = load_ngu_uiv_full(filePath);

    t = D.t_s;
    V = D.V_V;
    I = D.I_A;
    N = numel(t);

    if N < 1000
        error('EXT2:B12A:TooFewSamples', ...
            'Frozen source %s has only %d valid samples.',char(def.case_id),N);
    end

    dt = diff(t);
    dtMed = median(dt);
    gapMask = dt > cfg.maxAllowedGap_s;
    nGaps = sum(gapMask);
    maxGap = max(dt);

    timebasePass = ...
        abs(dtMed-1.0) <= cfg.maxMedianDtError_s && ...
        nGaps <= cfg.maxAllowedGapCount;

    % Period sanity from first 4200 valid samples (same A2/B1 context).
    nFFT = min(4200,N);
    Ifirst = I(1:nFFT);
    IexcFirst = Ifirst-mean(Ifirst);
    periodMeasured = dominant_period_fft(IexcFirst,dtMed);

    if def.band == "MID"
        periodTol = cfg.midPeriodTol_s;
    else
        periodTol = cfg.slowPeriodTol_s;
    end
    periodPass = isfinite(periodMeasured) && ...
        abs(periodMeasured-def.expected_period_s) <= periodTol;

    % -------------------------------------------------------------
    % Terminal SOC=1 anchor
    % -------------------------------------------------------------
    tailStartTime = max(t(1),t(end)-cfg.anchorSearchTail_s);
    anchorCandidate = find( ...
        t >= tailStartTime & ...
        abs(V-cfg.anchorVoltage_V) <= 2*cfg.anchorVoltageTol_V & ...
        I >= 0 & I <= 0.10);

    if isempty(anchorCandidate)
        error('EXT2:B12A:AnchorCandidateMissing', ...
            'No terminal 4.2 V / low-current anchor candidate in %s.', ...
            char(def.case_id));
    end

    score = ...
        abs(V(anchorCandidate)-cfg.anchorVoltage_V)/cfg.anchorVoltageTol_V + ...
        abs(I(anchorCandidate)-cfg.anchorCurrent_A)/cfg.anchorCurrentTol_A;

    [~,jBest] = min(score);
    idxAnchor = anchorCandidate(jBest);

    anchorVoltage = V(idxAnchor);
    anchorCurrent = I(idxAnchor);
    anchorTime = t(idxAnchor);
    anchorDistanceFromEnd = t(end)-anchorTime;

    anchorPass = ...
        abs(anchorVoltage-cfg.anchorVoltage_V) <= cfg.anchorVoltageTol_V && ...
        abs(anchorCurrent-cfg.anchorCurrent_A) <= cfg.anchorCurrentTol_A && ...
        anchorDistanceFromEnd <= cfg.anchorMaxDistanceFromEnd_s;

    % Last 60 s before anchor: voltage should be a stable CV plateau.
    tail60 = t >= max(t(1),anchorTime-60) & t <= anchorTime;
    cvTailMeanV = mean(V(tail60));
    cvTailStdV = std(V(tail60));
    cvTailPass = ...
        abs(cvTailMeanV-cfg.anchorVoltage_V) <= cfg.anchorVoltageTol_V && ...
        cvTailStdV <= 0.003;

    % -------------------------------------------------------------
    % Backward Coulomb count from SOC=1 anchor
    % -------------------------------------------------------------
    tA = t(1:idxAnchor);
    IA = I(1:idxAnchor);

    QcumAh = cumtrapz(tA,IA)/3600;
    deliveredToAnchor_Ah = QcumAh(end)-QcumAh(1);

    soc = nan(N,1);
    soc(1:idxAnchor) = ...
        1 - (QcumAh(end)-QcumAh)/model.qRefAh;

    % Period-centered SOC is used ONLY to select phase-insensitive target
    % centers. The raw Coulomb-counted SOC remains the state trajectory.
    nPer = max(3,round(def.expected_period_s/dtMed));
    socSmooth = nan(N,1);
    socSmooth(1:idxAnchor) = movmean( ...
        soc(1:idxAnchor),nPer,'Endpoints','shrink');

    startSOC = soc(1);
    startSOCPlausible = ...
        startSOC >= cfg.startSOCPlausibleRange(1) && ...
        startSOC <= cfg.startSOCPlausibleRange(2);

    % Charge-direction sanity: net positive charge and rising voltage.
    chargeDirectionPass = ...
        deliveredToAnchor_Ah > 0.50*model.qRefAh && ...
        anchorVoltage > V(1)+0.8;

    % -------------------------------------------------------------
    % Conservative AC-active region
    % -------------------------------------------------------------
    negIdx = find((1:N).' <= idxAnchor & ...
        I < cfg.negativeCurrentThreshold_A);

    if isempty(negIdx)
        error('EXT2:B12A:NoNegativeACConfirmation', ...
            'No negative-current AC samples detected in %s.',char(def.case_id));
    end

    idxFirstNeg = negIdx(1);
    idxLastNeg = negIdx(end);
    acSafeStart = t(idxFirstNeg);
    acSafeEnd = t(idxLastNeg);
    confirmedACCyles = (acSafeEnd-acSafeStart)/def.expected_period_s;
    acConfirmationPass = confirmedACCyles >= cfg.minConfirmedACCyles;

    % -------------------------------------------------------------
    % Model-valid simulation start at frozen model.socMin
    % -------------------------------------------------------------
    modelStartCandidates = find( ...
        (1:N).' <= idxAnchor & ...
        t >= acSafeStart & ...
        t <= acSafeEnd & ...
        isfinite(socSmooth));

    if isempty(modelStartCandidates)
        error('EXT2:B12A:NoModelStartCandidates', ...
            'No model-start candidates in %s.',char(def.case_id));
    end

    [modelStartErr,jStart] = min( ...
        abs(socSmooth(modelStartCandidates)-model.socMin));
    idxModelStart = modelStartCandidates(jStart);
    modelStartTime = t(idxModelStart);
    modelStartSOC = socSmooth(idxModelStart);

    modelStartPass = ...
        modelStartErr <= cfg.targetSOCCenterTol && ...
        modelStartSOC >= model.socMin-cfg.targetSOCCenterTol && ...
        modelStartSOC <= model.socMin+cfg.targetSOCCenterTol;

    % Save profile data needed by the next stage, but do not fit anything.
    P = struct();
    P.case_id = def.case_id;
    P.band = def.band;
    P.amplitude_group = def.amplitude_group;
    P.source_file_id = def.source_file_id;
    P.source_file = string(filePath);
    P.source_sha256 = string(actualSHA);
    P.t_s = t;
    P.V_V = V;
    P.I_A = I;
    P.SOC = soc;
    P.SOC_cycle_centered = socSmooth;
    P.idx_anchor = idxAnchor;
    P.idx_model_start = idxModelStart;
    P.ac_safe_start_s = acSafeStart;
    P.ac_safe_end_s = acSafeEnd;
    P.period_s = periodMeasured;

    if isempty(profileData)
        profileData = P;
    else
        profileData(end+1) = P; %#ok<SAGROW>
    end

    % -------------------------------------------------------------
    % 30 / 50 / 70% window audit
    % -------------------------------------------------------------
    allWindowsReadyThisProfile = true;

    for it = 1:numel(cfg.targetSOC)
        targetSOC = cfg.targetSOC(it);

        candidateIdx = find( ...
            (1:N).' <= idxAnchor & ...
            t >= acSafeStart & ...
            t <= acSafeEnd & ...
            isfinite(socSmooth));

        [targetErr,jTarget] = min(abs(socSmooth(candidateIdx)-targetSOC));
        idxCenter = candidateIdx(jTarget);
        centerTime = t(idxCenter);

        requestedStart = centerTime-cfg.halfFitWindow_s;
        requestedEnd = centerTime+cfg.halfFitWindow_s;

        idxWindow = find( ...
            (1:N).' <= idxAnchor & ...
            t >= requestedStart & ...
            t <= requestedEnd);

        if numel(idxWindow) >= 2
            actualWindowStart = t(idxWindow(1));
            actualWindowEnd = t(idxWindow(end));
            actualDuration = actualWindowEnd-actualWindowStart;
            windowDt = diff(t(idxWindow));
            windowMaxGap = max(windowDt);
            windowGapCount = sum(windowDt > cfg.maxAllowedGap_s);

            rawSOCMin = min(soc(idxWindow));
            rawSOCMax = max(soc(idxWindow));
            Vmin = min(V(idxWindow));
            Vmax = max(V(idxWindow));
            Imean = mean(I(idxWindow));
            IexcRMS = sqrt(mean((I(idxWindow)-Imean).^2));
        else
            actualWindowStart = NaN;
            actualWindowEnd = NaN;
            actualDuration = 0;
            windowMaxGap = Inf;
            windowGapCount = Inf;
            rawSOCMin = NaN;
            rawSOCMax = NaN;
            Vmin = NaN;
            Vmax = NaN;
            Imean = NaN;
            IexcRMS = NaN;
        end

        insideConservativeAC = ...
            requestedStart >= acSafeStart && ...
            requestedEnd <= acSafeEnd;

        modelSupportPass = ...
            isfinite(rawSOCMin) && isfinite(rawSOCMax) && ...
            rawSOCMin >= model.socMin && rawSOCMax <= model.socMax;

        pTarget = mj1_interp_params(model,targetSOC);
        tau2Target = pTarget.tau2;

        historyBeforeWindow_s = requestedStart-modelStartTime;
        historyTau2Multiple = historyBeforeWindow_s/tau2Target;

        windowIntegrityPass = ...
            actualDuration >= cfg.fitWindowDuration_s-2*dtMed && ...
            windowGapCount <= cfg.maxAllowedGapCount && ...
            windowMaxGap <= cfg.maxAllowedGap_s;

        centerPass = targetErr <= cfg.targetSOCCenterTol;
        historyPass = historyTau2Multiple >= cfg.minHistoryTau2Multiple;

        windowReady = ...
            anchorPass && cvTailPass && timebasePass && periodPass && ...
            chargeDirectionPass && acConfirmationPass && modelStartPass && ...
            centerPass && insideConservativeAC && modelSupportPass && ...
            historyPass && windowIntegrityPass;

        allWindowsReadyThisProfile = ...
            allWindowsReadyThisProfile && windowReady;

        iwinRow = iwinRow+1;
        windowRows(iwinRow).CaseID = def.case_id; %#ok<SAGROW>
        windowRows(iwinRow).Band = def.band;
        windowRows(iwinRow).AmplitudeGroup = def.amplitude_group;
        windowRows(iwinRow).TargetSOC = targetSOC;
        windowRows(iwinRow).CenterSOCSmoothed = socSmooth(idxCenter);
        windowRows(iwinRow).CenterSOCError = targetErr;
        windowRows(iwinRow).CenterTime_s = centerTime;
        windowRows(iwinRow).WindowStart_s = actualWindowStart;
        windowRows(iwinRow).WindowEnd_s = actualWindowEnd;
        windowRows(iwinRow).WindowDuration_s = actualDuration;
        windowRows(iwinRow).CyclesInWindow = ...
            actualDuration/def.expected_period_s;
        windowRows(iwinRow).RawSOCMin = rawSOCMin;
        windowRows(iwinRow).RawSOCMax = rawSOCMax;
        windowRows(iwinRow).VoltageMin_V = Vmin;
        windowRows(iwinRow).VoltageMax_V = Vmax;
        windowRows(iwinRow).MeanCurrent_A = Imean;
        windowRows(iwinRow).ExcitationRMS_A = IexcRMS;
        windowRows(iwinRow).HistoryBeforeWindow_s = historyBeforeWindow_s;
        windowRows(iwinRow).Tau2AtTarget_s = tau2Target;
        windowRows(iwinRow).HistoryTau2Multiple = historyTau2Multiple;
        windowRows(iwinRow).DistanceToConservativeACEnd_s = ...
            acSafeEnd-requestedEnd;
        windowRows(iwinRow).CenterPass = centerPass;
        windowRows(iwinRow).InsideConservativeAC = insideConservativeAC;
        windowRows(iwinRow).ModelSupportPass = modelSupportPass;
        windowRows(iwinRow).HistoryPass = historyPass;
        windowRows(iwinRow).WindowIntegrityPass = windowIntegrityPass;
        windowRows(iwinRow).WindowReady = windowReady;
    end

    iprofRow = iprofRow+1;
    profileSummaryRows(iprofRow).CaseID = def.case_id; %#ok<SAGROW>
    profileSummaryRows(iprofRow).Band = def.band;
    profileSummaryRows(iprofRow).AmplitudeGroup = def.amplitude_group;
    profileSummaryRows(iprofRow).SourceFileID = def.source_file_id;
    profileSummaryRows(iprofRow).SourceFile = string(filePath);
    profileSummaryRows(iprofRow).SourceSHA256 = string(actualSHA);
    profileSummaryRows(iprofRow).NSamples = N;
    profileSummaryRows(iprofRow).MedianDt_s = dtMed;
    profileSummaryRows(iprofRow).MaxGap_s = maxGap;
    profileSummaryRows(iprofRow).GapCount = nGaps;
    profileSummaryRows(iprofRow).MeasuredPeriod_s = periodMeasured;
    profileSummaryRows(iprofRow).ExpectedPeriod_s = def.expected_period_s;
    profileSummaryRows(iprofRow).StartVoltage_V = V(1);
    profileSummaryRows(iprofRow).AnchorTime_s = anchorTime;
    profileSummaryRows(iprofRow).AnchorVoltage_V = anchorVoltage;
    profileSummaryRows(iprofRow).AnchorCurrent_A = anchorCurrent;
    profileSummaryRows(iprofRow).AnchorDistanceFromEnd_s = anchorDistanceFromEnd;
    profileSummaryRows(iprofRow).CVTailMeanVoltage_V = cvTailMeanV;
    profileSummaryRows(iprofRow).CVTailStdVoltage_V = cvTailStdV;
    profileSummaryRows(iprofRow).DeliveredToAnchor_Ah = deliveredToAnchor_Ah;
    profileSummaryRows(iprofRow).BackwardStartSOC = startSOC;
    profileSummaryRows(iprofRow).ACSafeStart_s = acSafeStart;
    profileSummaryRows(iprofRow).ACSafeEnd_s = acSafeEnd;
    profileSummaryRows(iprofRow).ConfirmedACCyles = confirmedACCyles;
    profileSummaryRows(iprofRow).ModelStartTime_s = modelStartTime;
    profileSummaryRows(iprofRow).ModelStartSOC = modelStartSOC;
    profileSummaryRows(iprofRow).TimebasePass = timebasePass;
    profileSummaryRows(iprofRow).PeriodPass = periodPass;
    profileSummaryRows(iprofRow).AnchorPass = anchorPass;
    profileSummaryRows(iprofRow).CVTailPass = cvTailPass;
    profileSummaryRows(iprofRow).ChargeDirectionPass = chargeDirectionPass;
    profileSummaryRows(iprofRow).StartSOCPlausibleDiagnostic = startSOCPlausible;
    profileSummaryRows(iprofRow).ACConfirmationPass = acConfirmationPass;
    profileSummaryRows(iprofRow).ModelStartPass = modelStartPass;
    profileSummaryRows(iprofRow).AllTargetWindowsReady = ...
        allWindowsReadyThisProfile;

    % Per-sample trajectory output.
    CaseIDcol = repmat(def.case_id,N,1);
    Bandcol = repmat(def.band,N,1);
    trajectoryTables{ip} = table( ...
        CaseIDcol,Bandcol,t,V,I,soc,socSmooth, ...
        'VariableNames', { ...
        'CaseID','Band','Time_s','Voltage_V','Current_A', ...
        'SOC_BackwardCC','SOC_CycleCentered'});

    fprintf("%-18s | %-4s | SHA256 PASS | anchor V=%.6f V I=%.6f A | start SOC=% .4f | period=%.3f s\n", ...
        def.case_id,def.band,anchorVoltage,anchorCurrent,startSOC,periodMeasured);
    fprintf("  AC conservative: %.1f ... %.1f s | model start SOC %.4f @ %.1f s | windows %s\n", ...
        acSafeStart,acSafeEnd,modelStartSOC,modelStartTime, ...
        pass_text(allWindowsReadyThisProfile));
end

fprintf("\n");

%% ------------------------------------------------------------------------
% 5. SAVE TABLES
% -------------------------------------------------------------------------
ProfileSummary = struct2table(profileSummaryRows);
WindowSummary = struct2table(windowRows);
Trajectory = vertcat(trajectoryTables{:});

profileSummaryFile = fullfile( ...
    resultsDir,'EXT2_B1_2A_profile_anchor_summary_v1.csv');
windowSummaryFile = fullfile( ...
    resultsDir,'EXT2_B1_2A_target_window_summary_v1.csv');
trajectoryFile = fullfile( ...
    resultsDir,'EXT2_B1_2A_SOC_trajectories_v1.csv');

writetable(ProfileSummary,profileSummaryFile);
writetable(WindowSummary,windowSummaryFile);
writetable(Trajectory,trajectoryFile);

%% ------------------------------------------------------------------------
% 6. DIAGNOSTIC FIGURES — no parameter fit
% -------------------------------------------------------------------------
figureFiles = strings(numel(profileData),1);

for ip = 1:numel(profileData)
    P = profileData(ip);

    f = figure('Name',char("EXT2-B1-2A "+P.case_id), ...
        'Visible','off');
    tiledlayout(3,1);

    nexttile;
    plot(P.t_s,P.V_V,'LineWidth',1.0);
    ylabel('Voltage [V]');
    title(char(P.case_id+" | measured NGU voltage"));
    grid on;

    nexttile;
    plot(P.t_s,P.I_A,'LineWidth',1.0);
    ylabel('Current [A]');
    grid on;

    nexttile;
    plot(P.t_s,100*P.SOC,'LineWidth',1.0);
    hold on;
    plot(P.t_s,100*P.SOC_cycle_centered,'--','LineWidth',1.0);
    yline(100*model.socMin,'--','model SOC min');
    yline(100*model.socMax,'--','model SOC max');

    W = WindowSummary(WindowSummary.CaseID == P.case_id,:);
    for iw = 1:height(W)
        xline(W.CenterTime_s(iw),'--', ...
            sprintf('%.0f%%',100*W.TargetSOC(iw)));
    end

    xlabel('Time [s]');
    ylabel('SOC [%]');
    legend('Backward Coulomb count','Cycle-centered selector', ...
        'Location','best');
    grid on;

    figureFiles(ip) = fullfile(resultsDir, ...
        "EXT2_B1_2A_"+P.case_id+"_SOC_preflight_v1.png");

    try
        exportgraphics(f,figureFiles(ip),'Resolution',180);
    catch ME
        warning('EXT2:B12A:PlotExport', ...
            'Could not export %s: %s',char(P.case_id),ME.message);
    end
    close(f);
end

%% ------------------------------------------------------------------------
% 7. PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);
[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetAuditFile = fullfile( ...
    resultsDir,'EXT2_B1_2A_protected_asset_audit_v1.csv');
writetable(AssetAudit,assetAuditFile);

if ~assetsUnchanged
    error('EXT2:B12A:ProtectedAssetChanged', ...
        'A protected frozen/EXT1 asset changed during B1-2A. STOP.');
end

%% ------------------------------------------------------------------------
% 8. PASS / FAIL DECISION
% -------------------------------------------------------------------------
sourceCountPass = height(ProfileSummary) == 6;
allTimebasePass = all(ProfileSummary.TimebasePass);
allPeriodPass = all(ProfileSummary.PeriodPass);
allAnchorPass = all(ProfileSummary.AnchorPass);
allCVTailPass = all(ProfileSummary.CVTailPass);
allChargeDirectionPass = all(ProfileSummary.ChargeDirectionPass);
allACPass = all(ProfileSummary.ACConfirmationPass);
allModelStartPass = all(ProfileSummary.ModelStartPass);

windowCountPass = height(WindowSummary) == 18;
allWindowsReady = all(WindowSummary.WindowReady);

overallPass = ...
    sourceCountPass && allTimebasePass && allPeriodPass && ...
    allAnchorPass && allCVTailPass && allChargeDirectionPass && ...
    allACPass && allModelStartPass && windowCountPass && ...
    allWindowsReady && assetsUnchanged;

reportFile = fullfile(resultsDir,'EXT2_B1_2A_pass_fail_v1.txt');
fid = fopen(reportFile,'w');
if fid < 0
    error('EXT2:B12A:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-B1-2A Real-Voltage SOC/State Preflight v1\n");
fprintf(fid,"==================================================\n\n");
fprintf(fid,"No measured-voltage parameter fitting performed.\n");
fprintf(fid,"No R2/tau2 adaptation performed.\n\n");
fprintf(fid,"Frozen qRefAh = %.9f Ah\n",model.qRefAh);
fprintf(fid,"Frozen model SOC support = %.6f ... %.6f\n", ...
    model.socMin,model.socMax);
fprintf(fid,"SOC anchor definition = 4.2 V CV near 50 mA => SOC=1\n");
fprintf(fid,"Absolute SOC reconstruction = backward Coulomb count from terminal anchor\n");
fprintf(fid,"OCV inversion = NOT USED\n\n");

fprintf(fid,"Source count 6/6                  = %s\n",pass_text(sourceCountPass));
fprintf(fid,"Timebase integrity all profiles   = %s\n",pass_text(allTimebasePass));
fprintf(fid,"Period sanity all profiles        = %s\n",pass_text(allPeriodPass));
fprintf(fid,"Terminal SOC=1 anchor all profiles= %s\n",pass_text(allAnchorPass));
fprintf(fid,"CV-tail stability all profiles    = %s\n",pass_text(allCVTailPass));
fprintf(fid,"Charge-direction sanity           = %s\n",pass_text(allChargeDirectionPass));
fprintf(fid,"AC confirmation all profiles      = %s\n",pass_text(allACPass));
fprintf(fid,"Model-start at SOC min            = %s\n",pass_text(allModelStartPass));
fprintf(fid,"Target window count 18/18         = %s\n",pass_text(windowCountPass));
fprintf(fid,"All 30/50/70%% windows ready       = %s\n",pass_text(allWindowsReady));
fprintf(fid,"Protected assets unchanged        = %s\n",pass_text(assetsUnchanged));
fprintf(fid,"\nOVERALL B1-2A                     = %s\n",pass_text(overallPass));

if overallPass
    fprintf(fid,"\nDecision: B1-2B real-voltage R2/tau2 target-consistency scan may proceed.\n");
    fprintf(fid,"Claim boundary: SOC/state preflight only; no real-voltage target claim yet.\n");
else
    fprintf(fid,"\nDecision: STOP before B1-2B. Review failed anchor/window/state criteria.\n");
end
fclose(fid);

runBundleFile = fullfile(resultsDir,'EXT2_B1_2A_run_bundle_v1.mat');
save(runBundleFile, ...
    'cfg','profileDefs','profileData','ProfileSummary','WindowSummary', ...
    'modelFile','profileRoot','assetsUnchanged','overallPass');

%% ------------------------------------------------------------------------
% 9. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-B1-2A COMPLETE\n");
fprintf("============================================================\n");
fprintf("Frozen sources SHA256       : 6/6 PASS\n");
fprintf("Terminal SOC=1 anchors      : %d/6 PASS\n",sum(ProfileSummary.AnchorPass));
fprintf("Model-start @ frozen socMin : %d/6 PASS\n",sum(ProfileSummary.ModelStartPass));
fprintf("Target windows ready        : %d/18 PASS\n",sum(WindowSummary.WindowReady));
fprintf("Protected assets unchanged  : %s\n",pass_text(assetsUnchanged));
fprintf("OVERALL B1-2A               : %s\n",pass_text(overallPass));

fprintf("\nBackward-start SOC diagnostic:\n");
for ip = 1:height(ProfileSummary)
    fprintf("  %-18s : % .4f\n", ...
        ProfileSummary.CaseID(ip),ProfileSummary.BackwardStartSOC(ip));
end

fprintf("\nTarget-window centers / readiness:\n");
for iw = 1:height(WindowSummary)
    fprintf("  %-18s SOC %.0f%% | t=%8.1f s | raw SOC %.3f...%.3f | cycles=%.2f | history=%.1f tau2 | %s\n", ...
        WindowSummary.CaseID(iw),100*WindowSummary.TargetSOC(iw), ...
        WindowSummary.CenterTime_s(iw), ...
        WindowSummary.RawSOCMin(iw),WindowSummary.RawSOCMax(iw), ...
        WindowSummary.CyclesInWindow(iw), ...
        WindowSummary.HistoryTau2Multiple(iw), ...
        pass_text(WindowSummary.WindowReady(iw)));
end

if overallPass
    fprintf("\nDecision: B1-2B may proceed.\n");
    fprintf("No real-voltage R2/tau2 consistency/adaptation claim has been made.\n");
else
    fprintf("\nDecision: STOP before B1-2B and inspect failed criteria.\n");
end

fprintf("\nSaved under:\n%s\n\n",resultsDir);


%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function d = make_profile_def(caseID,band,ampGroup,sourceFileID,relativePath,expectedSHA256,expectedPeriod)
d = struct();
d.case_id = string(caseID);
d.band = string(band);
d.amplitude_group = string(ampGroup);
d.source_file_id = string(sourceFileID);
d.relative_path = string(relativePath);
d.expected_sha256 = lower(string(expectedSHA256));
d.expected_period_s = expectedPeriod;
end


function D = load_ngu_uiv_full(filePath)
% Read-only NGU201 CSV parser for Timestamp, U1[V], I1[A].
% No smoothing, no interpolation, no rewriting.
% Invalid data lines are excluded; all retained timestamps must remain
% strictly increasing.

txt = fileread(filePath);
lines = splitlines(string(txt));

if isempty(lines)
    error('EXT2:B12A:EmptyProfile','Empty profile: %s',char(filePath));
end

if strlength(lines(1)) > 0
    lines(1) = erase(lines(1),string(char(65279)));
end

mask = contains(lower(lines),'timestamp') & ...
       contains(lower(lines),'u1[v]') & ...
       contains(lower(lines),'i1[a]');
headerIdx = find(mask,1,'first');

if isempty(headerIdx)
    error('EXT2:B12A:NGUHeaderMissing', ...
        'NGU header not found: %s',char(filePath));
end

headers = split(lines(headerIdx),',');
headers = strtrim(erase(headers,'"'));
headers = erase(headers,string(char(65279)));

iT = find(strcmpi(headers,'Timestamp'),1);
iV = find(strcmpi(headers,'U1[V]'),1);
iI = find(strcmpi(headers,'I1[A]'),1);

if isempty(iT) || isempty(iV) || isempty(iI)
    error('EXT2:B12A:NGUColumnsMissing', ...
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
    error('EXT2:B12A:NoValidData', ...
        'Too few valid NGU rows: %s',char(filePath));
end

t = unwrap_elapsed_time(tRaw);
t = t-t(1);

if any(diff(t) <= 0)
    error('EXT2:B12A:NonMonotonicTime', ...
        'Retained NGU timestamps are not strictly increasing: %s',char(filePath));
end

D = struct();
D.t_s = t(:);
D.V_V = V(:);
D.I_A = I(:);
D.valid_fraction = sum(valid)/max(1,n);
end


function t = parse_time_token(token)
s = strtrim(erase(string(token),'"'));
t = NaN;

if contains(s,' ')
    partsSpace = split(s);
    s = partsSpace(end);
end

parts = split(s,':');

if numel(parts) == 3
    h = str2double(parts(1));
    m = str2double(parts(2));
    sec = str2double(parts(3));
    if all(isfinite([h m sec]))
        t = 3600*h + 60*m + sec;
    end
elseif numel(parts) == 2
    m = str2double(parts(1));
    sec = str2double(parts(2));
    if all(isfinite([m sec]))
        t = 60*m + sec;
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
if numel(tOut) < 2
    return
end

offset = 0;

for k = 2:numel(tOut)
    current = tOut(k)+offset;
    prev = tOut(k-1);

    if current <= prev
        candidates = [60,3600,24*3600];
        added = NaN;

        for c = candidates
            if current+c > prev && abs((current+c)-prev) < 10
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


function T = dominant_period_fft(x,dt)
x = x(:)-mean(x);
N = numel(x);

if N < 8 || sqrt(mean(x.^2)) < 1e-9
    T = NaN;
    return
end

Y = fft(x);
P = abs(Y).^2;
f = (0:N-1).'/(N*dt);
nPos = floor(N/2)+1;
P = P(2:nPos);
f = f(2:nPos);

[~,idx] = max(P);
T = 1/f(idx);
end


function h = sha256_file(filePath)
% Windows-first SHA-256 with Java fallback. Read-only.

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
    error('EXT2:B12A:HashOpenFailed', ...
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
    error('EXT2:B12A:HashFailed', ...
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
    error('EXT2:B12A:AssetSnapshotMismatch', ...
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


function s = pass_text(tf)
if tf
    s = 'PASS';
else
    s = 'FAIL';
end
end
