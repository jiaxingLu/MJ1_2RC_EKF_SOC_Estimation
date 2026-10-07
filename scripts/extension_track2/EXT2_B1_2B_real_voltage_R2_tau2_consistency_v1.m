% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_B1_2B_real_voltage_R2_tau2_consistency_v1.m
% MJ1 2RC-EKF EXT2-B1
% B1-2B Real-Voltage R2/tau2 Target-Consistency Scan v1
%
% PURPOSE
%   Test whether measured NGU201 terminal voltage from the six frozen
%   MID/SLOW DC-AC experiments points to a stable multiplicative correction
%   for the frozen SOC-dependent R2/tau2 branch.
%
% THIS IS AN OFFLINE SHADOW SCAN.
% THIS SCRIPT DOES NOT MODIFY OR ONLINE-ADAPT THE FROZEN EKF.
% THIS SCRIPT DOES NOT MODIFY BAYESIAN R0 v1.0 OR EXT1 K4.
%
% Frozen 2RC sign/equations:
%   I > 0 = charge
%   v1(k+1) = a1*v1(k) + R1*(1-a1)*I(k)
%   v2(k+1) = a2*v2(k) + R2*(1-a2)*I(k)
%   Vhat(k)  = OCV(SOC(k)) + v1(k) + v2(k) + R0(SOC(k))*I(k)
%
% Target parameterization:
%   R2    -> alpha_R2   * R2_frozen(SOC)
%   tau2  -> alpha_tau2 * tau2_frozen(SOC)
%
% All other model quantities remain frozen.
%
% Primary objective:
%   absolute measured-voltage RMSE in each 700 s target window.
%
% Robustness diagnostic:
%   centered-residual RMSE, where only the residual window mean is removed.
%   This is NOT used to replace the primary objective. It tests whether the
%   selected R2/tau2 target is driven mainly by absolute baseline mismatch.
%
% B1-2B consistency dimensions:
%   1) frequency consistency: MID vs SLOW
%   2) amplitude consistency: A vs B vs DEV
%   3) SOC smoothness: 30 -> 50 -> 70%
%   4) objective robustness: absolute vs centered optimum
%
% PRE-REGISTERED GRID / THRESHOLDS
%   alpha_R2, alpha_tau2 = 0.70 : 0.005 : 1.30
%   amplitude consistency tolerance = 0.10 alpha
%   frequency consistency tolerance = 0.10 alpha
%   adjacent-SOC smoothness tolerance = 0.15 alpha
%   absolute-vs-centered optimum tolerance = 0.10 alpha
%   local Jacobian cond(J) <= 20
%   boundary-risk margin = 0.01 alpha
%
% Material-benefit diagnostic for B2:
%   median absolute RMSE improvement >= 1 mV
%   AND median relative RMSE improvement >= 5%
%
% These benefit thresholds do NOT define target consistency. They only
% decide whether a consistent target is worth carrying into B2.
%
% STATE HANDLING
%   B1-2A terminal SOC=1 anchored backward-Coulomb-counted trajectories
%   are reused. No OCV inversion is performed.
%
%   A new "raw-SOC safe start" is chosen for each profile so that all
%   subsequent samples used by the shadow model remain inside the frozen
%   LUT support [model.socMin, model.socMax]. Thus no parameter clamp below
%   the validated range is permitted to influence the fit.
%
%   v1 and v2 are initialized to zero at this safe start. The earliest
%   target window must have >=15 times the LARGEST scanned tau2 of history.
%   exp(-15) ~ 3.1e-7, so initial RC-state influence is negligible.
%
% OUTPUT POLICY
%   New outputs only under EXT2_dynamic_parameter_identifiability/results.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-2B | Real-Voltage R2/tau2 Consistency Scan v1\n");
fprintf(" Measured NGU voltage | Full frozen 2RC shadow model | No adaptation\n");
fprintf("============================================================\n\n");
fprintf("MATLAB table compatibility: legacy char/cell VariableNames mode\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));
if strlength(scriptDir) == 0
    error('EXT2:B12B:RunAsFile', ...
        'Run this script from its saved .m file, not from an unsaved editor buffer.');
end

ext2Dir = scriptDir;
resultsDir = fullfile(ext2Dir,'results');

if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end

expectedExt2Name = "EXT2_dynamic_parameter_identifiability";
[~,actualExt2Name] = fileparts(ext2Dir);
if ~strcmpi(string(actualExt2Name),expectedExt2Name)
    error('EXT2:B12B:WrongFolder', ...
        'This script must live inside %s. Current folder: %s', ...
        char(expectedExt2Name),char(ext2Dir));
end

cfg.repoRoot = ...
    "<REPO_ROOT>";
cfg.githubRemote = ...
    "https://github.com/jiaxingLu/MJ1_2RC_EKF_SOC_Estimation";

repoMatlab = fullfile(cfg.repoRoot,'matlab');
modelFile = fullfile(cfg.repoRoot,'data','mj1_v02_model.mat');

b12aBundleFile = fullfile( ...
    resultsDir,'EXT2_B1_2A_run_bundle_v1.mat');

required = { ...
    modelFile, ...
    b12aBundleFile, ...
    fullfile(repoMatlab,'mj1_load_model.m'), ...
    fullfile(repoMatlab,'mj1_interp_params.m'), ...
    fullfile(repoMatlab,'mj1_state_transition.m'), ...
    fullfile(repoMatlab,'mj1_measurement.m')};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:B12B:MissingInput', ...
            'Required frozen/B1-2A input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

B12A = load(b12aBundleFile);

requiredBundleFields = { ...
    'cfg','profileDefs','profileData','ProfileSummary','WindowSummary', ...
    'modelFile','profileRoot','assetsUnchanged','overallPass'};

missingBundleFields = requiredBundleFields( ...
    ~cellfun(@(f) isfield(B12A,f),requiredBundleFields));

if ~isempty(missingBundleFields)
    error('EXT2:B12B:B12ABundleContract', ...
        'B1-2A run bundle missing field(s): %s', ...
        strjoin(missingBundleFields,', '));
end

if ~logical(B12A.overallPass)
    error('EXT2:B12B:B12ANotPassed', ...
        'B1-2A did not PASS. B1-2B is not allowed to run.');
end

profileData = B12A.profileData;
profileDefs = B12A.profileDefs;
ProfileSummary = B12A.ProfileSummary;
WindowSummary = B12A.WindowSummary;
profileRoot = string(B12A.profileRoot);

% MATLAB compatibility preflight.
try
    Tcompat = table((1:2).',(3:4).', ...
        'VariableNames',{'A','B'}); %#ok<NASGU>
catch ME
    error('EXT2:B12B:TableCompatibility', ...
        'MATLAB table compatibility preflight failed: %s',ME.message);
end

fprintf("EXT2 work folder : %s\n",ext2Dir);
fprintf("Results only     : %s\n",resultsDir);
fprintf("Local Git repo   : %s\n",cfg.repoRoot);
fprintf("GitHub remote    : %s\n",cfg.githubRemote);
fprintf("Frozen model     : %s\n",modelFile);
fprintf("B1-2A bundle     : %s\n",b12aBundleFile);
fprintf("B1-2A status     : PASS\n\n");

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
% 2. PROSPECTIVE B1-2B CONFIGURATION
% -------------------------------------------------------------------------
cfg.alphaGrid = (0.70:0.005:1.30).';
cfg.alphaMin = cfg.alphaGrid(1);
cfg.alphaMax = cfg.alphaGrid(end);
cfg.alphaStep = median(diff(cfg.alphaGrid));

cfg.boundaryMarginAlpha = 0.01;
cfg.consistencyTolAmplitude = 0.10;
cfg.consistencyTolFrequency = 0.10;
cfg.socSmoothnessTol = 0.15;
cfg.absCenteredTol = 0.10;
cfg.maxCondJ = 20;

cfg.minHistoryAtMaxTauMultiple = 15;
cfg.jacobianTauStep = 0.002;
cfg.assumedSigmaV_V = 1e-3; % engineering normalization only

cfg.materialBenefitMedian_mV = 1.0;
cfg.materialBenefitMedian_pct = 5.0;

cfg.basinDeltaRMSE_mV = 1.0;

% Fail-fast grid contract.
[~,idxNomR] = min(abs(cfg.alphaGrid-1));
[~,idxNomT] = min(abs(cfg.alphaGrid-1));

if abs(cfg.alphaGrid(idxNomR)-1) > 1e-12 || ...
   abs(cfg.alphaGrid(idxNomT)-1) > 1e-12
    error('EXT2:B12B:NominalNotOnGrid', ...
        'alpha=1 must be exactly represented in the scan grid.');
end

fprintf("alpha_R2 / alpha_tau2 grid: %.3f ... %.3f, step %.3f\n", ...
    cfg.alphaMin,cfg.alphaMax,cfg.alphaStep);
fprintf("Grid size per window      : %d x %d = %d\n", ...
    numel(cfg.alphaGrid),numel(cfg.alphaGrid),numel(cfg.alphaGrid)^2);
fprintf("Target windows            : %d\n\n",height(WindowSummary));

%% ------------------------------------------------------------------------
% 3. SOURCE IDENTITY + B1-2A SCHEMA CONTRACT
% -------------------------------------------------------------------------
if numel(profileData) ~= 6 || height(WindowSummary) ~= 18
    error('EXT2:B12B:B12ACountMismatch', ...
        'Expected 6 profiles and 18 B1-2A windows.');
end

requiredProfileFields = { ...
    'case_id','band','amplitude_group','source_file_id','source_file', ...
    'source_sha256','t_s','V_V','I_A','SOC','SOC_cycle_centered', ...
    'idx_anchor','idx_model_start','ac_safe_start_s','ac_safe_end_s','period_s'};

for ip = 1:numel(profileData)
    missingFields = requiredProfileFields( ...
        ~cellfun(@(f) isfield(profileData(ip),f),requiredProfileFields));

    if ~isempty(missingFields)
        error('EXT2:B12B:ProfileDataContract', ...
            'Profile %s missing field(s): %s', ...
            char(profileData(ip).case_id),strjoin(missingFields,', '));
    end

    if ~isfile(profileData(ip).source_file)
        error('EXT2:B12B:FrozenSourceMissing', ...
            'Frozen source missing: %s',char(profileData(ip).source_file));
    end

    shaNow = sha256_file(profileData(ip).source_file);
    if ~strcmpi(shaNow,char(profileData(ip).source_sha256))
        error('EXT2:B12B:FrozenSourceHashMismatch', ...
            'Frozen source SHA-256 changed for %s. STOP.', ...
            char(profileData(ip).case_id));
    end
end

requiredWindowVars = { ...
    'CaseID','Band','AmplitudeGroup','TargetSOC','CenterTime_s', ...
    'WindowStart_s','WindowEnd_s','WindowDuration_s','WindowReady'};

missingWindowVars = setdiff( ...
    requiredWindowVars,WindowSummary.Properties.VariableNames);

if ~isempty(missingWindowVars)
    error('EXT2:B12B:WindowTableContract', ...
        'B1-2A WindowSummary missing variable(s): %s', ...
        strjoin(missingWindowVars,', '));
end

if ~all(WindowSummary.WindowReady)
    error('EXT2:B12B:WindowNotReady', ...
        'At least one B1-2A target window is not ready.');
end

fprintf("Frozen source identity       : 6/6 SHA256 PASS\n");
fprintf("B1-2A downstream field check : PASS\n\n");

%% ------------------------------------------------------------------------
% 4. MAIN REAL-VOLTAGE SCAN
% -------------------------------------------------------------------------
nA = numel(cfg.alphaGrid);
nP = numel(profileData);

optRows = struct([]);
safeStartRows = struct([]);
SurfaceBundle = struct([]);

io = 0;
isr = 0;
isb = 0;

fprintf("Running measured-voltage scans ...\n\n");

for ip = 1:nP

    P = profileData(ip);
    caseID = P.case_id;

    Wp = WindowSummary(WindowSummary.CaseID == caseID,:);
    Wp = sortrows(Wp,'TargetSOC');

    if height(Wp) ~= 3
        error('EXT2:B12B:TargetWindowCount', ...
            'Expected 3 target windows for %s.',char(caseID));
    end

    t = P.t_s(:);
    Vmeas = P.V_V(:);
    I = P.I_A(:);
    soc = P.SOC(:);

    maxWindowEnd = max(Wp.WindowEnd_s);
    earliestWindowStart = min(Wp.WindowStart_s);

    idxMax = find(t <= maxWindowEnd,1,'last');
    idxEarliestWindow = find(t >= earliestWindowStart,1,'first');

    if isempty(idxMax) || isempty(idxEarliestWindow)
        error('EXT2:B12B:WindowIndexFailure', ...
            'Could not locate target-window indices for %s.',char(caseID));
    end

    % Raw-SOC safe start: after the LAST sample below model.socMin in the
    % entire simulation horizon. Also reject any later sample above socMax.
    horizonIdx = (1:idxMax).';

    below = horizonIdx(isfinite(soc(horizonIdx)) & ...
        soc(horizonIdx) < model.socMin);

    if isempty(below)
        idxSafeStart = find(isfinite(soc(1:idxMax)),1,'first');
    else
        idxSafeStart = below(end)+1;
    end

    if isempty(idxSafeStart) || idxSafeStart >= idxEarliestWindow
        error('EXT2:B12B:NoSafeWarmup', ...
            'No raw-SOC-safe warmup start exists before the earliest window for %s.', ...
            char(caseID));
    end

    supportSegment = soc(idxSafeStart:idxMax);

    rawSupportPass = ...
        all(isfinite(supportSegment)) && ...
        all(supportSegment >= model.socMin) && ...
        all(supportSegment <= model.socMax);

    if ~rawSupportPass
        error('EXT2:B12B:RawSOCSupportViolation', ...
            'Raw SOC leaves frozen LUT support after safe start for %s.', ...
            char(caseID));
    end

    safeStartTime = t(idxSafeStart);
    safeStartSOC = soc(idxSafeStart);

    % History margin uses the LARGEST scanned tau2.
    historyPassAll = true;
    historyMinMultiple = Inf;

    for iw = 1:height(Wp)
        targetSOC = Wp.TargetSOC(iw);
        pTarget = mj1_interp_params(model,targetSOC);
        maxTau2 = cfg.alphaMax*pTarget.tau2;
        hist_s = Wp.WindowStart_s(iw)-safeStartTime;
        histMult = hist_s/maxTau2;
        historyMinMultiple = min(historyMinMultiple,histMult);
        historyPassAll = historyPassAll && ...
            histMult >= cfg.minHistoryAtMaxTauMultiple;
    end

    if ~historyPassAll
        error('EXT2:B12B:HistoryAtMaxTauInsufficient', ...
            ['Profile %s has only %.3f x max-scanned tau2 before a target window; ' ...
             'required %.1f. STOP.'], ...
            char(caseID),historyMinMultiple,cfg.minHistoryAtMaxTauMultiple);
    end

    % Full shadow segment.
    idxSeg = (idxSafeStart:idxMax).';
    tSeg = t(idxSeg);
    ISeg = I(idxSeg);
    socSeg = soc(idxSeg);
    VmeasSeg = Vmeas(idxSeg);

    % Interpolate all frozen parameters on the externally anchored SOC
    % trajectory. No parameter extrapolation/clamp should occur because
    % rawSupportPass was already enforced.
    OCV = interp1(model.soc,model.ocv,socSeg,'linear');
    R0 = interp1(model.soc,model.R0,socSeg,'linear');
    R1 = interp1(model.soc,model.R1,socSeg,'linear');
    C1 = interp1(model.soc,model.C1,socSeg,'linear');
    R2 = interp1(model.soc,model.R2,socSeg,'linear');
    C2 = interp1(model.soc,model.C2,socSeg,'linear');

    if any(~isfinite(OCV)) || any(~isfinite(R0)) || ...
       any(~isfinite(R1)) || any(~isfinite(C1)) || ...
       any(~isfinite(R2)) || any(~isfinite(C2))
        error('EXT2:B12B:FrozenInterpolationNaN', ...
            'Frozen parameter interpolation returned NaN for %s.',char(caseID));
    end

    tau1 = R1.*C1;
    tau2 = R2.*C2;

    % v1 frozen branch. Zero initialization at raw-SOC-safe start.
    v1 = simulate_rc_branch_variable( ...
        tSeg,ISeg,R1,tau1,1.0);

    baseV = OCV + v1 + R0.*ISeg;

    % Map the three B1-2A windows into the segment.
    winLocal = cell(3,1);

    for iw = 1:3
        mask = ...
            tSeg >= Wp.WindowStart_s(iw)-1e-9 & ...
            tSeg <= Wp.WindowEnd_s(iw)+1e-9;
        winLocal{iw} = find(mask);

        if numel(winLocal{iw}) < 600
            error('EXT2:B12B:WindowSampleCount', ...
                'Too few samples in %s SOC %.0f%% window.', ...
                char(caseID),100*Wp.TargetSOC(iw));
        end
    end

    AbsMaps = cell(3,1);
    CenteredMaps = cell(3,1);

    for iw = 1:3
        AbsMaps{iw} = nan(nA,nA);
        CenteredMaps{iw} = nan(nA,nA);
    end

    % Sweep alpha_tau2. For each alpha_tau2, v2 is linear in alpha_R2,
    % so the full alpha_R2 row is obtained analytically/vectorially.
    for it = 1:nA

        aTau = cfg.alphaGrid(it);

        zFull = simulate_rc_branch_variable( ...
            tSeg,ISeg,R2,tau2,aTau); % unit alpha_R2

        for iw = 1:3
            idxW = winLocal{iw};

            r0 = baseV(idxW)-VmeasSeg(idxW);
            z = zFull(idxW);

            C0 = mean(r0.^2);
            B0 = 2*mean(r0.*z);
            A0 = mean(z.^2);

            mseAbs = C0 + B0*cfg.alphaGrid + A0*(cfg.alphaGrid.^2);
            mseAbs = max(mseAbs,0);
            AbsMaps{iw}(it,:) = sqrt(mseAbs).'*1000;

            r0c = r0-mean(r0);
            zc = z-mean(z);

            Cc = mean(r0c.^2);
            Bc = 2*mean(r0c.*zc);
            Ac = mean(zc.^2);

            mseCtr = Cc + Bc*cfg.alphaGrid + Ac*(cfg.alphaGrid.^2);
            mseCtr = max(mseCtr,0);
            CenteredMaps{iw}(it,:) = sqrt(mseCtr).'*1000;
        end
    end

    % Extract optimum / geometry for each target window.
    for iw = 1:3

        targetSOC = Wp.TargetSOC(iw);
        absMap = AbsMaps{iw};
        ctrMap = CenteredMaps{iw};

        [bestAbsRMSE,linearAbs] = min(absMap(:));
        [iTauAbs,iRAbs] = ind2sub(size(absMap),linearAbs);

        bestAlphaR2 = cfg.alphaGrid(iRAbs);
        bestAlphaTau2 = cfg.alphaGrid(iTauAbs);

        [bestCtrRMSE,linearCtr] = min(ctrMap(:));
        [iTauCtr,iRCtr] = ind2sub(size(ctrMap),linearCtr);

        bestCtrAlphaR2 = cfg.alphaGrid(iRCtr);
        bestCtrAlphaTau2 = cfg.alphaGrid(iTauCtr);

        nominalRMSE = absMap(idxNomT,idxNomR);
        nominalCtrRMSE = ctrMap(idxNomT,idxNomR);

        improvement_mV = nominalRMSE-bestAbsRMSE;
        if nominalRMSE > eps
            improvement_pct = 100*improvement_mV/nominalRMSE;
        else
            improvement_pct = 0;
        end

        % Reconstruct best absolute prediction / residual.
        zBestFull = simulate_rc_branch_variable( ...
            tSeg,ISeg,R2,tau2,bestAlphaTau2);

        idxW = winLocal{iw};
        VhatBest = baseV(idxW) + bestAlphaR2*zBestFull(idxW);
        resid = VhatBest-VmeasSeg(idxW);

        bestMAE_mV = mean(abs(resid))*1000;
        bestMaxAbs_mV = max(abs(resid))*1000;
        residualBias_mV = mean(resid)*1000;

        % Local Jacobian at best absolute optimum.
        h = cfg.jacobianTauStep;

        if bestAlphaTau2-h <= 0
            error('EXT2:B12B:JacobianTauStep', ...
                'Invalid local alpha_tau2 finite-difference step.');
        end

        zPlus = simulate_rc_branch_variable( ...
            tSeg,ISeg,R2,tau2,bestAlphaTau2+h);
        zMinus = simulate_rc_branch_variable( ...
            tSeg,ISeg,R2,tau2,bestAlphaTau2-h);

        dVdR = zBestFull(idxW);
        dVdTau = bestAlphaR2 * ...
            (zPlus(idxW)-zMinus(idxW))/(2*h);

        J = [dVdR,dVdTau];
        [condJ,jacCos,sigmaR1mV,sigmaTau1mV] = ...
            jacobian_metrics(J,cfg.assumedSigmaV_V);

        Jc = J-mean(J,1);
        [condJCentered,~,~,~] = ...
            jacobian_metrics(Jc,cfg.assumedSigmaV_V);

        boundaryRisk = ...
            bestAlphaR2 <= cfg.alphaMin+cfg.boundaryMarginAlpha || ...
            bestAlphaR2 >= cfg.alphaMax-cfg.boundaryMarginAlpha || ...
            bestAlphaTau2 <= cfg.alphaMin+cfg.boundaryMarginAlpha || ...
            bestAlphaTau2 >= cfg.alphaMax-cfg.boundaryMarginAlpha;

        objectiveDeltaR2 = abs(bestAlphaR2-bestCtrAlphaR2);
        objectiveDeltaTau2 = abs(bestAlphaTau2-bestCtrAlphaTau2);
        objectiveRobustPass = ...
            objectiveDeltaR2 <= cfg.absCenteredTol && ...
            objectiveDeltaTau2 <= cfg.absCenteredTol;

        geometryPass = isfinite(condJ) && condJ <= cfg.maxCondJ;

        % 1 mV basin width diagnostic. Not a hard PASS criterion.
        basinMask = absMap <= bestAbsRMSE+cfg.basinDeltaRMSE_mV;
        [iTauB,iRB] = find(basinMask);

        if isempty(iTauB)
            basinWidthR2 = NaN;
            basinWidthTau2 = NaN;
        else
            basinWidthR2 = ...
                max(cfg.alphaGrid(iRB))-min(cfg.alphaGrid(iRB));
            basinWidthTau2 = ...
                max(cfg.alphaGrid(iTauB))-min(cfg.alphaGrid(iTauB));
        end

        io = io+1;
        optRows(io).CaseID = caseID; %#ok<SAGROW>
        optRows(io).GroupKey = group_key(caseID);
        optRows(io).Band = P.band;
        optRows(io).AmplitudeGroup = P.amplitude_group;
        optRows(io).TargetSOC = targetSOC;
        optRows(io).SafeStartTime_s = safeStartTime;
        optRows(io).SafeStartSOC = safeStartSOC;
        optRows(io).HistoryMinAtMaxTauMultiple = historyMinMultiple;
        optRows(io).BestAlphaR2 = bestAlphaR2;
        optRows(io).BestAlphaTau2 = bestAlphaTau2;
        optRows(io).BestRMSE_mV = bestAbsRMSE;
        optRows(io).NominalRMSE_mV = nominalRMSE;
        optRows(io).Improvement_mV = improvement_mV;
        optRows(io).Improvement_pct = improvement_pct;
        optRows(io).BestMAE_mV = bestMAE_mV;
        optRows(io).BestMaxAbs_mV = bestMaxAbs_mV;
        optRows(io).ResidualBias_mV = residualBias_mV;
        optRows(io).CenteredBestAlphaR2 = bestCtrAlphaR2;
        optRows(io).CenteredBestAlphaTau2 = bestCtrAlphaTau2;
        optRows(io).CenteredBestRMSE_mV = bestCtrRMSE;
        optRows(io).CenteredNominalRMSE_mV = nominalCtrRMSE;
        optRows(io).AbsVsCenteredDeltaR2 = objectiveDeltaR2;
        optRows(io).AbsVsCenteredDeltaTau2 = objectiveDeltaTau2;
        optRows(io).ObjectiveRobustPass = objectiveRobustPass;
        optRows(io).CondJ = condJ;
        optRows(io).CondJCentered = condJCentered;
        optRows(io).JacobianCosine = jacCos;
        optRows(io).SigmaAlphaR2_1mV = sigmaR1mV;
        optRows(io).SigmaAlphaTau2_1mV = sigmaTau1mV;
        optRows(io).Basin1mVWidthR2 = basinWidthR2;
        optRows(io).Basin1mVWidthTau2 = basinWidthTau2;
        optRows(io).BoundaryRisk = boundaryRisk;
        optRows(io).GeometryPass = geometryPass;
        optRows(io).NumericallyFinite = ...
            all(isfinite([ ...
            bestAlphaR2,bestAlphaTau2,bestAbsRMSE,nominalRMSE, ...
            condJ,jacCos,sigmaR1mV,sigmaTau1mV]));

        isb = isb+1;
        SurfaceBundle(isb).CaseID = caseID; %#ok<SAGROW>
        SurfaceBundle(isb).Band = P.band;
        SurfaceBundle(isb).TargetSOC = targetSOC;
        SurfaceBundle(isb).AlphaGrid = cfg.alphaGrid;
        SurfaceBundle(isb).AbsoluteRMSE_mV = absMap;
        SurfaceBundle(isb).CenteredRMSE_mV = ctrMap;
    end

    isr = isr+1;
    safeStartRows(isr).CaseID = caseID; %#ok<SAGROW>
    safeStartRows(isr).Band = P.band;
    safeStartRows(isr).SafeStartTime_s = safeStartTime;
    safeStartRows(isr).SafeStartSOC = safeStartSOC;
    safeStartRows(isr).RawSupportPass = rawSupportPass;
    safeStartRows(isr).MinHistoryAtMaxTauMultiple = historyMinMultiple;
    safeStartRows(isr).HistoryPass = historyPassAll;

    fprintf("%-18s | %-4s | safe start SOC %.4f @ %.1f s | min history %.2f x max tau2 | PASS\n", ...
        caseID,P.band,safeStartSOC,safeStartTime,historyMinMultiple);
end

fprintf("\n");

OptimumSummary = struct2table(optRows);
SafeStartSummary = struct2table(safeStartRows);

%% ------------------------------------------------------------------------
% 5. CROSS-PROFILE CONSISTENCY TABLES
% -------------------------------------------------------------------------
% 5A. Amplitude consistency: A/B/DEV within same band and SOC.
ampRows = struct([]);
ia = 0;

bands = ["MID","SLOW"];
socTargets = sort(unique(OptimumSummary.TargetSOC));

for ib = 1:numel(bands)
    for iz = 1:numel(socTargets)

        mask = OptimumSummary.Band == bands(ib) & ...
            abs(OptimumSummary.TargetSOC-socTargets(iz)) < 1e-12;

        T = OptimumSummary(mask,:);

        if height(T) ~= 3
            error('EXT2:B12B:AmplitudeGroupCount', ...
                'Expected 3 amplitude groups for %s SOC %.0f%%.', ...
                char(bands(ib)),100*socTargets(iz));
        end

        rangeR = max(T.BestAlphaR2)-min(T.BestAlphaR2);
        rangeTau = max(T.BestAlphaTau2)-min(T.BestAlphaTau2);
        pass = ...
            rangeR <= cfg.consistencyTolAmplitude && ...
            rangeTau <= cfg.consistencyTolAmplitude;

        ia = ia+1;
        ampRows(ia).Band = bands(ib); %#ok<SAGROW>
        ampRows(ia).TargetSOC = socTargets(iz);
        ampRows(ia).AlphaR2Range = rangeR;
        ampRows(ia).AlphaTau2Range = rangeTau;
        ampRows(ia).Pass = pass;
    end
end

AmplitudeConsistency = struct2table(ampRows);

% 5B. Frequency consistency: MID vs SLOW within amplitude group and SOC.
freqRows = struct([]);
ifq = 0;
groups = ["A","B","DEV"];

for ig = 1:numel(groups)
    for iz = 1:numel(socTargets)

        mask = OptimumSummary.GroupKey == groups(ig) & ...
            abs(OptimumSummary.TargetSOC-socTargets(iz)) < 1e-12;

        T = OptimumSummary(mask,:);

        if height(T) ~= 2
            error('EXT2:B12B:FrequencyPairCount', ...
                'Expected MID/SLOW pair for group %s SOC %.0f%%.', ...
                char(groups(ig)),100*socTargets(iz));
        end

        mid = T(T.Band == "MID",:);
        slow = T(T.Band == "SLOW",:);

        if height(mid) ~= 1 || height(slow) ~= 1
            error('EXT2:B12B:FrequencyBandPair', ...
                'Could not form MID/SLOW pair for group %s.',char(groups(ig)));
        end

        dR = abs(mid.BestAlphaR2-slow.BestAlphaR2);
        dTau = abs(mid.BestAlphaTau2-slow.BestAlphaTau2);
        pass = ...
            dR <= cfg.consistencyTolFrequency && ...
            dTau <= cfg.consistencyTolFrequency;

        ifq = ifq+1;
        freqRows(ifq).GroupKey = groups(ig); %#ok<SAGROW>
        freqRows(ifq).TargetSOC = socTargets(iz);
        freqRows(ifq).DeltaAlphaR2 = dR;
        freqRows(ifq).DeltaAlphaTau2 = dTau;
        freqRows(ifq).Pass = pass;
    end
end

FrequencyConsistency = struct2table(freqRows);

% 5C. SOC smoothness: adjacent target SOCs within each profile.
socRows = struct([]);
isc = 0;

caseIDs = unique(OptimumSummary.CaseID,'stable');

for ic = 1:numel(caseIDs)

    T = OptimumSummary(OptimumSummary.CaseID == caseIDs(ic),:);
    T = sortrows(T,'TargetSOC');

    if height(T) ~= 3
        error('EXT2:B12B:SOCPointCount', ...
            'Expected 3 SOC points for %s.',char(caseIDs(ic)));
    end

    for j = 1:2
        dR = abs(T.BestAlphaR2(j+1)-T.BestAlphaR2(j));
        dTau = abs(T.BestAlphaTau2(j+1)-T.BestAlphaTau2(j));

        pass = ...
            dR <= cfg.socSmoothnessTol && ...
            dTau <= cfg.socSmoothnessTol;

        isc = isc+1;
        socRows(isc).CaseID = caseIDs(ic); %#ok<SAGROW>
        socRows(isc).SOC_From = T.TargetSOC(j);
        socRows(isc).SOC_To = T.TargetSOC(j+1);
        socRows(isc).DeltaAlphaR2 = dR;
        socRows(isc).DeltaAlphaTau2 = dTau;
        socRows(isc).Pass = pass;
    end
end

SOCSmoothness = struct2table(socRows);

%% ------------------------------------------------------------------------
% 6. DECISION LOGIC
% -------------------------------------------------------------------------
finitePass = all(OptimumSummary.NumericallyFinite);
boundaryPass = ~any(OptimumSummary.BoundaryRisk);
geometryPass = all(OptimumSummary.GeometryPass);
objectiveRobustPass = all(OptimumSummary.ObjectiveRobustPass);
amplitudePass = all(AmplitudeConsistency.Pass);
frequencyPass = all(FrequencyConsistency.Pass);
socSmoothnessPass = all(SOCSmoothness.Pass);
safeStartPass = all(SafeStartSummary.RawSupportPass) && ...
    all(SafeStartSummary.HistoryPass);

targetConsistencyPass = ...
    finitePass && boundaryPass && geometryPass && ...
    objectiveRobustPass && amplitudePass && frequencyPass && ...
    socSmoothnessPass && safeStartPass;

medianImprovement_mV = median(OptimumSummary.Improvement_mV);
medianImprovement_pct = median(OptimumSummary.Improvement_pct);

materialBenefitPass = ...
    medianImprovement_mV >= cfg.materialBenefitMedian_mV && ...
    medianImprovement_pct >= cfg.materialBenefitMedian_pct;

b2MayProceed = targetConsistencyPass && materialBenefitPass;

%% ------------------------------------------------------------------------
% 7. SAVE RESULTS
% -------------------------------------------------------------------------
optFile = fullfile(resultsDir, ...
    'EXT2_B1_2B_optimum_summary_v1.csv');
safeFile = fullfile(resultsDir, ...
    'EXT2_B1_2B_safe_start_summary_v1.csv');
ampFile = fullfile(resultsDir, ...
    'EXT2_B1_2B_amplitude_consistency_v1.csv');
freqFile = fullfile(resultsDir, ...
    'EXT2_B1_2B_frequency_consistency_v1.csv');
socFile = fullfile(resultsDir, ...
    'EXT2_B1_2B_SOC_smoothness_v1.csv');

writetable(OptimumSummary,optFile);
writetable(SafeStartSummary,safeFile);
writetable(AmplitudeConsistency,ampFile);
writetable(FrequencyConsistency,freqFile);
writetable(SOCSmoothness,socFile);

% Full cost surfaces remain in MAT to avoid a very large flat CSV.
surfaceMatFile = fullfile(resultsDir, ...
    'EXT2_B1_2B_cost_surfaces_v1.mat');
save(surfaceMatFile,'SurfaceBundle','cfg','-v7.3');

% Export SOC=50% surfaces as a compact long CSV for inspection.
surface50Rows = struct([]);
is50 = 0;

for k = 1:numel(SurfaceBundle)
    if abs(SurfaceBundle(k).TargetSOC-0.50) > 1e-12
        continue
    end

    [AT,AR] = ndgrid( ...
        SurfaceBundle(k).AlphaGrid,SurfaceBundle(k).AlphaGrid);

    nHere = numel(AR);

    idxStart = is50+1;
    idxEnd = is50+nHere;

    for q = idxStart:idxEnd
        % Struct growth is acceptable for ~88k inspection rows but the
        % vectorized table below is preferred. This loop is not used.
    end

    % vectorized accumulation in temporary table
    CaseID = repmat(SurfaceBundle(k).CaseID,nHere,1);
    Band = repmat(SurfaceBundle(k).Band,nHere,1);
    TargetSOC = repmat(SurfaceBundle(k).TargetSOC,nHere,1);
    AlphaR2 = AR(:);
    AlphaTau2 = AT(:);
    AbsoluteRMSE_mV = SurfaceBundle(k).AbsoluteRMSE_mV(:);
    CenteredRMSE_mV = SurfaceBundle(k).CenteredRMSE_mV(:);

    Ttmp = table( ...
        CaseID,Band,TargetSOC,AlphaR2,AlphaTau2, ...
        AbsoluteRMSE_mV,CenteredRMSE_mV, ...
        'VariableNames', { ...
        'CaseID','Band','TargetSOC','AlphaR2','AlphaTau2', ...
        'AbsoluteRMSE_mV','CenteredRMSE_mV'});

    if is50 == 0
        Surface50 = Ttmp;
    else
        Surface50 = [Surface50;Ttmp]; %#ok<AGROW>
    end
    is50 = is50+nHere;
end

surface50File = fullfile(resultsDir, ...
    'EXT2_B1_2B_cost_surfaces_SOC50_v1.csv');
writetable(Surface50,surface50File);

%% ------------------------------------------------------------------------
% 8. FIGURES
% -------------------------------------------------------------------------
figureFiles = strings(numel(caseIDs),1);

for ic = 1:numel(caseIDs)

    cid = caseIDs(ic);
    Tcase = OptimumSummary(OptimumSummary.CaseID == cid,:);
    Tcase = sortrows(Tcase,'TargetSOC');

    f = figure('Name',char("EXT2-B1-2B "+cid), ...
        'Visible','off');
    tiledlayout(1,3);

    for iz = 1:3
        targetSOC = Tcase.TargetSOC(iz);

        idxSurface = find(arrayfun(@(s) ...
            s.CaseID == cid && abs(s.TargetSOC-targetSOC) < 1e-12, ...
            SurfaceBundle),1);

        S = SurfaceBundle(idxSurface);

        nexttile;
        imagesc(S.AlphaGrid,S.AlphaGrid,S.AbsoluteRMSE_mV);
        axis xy;
        hold on;
        plot(Tcase.BestAlphaR2(iz),Tcase.BestAlphaTau2(iz), ...
            'wx','MarkerSize',10,'LineWidth',1.5);
        plot(1,1,'wo','MarkerSize',6,'LineWidth',1.2);
        xlabel('\alpha_{R2}');
        ylabel('\alpha_{\tau2}');
        title(sprintf('SOC %.0f%%',100*targetSOC));
        colorbar;
    end

    sgtitle(char(cid+" | absolute measured-voltage RMSE [mV]"));

    figureFiles(ic) = fullfile(resultsDir, ...
        "EXT2_B1_2B_"+cid+"_cost_maps_v1.png");

    try
        exportgraphics(f,figureFiles(ic),'Resolution',180);
    catch ME
        warning('EXT2:B12B:PlotExport', ...
            'Could not export %s: %s',char(cid),ME.message);
    end
    close(f);
end

%% ------------------------------------------------------------------------
% 9. PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);
[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetAuditFile = fullfile(resultsDir, ...
    'EXT2_B1_2B_protected_asset_audit_v1.csv');
writetable(AssetAudit,assetAuditFile);

if ~assetsUnchanged
    error('EXT2:B12B:ProtectedAssetChanged', ...
        'A protected frozen/EXT1 asset changed during B1-2B. STOP.');
end

% Protected status is also mandatory for consistency.
targetConsistencyPass = targetConsistencyPass && assetsUnchanged;
b2MayProceed = targetConsistencyPass && materialBenefitPass;

%% ------------------------------------------------------------------------
% 10. REPORT
% -------------------------------------------------------------------------
reportFile = fullfile(resultsDir,'EXT2_B1_2B_pass_fail_v1.txt');

fid = fopen(reportFile,'w');
if fid < 0
    error('EXT2:B12B:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-B1-2B Real-Voltage R2/tau2 Consistency Scan v1\n");
fprintf(fid,"========================================================\n\n");
fprintf(fid,"Offline measured-voltage shadow scan only.\n");
fprintf(fid,"No online adaptation and no frozen-model modification.\n\n");

fprintf(fid,"alpha grid = %.3f ... %.3f, step %.3f\n", ...
    cfg.alphaMin,cfg.alphaMax,cfg.alphaStep);
fprintf(fid,"amplitude consistency tol = %.3f\n",cfg.consistencyTolAmplitude);
fprintf(fid,"frequency consistency tol = %.3f\n",cfg.consistencyTolFrequency);
fprintf(fid,"SOC smoothness tol = %.3f\n",cfg.socSmoothnessTol);
fprintf(fid,"abs-vs-centered tol = %.3f\n",cfg.absCenteredTol);
fprintf(fid,"max cond(J) = %.3f\n\n",cfg.maxCondJ);

fprintf(fid,"Finite optimum/geometry         = %s\n",pass_text(finitePass));
fprintf(fid,"No boundary-risk optimum        = %s\n",pass_text(boundaryPass));
fprintf(fid,"Local geometry                  = %s\n",pass_text(geometryPass));
fprintf(fid,"Absolute-vs-centered robustness = %s\n",pass_text(objectiveRobustPass));
fprintf(fid,"Amplitude consistency           = %s\n",pass_text(amplitudePass));
fprintf(fid,"Frequency consistency           = %s\n",pass_text(frequencyPass));
fprintf(fid,"SOC smoothness                  = %s\n",pass_text(socSmoothnessPass));
fprintf(fid,"Raw-SOC safe-start/history      = %s\n",pass_text(safeStartPass));
fprintf(fid,"Protected assets unchanged      = %s\n",pass_text(assetsUnchanged));

fprintf(fid,"\nTARGET CONSISTENCY B1-2B       = %s\n", ...
    pass_text(targetConsistencyPass));

fprintf(fid,"\nMedian RMSE improvement         = %.6f mV\n",medianImprovement_mV);
fprintf(fid,"Median relative improvement     = %.6f %%\n",medianImprovement_pct);
fprintf(fid,"MATERIAL BENEFIT               = %s\n", ...
    pass_text(materialBenefitPass));

fprintf(fid,"\nB2 MAY PROCEED                 = %s\n", ...
    pass_text(b2MayProceed));

if ~targetConsistencyPass
    fprintf(fid,"\nDecision: STOP R2/tau2 online adaptation. Real-voltage target is not sufficiently consistent.\n");
elseif ~materialBenefitPass
    fprintf(fid,"\nDecision: target is consistent but material benefit is insufficient; do not proceed to online adaptation.\n");
else
    fprintf(fid,"\nDecision: B2 may proceed, subject to later robustness checks (e.g. SOC/capacity uncertainty).\n");
end

fprintf(fid,"\nClaim boundary: measured-voltage target consistency only; no online adaptation result.\n");
fclose(fid);

runBundleFile = fullfile(resultsDir, ...
    'EXT2_B1_2B_run_bundle_v1.mat');

save(runBundleFile, ...
    'cfg','OptimumSummary','SafeStartSummary', ...
    'AmplitudeConsistency','FrequencyConsistency','SOCSmoothness', ...
    'SurfaceBundle','targetConsistencyPass','materialBenefitPass', ...
    'b2MayProceed','assetsUnchanged','-v7.3');

%% ------------------------------------------------------------------------
% 11. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-B1-2B COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Per-window optima:\n");
for k = 1:height(OptimumSummary)
    fprintf("  %-18s SOC %.0f%% | aR2=%.3f aTau2=%.3f | RMSE %.3f -> %.3f mV (%+.2f%%) | centered %.3f/%.3f | condJ=%.2f | %s\n", ...
        OptimumSummary.CaseID(k), ...
        100*OptimumSummary.TargetSOC(k), ...
        OptimumSummary.BestAlphaR2(k), ...
        OptimumSummary.BestAlphaTau2(k), ...
        OptimumSummary.NominalRMSE_mV(k), ...
        OptimumSummary.BestRMSE_mV(k), ...
        OptimumSummary.Improvement_pct(k), ...
        OptimumSummary.CenteredBestAlphaR2(k), ...
        OptimumSummary.CenteredBestAlphaTau2(k), ...
        OptimumSummary.CondJ(k), ...
        pass_text(~OptimumSummary.BoundaryRisk(k) && ...
                  OptimumSummary.GeometryPass(k) && ...
                  OptimumSummary.ObjectiveRobustPass(k)));
end

fprintf("\nConsistency checks:\n");
fprintf("  No boundary-risk optimum        : %s\n",pass_text(boundaryPass));
fprintf("  Local geometry                  : %s\n",pass_text(geometryPass));
fprintf("  Absolute-vs-centered robustness : %s\n",pass_text(objectiveRobustPass));
fprintf("  Amplitude consistency           : %s\n",pass_text(amplitudePass));
fprintf("  Frequency consistency           : %s\n",pass_text(frequencyPass));
fprintf("  SOC smoothness                  : %s\n",pass_text(socSmoothnessPass));
fprintf("  Raw-SOC safe-start/history      : %s\n",pass_text(safeStartPass));
fprintf("  Protected assets unchanged      : %s\n",pass_text(assetsUnchanged));

fprintf("\nTARGET CONSISTENCY B1-2B : %s\n",pass_text(targetConsistencyPass));
fprintf("Median RMSE improvement   : %.3f mV / %.2f %%\n", ...
    medianImprovement_mV,medianImprovement_pct);
fprintf("MATERIAL BENEFIT          : %s\n",pass_text(materialBenefitPass));
fprintf("B2 MAY PROCEED            : %s\n",pass_text(b2MayProceed));

if ~targetConsistencyPass
    fprintf("\nDecision: STOP online R2/tau2 adaptation. Inspect inconsistency source.\n");
elseif ~materialBenefitPass
    fprintf("\nDecision: target is consistent but benefit is too small for B2.\n");
else
    fprintf("\nDecision: B2 may proceed. No online-adaptation claim yet.\n");
end

fprintf("\nSaved under:\n%s\n\n",resultsDir);


%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function v = simulate_rc_branch_variable(t,I,Rbase,taubase,alphaTau)
% Exact-discrete RC branch with SOC-varying frozen R/tau arrays.
% Output is for unit alpha_R. A multiplicative alpha_R can be applied
% linearly after simulation because the recurrence is linear in R.

t = t(:);
I = I(:);
Rbase = Rbase(:);
taubase = taubase(:);

N = numel(t);

if numel(I) ~= N || numel(Rbase) ~= N || numel(taubase) ~= N
    error('EXT2:B12B:RCVectorLength', ...
        't/I/R/tau vectors must have equal length.');
end

if alphaTau <= 0 || any(Rbase <= 0) || any(taubase <= 0)
    error('EXT2:B12B:InvalidRC', ...
        'R, tau and alphaTau must remain positive.');
end

v = zeros(N,1);

for k = 1:N-1
    dt = t(k+1)-t(k);

    if dt <= 0
        error('EXT2:B12B:NonPositiveDt', ...
            'Non-positive dt in RC simulation.');
    end

    tau = alphaTau*taubase(k);
    a = exp(-dt/tau);
    b = Rbase(k)*(1-a);

    v(k+1) = a*v(k)+b*I(k);
end
end


function [condJ,cosineAbs,sigmaA,sigmaB] = ...
    jacobian_metrics(J,assumedSigmaV_V)

if size(J,2) ~= 2 || any(~isfinite(J(:)))
    condJ = Inf;
    cosineAbs = NaN;
    sigmaA = Inf;
    sigmaB = Inf;
    return
end

s = svd(J,'econ');

if numel(s) < 2 || s(2) <= eps
    condJ = Inf;
else
    condJ = s(1)/s(2);
end

n1 = norm(J(:,1));
n2 = norm(J(:,2));

if n1 <= eps || n2 <= eps
    cosineAbs = NaN;
else
    cosineAbs = abs(dot(J(:,1),J(:,2))/(n1*n2));
end

G = J.'*J;
Cov = (assumedSigmaV_V^2)*pinv(G);
sd = sqrt(max(diag(Cov),0));

sigmaA = sd(1);
sigmaB = sd(2);
end


function g = group_key(caseID)
s = string(caseID);

if startsWith(s,"A_")
    g = "A";
elseif startsWith(s,"B_")
    g = "B";
elseif startsWith(s,"DEV_")
    g = "DEV";
else
    error('EXT2:B12B:UnknownGroupKey', ...
        'Unknown amplitude-group prefix in case ID: %s',char(s));
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
    error('EXT2:B12B:HashOpenFailed', ...
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
    error('EXT2:B12B:HashFailed', ...
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
    error('EXT2:B12B:AssetSnapshotMismatch', ...
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
