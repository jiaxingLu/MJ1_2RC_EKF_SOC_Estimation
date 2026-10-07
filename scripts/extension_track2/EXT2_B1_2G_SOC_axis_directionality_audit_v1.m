% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_B1_2G_SOC_axis_directionality_audit_v1.m
% MJ1 2RC-EKF EXT2-B1
% B1-2G SOC-Axis Directionality Robustness Audit v1
%
% PURPOSE
%   Resolve the ambiguity exposed by B1-2F:
%     - strong low-rate charge pseudo-OCV offset,
%     - finite 1C charge/discharge directional gap,
%     - but measurable dependence on SOC-axis convention.
%
% This script asks:
%   1) Does charge-vs-discharge directionality keep the SAME SIGN under
%      SELF_NORMALIZED, NOMINAL_3P5, and FROZEN_QREF SOC axes?
%   2) Is the low-rate charge branch above the frozen OCV under all axes?
%   3) Which SOC-axis convention best aligns 0.1C and 1C charge branches?
%   4) Does the B1-2D common-mode correction remain closer to the low-rate
%      charge pseudo-OCV than to a pure dynamic R2/tau2 explanation?
%
% DIAGNOSTIC ONLY
%   - No raw-data refit.
%   - No R2/tau2 fitting.
%   - No qRef optimization.
%   - No online adaptation.
%   - No frozen-model modification.
%
% INPUTS
%   results/EXT2_B1_2F_pseudo_OCV_summary_v1.csv
%   results/EXT2_B1_2D_common_mode_bias_by_SOC_v1.csv
%
% OUTPUTS
%   results/EXT2_B1_2G_axis_directionality_matrix_v1.csv
%   results/EXT2_B1_2G_axis_summary_v1.csv
%   results/EXT2_B1_2G_cross_axis_spread_v1.csv
%   results/EXT2_B1_2G_directionality_report_v1.txt
%   results/EXT2_B1_2G_directionality_by_axis_v1.png
%   results/EXT2_B1_2G_protected_asset_audit_v1.csv
%
% AUTODOC
%   Automatically updates:
%     docs/protocols/EXT2_B1_2G_PROTOCOL_v1.md
%     docs/audits/EXT2_B1_2G_EXECUTION_AUDIT_v1.md
%     docs/handoff/EXT2_CURRENT_HANDOFF.md
%     docs/handoff/EXT2_PROJECT_CONTINUITY_CURRENT.md
%
% MATLAB compatibility:
%   Base MATLAB only.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-2G | SOC-Axis Directionality Robustness Audit v1\n");
fprintf(" B1-2F post-processing | No fitting / no adaptation\n");
fprintf("============================================================\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));

if strlength(scriptDir) == 0
    error('EXT2:B12G:RunAsFile', ...
        'Run this script from its saved .m file.');
end

ext2Dir = scriptDir;

[~,folderName] = fileparts(ext2Dir);

if ~strcmpi(string(folderName),"EXT2_dynamic_parameter_identifiability")
    error('EXT2:B12G:WrongFolder', ...
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

b12fFile = fullfile( ...
    resultsDir,'EXT2_B1_2F_pseudo_OCV_summary_v1.csv');

b12dFile = fullfile( ...
    resultsDir,'EXT2_B1_2D_common_mode_bias_by_SOC_v1.csv');

required = {b12fFile,b12dFile};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:B12G:MissingInput', ...
            'Required result file not found:\n%s',required{k});
    end
end

F = readtable(b12fFile);
D = readtable(b12dFile);

requiredF = { ...
    'Axis','Profile','Direction','CurrentClass','TargetSOC', ...
    'FrozenOCV_V','PseudoOCV_Dynamic_V', ...
    'DynamicOffsetFromFrozen_mV','DynamicMinusQS_mV'};

missingF = setdiff(requiredF,F.Properties.VariableNames);

if ~isempty(missingF)
    error('EXT2:B12G:B12FContract', ...
        'B1-2F summary missing variable(s): %s', ...
        strjoin(missingF,', '));
end

requiredD = {'TargetSOC','SharedVoltageCorrection_mV'};

missingD = setdiff(requiredD,D.Properties.VariableNames);

if ~isempty(missingD)
    error('EXT2:B12G:B12DContract', ...
        'B1-2D summary missing variable(s): %s', ...
        strjoin(missingD,', '));
end

if height(F) ~= 27
    error('EXT2:B12G:B12FRowCount', ...
        'Expected 27 B1-2F rows (3 axes x 3 profiles x 3 SOC); found %d.', ...
        height(F));
end

fprintf("EXT2 root  : %s\n",ext2Dir);
fprintf("Results    : %s\n",resultsDir);
fprintf("Docs AUTO  : %s\n\n",docsDir);

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
% 2. BUILD AXIS x SOC DIRECTIONAL MATRIX
% -------------------------------------------------------------------------
axes = ["SELF_NORMALIZED","NOMINAL_3P5","FROZEN_QREF"];
socTargets = [0.30 0.50 0.70];

rows = struct([]);
ir = 0;

for ia = 1:numel(axes)

    axisName = axes(ia);

    for iz = 1:numel(socTargets)

        z = socTargets(iz);

        low = get_one_row(F,axisName,"CHARGE_0P1C",z);
        chg = get_one_row(F,axisName,"CHARGE_1C",z);
        dsg = get_one_row(F,axisName,"DISCHARGE_1C",z);

        Drow = D(abs(D.TargetSOC-z) < 1e-12,:);

        if height(Drow) ~= 1
            error('EXT2:B12G:B12DSOCLookup', ...
                'Expected one B1-2D row at SOC %.0f%%.',100*z);
        end

        gap = ...
            (chg.PseudoOCV_Dynamic_V-dsg.PseudoOCV_Dynamic_V)*1000;

        lowVsCharge = ...
            (low.PseudoOCV_Dynamic_V-chg.PseudoOCV_Dynamic_V)*1000;

        midpoint = ...
            0.5*(chg.PseudoOCV_Dynamic_V+dsg.PseudoOCV_Dynamic_V);

        midpointOffset = ...
            (midpoint-chg.FrozenOCV_V)*1000;

        b12dCorrection = Drow.SharedVoltageCorrection_mV;

        ir = ir+1;

        rows(ir).Axis = axisName; %#ok<SAGROW>
        rows(ir).TargetSOC = z;
        rows(ir).LowRateChargeOffset_mV = ...
            low.DynamicOffsetFromFrozen_mV;
        rows(ir).OneCChargeOffset_mV = ...
            chg.DynamicOffsetFromFrozen_mV;
        rows(ir).OneCDischargeOffset_mV = ...
            dsg.DynamicOffsetFromFrozen_mV;
        rows(ir).ChargeDischargeGap_mV = gap;
        rows(ir).LowRateMinusOneCCharge_mV = lowVsCharge;
        rows(ir).ChargeDischargeMidpointOffset_mV = midpointOffset;
        rows(ir).B12D_SharedCorrection_mV = b12dCorrection;
        rows(ir).AbsB12DMinusLowRate_mV = ...
            abs(b12dCorrection-low.DynamicOffsetFromFrozen_mV);
        rows(ir).AbsB12DMinusOneCCharge_mV = ...
            abs(b12dCorrection-chg.DynamicOffsetFromFrozen_mV);
        rows(ir).DirectionalGapPositive = gap > 0;
        rows(ir).LowRateAboveFrozen = ...
            low.DynamicOffsetFromFrozen_mV > 0;
        rows(ir).OneCChargeAboveDischarge = gap > 0;
    end
end

AxisDirectionalityMatrix = struct2table(rows);

%% ------------------------------------------------------------------------
% 3. AXIS SUMMARY
% -------------------------------------------------------------------------
axisRows = struct([]);

for ia = 1:numel(axes)

    axisName = axes(ia);
    T = AxisDirectionalityMatrix( ...
        string(AxisDirectionalityMatrix.Axis) == axisName,:);

    axisRows(ia).Axis = axisName; %#ok<SAGROW>
    axisRows(ia).MedianLowRateChargeOffset_mV = ...
        median(T.LowRateChargeOffset_mV);
    axisRows(ia).MedianOneCChargeOffset_mV = ...
        median(T.OneCChargeOffset_mV);
    axisRows(ia).MedianOneCDischargeOffset_mV = ...
        median(T.OneCDischargeOffset_mV);
    axisRows(ia).MedianChargeDischargeGap_mV = ...
        median(T.ChargeDischargeGap_mV);
    axisRows(ia).MedianAbsLowRateVsOneCCharge_mV = ...
        median(abs(T.LowRateMinusOneCCharge_mV));
    axisRows(ia).MedianChargeDischargeMidpointOffset_mV = ...
        median(T.ChargeDischargeMidpointOffset_mV);
    axisRows(ia).MedianAbsB12DMinusLowRate_mV = ...
        median(T.AbsB12DMinusLowRate_mV);
    axisRows(ia).MedianAbsB12DMinusOneCCharge_mV = ...
        median(T.AbsB12DMinusOneCCharge_mV);
    axisRows(ia).DirectionalGapPositive_All3SOC = ...
        all(T.DirectionalGapPositive);
    axisRows(ia).LowRateAboveFrozen_All3SOC = ...
        all(T.LowRateAboveFrozen);
end

AxisSummary = struct2table(axisRows);

%% ------------------------------------------------------------------------
% 4. CROSS-AXIS SPREAD
% -------------------------------------------------------------------------
spreadRows = struct([]);
isr = 0;

profiles = ["CHARGE_0P1C","CHARGE_1C","DISCHARGE_1C"];

for ip = 1:numel(profiles)

    p = profiles(ip);

    for iz = 1:numel(socTargets)

        z = socTargets(iz);

        vals = nan(numel(axes),1);

        for ia = 1:numel(axes)
            R = get_one_row(F,axes(ia),p,z);
            vals(ia) = R.DynamicOffsetFromFrozen_mV;
        end

        isr = isr+1;

        spreadRows(isr).Profile = p; %#ok<SAGROW>
        spreadRows(isr).TargetSOC = z;
        spreadRows(isr).MinOffset_mV = min(vals);
        spreadRows(isr).MaxOffset_mV = max(vals);
        spreadRows(isr).CrossAxisRange_mV = max(vals)-min(vals);
        spreadRows(isr).AllAxesPositive = all(vals > 0);
        spreadRows(isr).AllAxesNegative = all(vals < 0);
    end
end

CrossAxisSpread = struct2table(spreadRows);

%% ------------------------------------------------------------------------
% 5. DESCRIPTIVE ROBUSTNESS CLASS
% -------------------------------------------------------------------------
all9GapsPositive = all(AxisDirectionalityMatrix.DirectionalGapPositive);

lowRows = CrossAxisSpread( ...
    string(CrossAxisSpread.Profile) == "CHARGE_0P1C",:);

lowRatePositiveAllAxesSOC = all(lowRows.AllAxesPositive);

[bestChargeRateMismatch,bestAxisIdx] = min( ...
    AxisSummary.MedianAbsLowRateVsOneCCharge_mV);

bestChargeRateAxis = AxisSummary.Axis(bestAxisIdx);

medianDirectionalGapAcrossAxes = ...
    median(AxisSummary.MedianChargeDischargeGap_mV);

medianCrossAxisRange = ...
    median(CrossAxisSpread.CrossAxisRange_mV);

medianB12DLowAcrossAxes = ...
    median(AxisSummary.MedianAbsB12DMinusLowRate_mV);

% Relative, not absolute, descriptive rule:
% if the best same-direction rate mismatch is smaller than the directional
% charge-vs-discharge gap, directional information remains more coherent
% than the charge-rate/history discrepancy.
chargeRateMismatchLessThanDirectionalGap = ...
    bestChargeRateMismatch < medianDirectionalGapAcrossAxes;

if all9GapsPositive && ...
   lowRatePositiveAllAxesSOC && ...
   chargeRateMismatchLessThanDirectionalGap

    descriptiveClass = ...
        "DIRECTIONAL_EFFECT_ROBUST_ACROSS_SOC_AXES";

elseif all9GapsPositive && lowRatePositiveAllAxesSOC

    descriptiveClass = ...
        "DIRECTIONAL_EFFECT_SIGN_ROBUST_BUT_CHARGE_RATE_HISTORY_DEPENDENT";

elseif all9GapsPositive

    descriptiveClass = ...
        "DIRECTIONAL_GAP_SIGN_ROBUST_LOW_RATE_BRANCH_AXIS_SENSITIVE";

else

    descriptiveClass = ...
        "SOC_AXIS_CONFUNDED_DIRECTIONALITY";
end

%% ------------------------------------------------------------------------
% 6. SAVE
% -------------------------------------------------------------------------
matrixFile = fullfile( ...
    resultsDir,'EXT2_B1_2G_axis_directionality_matrix_v1.csv');

axisFile = fullfile( ...
    resultsDir,'EXT2_B1_2G_axis_summary_v1.csv');

spreadFile = fullfile( ...
    resultsDir,'EXT2_B1_2G_cross_axis_spread_v1.csv');

writetable(AxisDirectionalityMatrix,matrixFile);
writetable(AxisSummary,axisFile);
writetable(CrossAxisSpread,spreadFile);

reportFile = fullfile( ...
    resultsDir,'EXT2_B1_2G_directionality_report_v1.txt');

fid = fopen(reportFile,'w');

if fid < 0
    error('EXT2:B12G:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-B1-2G SOC-Axis Directionality Robustness Audit v1\n");
fprintf(fid,"===========================================================\n\n");
fprintf(fid,"Diagnostic only. No fitting/adaptation.\n\n");

fprintf(fid,"Axis summaries:\n");

for k = 1:height(AxisSummary)

    fprintf(fid, ...
        "%s | low-rate %+8.3f mV | 1C charge %+8.3f mV | 1C discharge %+8.3f mV | gap %+8.3f mV | |0.1C-1C charge| %.3f mV | |B1-2D-low| %.3f mV | gap positive all SOC=%s\n", ...
        AxisSummary.Axis(k), ...
        AxisSummary.MedianLowRateChargeOffset_mV(k), ...
        AxisSummary.MedianOneCChargeOffset_mV(k), ...
        AxisSummary.MedianOneCDischargeOffset_mV(k), ...
        AxisSummary.MedianChargeDischargeGap_mV(k), ...
        AxisSummary.MedianAbsLowRateVsOneCCharge_mV(k), ...
        AxisSummary.MedianAbsB12DMinusLowRate_mV(k), ...
        yes_no(AxisSummary.DirectionalGapPositive_All3SOC(k)));
end

fprintf(fid,"\nAggregate robustness:\n");
fprintf(fid,"All 9 charge-discharge gaps positive = %s\n", ...
    yes_no(all9GapsPositive));
fprintf(fid,"Low-rate charge above frozen for all axes/SOC = %s\n", ...
    yes_no(lowRatePositiveAllAxesSOC));
fprintf(fid,"Best charge-rate alignment axis = %s\n",bestChargeRateAxis);
fprintf(fid,"Best median |0.1C - 1C charge| = %.3f mV\n", ...
    bestChargeRateMismatch);
fprintf(fid,"Median directional gap across axes = %.3f mV\n", ...
    medianDirectionalGapAcrossAxes);
fprintf(fid,"Median cross-axis offset range = %.3f mV\n", ...
    medianCrossAxisRange);
fprintf(fid,"Median |B1-2D correction - low-rate| across axes = %.3f mV\n", ...
    medianB12DLowAcrossAxes);
fprintf(fid,"Descriptive class = %s\n",descriptiveClass);

fprintf(fid,"\nClaim boundary:\n");
fprintf(fid,"This stage tests sign/magnitude robustness across existing SOC-axis conventions only. It is not an equilibrium hysteresis measurement.\n");
fprintf(fid,"B1-2B remains FAIL and B2 remains STOP.\n");
fclose(fid);

%% ------------------------------------------------------------------------
% 7. FIGURE
% -------------------------------------------------------------------------
f = figure('Name','EXT2-B1-2G directionality','Visible','off');

tiledlayout(1,3);

for ia = 1:numel(axes)

    T = AxisDirectionalityMatrix( ...
        string(AxisDirectionalityMatrix.Axis) == axes(ia),:);

    T = sortrows(T,'TargetSOC');

    nexttile;

    plot(100*T.TargetSOC,T.LowRateChargeOffset_mV,'-o','LineWidth',1.2);
    hold on;
    plot(100*T.TargetSOC,T.OneCChargeOffset_mV,'-s','LineWidth',1.2);
    plot(100*T.TargetSOC,T.OneCDischargeOffset_mV,'-^','LineWidth',1.2);
    yline(0,'--');

    xlabel('SOC [%]');
    ylabel('Pseudo-OCV offset [mV]');
    title(char(axes(ia)));
    grid on;

    if ia == 1
        legend('0.1C charge','1C charge','1C discharge', ...
            'Location','best');
    end
end

sgtitle('EXT2-B1-2G | pseudo-OCV directionality across SOC axes');

figureFile = fullfile( ...
    resultsDir,'EXT2_B1_2G_directionality_by_axis_v1.png');

try
    exportgraphics(f,figureFile,'Resolution',180);
catch ME
    warning('EXT2:B12G:PlotExport', ...
        'Could not export directionality figure: %s',ME.message);
end

close(f);

%% ------------------------------------------------------------------------
% 8. PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);

[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetFile = fullfile( ...
    resultsDir,'EXT2_B1_2G_protected_asset_audit_v1.csv');

writetable(AssetAudit,assetFile);

if ~assetsUnchanged
    error('EXT2:B12G:ProtectedAssetChanged', ...
        'A protected frozen asset changed during B1-2G. STOP.');
end

%% ------------------------------------------------------------------------
% 9. AUTODOC
% -------------------------------------------------------------------------
autodoc_B12G( ...
    protocolDir,auditDir,handoffDir, ...
    AxisSummary,all9GapsPositive, ...
    lowRatePositiveAllAxesSOC,bestChargeRateAxis, ...
    bestChargeRateMismatch,medianDirectionalGapAcrossAxes, ...
    medianCrossAxisRange,medianB12DLowAcrossAxes, ...
    descriptiveClass,assetsUnchanged);

%% ------------------------------------------------------------------------
% 10. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-B1-2G COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Axis summaries:\n");

for k = 1:height(AxisSummary)

    fprintf("  %-16s | low-rate %+7.2f | 1C chg %+7.2f | 1C dsg %+7.2f | gap %+7.2f | |0.1C-1C chg| %.2f | |B1-2D-low| %.2f mV\n", ...
        AxisSummary.Axis(k), ...
        AxisSummary.MedianLowRateChargeOffset_mV(k), ...
        AxisSummary.MedianOneCChargeOffset_mV(k), ...
        AxisSummary.MedianOneCDischargeOffset_mV(k), ...
        AxisSummary.MedianChargeDischargeGap_mV(k), ...
        AxisSummary.MedianAbsLowRateVsOneCCharge_mV(k), ...
        AxisSummary.MedianAbsB12DMinusLowRate_mV(k));
end

fprintf("\nRobustness:\n");
fprintf("  All 9 charge-discharge gaps positive : %s\n", ...
    yes_no(all9GapsPositive));
fprintf("  Low-rate charge above frozen all axes/SOC: %s\n", ...
    yes_no(lowRatePositiveAllAxesSOC));
fprintf("  Best charge-rate alignment axis      : %s\n", ...
    bestChargeRateAxis);
fprintf("  Best median |0.1C - 1C charge|       : %.3f mV\n", ...
    bestChargeRateMismatch);
fprintf("  Median directional gap across axes   : %.3f mV\n", ...
    medianDirectionalGapAcrossAxes);
fprintf("  Median cross-axis offset range       : %.3f mV\n", ...
    medianCrossAxisRange);
fprintf("  Median |B1-2D correction - low-rate| : %.3f mV\n", ...
    medianB12DLowAcrossAxes);

fprintf("\nDescriptive class:\n  %s\n",descriptiveClass);
fprintf("Protected assets unchanged             : %s\n", ...
    pass_text(assetsUnchanged));
fprintf("AUTODOC updated                         : PASS\n");
fprintf("B1-2B remains FAIL / B2 remains STOP.\n\n");

fprintf("Results:\n%s\n",resultsDir);
fprintf("Docs:\n%s\n\n",docsDir);


%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function row = get_one_row(T,axisName,profileName,targetSOC)

mask = ...
    string(T.Axis) == string(axisName) & ...
    string(T.Profile) == string(profileName) & ...
    abs(T.TargetSOC-targetSOC) < 1e-12;

row = T(mask,:);

if height(row) ~= 1
    error('EXT2:B12G:RowLookup', ...
        'Expected one row for %s / %s at SOC %.0f%%.', ...
        char(string(axisName)),char(string(profileName)),100*targetSOC);
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
    error('EXT2:B12G:HashOpenFailed', ...
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

    error('EXT2:B12G:HashFailed', ...
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
    error('EXT2:B12G:AssetSnapshotMismatch', ...
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


function autodoc_B12G( ...
    protocolDir,auditDir,handoffDir, ...
    AxisSummary,allGaps,lowPositive,bestAxis, ...
    bestMismatch,medianGap,medianSpread,medianB12DLow, ...
    descriptiveClass,assetsUnchanged)

protocolPath = fullfile( ...
    protocolDir,'EXT2_B1_2G_PROTOCOL_v1.md');

protocol = {
'# EXT2-B1-2G Protocol v1 — SOC-Axis Directionality Robustness Audit'
''
'## Purpose'
''
'Test whether the directional pseudo-OCV evidence found in B1-2F keeps the same sign and relative structure under SELF_NORMALIZED, NOMINAL_3P5 and FROZEN_QREF SOC axes.'
''
'This is post-processing only. No raw-data refit, qRef optimization, R2/tau2 fitting or online adaptation is performed.'
''
'## Main diagnostics'
''
'- charge-discharge gap sign across 3 axes x 3 SOC points'
'- low-rate charge offset sign across all axes/SOC'
'- 0.1C vs 1C charge branch alignment by SOC-axis convention'
'- B1-2D shared correction vs low-rate charge pseudo-OCV'
'- cross-axis offset spread'
''
'## Claim boundary'
''
'B1-2G tests robustness across existing SOC-axis conventions. It is not an equilibrium hysteresis measurement.'
''
'B1-2B remains FAIL and B2 remains STOP.'
};

write_text_lines(protocolPath,protocol);

auditPath = fullfile( ...
    auditDir,'EXT2_B1_2G_EXECUTION_AUDIT_v1.md');

audit = {
'# EXT2-B1-2G Execution Audit v1'
''
'## Status'
''
'`CLOSED / DIAGNOSTIC COMPLETE`'
''
sprintf('- all 9 charge-discharge gaps positive: **%s**',yes_no(allGaps))
sprintf('- low-rate charge above frozen OCV for all axes/SOC: **%s**',yes_no(lowPositive))
sprintf('- best charge-rate alignment axis: **%s**',bestAxis)
sprintf('- best median |0.1C - 1C charge|: **%.3f mV**',bestMismatch)
sprintf('- median directional gap across axes: **%.3f mV**',medianGap)
sprintf('- median cross-axis offset range: **%.3f mV**',medianSpread)
sprintf('- median |B1-2D correction - low-rate| across axes: **%.3f mV**',medianB12DLow)
sprintf('- protected frozen assets unchanged: **%s**',pass_text(assetsUnchanged))
''
'## Axis summaries'
''
'| Axis | Low-rate charge | 1C charge | 1C discharge | Directional gap | |0.1C-1C charge| |'
'|---|---:|---:|---:|---:|---:|'
};

for k = 1:height(AxisSummary)

    audit{end+1} = sprintf( ...
        '| %s | %+.2f mV | %+.2f mV | %+.2f mV | %+.2f mV | %.2f mV |', ...
        AxisSummary.Axis(k), ...
        AxisSummary.MedianLowRateChargeOffset_mV(k), ...
        AxisSummary.MedianOneCChargeOffset_mV(k), ...
        AxisSummary.MedianOneCDischargeOffset_mV(k), ...
        AxisSummary.MedianChargeDischargeGap_mV(k), ...
        AxisSummary.MedianAbsLowRateVsOneCCharge_mV(k)); %#ok<AGROW>
end

audit{end+1} = '';
audit{end+1} = '## Descriptive class';
audit{end+1} = '';
audit{end+1} = ['`' char(descriptiveClass) '`'];
audit{end+1} = '';
audit{end+1} = 'B1-2B remains FAIL / B2 remains STOP.';

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
'- B1-2C baseline bias dominant'
'- B1-2D qRef/SOC mapping strongly reduces baseline'
'- B1-2E voltage-derived effective qRef exceeds independent capacity references'
sprintf('- B1-2F directional pseudo-OCV classification completed')
sprintf('- B1-2G: `%s`',descriptiveClass)
''
'## B1-2G core values'
''
sprintf('- all 9 charge-discharge gaps positive: %s',yes_no(allGaps))
sprintf('- low-rate charge above frozen across all axes/SOC: %s',yes_no(lowPositive))
sprintf('- best charge-rate alignment axis: %s',bestAxis)
sprintf('- best median |0.1C - 1C charge|: %.3f mV',bestMismatch)
sprintf('- median directional gap across axes: %.3f mV',medianGap)
sprintf('- median cross-axis offset range: %.3f mV',medianSpread)
''
'## Frozen decision'
''
'B1-2B remains FAIL. R2/tau2 online adaptation remains stopped. Do not expand its grid.'
};

write_text_lines(handoffPath,handoff);

continuityPath = fullfile( ...
    handoffDir,'EXT2_PROJECT_CONTINUITY_CURRENT.md');

continuity = {
'# EXT2 Project Continuity — CURRENT'
''
'## Code structure'
''
'header -> PATHS -> frozen-input preflight -> schema checks -> main analysis -> results -> protected-asset SHA audit -> AUTODOC -> decision/claim boundary -> local functions.'
''
'## Current evidence'
''
'- B1-2B adaptation target failed real-voltage consistency'
'- B1-2C found baseline-dominant residual'
'- B1-2D showed SOC-axis/qRef can remove most baseline numerically'
'- B1-2E rejected that voltage-derived qRef as a directly supported physical capacity'
'- B1-2F introduced low-rate/charge/discharge pseudo-OCV directionality evidence'
sprintf('- B1-2G robustness class: %s',descriptiveClass)
''
'## Frozen boundary'
''
'Do not modify frozen MJ1 v0.2 EKF, Bayesian R0 v1.0, EXT1 K4, Simulink frozen assets or released v1.0 history.'
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
    error('EXT2:B12G:DocWriteFailed', ...
        'Could not open documentation file: %s',char(filePath));
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

for k = 1:numel(lines)
    fprintf(fid,'%s\n',char(string(lines{k})));
end
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
