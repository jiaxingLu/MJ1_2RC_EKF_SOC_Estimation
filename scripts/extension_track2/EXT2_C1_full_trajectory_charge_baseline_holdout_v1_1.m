% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_C1_full_trajectory_charge_baseline_holdout_v1.m
% MJ1 2RC-EKF EXT2-C
% C1 Independent Full-Trajectory Charge-Baseline Holdout Validation v1
%
% PURPOSE
%   Validate whether the independently derived B1-2H charge-direction
%   OCV/baseline correction transfers over the complete 17-85% SOC
%   trajectory of the historical 1C full-charge record.
%
% DEVELOPMENT / HOLDOUT SEPARATION
%   Development of correction:
%       exact historical 0.1C DC charge (B1-2H)
%
%   Holdout validation:
%       raw_original/1C/1C_full_charge.csv
%
%   The 1C full-charge voltage is NOT used to fit or modify the B1-2H
%   correction curve in this stage.
%
% IMPORTANT CLAIM BOUNDARY
%   This is "independent with respect to correction-curve development".
%   The 1C full-charge record has appeared in earlier capacity/provenance
%   audits, so it is NOT globally unseen data.
%
% MODEL COMPARISON
%   Frozen:
%       Vhat_frozen =
%       OCV_frozen(SOC) + v1 + v2 + R0*I
%
%   Corrected:
%       Vhat_corrected =
%       Vhat_frozen + delta_OCV_charge(SOC)
%
%   Frozen R0/R1/C1/R2/C2/qRef are unchanged.
%
% SOC BASIS
%   FROZEN_QREF is used because:
%   - B1-2G identified it as the best charge-rate alignment axis;
%   - B1-2H correction curve was frozen on this axis.
%
%   SOC is reconstructed backward from the terminal full-charge anchor:
%
%       z(t) = 1 - Q_remaining(t)/model.qRefAh
%
%   where terminal full charge is identified near 4.2 V / 50 mA.
%
% SUPPORT
%   Only the frozen LUT interval 17-85% SOC is evaluated.
%
% PRIMARY FULL-TRAJECTORY METRICS
%   - RMSE
%   - MAE
%   - mean bias
%   - maximum absolute error
%   - centered RMSE
%
% SOC-BIN METRICS
%   - 17-30%
%   - 30-50%
%   - 50-70%
%   - 70-85%
%
% CHARGE-PHASE DIAGNOSTIC
%   CC/CV transition is detected descriptively from measured I/V.
%   Performance is also reported for CC and CV portions within 17-85%.
%
% PROSPECTIVE C1 GATES
%   Fixed before holdout results are inspected:
%
%   G1 full-trajectory RMSE reduction >= 50%
%   G2 corrected full-trajectory RMSE <= 10 mV
%   G3 full-trajectory MAE reduction >= 50%
%   G4 corrected |mean bias| <= 10 mV
%   G5 all 4 SOC bins improve RMSE
%   G6 maximum corrected SOC-bin RMSE <= 15 mV
%   G7 centered-RMSE increase <= 2 mV
%
% A PASS supports:
%   a transferable SOC-dependent CHARGING-BASELINE model-form candidate
%   for these historical data.
%
% A PASS does NOT prove:
%   - equilibrium hysteresis;
%   - HPPC SOC labels are correct;
%   - cross-temperature/cross-cell generalization;
%   - production-model readiness.
%
% B1-2J remains:
%   HPPC_SOC_PROVENANCE_INCONCLUSIVE
%
% R2/tau2 continuous adaptation remains CLOSED.
%
% AUTODOC
%   Successful execution automatically updates:
%   - docs/protocols/EXT2_C1_PROTOCOL_v1_1.md
%   - docs/audits/EXT2_C1_EXECUTION_AUDIT_v1_1.md
%   - docs/handoff/EXT2_CURRENT_HANDOFF.md
%   - docs/handoff/EXT2_PROJECT_CONTINUITY_CURRENT.md
%
% MATLAB compatibility:
%   Base MATLAB only.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-C1 | Full-Trajectory Charge-Baseline Holdout v1.1\n");
fprintf(" B1-2H correction frozen | 1C full-charge 17-85%% validation\n");
fprintf("============================================================\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));

if strlength(scriptDir) == 0
    error('EXT2:C1:RunAsFile', ...
        'Run this script from its saved .m file.');
end

ext2Dir = scriptDir;

[~,folderName] = fileparts(ext2Dir);

if ~strcmpi(string(folderName),"EXT2_dynamic_parameter_identifiability")
    error('EXT2:C1:WrongFolder', ...
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

b12hBundleFile = fullfile( ...
    resultsDir,'EXT2_B1_2H_run_bundle_v1_2.mat');

profileRoot = fullfile(string(getenv("USERPROFILE")), ...
    'Desktop','MJ1_Experimental_Data_Reconstruction','raw_original');

holdoutFile = fullfile( ...
    profileRoot,'1C','1C_full_charge.csv');

holdoutSHA = ...
    "9df6afbf73b78742e0449803d8f2eae8e9506583b5ff2f5161fabc65934d72f2";

required = { ...
    modelFile, ...
    b12hBundleFile, ...
    holdoutFile, ...
    fullfile(repoMatlab,'mj1_load_model.m')};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:C1:MissingInput', ...
            'Required input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

H = load(b12hBundleFile);

requiredH = { ...
    'CorrectionCurve', ...
    'independentChargeOCVSupported', ...
    'descriptiveClass'};

missingH = requiredH(~cellfun(@(f) isfield(H,f),requiredH));

if ~isempty(missingH)
    error('EXT2:C1:B12HContract', ...
        'B1-2H bundle missing field(s): %s', ...
        strjoin(missingH,', '));
end

if ~logical(H.independentChargeOCVSupported)
    error('EXT2:C1:B12HNotSupported', ...
        'B1-2H independent charge OCV correction did not PASS.');
end

CorrectionCurve = H.CorrectionCurve;

requiredCurveVars = { ...
    'SOC','DeltaChargeOCV_V'};

missingCurve = setdiff( ...
    requiredCurveVars,CorrectionCurve.Properties.VariableNames);

if ~isempty(missingCurve)
    error('EXT2:C1:CorrectionCurveContract', ...
        'CorrectionCurve missing variable(s): %s', ...
        strjoin(missingCurve,', '));
end

if min(CorrectionCurve.SOC) > model.socMin+1e-6 || ...
   max(CorrectionCurve.SOC) < model.socMax-1e-6 || ...
   any(~isfinite(CorrectionCurve.DeltaChargeOCV_V))
    error('EXT2:C1:CorrectionCurveSupport', ...
        'B1-2H correction curve does not fully cover frozen SOC support.');
end

fprintf("EXT2 root       : %s\n",ext2Dir);
fprintf("Results         : %s\n",resultsDir);
fprintf("Docs AUTO       : %s\n",docsDir);
fprintf("Frozen model    : %s\n",modelFile);
fprintf("B1-2H bundle    : %s\n",b12hBundleFile);
fprintf("B1-2H support   : PASS\n");
fprintf("Holdout source  : %s\n\n",holdoutFile);

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
% 2. HOLDOUT SOURCE IDENTITY
% -------------------------------------------------------------------------
actualSHA = sha256_file(holdoutFile);

if ~strcmpi(actualSHA,char(holdoutSHA))
    error('EXT2:C1:HoldoutHashMismatch', ...
        '1C full-charge SHA-256 mismatch. STOP.');
end

fprintf("Holdout source identity: SHA256 PASS\n\n");

%% ------------------------------------------------------------------------
% 3. PROSPECTIVE CONFIGURATION
% -------------------------------------------------------------------------
cfg.fullVoltage_V = 4.200;
cfg.fullCurrent_A = 0.050;
cfg.fullVoltageTol_V = 0.006;
cfg.fullCurrentTol_A = 0.006;
cfg.anchorSearchTail_s = 900;

cfg.minSamplesFull = 1000;
cfg.minSamplesBin = 300;

cfg.socEdges = [0.17 0.30 0.50 0.70 0.85];

% CC/CV descriptive detection.
cfg.cvVoltageThreshold_V = 4.195;
cfg.cvCurrentFractionOfCC = 0.95;

% Prospective gates.
cfg.minFullRMSEImprovement_pct = 50;
cfg.maxCorrectedFullRMSE_mV = 10;
cfg.minFullMAEImprovement_pct = 50;
cfg.maxCorrectedAbsMeanBias_mV = 10;
cfg.requiredImprovedBins = 4;
cfg.maxCorrectedBinRMSE_mV = 15;
cfg.maxCenteredRMSEIncrease_mV = 2;

%% ------------------------------------------------------------------------
% 4. LOAD 1C FULL-CHARGE HOLDOUT + TERMINAL FULL ANCHOR
% -------------------------------------------------------------------------
D = load_ngu_uiv_full(holdoutFile);

idxAnchor = find_terminal_anchor_charge(D,cfg);

D = truncate_data(D,idxAnchor);

qCum_Ah = cumtrapz(D.t_s,max(D.I_A,0))/3600;
qRemain_Ah = qCum_Ah(end)-qCum_Ah;

soc = 1-qRemain_Ah/model.qRefAh;

idx0 = find(soc >= model.socMin,1,'first');
idx1 = find(soc <= model.socMax,1,'last');

if isempty(idx0) || isempty(idx1) || idx0 >= idx1
    error('EXT2:C1:SupportSegment', ...
        'Could not isolate frozen 17-85%% SOC support.');
end

idx = (idx0:idx1).';

t = D.t_s(idx);
I = D.I_A(idx);
V = D.V_V(idx);
z = soc(idx);

if numel(idx) < cfg.minSamplesFull
    error('EXT2:C1:TooFewHoldoutSamples', ...
        'Only %d holdout samples in 17-85%% SOC.',numel(idx));
end

if min(z) > model.socMin+0.002 || ...
   max(z) < model.socMax-0.002
    error('EXT2:C1:Coverage', ...
        'Holdout does not adequately span frozen 17-85%% support.');
end

fprintf("Terminal full anchor:\n");
fprintf("  t              : %.3f s\n",D.t_s(end));
fprintf("  V / I          : %.6f V / %.6f A\n",D.V_V(end),D.I_A(end));
fprintf("  integrated Q   : %.6f Ah\n",qCum_Ah(end));
fprintf("  support SOC    : %.3f ... %.3f %%\n",100*min(z),100*max(z));
fprintf("  support samples: %d\n\n",numel(z));

%% ------------------------------------------------------------------------
% 5. FROZEN 2RC + CORRECTED SHADOW MODEL
% -------------------------------------------------------------------------
OCV = interp1(model.soc,model.ocv,z,'linear');
R0 = interp1(model.soc,model.R0,z,'linear');
R1 = interp1(model.soc,model.R1,z,'linear');
C1 = interp1(model.soc,model.C1,z,'linear');
R2 = interp1(model.soc,model.R2,z,'linear');
C2 = interp1(model.soc,model.C2,z,'linear');

tau1 = R1.*C1;
tau2 = R2.*C2;

if any(~isfinite(OCV)) || ...
   any(~isfinite(R0)) || ...
   any(~isfinite(R1)) || ...
   any(~isfinite(R2)) || ...
   any(~isfinite(tau1)) || ...
   any(~isfinite(tau2))
    error('EXT2:C1:FrozenInterpolation', ...
        'Frozen-model interpolation returned non-finite values.');
end

% Before entering 17% SOC, the 1C record has already been charging at
% near-constant current for many RC time constants. Use steady-current
% branch initialization at the support entry instead of zero.
v10 = R1(1)*I(1);
v20 = R2(1)*I(1);

v1 = simulate_rc_branch_variable_init(t,I,R1,tau1,v10);
v2 = simulate_rc_branch_variable_init(t,I,R2,tau2,v20);

VhatFrozen = OCV+v1+v2+R0.*I;

deltaChargeOCV = interp1( ...
    CorrectionCurve.SOC, ...
    CorrectionCurve.DeltaChargeOCV_V, ...
    z,'linear');

if any(~isfinite(deltaChargeOCV))
    error('EXT2:C1:CorrectionInterpolation', ...
        'B1-2H correction interpolation returned non-finite values.');
end

VhatCorrected = VhatFrozen+deltaChargeOCV;

rFrozen = VhatFrozen-V;
rCorrected = VhatCorrected-V;

%% ------------------------------------------------------------------------
% 6. FULL-TRAJECTORY METRICS
% -------------------------------------------------------------------------
FullMetrics = compute_metrics_table( ...
    "FULL_17_TO_85",z,I,rFrozen,rCorrected);

fullFrozenRMSE = FullMetrics.FrozenRMSE_mV(1);
fullCorrectedRMSE = FullMetrics.CorrectedRMSE_mV(1);
fullFrozenMAE = FullMetrics.FrozenMAE_mV(1);
fullCorrectedMAE = FullMetrics.CorrectedMAE_mV(1);
fullFrozenBias = FullMetrics.FrozenMeanBias_mV(1);
fullCorrectedBias = FullMetrics.CorrectedMeanBias_mV(1);
fullFrozenCentered = FullMetrics.FrozenCenteredRMSE_mV(1);
fullCorrectedCentered = FullMetrics.CorrectedCenteredRMSE_mV(1);

fullRMSEImprovement_pct = ...
    100*(fullFrozenRMSE-fullCorrectedRMSE)/fullFrozenRMSE;

fullMAEImprovement_pct = ...
    100*(fullFrozenMAE-fullCorrectedMAE)/fullFrozenMAE;

centeredRMSEChange_mV = ...
    fullCorrectedCentered-fullFrozenCentered;

%% ------------------------------------------------------------------------
% 7. SOC-BIN METRICS
% -------------------------------------------------------------------------
binRows = struct([]);

for ib = 1:numel(cfg.socEdges)-1

    lo = cfg.socEdges(ib);
    hi = cfg.socEdges(ib+1);

    if ib < numel(cfg.socEdges)-1
        mask = z >= lo & z < hi;
    else
        mask = z >= lo & z <= hi;
    end

    if sum(mask) < cfg.minSamplesBin
        error('EXT2:C1:BinSamples', ...
            'Only %d samples in SOC bin %.0f-%.0f%%.', ...
            sum(mask),100*lo,100*hi);
    end

    label = sprintf('SOC_%02dto%02d',round(100*lo),round(100*hi));

    T = compute_metrics_table( ...
        string(label),z(mask),I(mask), ...
        rFrozen(mask),rCorrected(mask));

    binRows(ib).Bin = T.Region(1); %#ok<SAGROW>
    binRows(ib).SOC_Low = lo;
    binRows(ib).SOC_High = hi;
    binRows(ib).NSamples = T.NSamples(1);
    binRows(ib).MeanCurrent_A = T.MeanCurrent_A(1);
    binRows(ib).FrozenRMSE_mV = T.FrozenRMSE_mV(1);
    binRows(ib).CorrectedRMSE_mV = T.CorrectedRMSE_mV(1);
    binRows(ib).RMSEImprovement_pct = T.RMSEImprovement_pct(1);
    binRows(ib).FrozenMAE_mV = T.FrozenMAE_mV(1);
    binRows(ib).CorrectedMAE_mV = T.CorrectedMAE_mV(1);
    binRows(ib).FrozenMeanBias_mV = T.FrozenMeanBias_mV(1);
    binRows(ib).CorrectedMeanBias_mV = T.CorrectedMeanBias_mV(1);
    binRows(ib).FrozenMaxAbs_mV = T.FrozenMaxAbs_mV(1);
    binRows(ib).CorrectedMaxAbs_mV = T.CorrectedMaxAbs_mV(1);
    binRows(ib).FrozenCenteredRMSE_mV = T.FrozenCenteredRMSE_mV(1);
    binRows(ib).CorrectedCenteredRMSE_mV = T.CorrectedCenteredRMSE_mV(1);
    binRows(ib).Improved = ...
        T.CorrectedRMSE_mV(1) < T.FrozenRMSE_mV(1);
end

BinMetrics = struct2table(binRows);

%% ------------------------------------------------------------------------
% 8. CC/CV PHASE DIAGNOSTIC
% -------------------------------------------------------------------------
nCCRef = min(300,numel(I));
IccRef = median(I(1:nCCRef));

cvCandidates = find( ...
    V >= cfg.cvVoltageThreshold_V & ...
    I <= cfg.cvCurrentFractionOfCC*IccRef);

if isempty(cvCandidates)
    cvStartFound = false;
    idxCV = [];
    socCVStart = NaN;
else
    cvStartFound = true;
    idxCV = cvCandidates(1);
    socCVStart = z(idxCV);
end

phaseRows = struct([]);
ip = 0;

if cvStartFound && idxCV > 1

    maskCC = (1:numel(z)).' < idxCV;

    if sum(maskCC) >= cfg.minSamplesBin
        ip = ip+1;
        Tcc = compute_metrics_table( ...
            "CC_WITHIN_SUPPORT",z(maskCC),I(maskCC), ...
            rFrozen(maskCC),rCorrected(maskCC));

        newPhaseRow = table_row_to_struct(Tcc);
        phaseRows = [phaseRows; newPhaseRow]; %#ok<AGROW>
    end

    maskCV = (1:numel(z)).' >= idxCV;

    if sum(maskCV) >= 50
        ip = ip+1;
        Tcv = compute_metrics_table( ...
            "CV_WITHIN_SUPPORT",z(maskCV),I(maskCV), ...
            rFrozen(maskCV),rCorrected(maskCV));

        newPhaseRow = table_row_to_struct(Tcv);
        phaseRows = [phaseRows; newPhaseRow]; %#ok<AGROW>
    end
else
    ip = ip+1;
    Tall = compute_metrics_table( ...
        "CC_OR_NO_CV_DETECTED",z,I,rFrozen,rCorrected);

    newPhaseRow = table_row_to_struct(Tall);
    phaseRows = [phaseRows; newPhaseRow]; %#ok<AGROW>
end

PhaseMetrics = struct2table(phaseRows);

%% ------------------------------------------------------------------------
% 9. PROSPECTIVE GATES
% -------------------------------------------------------------------------
gateFullRMSEImprovement = ...
    fullRMSEImprovement_pct >= ...
    cfg.minFullRMSEImprovement_pct;

gateCorrectedFullRMSE = ...
    fullCorrectedRMSE <= ...
    cfg.maxCorrectedFullRMSE_mV;

gateFullMAEImprovement = ...
    fullMAEImprovement_pct >= ...
    cfg.minFullMAEImprovement_pct;

gateCorrectedBias = ...
    abs(fullCorrectedBias) <= ...
    cfg.maxCorrectedAbsMeanBias_mV;

nImprovedBins = sum(BinMetrics.Improved);

gateAllBinsImprove = ...
    nImprovedBins >= cfg.requiredImprovedBins;

maxCorrectedBinRMSE = ...
    max(BinMetrics.CorrectedRMSE_mV);

gateMaxBinRMSE = ...
    maxCorrectedBinRMSE <= ...
    cfg.maxCorrectedBinRMSE_mV;

gateCenteredPreservation = ...
    centeredRMSEChange_mV <= ...
    cfg.maxCenteredRMSEIncrease_mV;

c1Pass = ...
    gateFullRMSEImprovement && ...
    gateCorrectedFullRMSE && ...
    gateFullMAEImprovement && ...
    gateCorrectedBias && ...
    gateAllBinsImprove && ...
    gateMaxBinRMSE && ...
    gateCenteredPreservation;

if c1Pass
    descriptiveClass = ...
        "TRANSFERABLE_CHARGING_BASELINE_CORRECTION_SUPPORTED";
elseif nImprovedBins >= 3 && fullRMSEImprovement_pct > 0
    descriptiveClass = ...
        "PARTIAL_FULL_TRAJECTORY_TRANSFER_SUPPORT";
else
    descriptiveClass = ...
        "FULL_TRAJECTORY_TRANSFER_NOT_SUPPORTED";
end

%% ------------------------------------------------------------------------
% 10. SAVE NUMERICAL EVIDENCE
% -------------------------------------------------------------------------
fullOut = fullfile( ...
    resultsDir,'EXT2_C1_full_trajectory_metrics_v1_1.csv');

binOut = fullfile( ...
    resultsDir,'EXT2_C1_SOC_bin_metrics_v1_1.csv');

phaseOut = fullfile( ...
    resultsDir,'EXT2_C1_charge_phase_metrics_v1_1.csv');

trajectoryOut = fullfile( ...
    resultsDir,'EXT2_C1_holdout_trajectory_v1_1.csv');

writetable(FullMetrics,fullOut);
writetable(BinMetrics,binOut);
writetable(PhaseMetrics,phaseOut);

HoldoutTrajectory = table( ...
    t,z,I,V,VhatFrozen,VhatCorrected, ...
    1000*rFrozen,1000*rCorrected, ...
    1000*deltaChargeOCV, ...
    'VariableNames', { ...
    'Time_s','SOC','Current_A','MeasuredVoltage_V', ...
    'FrozenVoltage_V','CorrectedVoltage_V', ...
    'FrozenResidual_mV','CorrectedResidual_mV', ...
    'AppliedChargeCorrection_mV'});

writetable(HoldoutTrajectory,trajectoryOut);

runBundleOut = fullfile( ...
    resultsDir,'EXT2_C1_run_bundle_v1_1.mat');

save(runBundleOut, ...
    'cfg','FullMetrics','BinMetrics','PhaseMetrics', ...
    'HoldoutTrajectory','c1Pass','descriptiveClass', ...
    'cvStartFound','socCVStart','-v7.3');

%% ------------------------------------------------------------------------
% 11. FIGURES
% -------------------------------------------------------------------------
f1 = figure('Name','EXT2-C1 voltage holdout','Visible','off');

plot(100*z,V,'LineWidth',1.2);
hold on;
plot(100*z,VhatFrozen,'LineWidth',1.0);
plot(100*z,VhatCorrected,'LineWidth',1.0);

xlabel('SOC [%]');
ylabel('Voltage [V]');
title('EXT2-C1 | 1C full-charge holdout, 17-85% SOC');
legend('Measured','Frozen 2RC','+ charge-baseline correction', ...
    'Location','best');
grid on;

fig1 = fullfile( ...
    resultsDir,'EXT2_C1_voltage_holdout_v1_1.png');

try
    exportgraphics(f1,fig1,'Resolution',180);
catch
    saveas(f1,fig1);
end

close(f1);

f2 = figure('Name','EXT2-C1 residual holdout','Visible','off');

plot(100*z,1000*rFrozen,'LineWidth',1.0);
hold on;
plot(100*z,1000*rCorrected,'LineWidth',1.0);
yline(0,'--');

xlabel('SOC [%]');
ylabel('Prediction residual [mV]');
title('EXT2-C1 | residual vs SOC');
legend('Frozen','Corrected','Location','best');
grid on;

fig2 = fullfile( ...
    resultsDir,'EXT2_C1_residual_vs_SOC_v1_1.png');

try
    exportgraphics(f2,fig2,'Resolution',180);
catch
    saveas(f2,fig2);
end

close(f2);

%% ------------------------------------------------------------------------
% 12. REPORT
% -------------------------------------------------------------------------
reportFile = fullfile( ...
    resultsDir,'EXT2_C1_holdout_report_v1_1.txt');

fid = fopen(reportFile,'w');

if fid < 0
    error('EXT2:C1:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-C1 Full-Trajectory Charge-Baseline Holdout v1.1\n");
fprintf(fid,"======================================================\n\n");

fprintf(fid,"Development correction: B1-2H exact 0.1C charge.\n");
fprintf(fid,"Holdout: exact 1C_full_charge.csv.\n");
fprintf(fid,"Independent with respect to correction-curve development; not globally unseen.\n\n");

fprintf(fid,"Holdout source SHA256 = %s\n",actualSHA);
fprintf(fid,"terminal anchor V/I = %.9f V / %.9f A\n", ...
    D.V_V(end),D.I_A(end));
fprintf(fid,"terminal-anchor throughput = %.9f Ah\n",qCum_Ah(end));
fprintf(fid,"evaluated SOC support = %.6f ... %.6f %%\n\n", ...
    100*min(z),100*max(z));

fprintf(fid,"Full trajectory:\n");
fprintf(fid,"Frozen RMSE = %.6f mV\n",fullFrozenRMSE);
fprintf(fid,"Corrected RMSE = %.6f mV\n",fullCorrectedRMSE);
fprintf(fid,"RMSE improvement = %.3f %%\n",fullRMSEImprovement_pct);
fprintf(fid,"Frozen MAE = %.6f mV\n",fullFrozenMAE);
fprintf(fid,"Corrected MAE = %.6f mV\n",fullCorrectedMAE);
fprintf(fid,"MAE improvement = %.3f %%\n",fullMAEImprovement_pct);
fprintf(fid,"Frozen mean bias = %+.6f mV\n",fullFrozenBias);
fprintf(fid,"Corrected mean bias = %+.6f mV\n",fullCorrectedBias);
fprintf(fid,"Frozen centered RMSE = %.6f mV\n",fullFrozenCentered);
fprintf(fid,"Corrected centered RMSE = %.6f mV\n",fullCorrectedCentered);
fprintf(fid,"Centered-RMSE change = %+.6f mV\n\n", ...
    centeredRMSEChange_mV);

fprintf(fid,"SOC-bin validation:\n");
for k = 1:height(BinMetrics)
    fprintf(fid, ...
        "%s | RMSE %.3f -> %.3f mV | improvement %.2f %% | bias %+.3f -> %+.3f mV | improved=%s\n", ...
        BinMetrics.Bin(k), ...
        BinMetrics.FrozenRMSE_mV(k), ...
        BinMetrics.CorrectedRMSE_mV(k), ...
        BinMetrics.RMSEImprovement_pct(k), ...
        BinMetrics.FrozenMeanBias_mV(k), ...
        BinMetrics.CorrectedMeanBias_mV(k), ...
        yes_no(BinMetrics.Improved(k)));
end

fprintf(fid,"\nCC/CV diagnostic:\n");
fprintf(fid,"CV start found = %s\n",yes_no(cvStartFound));
if cvStartFound
    fprintf(fid,"detected CV-start SOC = %.3f %%\n",100*socCVStart);
end

fprintf(fid,"\nProspective gates:\n");
fprintf(fid,"G1 RMSE reduction >=50%% = %s\n",pass_text(gateFullRMSEImprovement));
fprintf(fid,"G2 corrected RMSE <=10 mV = %s\n",pass_text(gateCorrectedFullRMSE));
fprintf(fid,"G3 MAE reduction >=50%% = %s\n",pass_text(gateFullMAEImprovement));
fprintf(fid,"G4 corrected |mean bias| <=10 mV = %s\n",pass_text(gateCorrectedBias));
fprintf(fid,"G5 all 4 SOC bins improve = %s\n",pass_text(gateAllBinsImprove));
fprintf(fid,"G6 max corrected bin RMSE <=15 mV = %s\n",pass_text(gateMaxBinRMSE));
fprintf(fid,"G7 centered-RMSE increase <=2 mV = %s\n",pass_text(gateCenteredPreservation));

fprintf(fid,"\nEXT2-C1 PASS = %s\n",pass_text(c1Pass));
fprintf(fid,"Descriptive class = %s\n",descriptiveClass);

fprintf(fid,"\nClaim boundary:\n");
fprintf(fid,"C1 tests transfer of an independently developed charging-baseline correction on one historical 1C full-charge trajectory. It does not establish equilibrium hysteresis, HPPC SOC provenance, cross-temperature/cross-cell generalization, or production readiness.\n");
fprintf(fid,"B1-2J remains HPPC_SOC_PROVENANCE_INCONCLUSIVE.\n");
fprintf(fid,"R2/tau2 continuous adaptation remains CLOSED.\n");

fclose(fid);

%% ------------------------------------------------------------------------
% 13. PROTECTED-ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);

[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetOut = fullfile( ...
    resultsDir,'EXT2_C1_protected_asset_audit_v1_1.csv');

writetable(AssetAudit,assetOut);

if ~assetsUnchanged
    error('EXT2:C1:ProtectedAssetChanged', ...
        'A protected frozen asset changed during C1. STOP.');
end

%% ------------------------------------------------------------------------
% 14. AUTODOC
% -------------------------------------------------------------------------
autodoc_C1( ...
    protocolDir,auditDir,handoffDir, ...
    fullFrozenRMSE,fullCorrectedRMSE, ...
    fullRMSEImprovement_pct, ...
    fullFrozenMAE,fullCorrectedMAE, ...
    fullMAEImprovement_pct, ...
    fullFrozenBias,fullCorrectedBias, ...
    fullFrozenCentered,fullCorrectedCentered, ...
    centeredRMSEChange_mV, ...
    BinMetrics, ...
    cvStartFound,socCVStart, ...
    gateFullRMSEImprovement, ...
    gateCorrectedFullRMSE, ...
    gateFullMAEImprovement, ...
    gateCorrectedBias, ...
    gateAllBinsImprove, ...
    gateMaxBinRMSE, ...
    gateCenteredPreservation, ...
    c1Pass,descriptiveClass, ...
    assetsUnchanged);

%% ------------------------------------------------------------------------
% 15. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-C1 COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Holdout identity / support:\n");
fprintf("  1C full-charge SHA256             : PASS\n");
fprintf("  Terminal anchor V / I             : %.6f V / %.6f A\n", ...
    D.V_V(end),D.I_A(end));
fprintf("  Terminal-anchor throughput        : %.6f Ah\n",qCum_Ah(end));
fprintf("  Evaluated SOC                     : %.3f ... %.3f %%\n", ...
    100*min(z),100*max(z));
fprintf("  Samples                           : %d\n",numel(z));

fprintf("\nFull-trajectory metrics:\n");
fprintf("  Frozen RMSE                       : %.3f mV\n",fullFrozenRMSE);
fprintf("  Corrected RMSE                    : %.3f mV\n",fullCorrectedRMSE);
fprintf("  RMSE improvement                  : %.2f %%\n",fullRMSEImprovement_pct);
fprintf("  Frozen MAE                        : %.3f mV\n",fullFrozenMAE);
fprintf("  Corrected MAE                     : %.3f mV\n",fullCorrectedMAE);
fprintf("  MAE improvement                   : %.2f %%\n",fullMAEImprovement_pct);
fprintf("  Frozen mean bias                  : %+.3f mV\n",fullFrozenBias);
fprintf("  Corrected mean bias               : %+.3f mV\n",fullCorrectedBias);
fprintf("  Frozen MaxAbs                     : %.3f mV\n", ...
    FullMetrics.FrozenMaxAbs_mV(1));
fprintf("  Corrected MaxAbs                  : %.3f mV\n", ...
    FullMetrics.CorrectedMaxAbs_mV(1));
fprintf("  Frozen centered RMSE              : %.3f mV\n",fullFrozenCentered);
fprintf("  Corrected centered RMSE           : %.3f mV\n",fullCorrectedCentered);
fprintf("  Centered RMSE change              : %+.3f mV\n",centeredRMSEChange_mV);

fprintf("\nSOC-bin metrics:\n");
for k = 1:height(BinMetrics)
    fprintf("  %-12s | RMSE %6.2f -> %6.2f mV | %7.2f %% | bias %+7.2f -> %+7.2f mV | %s\n", ...
        BinMetrics.Bin(k), ...
        BinMetrics.FrozenRMSE_mV(k), ...
        BinMetrics.CorrectedRMSE_mV(k), ...
        BinMetrics.RMSEImprovement_pct(k), ...
        BinMetrics.FrozenMeanBias_mV(k), ...
        BinMetrics.CorrectedMeanBias_mV(k), ...
        pass_text(BinMetrics.Improved(k)));
end

fprintf("\nCharge-phase diagnostic:\n");
fprintf("  CV start detected                 : %s\n",yes_no(cvStartFound));
if cvStartFound
    fprintf("  CV-start SOC                      : %.3f %%\n",100*socCVStart);
end

fprintf("\nProspective gates:\n");
fprintf("  G1 RMSE reduction >=50%%           : %s\n",pass_text(gateFullRMSEImprovement));
fprintf("  G2 corrected RMSE <=10 mV         : %s\n",pass_text(gateCorrectedFullRMSE));
fprintf("  G3 MAE reduction >=50%%            : %s\n",pass_text(gateFullMAEImprovement));
fprintf("  G4 corrected |mean bias| <=10 mV  : %s\n",pass_text(gateCorrectedBias));
fprintf("  G5 all 4 SOC bins improve         : %s\n",pass_text(gateAllBinsImprove));
fprintf("  G6 max corrected bin RMSE <=15 mV : %s\n",pass_text(gateMaxBinRMSE));
fprintf("  G7 centered increase <=2 mV       : %s\n",pass_text(gateCenteredPreservation));

fprintf("\nEXT2-C1 PASS                       : %s\n",pass_text(c1Pass));
fprintf("Descriptive class:\n  %s\n",descriptiveClass);
fprintf("B1-2J HPPC SOC provenance          : INCONCLUSIVE\n");
fprintf("R2/tau2 continuous adaptation      : CLOSED\n");
fprintf("Protected assets unchanged         : %s\n",pass_text(assetsUnchanged));
fprintf("AUTODOC updated                     : PASS\n\n");

fprintf("Results:\n%s\n",resultsDir);
fprintf("Docs:\n%s\n\n",docsDir);


%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function T = compute_metrics_table(region,z,I,r0,r1)

z = z(:);
I = I(:);
r0 = r0(:);
r1 = r1(:);

if numel(z) ~= numel(I) || ...
   numel(z) ~= numel(r0) || ...
   numel(z) ~= numel(r1)
    error('EXT2:C1:MetricVectorLength', ...
        'Metric vectors must have equal length.');
end

n = numel(z);

rmse0 = sqrt(mean(r0.^2))*1000;
rmse1 = sqrt(mean(r1.^2))*1000;

mae0 = mean(abs(r0))*1000;
mae1 = mean(abs(r1))*1000;

bias0 = mean(r0)*1000;
bias1 = mean(r1)*1000;

max0 = max(abs(r0))*1000;
max1 = max(abs(r1))*1000;

c0 = r0-mean(r0);
c1 = r1-mean(r1);

centered0 = sqrt(mean(c0.^2))*1000;
centered1 = sqrt(mean(c1.^2))*1000;

if rmse0 > eps
    imp = 100*(rmse0-rmse1)/rmse0;
else
    imp = 0;
end

Region = string(region);
NSamples = n;
SOC_Min = min(z);
SOC_Max = max(z);
MeanCurrent_A = mean(I);

FrozenRMSE_mV = rmse0;
CorrectedRMSE_mV = rmse1;
RMSEImprovement_pct = imp;

FrozenMAE_mV = mae0;
CorrectedMAE_mV = mae1;

FrozenMeanBias_mV = bias0;
CorrectedMeanBias_mV = bias1;

FrozenMaxAbs_mV = max0;
CorrectedMaxAbs_mV = max1;

FrozenCenteredRMSE_mV = centered0;
CorrectedCenteredRMSE_mV = centered1;

T = table( ...
    Region,NSamples,SOC_Min,SOC_Max,MeanCurrent_A, ...
    FrozenRMSE_mV,CorrectedRMSE_mV,RMSEImprovement_pct, ...
    FrozenMAE_mV,CorrectedMAE_mV, ...
    FrozenMeanBias_mV,CorrectedMeanBias_mV, ...
    FrozenMaxAbs_mV,CorrectedMaxAbs_mV, ...
    FrozenCenteredRMSE_mV,CorrectedCenteredRMSE_mV, ...
    'VariableNames', { ...
    'Region','NSamples','SOC_Min','SOC_Max','MeanCurrent_A', ...
    'FrozenRMSE_mV','CorrectedRMSE_mV','RMSEImprovement_pct', ...
    'FrozenMAE_mV','CorrectedMAE_mV', ...
    'FrozenMeanBias_mV','CorrectedMeanBias_mV', ...
    'FrozenMaxAbs_mV','CorrectedMaxAbs_mV', ...
    'FrozenCenteredRMSE_mV','CorrectedCenteredRMSE_mV'});
end


function S = table_row_to_struct(T)

S = struct();

names = T.Properties.VariableNames;

for k = 1:numel(names)
    value = T.(names{k})(1);

    if iscell(value)
        value = value{1};
    end

    S.(names{k}) = value;
end
end


function D = load_ngu_uiv_full(filePath)

txt = fileread(filePath);
lines = splitlines(string(txt));

if isempty(lines)
    error('EXT2:C1:EmptyProfile', ...
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
    error('EXT2:C1:NGUHeaderMissing', ...
        'NGU header not found: %s',char(filePath));
end

headers = split(lines(headerIdx),',');
headers = strtrim(erase(headers,'"'));
headers = erase(headers,string(char(65279)));

iT = find(strcmpi(headers,'Timestamp'),1);
iV = find(strcmpi(headers,'U1[V]'),1);
iI = find(strcmpi(headers,'I1[A]'),1);

if isempty(iT) || isempty(iV) || isempty(iI)
    error('EXT2:C1:NGUColumnsMissing', ...
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
    error('EXT2:C1:NoValidData', ...
        'Too few valid rows: %s',char(filePath));
end

t = unwrap_elapsed_time(tRaw);
t = t-t(1);

if any(diff(t) <= 0)
    error('EXT2:C1:NonMonotonicTime', ...
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
    error('EXT2:C1:ChargeAnchorCandidate', ...
        'No terminal full-charge anchor candidate found.');
end

score = ...
    abs(D.V_V(cand)-cfg.fullVoltage_V)/cfg.fullVoltageTol_V + ...
    abs(D.I_A(cand)-cfg.fullCurrent_A)/cfg.fullCurrentTol_A;

[~,j] = min(score);
idx = cand(j);

if abs(D.V_V(idx)-cfg.fullVoltage_V) > cfg.fullVoltageTol_V || ...
   abs(D.I_A(idx)-cfg.fullCurrent_A) > cfg.fullCurrentTol_A

    error('EXT2:C1:ChargeAnchorFail', ...
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
    error('EXT2:C1:RCVectorLength', ...
        't/I/R/tau vectors must have equal length.');
end

v = zeros(N,1);
v(1) = v0;

for k = 1:N-1

    dt = t(k+1)-t(k);

    if dt <= 0
        error('EXT2:C1:NonPositiveDt', ...
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
    error('EXT2:C1:HashOpenFailed', ...
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

    error('EXT2:C1:HashFailed', ...
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
    error('EXT2:C1:AssetSnapshotMismatch', ...
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


function autodoc_C1( ...
    protocolDir,auditDir,handoffDir, ...
    frozenRMSE,corrRMSE,rmseImp, ...
    frozenMAE,corrMAE,maeImp, ...
    frozenBias,corrBias, ...
    frozenCentered,corrCentered,centeredChange, ...
    BinMetrics, ...
    cvFound,socCV, ...
    g1,g2,g3,g4,g5,g6,g7, ...
    c1Pass,descriptiveClass,assetsUnchanged)

protocolPath = fullfile( ...
    protocolDir,'EXT2_C1_PROTOCOL_v1_1.md');

protocol = {
'# EXT2-C1 Protocol v1.1 — Independent Full-Trajectory Charge-Baseline Holdout'
''
'## Purpose'
''
'Validate whether the B1-2H correction derived only from the historical 0.1C charge transfers over the complete 17-85% SOC trajectory of `1C_full_charge.csv`.'
''
'## Independence boundary'
''
'The holdout voltage is not used to fit or modify the B1-2H correction. The 1C record appeared in earlier capacity/provenance audits, therefore C1 is independent with respect to correction-curve development rather than globally unseen.'
''
'## Compared models'
''
'- frozen SOC-dependent 2RC'
'- frozen 2RC + B1-2H additive charge-direction OCV/baseline correction'
''
'## SOC basis'
''
'FROZEN_QREF, reconstructed backward from the terminal 4.2 V / approximately 50 mA full-charge anchor.'
''
'## Prospective gates'
''
'- full-trajectory RMSE reduction >=50%'
'- corrected full RMSE <=10 mV'
'- full-trajectory MAE reduction >=50%'
'- corrected |mean bias| <=10 mV'
'- all four SOC bins improve RMSE'
'- maximum corrected bin RMSE <=15 mV'
'- centered-RMSE increase <=2 mV'
''
'## Claim boundary'
''
'A PASS supports a transferable historical charging-baseline correction model-form candidate. It does not establish equilibrium hysteresis, HPPC SOC provenance, cross-temperature/cross-cell generalization or production readiness.'
''
'B1-2J remains HPPC_SOC_PROVENANCE_INCONCLUSIVE.'
'R2/tau2 continuous adaptation remains CLOSED.'
};

write_text_lines(protocolPath,protocol);

auditPath = fullfile( ...
    auditDir,'EXT2_C1_EXECUTION_AUDIT_v1_1.md');

audit = {
'# EXT2-C1 Execution Audit v1.1'
''
'## Status'
''
'`CLOSED / FULL-TRAJECTORY HOLDOUT COMPLETE`'
''
'Implementation note: C1 v1 stopped after successful source/anchor/SOC preflight because MATLAB rejected indexed assignment of a populated struct into fieldless `struct([])` in the CC/CV phase-summary builder. v1.1 changes only that container operation to struct concatenation; scientific inputs, correction curve, metrics, SOC bins and all seven prospective gates are unchanged.'
''
sprintf('- frozen RMSE: **%.3f mV**',frozenRMSE)
sprintf('- corrected RMSE: **%.3f mV**',corrRMSE)
sprintf('- RMSE improvement: **%.2f%%**',rmseImp)
sprintf('- frozen MAE: **%.3f mV**',frozenMAE)
sprintf('- corrected MAE: **%.3f mV**',corrMAE)
sprintf('- MAE improvement: **%.2f%%**',maeImp)
sprintf('- frozen mean bias: **%+.3f mV**',frozenBias)
sprintf('- corrected mean bias: **%+.3f mV**',corrBias)
sprintf('- frozen centered RMSE: **%.3f mV**',frozenCentered)
sprintf('- corrected centered RMSE: **%.3f mV**',corrCentered)
sprintf('- centered-RMSE change: **%+.3f mV**',centeredChange)
sprintf('- CV start detected: **%s**',yes_no(cvFound))
};

if cvFound
    audit{end+1} = sprintf('- detected CV-start SOC: **%.3f%%**',100*socCV);
end

audit{end+1} = '';
audit{end+1} = '## SOC-bin validation';
audit{end+1} = '';
audit{end+1} = '| Bin | Frozen RMSE | Corrected RMSE | Improvement | Frozen bias | Corrected bias |';
audit{end+1} = '|---|---:|---:|---:|---:|---:|';

for k = 1:height(BinMetrics)

    audit{end+1} = sprintf( ...
        '| %s | %.2f mV | %.2f mV | %.2f%% | %+.2f mV | %+.2f mV |', ...
        BinMetrics.Bin(k), ...
        BinMetrics.FrozenRMSE_mV(k), ...
        BinMetrics.CorrectedRMSE_mV(k), ...
        BinMetrics.RMSEImprovement_pct(k), ...
        BinMetrics.FrozenMeanBias_mV(k), ...
        BinMetrics.CorrectedMeanBias_mV(k)); %#ok<AGROW>
end

audit{end+1} = '';
audit{end+1} = '## Prospective gates';
audit{end+1} = '';
audit{end+1} = sprintf('- G1 RMSE reduction >=50%%: **%s**',pass_text(g1));
audit{end+1} = sprintf('- G2 corrected RMSE <=10 mV: **%s**',pass_text(g2));
audit{end+1} = sprintf('- G3 MAE reduction >=50%%: **%s**',pass_text(g3));
audit{end+1} = sprintf('- G4 corrected |mean bias| <=10 mV: **%s**',pass_text(g4));
audit{end+1} = sprintf('- G5 all four SOC bins improve: **%s**',pass_text(g5));
audit{end+1} = sprintf('- G6 max corrected bin RMSE <=15 mV: **%s**',pass_text(g6));
audit{end+1} = sprintf('- G7 centered-RMSE increase <=2 mV: **%s**',pass_text(g7));
audit{end+1} = '';
audit{end+1} = sprintf('**EXT2-C1 PASS: %s**',pass_text(c1Pass));
audit{end+1} = '';
audit{end+1} = ['Descriptive class: `' char(descriptiveClass) '`'];
audit{end+1} = '';
audit{end+1} = sprintf('Protected frozen assets unchanged: **%s**',pass_text(assetsUnchanged));
audit{end+1} = '';
audit{end+1} = 'B1-2J remains HPPC_SOC_PROVENANCE_INCONCLUSIVE. R2/tau2 continuous adaptation remains CLOSED.';

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
'- B1-2B original real-voltage R2/tau2 target consistency: FAIL'
'- B1-2C baseline-bias dominant'
'- B1-2D SOC-axis/qRef sensitivity strongly reduces baseline'
'- B1-2E voltage-optimal effective qRef not independently supported as physical capacity'
'- B1-2F/B1-2G direction-sensitive pseudo-OCV evidence robust across SOC-axis conventions'
'- B1-2H independent 0.1C charge baseline correction: PASS on 18/18 DC-AC windows'
'- B1-2I confounder-controlled R2/tau2 target consistency: FAIL; dynamic adaptation CLOSED'
'- B1-2J HPPC SOC provenance: INCONCLUSIVE'
sprintf('- C1 full-trajectory 1C charge holdout: %s',pass_text(c1Pass))
sprintf('- C1 class: `%s`',descriptiveClass)
''
'## C1 core metrics'
''
sprintf('- RMSE: %.3f -> %.3f mV (%.2f%% improvement)',frozenRMSE,corrRMSE,rmseImp)
sprintf('- MAE: %.3f -> %.3f mV (%.2f%% improvement)',frozenMAE,corrMAE,maeImp)
sprintf('- mean bias: %+.3f -> %+.3f mV',frozenBias,corrBias)
sprintf('- centered RMSE: %.3f -> %.3f mV',frozenCentered,corrCentered)
''
'## Claim boundary'
''
'C1 concerns transfer of a historical charging-baseline correction. It does not prove equilibrium hysteresis or resolve the inconclusive HPPC SOC provenance.'
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
'header -> PATHS -> frozen-input/source checks -> analysis -> results -> protected SHA audit -> AUTODOC -> decision/claim boundary -> local functions.'
''
'## Current technical position'
''
'- The original R2/tau2 continuous-adaptation candidate is closed by measured-voltage target inconsistency, even after OCV/baseline confounder control.'
'- HPPC SOC-label provenance remains inconclusive because authoritative current history does not fully bridge pulse states to a physical SOC anchor.'
'- B1-2H established an independently developed 0.1C charge-baseline correction on DC-AC windows.'
sprintf('- C1 full-trajectory transfer result: %s',descriptiveClass)
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
    error('EXT2:C1:DocWriteFailed', ...
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


function s = yes_no(tf)

if tf
    s = 'YES';
else
    s = 'NO';
end
end
