% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_B1_2H_independent_charge_OCV_validation_v1.m
% MJ1 2RC-EKF EXT2-B1
% B1-2H Independent Charge-Branch OCV Correction Validation v1
%
% PURPOSE
%   Independently validate whether a charge-direction OCV correction
%   derived ONLY from the historical 0.1C DC charge can explain the
%   common-mode voltage bias observed in the six DC-AC charge profiles.
%
% KEY SCIENTIFIC DESIGN
%   DEVELOPMENT SOURCE:
%     B1-2F FROZEN_QREF 0.1C charge pseudo-OCV curve only.
%
%   VALIDATION TARGETS:
%     six frozen DC-AC MID/SLOW charge profiles x SOC 30/50/70% = 18 windows.
%
%   NO DC-AC VOLTAGE IS USED TO FIT THE CORRECTION CURVE.
%
% CORRECTION
%   delta_OCV_charge(SOC) =
%       pseudoOCV_0p1C_charge(SOC) - frozen_OCV(SOC)
%
%   Validation model:
%       Vhat_corrected =
%       Vhat_frozen_2RC + delta_OCV_charge(SOC)
%
%   R0/R1/tau1/R2/tau2/qRef remain frozen.
%
% THIS IS OFFLINE SHADOW VALIDATION ONLY.
%   - No R2/tau2 fitting.
%   - No qRef optimization.
%   - No EKF modification.
%   - No online adaptation.
%   - No frozen-model modification.
%
% PROSPECTIVE SCREENING GATES
%   These gates are frozen in code before validation results are inspected:
%
%   - >=15/18 windows must improve absolute RMSE
%   - median RMSE reduction >=50%
%   - median corrected RMSE <=10 mV
%   - median |bias| reduction >=75%
%   - median corrected |bias| <=10 mV
%   - corrected centered-RMSE median may not increase by >2 mV
%
% A PASS means only:
%   an independently derived charge-direction OCV correction is supported
%   as a model-form candidate for these historical profiles.
%
% It does NOT release a hysteresis model and does NOT reopen R2/tau2 B2.
%
% AUTODOC
%   Successful execution automatically updates docs/protocols, docs/audits
%   and docs/handoff.
%
% MATLAB compatibility:
%   Base MATLAB only.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-2H | Independent Charge-Branch OCV Validation v1.2\n");
fprintf(" 0.1C charge development -> DC-AC validation | No fitting\n");
fprintf("============================================================\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));

if strlength(scriptDir) == 0
    error('EXT2:B12H:RunAsFile', ...
        'Run this script from its saved .m file.');
end

ext2Dir = scriptDir;

[~,folderName] = fileparts(ext2Dir);

if ~strcmpi(string(folderName),"EXT2_dynamic_parameter_identifiability")
    error('EXT2:B12H:WrongFolder', ...
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

b12aFile = fullfile( ...
    resultsDir,'EXT2_B1_2A_run_bundle_v1.mat');

b12bFile = fullfile( ...
    resultsDir,'EXT2_B1_2B_run_bundle_v1.mat');

b12gAxisFile = fullfile( ...
    resultsDir,'EXT2_B1_2G_axis_summary_v1.csv');

profileRoot = fullfile(string(getenv("USERPROFILE")), ...
    'Desktop','MJ1_Experimental_Data_Reconstruction','raw_original');

file01Charge = fullfile(profileRoot,'0.1C','NGU','0.1C dc.csv');

sha01Charge = ...
    "65a96280e83c7ff3236453f7aab97ab5aaba67d693cd71447a4dcefbb40ea695";

required = { ...
    modelFile, ...
    b12aFile, ...
    b12bFile, ...
    b12gAxisFile, ...
    file01Charge, ...
    fullfile(repoMatlab,'mj1_load_model.m')};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:B12H:MissingInput', ...
            'Required input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

A = load(b12aFile);
B = load(b12bFile);
G = readtable(b12gAxisFile);

requiredA = {'profileData','WindowSummary','overallPass'};
missingA = requiredA(~cellfun(@(f) isfield(A,f),requiredA));

if ~isempty(missingA) || ~logical(A.overallPass)
    error('EXT2:B12H:B12AContract', ...
        'B1-2A PASS/profile-data contract failed.');
end

requiredB = {'SafeStartSummary','b2MayProceed'};
missingB = requiredB(~cellfun(@(f) isfield(B,f),requiredB));

if ~isempty(missingB)
    error('EXT2:B12H:B12BContract', ...
        'B1-2B bundle missing required fields.');
end

if logical(B.b2MayProceed)
    error('EXT2:B12H:B12BUnexpectedProceed', ...
        'B1-2B says B2 may proceed; B1-2H is intended for the failed-target path.');
end

requiredG = {'Axis','MedianAbsLowRateVsOneCCharge_mV'};

missingG = setdiff(requiredG,G.Properties.VariableNames);

if ~isempty(missingG)
    error('EXT2:B12H:B12GContract', ...
        'B1-2G axis summary missing variable(s): %s', ...
        strjoin(missingG,', '));
end

% B1-2G already established FROZEN_QREF as the best charge-rate alignment
% axis. This selection is fixed before B1-2H validation.
[~,idxBestAxis] = min(G.MedianAbsLowRateVsOneCCharge_mV);
bestAxis = string(G.Axis(idxBestAxis));

if bestAxis ~= "FROZEN_QREF"
    error('EXT2:B12H:UnexpectedBestAxis', ...
        'Expected B1-2G best charge-rate alignment axis FROZEN_QREF; found %s.', ...
        char(bestAxis));
end

actual01SHA = sha256_file(file01Charge);

if ~strcmpi(actual01SHA,char(sha01Charge))
    error('EXT2:B12H:DevelopmentSourceHashMismatch', ...
        '0.1C development-source SHA-256 mismatch. STOP.');
end

profileData = A.profileData;
WindowSummary = A.WindowSummary;
SafeStartSummary = B.SafeStartSummary;

fprintf("EXT2 root   : %s\n",ext2Dir);
fprintf("Results     : %s\n",resultsDir);
fprintf("Docs AUTO   : %s\n",docsDir);
fprintf("Frozen model: %s\n",modelFile);
fprintf("Correction development axis: FROZEN_QREF (fixed from B1-2G)\n\n");

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
% 2. PROSPECTIVE SCREENING CONFIG
% -------------------------------------------------------------------------
cfg.correctionBandHalfWidth_SOC = 0.005; % +/-0.5 pp around each LUT node
cfg.minDevelopmentSamplesPerNode = 100;

cfg.minImprovedWindows = 15;
cfg.minMedianRMSEImprovement_pct = 50;
cfg.maxMedianCorrectedRMSE_mV = 10;
cfg.minMedianBiasReduction_pct = 75;
cfg.maxMedianCorrectedAbsBias_mV = 10;
cfg.maxCenteredRMSEIncrease_mV = 2;

%% ------------------------------------------------------------------------
% 3. BUILD FULL-SUPPORT CHARGE-DIRECTION OCV CORRECTION
%
% v1.1 fix:
%   B1-2F curveBundle was deliberately truncated around the 30/50/70%
%   diagnostic region and therefore ended near 71% SOC.
%   B1-2H v1 incorrectly requested correction nodes through 85% from that
%   truncated bundle.
%
%   v1.1 does NOT lower the 100-sample/node requirement and does NOT
%   extrapolate. It re-reads the exact SHA-locked raw 0.1C charge and
%   reconstructs the development curve over the complete frozen 17-85%
%   support. DC-AC voltage remains absent from development.
% -------------------------------------------------------------------------
cfg.devFullVoltage_V = 4.200;
cfg.devFullCurrent_A = 0.050;
cfg.devFullVoltageTol_V = 0.006;
cfg.devFullCurrentTol_A = 0.006;
cfg.devAnchorSearchTail_s = 900;

Ddev = load_ngu_uiv_full_B12H(file01Charge);

idxDevAnchor = find_terminal_anchor_charge_B12H(Ddev,cfg);
Ddev = truncate_data_B12H(Ddev,idxDevAnchor);

qCumDev_Ah = cumtrapz(Ddev.t_s,max(Ddev.I_A,0))/3600;
qRemainDev_Ah = qCumDev_Ah(end)-qCumDev_Ah;

zDevFull = 1-qRemainDev_Ah/model.qRefAh;

idxDevStart = find(zDevFull >= model.socMin,1,'first');
idxDevEnd = find(zDevFull <= model.socMax,1,'last');

if isempty(idxDevStart) || isempty(idxDevEnd) || idxDevStart >= idxDevEnd
    error('EXT2:B12H:DevelopmentSupport', ...
        'Could not construct full 17-85%% 0.1C development support.');
end

idxDev = (idxDevStart:idxDevEnd).';

tDev = Ddev.t_s(idxDev);
IDev = Ddev.I_A(idxDev);
VDev = Ddev.V_V(idxDev);
zDev = zDevFull(idxDev);

if min(zDev) > model.socMin+0.002 || ...
   max(zDev) < model.socMax-0.002
    error('EXT2:B12H:DevelopmentCoverage', ...
        '0.1C development source does not span the frozen 17-85%% support.');
end

OCVDev = interp1(model.soc,model.ocv,zDev,'linear');
R0Dev = interp1(model.soc,model.R0,zDev,'linear');
R1Dev = interp1(model.soc,model.R1,zDev,'linear');
C1Dev = interp1(model.soc,model.C1,zDev,'linear');
R2Dev = interp1(model.soc,model.R2,zDev,'linear');
C2Dev = interp1(model.soc,model.C2,zDev,'linear');

tau1Dev = R1Dev.*C1Dev;
tau2Dev = R2Dev.*C2Dev;

% The 0.1C source has already been under nearly constant charge current for
% many RC time constants before the 17% model-support entry.
v10Dev = R1Dev(1)*IDev(1);
v20Dev = R2Dev(1)*IDev(1);

v1Dev = simulate_rc_branch_variable_init_B12H( ...
    tDev,IDev,R1Dev,tau1Dev,v10Dev);

v2Dev = simulate_rc_branch_variable_init_B12H( ...
    tDev,IDev,R2Dev,tau2Dev,v20Dev);

pseudoDev = VDev-R0Dev.*IDev-v1Dev-v2Dev;
deltaDev = pseudoDev-OCVDev;

nNode = numel(model.soc);

SOC = model.soc(:);
FrozenOCV_V = model.ocv(:);
DeltaChargeOCV_V = nan(nNode,1);
DeltaChargeOCV_mV = nan(nNode,1);
NSamples = zeros(nNode,1);

for k = 1:nNode

    z0 = SOC(k);

    mask = ...
        abs(zDev-z0) <= cfg.correctionBandHalfWidth_SOC;

    NSamples(k) = sum(mask);

    if NSamples(k) < cfg.minDevelopmentSamplesPerNode
        error('EXT2:B12H:DevelopmentNodeSamples', ...
            'Only %d development samples near SOC %.1f%%; %d required.', ...
            NSamples(k),100*z0,cfg.minDevelopmentSamplesPerNode);
    end

    DeltaChargeOCV_V(k) = median(deltaDev(mask));
    DeltaChargeOCV_mV(k) = 1000*DeltaChargeOCV_V(k);
end

ChargeOCV_V = FrozenOCV_V+DeltaChargeOCV_V;

CorrectionCurve = table( ...
    SOC,FrozenOCV_V,DeltaChargeOCV_V, ...
    DeltaChargeOCV_mV,ChargeOCV_V,NSamples, ...
    'VariableNames', { ...
    'SOC','FrozenOCV_V','DeltaChargeOCV_V', ...
    'DeltaChargeOCV_mV','ChargeDirectionOCV_V','DevelopmentSamples'});

maxAdjacentCorrectionJump_mV = ...
    max(abs(diff(DeltaChargeOCV_mV)));

fprintf("Independent correction curve built from exact 0.1C raw charge:\n");
fprintf("  Source SHA256           : PASS\n");
fprintf("  Development SOC support : %.3f ... %.3f %%\n", ...
    100*min(zDev),100*max(zDev));
fprintf("  SOC nodes               : %d / %d\n", ...
    sum(isfinite(DeltaChargeOCV_V)),nNode);
fprintf("  Minimum samples/node    : %d\n",min(NSamples));
fprintf("  correction range        : %.2f ... %.2f mV\n", ...
    min(DeltaChargeOCV_mV),max(DeltaChargeOCV_mV));
fprintf("  max adjacent-node jump  : %.2f mV\n\n", ...
    maxAdjacentCorrectionJump_mV);

%% ------------------------------------------------------------------------
% 4. VALIDATE ON SIX DC-AC PROFILES / 18 WINDOWS
% -------------------------------------------------------------------------
rows = struct([]);
ir = 0;

for ip = 1:numel(profileData)

    P = profileData(ip);
    cid = P.case_id;

    S = SafeStartSummary(SafeStartSummary.CaseID == cid,:);

    if height(S) ~= 1
        error('EXT2:B12H:SafeStartLookup', ...
            'Expected one B1-2B safe-start row for %s.',char(cid));
    end

    W = WindowSummary(WindowSummary.CaseID == cid,:);
    W = sortrows(W,'TargetSOC');

    if height(W) ~= 3
        error('EXT2:B12H:WindowCount', ...
            'Expected three B1-2A windows for %s.',char(cid));
    end

    t = P.t_s(:);
    I = P.I_A(:);
    Vmeas = P.V_V(:);
    soc = P.SOC(:);

    safeStartTime = S.SafeStartTime_s;
    maxWindowEnd = max(W.WindowEnd_s);

    idx0 = find(t >= safeStartTime-1e-9,1,'first');
    idx1 = find(t <= maxWindowEnd+1e-9,1,'last');

    if isempty(idx0) || isempty(idx1) || idx0 >= idx1
        error('EXT2:B12H:SegmentIndex', ...
            'Invalid validation segment for %s.',char(cid));
    end

    idx = (idx0:idx1).';

    ts = t(idx);
    Is = I(idx);
    Vs = Vmeas(idx);
    zs = soc(idx);

    if any(zs < model.socMin) || any(zs > model.socMax)
        error('EXT2:B12H:RawSOCSupport', ...
            'Raw SOC leaves frozen LUT support for %s.',char(cid));
    end

    OCV = interp1(model.soc,model.ocv,zs,'linear');
    R0 = interp1(model.soc,model.R0,zs,'linear');
    R1 = interp1(model.soc,model.R1,zs,'linear');
    C1 = interp1(model.soc,model.C1,zs,'linear');
    R2 = interp1(model.soc,model.R2,zs,'linear');
    C2 = interp1(model.soc,model.C2,zs,'linear');

    tau1 = R1.*C1;
    tau2 = R2.*C2;

    % Same long-warmup frozen shadow convention used in B1-2B/B1-2C.
    v1 = simulate_rc_branch_variable_zero(ts,Is,R1,tau1);
    v2 = simulate_rc_branch_variable_zero(ts,Is,R2,tau2);

    VhatFrozen = OCV+v1+v2+R0.*Is;

    deltaCharge = interp1( ...
        SOC,DeltaChargeOCV_V,zs,'linear');

    if any(~isfinite(deltaCharge))
        error('EXT2:B12H:CorrectionInterpolation', ...
            'Charge correction interpolation returned NaN for %s.',char(cid));
    end

    VhatCorrected = VhatFrozen+deltaCharge;

    for iw = 1:height(W)

        mask = ...
            ts >= W.WindowStart_s(iw)-1e-9 & ...
            ts <= W.WindowEnd_s(iw)+1e-9;

        if sum(mask) < 600
            error('EXT2:B12H:WindowSamples', ...
                'Too few validation samples for %s SOC %.0f%%.', ...
                char(cid),100*W.TargetSOC(iw));
        end

        r0 = VhatFrozen(mask)-Vs(mask);
        r1 = VhatCorrected(mask)-Vs(mask);

        rmse0 = sqrt(mean(r0.^2))*1000;
        rmse1 = sqrt(mean(r1.^2))*1000;

        bias0 = mean(r0)*1000;
        bias1 = mean(r1)*1000;

        c0 = r0-mean(r0);
        c1 = r1-mean(r1);

        centered0 = sqrt(mean(c0.^2))*1000;
        centered1 = sqrt(mean(c1.^2))*1000;

        improvement_mV = rmse0-rmse1;

        if rmse0 > eps
            improvement_pct = 100*improvement_mV/rmse0;
        else
            improvement_pct = 0;
        end

        absBiasReduction_mV = abs(bias0)-abs(bias1);

        if abs(bias0) > eps
            biasReduction_pct = ...
                100*absBiasReduction_mV/abs(bias0);
        else
            biasReduction_pct = 0;
        end

        corrW = deltaCharge(mask)*1000;

        ir = ir+1;

        rows(ir).CaseID = cid; %#ok<SAGROW>
        rows(ir).Band = P.band;
        rows(ir).AmplitudeGroup = P.amplitude_group;
        rows(ir).TargetSOC = W.TargetSOC(iw);
        rows(ir).NominalRMSE_mV = rmse0;
        rows(ir).CorrectedRMSE_mV = rmse1;
        rows(ir).RMSEImprovement_mV = improvement_mV;
        rows(ir).RMSEImprovement_pct = improvement_pct;
        rows(ir).NominalBias_mV = bias0;
        rows(ir).CorrectedBias_mV = bias1;
        rows(ir).AbsBiasReduction_mV = absBiasReduction_mV;
        rows(ir).BiasReduction_pct = biasReduction_pct;
        rows(ir).NominalCenteredRMSE_mV = centered0;
        rows(ir).CorrectedCenteredRMSE_mV = centered1;
        rows(ir).CenteredRMSEChange_mV = centered1-centered0;
        rows(ir).MeanAppliedCorrection_mV = mean(corrW);
        rows(ir).CorrectionRange_mV = max(corrW)-min(corrW);
        rows(ir).Improved = rmse1 < rmse0;
    end
end

ValidationSummary = struct2table(rows);

%% ------------------------------------------------------------------------
% 5. AGGREGATE / GROUP SUMMARY
% -------------------------------------------------------------------------
nImproved = sum(ValidationSummary.Improved);

medianNominalRMSE = median(ValidationSummary.NominalRMSE_mV);
medianCorrectedRMSE = median(ValidationSummary.CorrectedRMSE_mV);
medianRMSEImprovement_mV = ...
    median(ValidationSummary.RMSEImprovement_mV);
medianRMSEImprovement_pct = ...
    median(ValidationSummary.RMSEImprovement_pct);

medianNominalAbsBias = ...
    median(abs(ValidationSummary.NominalBias_mV));
medianCorrectedAbsBias = ...
    median(abs(ValidationSummary.CorrectedBias_mV));

if medianNominalAbsBias > eps
    medianBiasReduction_pct = ...
        100*(medianNominalAbsBias-medianCorrectedAbsBias)/ ...
        medianNominalAbsBias;
else
    medianBiasReduction_pct = 0;
end

medianNominalCentered = ...
    median(ValidationSummary.NominalCenteredRMSE_mV);

medianCorrectedCentered = ...
    median(ValidationSummary.CorrectedCenteredRMSE_mV);

centeredIncrease_mV = ...
    medianCorrectedCentered-medianNominalCentered;

groupRows = struct([]);
ig = 0;

groupTypes = ["AmplitudeGroup","Band"];
groupValues = {["A","B","DEV"],["MID","SLOW"]};

for it = 1:numel(groupTypes)

    vals = groupValues{it};

    for j = 1:numel(vals)

        if groupTypes(it) == "AmplitudeGroup"
            mask = ...
                string(ValidationSummary.AmplitudeGroup) == vals(j);
        else
            mask = ...
                string(ValidationSummary.Band) == vals(j);
        end

        T = ValidationSummary(mask,:);

        ig = ig+1;

        groupRows(ig).Category = groupTypes(it); %#ok<SAGROW>
        groupRows(ig).Level = vals(j);
        groupRows(ig).N = height(T);
        groupRows(ig).MedianNominalRMSE_mV = ...
            median(T.NominalRMSE_mV);
        groupRows(ig).MedianCorrectedRMSE_mV = ...
            median(T.CorrectedRMSE_mV);
        groupRows(ig).MedianImprovement_pct = ...
            median(T.RMSEImprovement_pct);
        groupRows(ig).MedianCorrectedAbsBias_mV = ...
            median(abs(T.CorrectedBias_mV));
        groupRows(ig).ImprovedWindows = ...
            sum(T.Improved);
    end
end

GroupSummary = struct2table(groupRows);

%% ------------------------------------------------------------------------
% 6. PROSPECTIVE DECISION
% -------------------------------------------------------------------------
improvedCountPass = ...
    nImproved >= cfg.minImprovedWindows;

rmsePercentPass = ...
    medianRMSEImprovement_pct >= ...
    cfg.minMedianRMSEImprovement_pct;

correctedRMSEPass = ...
    medianCorrectedRMSE <= ...
    cfg.maxMedianCorrectedRMSE_mV;

biasReductionPass = ...
    medianBiasReduction_pct >= ...
    cfg.minMedianBiasReduction_pct;

correctedBiasPass = ...
    medianCorrectedAbsBias <= ...
    cfg.maxMedianCorrectedAbsBias_mV;

centeredPreservationPass = ...
    centeredIncrease_mV <= ...
    cfg.maxCenteredRMSEIncrease_mV;

independentChargeOCVSupported = ...
    improvedCountPass && ...
    rmsePercentPass && ...
    correctedRMSEPass && ...
    biasReductionPass && ...
    correctedBiasPass && ...
    centeredPreservationPass;

if independentChargeOCVSupported

    descriptiveClass = ...
        "INDEPENDENT_CHARGE_DIRECTION_OCV_CORRECTION_SUPPORTED";

elseif improvedCountPass && biasReductionPass

    descriptiveClass = ...
        "PARTIAL_CHARGE_DIRECTION_BASELINE_SUPPORT";

else

    descriptiveClass = ...
        "CHARGE_DIRECTION_OCV_CORRECTION_NOT_SUFFICIENT";
end

%% ------------------------------------------------------------------------
% 7. SAVE NUMERICAL RESULTS
% -------------------------------------------------------------------------
curveOut = fullfile( ...
    resultsDir,'EXT2_B1_2H_charge_OCV_correction_curve_v1_2.csv');

validationOut = fullfile( ...
    resultsDir,'EXT2_B1_2H_window_validation_v1_2.csv');

groupOut = fullfile( ...
    resultsDir,'EXT2_B1_2H_group_summary_v1_2.csv');

writetable(CorrectionCurve,curveOut);
writetable(ValidationSummary,validationOut);
writetable(GroupSummary,groupOut);

runBundleFile = fullfile( ...
    resultsDir,'EXT2_B1_2H_run_bundle_v1_2.mat');

save(runBundleFile, ...
    'cfg','CorrectionCurve','ValidationSummary', ...
    'GroupSummary','independentChargeOCVSupported', ...
    'descriptiveClass','-v7.3');

%% ------------------------------------------------------------------------
% 8. FIGURES
% -------------------------------------------------------------------------
f1 = figure('Name','EXT2-B1-2H charge correction','Visible','off');

plot(100*SOC,DeltaChargeOCV_mV,'LineWidth',1.5);
xlabel('SOC [%]');
ylabel('\Delta OCV_{charge} [mV]');
title('Independent 0.1C-derived charge-direction OCV correction');
grid on;

figCurve = fullfile( ...
    resultsDir,'EXT2_B1_2H_charge_OCV_correction_v1_2.png');

try
    exportgraphics(f1,figCurve,'Resolution',180);
catch ME
    warning('EXT2:B12H:CurvePlotExport', ...
        'Could not export correction curve: %s',ME.message);
end

close(f1);

f2 = figure('Name','EXT2-B1-2H RMSE comparison','Visible','off');

x = (1:height(ValidationSummary)).';

plot(x,ValidationSummary.NominalRMSE_mV,'-o','LineWidth',1.0);
hold on;
plot(x,ValidationSummary.CorrectedRMSE_mV,'-s','LineWidth',1.0);

xlabel('Validation window index');
ylabel('RMSE [mV]');
title('Frozen vs independent charge-OCV-corrected validation');
legend('Frozen','Charge-OCV corrected','Location','best');
grid on;

figRMSE = fullfile( ...
    resultsDir,'EXT2_B1_2H_RMSE_comparison_v1_2.png');

try
    exportgraphics(f2,figRMSE,'Resolution',180);
catch ME
    warning('EXT2:B12H:RMSEPlotExport', ...
        'Could not export RMSE comparison: %s',ME.message);
end

close(f2);

%% ------------------------------------------------------------------------
% 9. REPORT
% -------------------------------------------------------------------------
reportFile = fullfile( ...
    resultsDir,'EXT2_B1_2H_validation_report_v1_2.txt');

fid = fopen(reportFile,'w');

if fid < 0
    error('EXT2:B12H:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-B1-2H Independent Charge-Branch OCV Validation v1.2\n");
fprintf(fid,"===========================================================\n\n");

fprintf(fid,"Development source: exact SHA-locked raw 0.1C charge only.\n");
fprintf(fid,"Validation targets: six DC-AC profiles / 18 B1-2A windows.\n");
fprintf(fid,"No DC-AC voltage used to fit the correction.\n\n");

fprintf(fid,"Correction curve:\n");
fprintf(fid,"SOC nodes = %d\n",height(CorrectionCurve));
fprintf(fid,"correction range = %.3f ... %.3f mV\n", ...
    min(DeltaChargeOCV_mV),max(DeltaChargeOCV_mV));
fprintf(fid,"max adjacent-node jump = %.3f mV\n\n", ...
    maxAdjacentCorrectionJump_mV);

fprintf(fid,"Validation aggregate:\n");
fprintf(fid,"improved windows = %d / 18\n",nImproved);
fprintf(fid,"median nominal RMSE = %.6f mV\n",medianNominalRMSE);
fprintf(fid,"median corrected RMSE = %.6f mV\n",medianCorrectedRMSE);
fprintf(fid,"median RMSE improvement = %.6f mV / %.3f %%\n", ...
    medianRMSEImprovement_mV,medianRMSEImprovement_pct);
fprintf(fid,"median nominal |bias| = %.6f mV\n",medianNominalAbsBias);
fprintf(fid,"median corrected |bias| = %.6f mV\n",medianCorrectedAbsBias);
fprintf(fid,"median |bias| reduction = %.3f %%\n",medianBiasReduction_pct);
fprintf(fid,"median nominal centered RMSE = %.6f mV\n", ...
    medianNominalCentered);
fprintf(fid,"median corrected centered RMSE = %.6f mV\n", ...
    medianCorrectedCentered);
fprintf(fid,"centered RMSE median change = %+.6f mV\n\n", ...
    centeredIncrease_mV);

fprintf(fid,"Prospective gates:\n");
fprintf(fid,">=15/18 windows improve = %s\n",pass_text(improvedCountPass));
fprintf(fid,"median RMSE reduction >=50%% = %s\n",pass_text(rmsePercentPass));
fprintf(fid,"median corrected RMSE <=10 mV = %s\n",pass_text(correctedRMSEPass));
fprintf(fid,"median |bias| reduction >=75%% = %s\n",pass_text(biasReductionPass));
fprintf(fid,"median corrected |bias| <=10 mV = %s\n",pass_text(correctedBiasPass));
fprintf(fid,"centered median increase <=2 mV = %s\n",pass_text(centeredPreservationPass));

fprintf(fid,"\nINDEPENDENT CHARGE OCV SUPPORT = %s\n", ...
    pass_text(independentChargeOCVSupported));
fprintf(fid,"Descriptive class = %s\n",descriptiveClass);

fprintf(fid,"\nClaim boundary:\n");
fprintf(fid,"A PASS supports a direction-dependent OCV/baseline model-form candidate on these historical data. It is not an equilibrium hysteresis identification and does not reopen R2/tau2 online adaptation.\n");
fclose(fid);

%% ------------------------------------------------------------------------
% 10. PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);

[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetOut = fullfile( ...
    resultsDir,'EXT2_B1_2H_protected_asset_audit_v1_2.csv');

writetable(AssetAudit,assetOut);

if ~assetsUnchanged
    error('EXT2:B12H:ProtectedAssetChanged', ...
        'A protected frozen asset changed during B1-2H. STOP.');
end

%% ------------------------------------------------------------------------
% 11. AUTODOC
% -------------------------------------------------------------------------
autodoc_B12H( ...
    protocolDir,auditDir,handoffDir, ...
    nImproved,medianNominalRMSE,medianCorrectedRMSE, ...
    medianRMSEImprovement_pct,medianNominalAbsBias, ...
    medianCorrectedAbsBias,medianBiasReduction_pct, ...
    medianNominalCentered,medianCorrectedCentered, ...
    centeredIncrease_mV,maxAdjacentCorrectionJump_mV, ...
    independentChargeOCVSupported,descriptiveClass, ...
    assetsUnchanged);

%% ------------------------------------------------------------------------
% 12. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-B1-2H COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Independent correction curve:\n");
fprintf("  Development source                 : exact raw 0.1C charge\n");
fprintf("  SOC nodes                          : %d\n",height(CorrectionCurve));
fprintf("  Correction range                   : %.2f ... %.2f mV\n", ...
    min(DeltaChargeOCV_mV),max(DeltaChargeOCV_mV));
fprintf("  Max adjacent-node jump             : %.2f mV\n\n", ...
    maxAdjacentCorrectionJump_mV);

fprintf("DC-AC independent validation:\n");
fprintf("  Improved windows                   : %d / 18\n",nImproved);
fprintf("  Median nominal RMSE                : %.3f mV\n",medianNominalRMSE);
fprintf("  Median corrected RMSE              : %.3f mV\n",medianCorrectedRMSE);
fprintf("  Median RMSE improvement            : %.3f mV / %.2f %%\n", ...
    medianRMSEImprovement_mV,medianRMSEImprovement_pct);
fprintf("  Median nominal |bias|              : %.3f mV\n",medianNominalAbsBias);
fprintf("  Median corrected |bias|            : %.3f mV\n",medianCorrectedAbsBias);
fprintf("  Median |bias| reduction            : %.2f %%\n",medianBiasReduction_pct);
fprintf("  Median centered RMSE frozen        : %.3f mV\n",medianNominalCentered);
fprintf("  Median centered RMSE corrected     : %.3f mV\n",medianCorrectedCentered);
fprintf("  Centered median change             : %+.3f mV\n\n",centeredIncrease_mV);

fprintf("Prospective gates:\n");
fprintf("  >=15/18 improve                    : %s\n",pass_text(improvedCountPass));
fprintf("  Median RMSE reduction >=50%%        : %s\n",pass_text(rmsePercentPass));
fprintf("  Median corrected RMSE <=10 mV      : %s\n",pass_text(correctedRMSEPass));
fprintf("  Median |bias| reduction >=75%%      : %s\n",pass_text(biasReductionPass));
fprintf("  Median corrected |bias| <=10 mV    : %s\n",pass_text(correctedBiasPass));
fprintf("  Centered median increase <=2 mV    : %s\n",pass_text(centeredPreservationPass));

fprintf("\nINDEPENDENT CHARGE OCV SUPPORT       : %s\n", ...
    pass_text(independentChargeOCVSupported));
fprintf("Descriptive class:\n  %s\n",descriptiveClass);
fprintf("Protected assets unchanged           : %s\n", ...
    pass_text(assetsUnchanged));
fprintf("AUTODOC updated                       : PASS\n");
fprintf("B1-2B remains FAIL / R2-tau2 B2 remains STOP.\n\n");

fprintf("Results:\n%s\n",resultsDir);
fprintf("Docs:\n%s\n\n",docsDir);


%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function D = load_ngu_uiv_full_B12H(filePath)

txt = fileread(filePath);
lines = splitlines(string(txt));

if isempty(lines)
    error('EXT2:B12H:EmptyProfile', ...
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
    error('EXT2:B12H:NGUHeaderMissing', ...
        'NGU header not found: %s',char(filePath));
end

headers = split(lines(headerIdx),',');
headers = strtrim(erase(headers,'"'));
headers = erase(headers,string(char(65279)));

iT = find(strcmpi(headers,'Timestamp'),1);
iV = find(strcmpi(headers,'U1[V]'),1);
iI = find(strcmpi(headers,'I1[A]'),1);

if isempty(iT) || isempty(iV) || isempty(iI)
    error('EXT2:B12H:NGUColumnsMissing', ...
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

    tRaw(k) = parse_time_token_B12H(tok(iT));
    V(k) = str2double(strtrim(erase(tok(iV),'"')));
    I(k) = str2double(strtrim(erase(tok(iI),'"')));
end

valid = isfinite(tRaw) & isfinite(V) & isfinite(I);

tRaw = tRaw(valid);
V = V(valid);
I = I(valid);

if numel(tRaw) < 2
    error('EXT2:B12H:NoValidData', ...
        'Too few valid rows: %s',char(filePath));
end

t = unwrap_elapsed_time_B12H(tRaw);
t = t-t(1);

if any(diff(t) <= 0)
    error('EXT2:B12H:NonMonotonicTime', ...
        'Timestamps are not strictly increasing: %s',char(filePath));
end

D = struct();
D.t_s = t(:);
D.V_V = V(:);
D.I_A = I(:);
end


function t = parse_time_token_B12H(token)

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


function tOut = unwrap_elapsed_time_B12H(tIn)

tOut = tIn(:);
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


function idx = find_terminal_anchor_charge_B12H(D,cfg)

tailStart = max(D.t_s(1), ...
    D.t_s(end)-cfg.devAnchorSearchTail_s);

cand = find( ...
    D.t_s >= tailStart & ...
    abs(D.V_V-cfg.devFullVoltage_V) <= ...
        2*cfg.devFullVoltageTol_V & ...
    D.I_A >= 0 & D.I_A <= 0.10);

if isempty(cand)
    error('EXT2:B12H:DevelopmentAnchorMissing', ...
        'No 0.1C terminal full-charge anchor candidate found.');
end

score = ...
    abs(D.V_V(cand)-cfg.devFullVoltage_V)/ ...
        cfg.devFullVoltageTol_V + ...
    abs(D.I_A(cand)-cfg.devFullCurrent_A)/ ...
        cfg.devFullCurrentTol_A;

[~,j] = min(score);
idx = cand(j);

if abs(D.V_V(idx)-cfg.devFullVoltage_V) > ...
        cfg.devFullVoltageTol_V || ...
   abs(D.I_A(idx)-cfg.devFullCurrent_A) > ...
        cfg.devFullCurrentTol_A

    error('EXT2:B12H:DevelopmentAnchorFail', ...
        '0.1C terminal 4.2 V / 50 mA anchor failed strict check.');
end
end


function D2 = truncate_data_B12H(D,idx)

D2 = D;
D2.t_s = D.t_s(1:idx);
D2.V_V = D.V_V(1:idx);
D2.I_A = D.I_A(1:idx);
end


function v = simulate_rc_branch_variable_init_B12H( ...
    t,I,Rbase,taubase,v0)

t = t(:);
I = I(:);
Rbase = Rbase(:);
taubase = taubase(:);

N = numel(t);

if numel(I) ~= N || ...
   numel(Rbase) ~= N || ...
   numel(taubase) ~= N

    error('EXT2:B12H:DevelopmentRCVectorLength', ...
        'Development t/I/R/tau vectors must have equal length.');
end

v = zeros(N,1);
v(1) = v0;

for k = 1:N-1
    dt = t(k+1)-t(k);

    if dt <= 0
        error('EXT2:B12H:DevelopmentNonPositiveDt', ...
            'Non-positive dt in development RC simulation.');
    end

    a = exp(-dt/taubase(k));
    b = Rbase(k)*(1-a);

    v(k+1) = a*v(k)+b*I(k);
end
end


function v = simulate_rc_branch_variable_zero(t,I,Rbase,taubase)

t = t(:);
I = I(:);
Rbase = Rbase(:);
taubase = taubase(:);

N = numel(t);

if numel(I) ~= N || ...
   numel(Rbase) ~= N || ...
   numel(taubase) ~= N
    error('EXT2:B12H:RCVectorLength', ...
        't/I/R/tau vectors must have equal length.');
end

v = zeros(N,1);

for k = 1:N-1

    dt = t(k+1)-t(k);

    if dt <= 0
        error('EXT2:B12H:NonPositiveDt', ...
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
    error('EXT2:B12H:HashOpenFailed', ...
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

    error('EXT2:B12H:HashFailed', ...
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
    error('EXT2:B12H:AssetSnapshotMismatch', ...
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


function autodoc_B12H( ...
    protocolDir,auditDir,handoffDir, ...
    nImproved,nomRMSE,corrRMSE,rmseImpPct, ...
    nomBias,corrBias,biasRedPct, ...
    nomCentered,corrCentered,centeredChange, ...
    maxJump,supported,descriptiveClass,assetsUnchanged)

protocolPath = fullfile( ...
    protocolDir,'EXT2_B1_2H_PROTOCOL_v1_2.md');

protocol = {
'# EXT2-B1-2H Protocol v1.2 — Independent Charge-Branch OCV Correction Validation'
''
'## Purpose'
''
'Derive a charge-direction OCV correction from the independent historical 0.1C DC charge only, then validate it without refitting on the six DC-AC charge profiles (18 SOC windows).'
''
'## Development / validation separation'
''
'- development: exact SHA-locked raw 0.1C charge reconstructed on the B1-2G-selected FROZEN_QREF axis'
'- validation: six DC-AC MID/SLOW profiles at SOC 30/50/70%'
''
'No DC-AC voltage is used to fit the correction curve.'
''
'## Model boundary'
''
'Only an additive SOC-dependent charge-direction OCV correction is applied. Frozen R0/R1/tau1/R2/tau2/qRef remain unchanged.'
''
'## Prospective screening gates'
''
'- >=15/18 validation windows improve'
'- median RMSE reduction >=50%'
'- median corrected RMSE <=10 mV'
'- median |bias| reduction >=75%'
'- median corrected |bias| <=10 mV'
'- centered-RMSE median increase <=2 mV'
''
'## Claim boundary'
''
'A PASS supports a direction-dependent OCV/baseline model-form candidate on these historical data only. It is not equilibrium hysteresis identification and does not reopen R2/tau2 online adaptation.'
};

write_text_lines(protocolPath,protocol);

auditPath = fullfile( ...
    auditDir,'EXT2_B1_2H_EXECUTION_AUDIT_v1_2.md');

audit = {
'# EXT2-B1-2H Execution Audit v1.2'
''
'## Status'
''
'`CLOSED / INDEPENDENT VALIDATION COMPLETE`'
''
'Implementation note: v1 stopped before validation because it reused the deliberately truncated B1-2F diagnostic curve bundle (ending near 71% SOC) while requesting correction nodes through 85%. v1.1 rebuilds the development curve directly from the exact SHA-locked raw 0.1C charge source; no threshold was relaxed and no extrapolation was introduced. v1.2 additionally restores the frozen upstream input filenames B1-2A/B1-2B/B1-2G to their actual v1 result names; v1.1 had accidentally version-bumped those input filenames during code generation.'
''
sprintf('- validation windows improved: **%d / 18**',nImproved)
sprintf('- median nominal RMSE: **%.3f mV**',nomRMSE)
sprintf('- median corrected RMSE: **%.3f mV**',corrRMSE)
sprintf('- median RMSE reduction: **%.2f%%**',rmseImpPct)
sprintf('- median nominal |bias|: **%.3f mV**',nomBias)
sprintf('- median corrected |bias|: **%.3f mV**',corrBias)
sprintf('- median |bias| reduction: **%.2f%%**',biasRedPct)
sprintf('- median centered RMSE frozen: **%.3f mV**',nomCentered)
sprintf('- median centered RMSE corrected: **%.3f mV**',corrCentered)
sprintf('- centered median change: **%+.3f mV**',centeredChange)
sprintf('- maximum adjacent correction-node jump: **%.3f mV**',maxJump)
sprintf('- protected frozen assets unchanged: **%s**',pass_text(assetsUnchanged))
''
'## Independent charge-direction OCV support'
''
['`' pass_text(supported) '`']
''
'## Descriptive class'
''
['`' char(descriptiveClass) '`']
''
'B1-2B remains FAIL / R2-tau2 B2 remains STOP.'
};

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
'- B1-1 synthetic R2/tau2 recovery: PASS'
'- B1-2A SOC/state preflight: PASS'
'- B1-2B real-voltage R2/tau2 target consistency: FAIL'
'- B1-2C: baseline bias dominant'
'- B1-2D: SOC-axis/qRef shift strongly reduces baseline'
'- B1-2E: voltage-optimal effective qRef exceeds independent capacity references'
'- B1-2F: direction-sensitive pseudo-OCV evidence'
'- B1-2G: directional effect robust across SOC-axis conventions'
sprintf('- B1-2H: `%s`',descriptiveClass)
''
'## B1-2H independent validation'
''
sprintf('- improved windows: %d/18',nImproved)
sprintf('- median RMSE: %.3f -> %.3f mV',nomRMSE,corrRMSE)
sprintf('- median RMSE reduction: %.2f%%',rmseImpPct)
sprintf('- median |bias|: %.3f -> %.3f mV',nomBias,corrBias)
sprintf('- median |bias| reduction: %.2f%%',biasRedPct)
sprintf('- independent charge-OCV support: %s',pass_text(supported))
''
'## Frozen decision'
''
'B1-2B remains FAIL. R2/tau2 online adaptation remains STOPPED.'
''
'If B1-2H supports the independent charge branch, the next extension target is model-form validation of a direction-dependent OCV/hysteresis layer, not R2/tau2 adaptation.'
};

write_text_lines(handoffPath,handoff);

continuityPath = fullfile( ...
    handoffDir,'EXT2_PROJECT_CONTINUITY_CURRENT.md');

continuity = {
'# EXT2 Project Continuity — CURRENT'
''
'## Structure'
''
'RUN scripts preserve: header -> PATHS -> frozen-input checks -> source/schema checks -> analysis -> results -> protected SHA audit -> AUTODOC -> decision/claim boundary -> local functions.'
''
'## Current evidence'
''
'- R2/tau2 is structurally/synthetically recoverable but failed measured-voltage target consistency.'
'- The measured-voltage failure is dominated by a common-mode baseline error.'
'- Artificial qRef stretching removes much of that baseline but lacks independent physical capacity support.'
'- Charge/discharge pseudo-OCV directionality persists across multiple SOC-axis definitions.'
sprintf('- Independent 0.1C-derived charge OCV correction validation: %s',descriptiveClass)
''
'## Frozen boundary'
''
'Do not modify frozen MJ1 v0.2 EKF, Bayesian R0 v1.0, EXT1 K4, Simulink frozen assets or released history.'
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
    error('EXT2:B12H:DocWriteFailed', ...
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
