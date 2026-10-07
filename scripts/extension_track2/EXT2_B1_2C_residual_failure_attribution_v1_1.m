% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_B1_2C_residual_failure_attribution_v1.m
% MJ1 2RC-EKF EXT2-B1
% B1-2C Residual Failure Attribution v1.1.1
%
% PURPOSE
%   Diagnose WHY B1-2B real-voltage R2/tau2 target consistency failed.
%
% IMPORTANT
%   This is diagnostic only.
%   - No R2/tau2 fitting.
%   - No grid expansion beyond the failed B1-2B boundary.
%   - No online adaptation.
%   - No frozen-model modification.
%
% The B1-2B result already established:
%   target consistency = FAIL
%   material RMSE benefit = PASS
%
% This script decomposes the nominal frozen-model residual into:
%   1) window-mean voltage bias;
%   2) centered/dynamic residual;
%   3) current-correlated residual;
%   4) excitation-frequency harmonic residual;
%   5) SOC-trend-correlated residual.
%
% It also reports the B1-2B absolute and centered R2/tau2 optima next to
% those residual diagnostics.
%
% No new adaptive candidate is accepted or rejected here. The result is
% used only to decide the next confounder test (SOC/Qref, R0, OCV/hysteresis,
% or other model-form mismatch).

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-2C | Residual Failure Attribution v1.1\n");
fprintf(" B1-2B FAIL follow-up | No fitting / no adaptation\n");
fprintf("============================================================\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));
if strlength(scriptDir) == 0
    error('EXT2:B12C:RunAsFile', ...
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
    error('EXT2:B12C:WrongFolder', ...
        'This script must live inside %s. Current folder: %s', ...
        char(expectedExt2Name),char(ext2Dir));
end

cfg.repoRoot = ...
    "<REPO_ROOT>";

repoMatlab = fullfile(cfg.repoRoot,'matlab');
modelFile = fullfile(cfg.repoRoot,'data','mj1_v02_model.mat');

b12aBundleFile = fullfile( ...
    resultsDir,'EXT2_B1_2A_run_bundle_v1.mat');
b12bBundleFile = fullfile( ...
    resultsDir,'EXT2_B1_2B_run_bundle_v1.mat');

required = { ...
    modelFile, ...
    b12aBundleFile, ...
    b12bBundleFile, ...
    fullfile(repoMatlab,'mj1_load_model.m')};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:B12C:MissingInput', ...
            'Required input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

A = load(b12aBundleFile);
B = load(b12bBundleFile);

requiredA = {'profileData','WindowSummary','overallPass'};
missingA = requiredA(~cellfun(@(f) isfield(A,f),requiredA));

if ~isempty(missingA)
    error('EXT2:B12C:B12ABundleContract', ...
        'B1-2A bundle missing: %s',strjoin(missingA,', '));
end

requiredB = { ...
    'OptimumSummary','SafeStartSummary', ...
    'targetConsistencyPass','materialBenefitPass','b2MayProceed'};

missingB = requiredB(~cellfun(@(f) isfield(B,f),requiredB));

if ~isempty(missingB)
    error('EXT2:B12C:B12BBundleContract', ...
        'B1-2B bundle missing: %s',strjoin(missingB,', '));
end

if ~logical(A.overallPass)
    error('EXT2:B12C:B12ANotPassed', ...
        'B1-2A is not PASS.');
end

if logical(B.b2MayProceed)
    error('EXT2:B12C:B12BUnexpectedProceed', ...
        'B1-2B says B2 may proceed; this failure-attribution script is not applicable.');
end

profileData = A.profileData;
WindowSummary = A.WindowSummary;
OptimumSummary = B.OptimumSummary;
SafeStartSummary = B.SafeStartSummary;

fprintf("B1-2A status              : PASS\n");
fprintf("B1-2B target consistency  : %s\n",pass_text(B.targetConsistencyPass));
fprintf("B1-2B material benefit    : %s\n",pass_text(B.materialBenefitPass));
fprintf("B2 may proceed            : %s\n\n",pass_text(B.b2MayProceed));

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
% 2. NOMINAL RESIDUAL RECONSTRUCTION
% -------------------------------------------------------------------------
rows = struct([]);
ir = 0;

for ip = 1:numel(profileData)

    P = profileData(ip);
    cid = P.case_id;

    S = SafeStartSummary(SafeStartSummary.CaseID == cid,:);

    if height(S) ~= 1
        error('EXT2:B12C:SafeStartCount', ...
            'Expected one safe-start row for %s.',char(cid));
    end

    safeStartTime = S.SafeStartTime_s;

    W = WindowSummary(WindowSummary.CaseID == cid,:);
    W = sortrows(W,'TargetSOC');

    if height(W) ~= 3
        error('EXT2:B12C:WindowCount', ...
            'Expected three windows for %s.',char(cid));
    end

    t = P.t_s(:);
    I = P.I_A(:);
    Vmeas = P.V_V(:);
    soc = P.SOC(:);

    maxWindowEnd = max(W.WindowEnd_s);

    idx0 = find(t >= safeStartTime-1e-9,1,'first');
    idx1 = find(t <= maxWindowEnd+1e-9,1,'last');

    if isempty(idx0) || isempty(idx1) || idx0 >= idx1
        error('EXT2:B12C:SegmentIndex', ...
            'Invalid nominal shadow segment for %s.',char(cid));
    end

    idx = (idx0:idx1).';

    tSeg = t(idx);
    ISeg = I(idx);
    VmeasSeg = Vmeas(idx);
    socSeg = soc(idx);

    if any(socSeg < model.socMin) || any(socSeg > model.socMax)
        error('EXT2:B12C:RawSOCSupport', ...
            'Raw SOC leaves frozen LUT support for %s.',char(cid));
    end

    OCV = interp1(model.soc,model.ocv,socSeg,'linear');
    R0 = interp1(model.soc,model.R0,socSeg,'linear');
    R1 = interp1(model.soc,model.R1,socSeg,'linear');
    C1 = interp1(model.soc,model.C1,socSeg,'linear');
    R2 = interp1(model.soc,model.R2,socSeg,'linear');
    C2 = interp1(model.soc,model.C2,socSeg,'linear');

    tau1 = R1.*C1;
    tau2 = R2.*C2;

    v1 = simulate_rc_branch_variable(tSeg,ISeg,R1,tau1);
    v2 = simulate_rc_branch_variable(tSeg,ISeg,R2,tau2);

    VhatNom = OCV + v1 + v2 + R0.*ISeg;

    for iw = 1:height(W)

        mask = ...
            tSeg >= W.WindowStart_s(iw)-1e-9 & ...
            tSeg <= W.WindowEnd_s(iw)+1e-9;

        tw = tSeg(mask);
        iwA = ISeg(mask);
        zw = socSeg(mask);
        rw = VhatNom(mask)-VmeasSeg(mask);

        if numel(rw) < 600
            error('EXT2:B12C:WindowSamples', ...
                'Too few samples for %s SOC %.0f%%.', ...
                char(cid),100*W.TargetSOC(iw));
        end

        biasV = mean(rw);
        centered = rw-biasV;

        absRMSE = sqrt(mean(rw.^2))*1000;
        centeredRMSE = sqrt(mean(centered.^2))*1000;
        absBias_mV = abs(biasV)*1000;

        if absRMSE > eps
            biasMSEFraction = ...
                (biasV^2)/mean(rw.^2);
        else
            biasMSEFraction = 0;
        end

        % Centered current regression:
        % residual ~= beta0 + betaI * (I-mean(I)).
        % Corrective voltage would be -beta0 - betaI*Iexc.
        Iexc = iwA-mean(iwA);
        X = [ones(numel(iwA),1),Iexc];
        beta = X\rw;
        rAfterCurrent = rw-X*beta;

        correctionBias_mV = -beta(1)*1000;
        effectiveACResistanceCorrection_mOhm = -beta(2)*1000;
        currentRegressionRMSE_mV = ...
            sqrt(mean(rAfterCurrent.^2))*1000;

        if std(Iexc) > eps && std(centered) > eps
            % Base-MATLAB Pearson correlation; no Statistics/Econometrics Toolbox.
            xCorr = Iexc-mean(Iexc);
            yCorr = centered-mean(centered);

            denomCorr = sqrt(sum(xCorr.^2)*sum(yCorr.^2));

            if denomCorr > eps
                corrResidualCurrent = sum(xCorr.*yCorr)/denomCorr;
            else
                corrResidualCurrent = NaN;
            end
        else
            corrResidualCurrent = NaN;
        end

        % Excitation-frequency residual harmonic.
        T = P.period_s;
        omega = 2*pi/T;
        th = tw-tw(1);

        Xh = [ ...
            ones(numel(th),1), ...
            sin(omega*th), ...
            cos(omega*th)];

        bh = Xh\rw;
        harmonicAmp_mV = hypot(bh(2),bh(3))*1000;
        harmonicBias_mV = bh(1)*1000;
        rAfterHarmonic = rw-Xh*bh;
        harmonicRegressionRMSE_mV = ...
            sqrt(mean(rAfterHarmonic.^2))*1000;

        % SOC-trend regression inside the window.
        zc = zw-mean(zw);
        Xz = [ones(numel(zw),1),zc];
        bz = Xz\rw;

        % Equivalent correction sign: add -bz(2)*(SOC-meanSOC)
        equivalentSOCSlopeCorrection_mV_per_1pct = ...
            -bz(2)*10;

        rAfterSOCTrend = rw-Xz*bz;
        socTrendRegressionRMSE_mV = ...
            sqrt(mean(rAfterSOCTrend.^2))*1000;

        % Fetch B1-2B absolute/centered optima.
        O = OptimumSummary( ...
            OptimumSummary.CaseID == cid & ...
            abs(OptimumSummary.TargetSOC-W.TargetSOC(iw)) < 1e-12,:);

        if height(O) ~= 1
            error('EXT2:B12C:OptimumRowCount', ...
                'Expected one B1-2B optimum row for %s SOC %.0f%%.', ...
                char(cid),100*W.TargetSOC(iw));
        end

        ir = ir+1;
        rows(ir).CaseID = cid; %#ok<SAGROW>
        rows(ir).Band = P.band;
        rows(ir).AmplitudeGroup = P.amplitude_group;
        rows(ir).TargetSOC = W.TargetSOC(iw);
        rows(ir).NominalAbsoluteRMSE_mV = absRMSE;
        rows(ir).NominalCenteredRMSE_mV = centeredRMSE;
        rows(ir).NominalResidualBias_mV = biasV*1000;
        rows(ir).AbsoluteBias_mV = absBias_mV;
        rows(ir).BiasMSEFraction = biasMSEFraction;
        rows(ir).BiasMSEPercent = 100*biasMSEFraction;
        rows(ir).CorrCenteredResidualCurrent = corrResidualCurrent;
        rows(ir).EquivalentCorrectionBias_mV = correctionBias_mV;
        rows(ir).EquivalentACResistanceCorrection_mOhm = ...
            effectiveACResistanceCorrection_mOhm;
        rows(ir).CurrentRegressionRMSE_mV = ...
            currentRegressionRMSE_mV;
        rows(ir).ResidualFundamentalAmplitude_mV = harmonicAmp_mV;
        rows(ir).ResidualHarmonicBias_mV = harmonicBias_mV;
        rows(ir).HarmonicRegressionRMSE_mV = ...
            harmonicRegressionRMSE_mV;
        rows(ir).EquivalentSOCSlopeCorrection_mV_per_1pct = ...
            equivalentSOCSlopeCorrection_mV_per_1pct;
        rows(ir).SOCTrendRegressionRMSE_mV = ...
            socTrendRegressionRMSE_mV;
        rows(ir).B12B_AbsoluteAlphaR2 = O.BestAlphaR2;
        rows(ir).B12B_AbsoluteAlphaTau2 = O.BestAlphaTau2;
        rows(ir).B12B_CenteredAlphaR2 = O.CenteredBestAlphaR2;
        rows(ir).B12B_CenteredAlphaTau2 = O.CenteredBestAlphaTau2;
        rows(ir).B12B_BestAbsoluteRMSE_mV = O.BestRMSE_mV;
        rows(ir).B12B_Improvement_mV = O.Improvement_mV;
        rows(ir).B12B_Improvement_pct = O.Improvement_pct;
    end
end

ResidualAttribution = struct2table(rows);

%% ------------------------------------------------------------------------
% 3. AGGREGATE DESCRIPTIVE DIAGNOSTICS
% -------------------------------------------------------------------------
medianAbsRMSE = median(ResidualAttribution.NominalAbsoluteRMSE_mV);
medianCenteredRMSE = median(ResidualAttribution.NominalCenteredRMSE_mV);
medianAbsBias = median(ResidualAttribution.AbsoluteBias_mV);
medianBiasMSEPct = median(ResidualAttribution.BiasMSEPercent);

nBiasMajority = sum(ResidualAttribution.BiasMSEPercent >= 50);
nBiasNegative = sum(ResidualAttribution.NominalResidualBias_mV < 0);
nBiasPositive = sum(ResidualAttribution.NominalResidualBias_mV > 0);

medianCurrentRegRMSE = ...
    median(ResidualAttribution.CurrentRegressionRMSE_mV);
medianHarmonicAmp = ...
    median(ResidualAttribution.ResidualFundamentalAmplitude_mV);
medianHarmonicRegRMSE = ...
    median(ResidualAttribution.HarmonicRegressionRMSE_mV);
medianSOCTREGRMSE = ...
    median(ResidualAttribution.SOCTrendRegressionRMSE_mV);

% This is descriptive, not a preregistered scientific gate.
if nBiasMajority >= 12
    descriptiveClass = "BASELINE_BIAS_DOMINANT";
elseif medianCenteredRMSE < 0.8*medianAbsRMSE
    descriptiveClass = "MIXED_BASELINE_AND_DYNAMIC";
else
    descriptiveClass = "DYNAMIC_OR_MODEL_FORM_DOMINANT";
end

%% ------------------------------------------------------------------------
% 4. SAVE
% -------------------------------------------------------------------------
csvFile = fullfile( ...
    resultsDir,'EXT2_B1_2C_residual_attribution_v1_1.csv');
writetable(ResidualAttribution,csvFile);

reportFile = fullfile( ...
    resultsDir,'EXT2_B1_2C_residual_attribution_report_v1_1.txt');

fid = fopen(reportFile,'w');
if fid < 0
    error('EXT2:B12C:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-B1-2C Residual Failure Attribution v1.1.1\n");
fprintf(fid,"===============================================\n\n");
fprintf(fid,"Diagnostic only. No R2/tau2 fitting or adaptation.\n");
fprintf(fid,"B1-2B target consistency = %s\n",pass_text(B.targetConsistencyPass));
fprintf(fid,"B1-2B material benefit   = %s\n\n",pass_text(B.materialBenefitPass));

fprintf(fid,"Median nominal absolute RMSE  = %.6f mV\n",medianAbsRMSE);
fprintf(fid,"Median nominal centered RMSE  = %.6f mV\n",medianCenteredRMSE);
fprintf(fid,"Median |residual bias|         = %.6f mV\n",medianAbsBias);
fprintf(fid,"Median MSE fraction from bias  = %.3f %%\n",medianBiasMSEPct);
fprintf(fid,"Windows with bias >=50%% MSE    = %d / 18\n",nBiasMajority);
fprintf(fid,"Residual-bias sign             = %d negative / %d positive\n", ...
    nBiasNegative,nBiasPositive);
fprintf(fid,"Median current-regression RMSE = %.6f mV\n",medianCurrentRegRMSE);
fprintf(fid,"Median residual fundamental    = %.6f mV\n",medianHarmonicAmp);
fprintf(fid,"Median harmonic-regression RMSE= %.6f mV\n",medianHarmonicRegRMSE);
fprintf(fid,"Median SOC-trend regression RMSE= %.6f mV\n",medianSOCTREGRMSE);
fprintf(fid,"\nDescriptive failure class      = %s\n",descriptiveClass);
fprintf(fid,"\nThis classification is diagnostic and was not a preregistered B1-2B gate.\n");
fclose(fid);

%% ------------------------------------------------------------------------
% 5. PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);
[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetAuditFile = fullfile( ...
    resultsDir,'EXT2_B1_2C_protected_asset_audit_v1_1.csv');
writetable(AssetAudit,assetAuditFile);

if ~assetsUnchanged
    error('EXT2:B12C:ProtectedAssetChanged', ...
        'A protected frozen asset changed during B1-2C. STOP.');
end

%% ------------------------------------------------------------------------
% 6. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-B1-2C COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Per-window nominal residual attribution:\n");
for k = 1:height(ResidualAttribution)
    fprintf("  %-18s SOC %.0f%% | RMSE %.2f mV | centered %.2f | bias %+7.2f mV (%5.1f%% MSE) | dR_eff %+7.2f mOhm | fundamental %.2f mV\n", ...
        ResidualAttribution.CaseID(k), ...
        100*ResidualAttribution.TargetSOC(k), ...
        ResidualAttribution.NominalAbsoluteRMSE_mV(k), ...
        ResidualAttribution.NominalCenteredRMSE_mV(k), ...
        ResidualAttribution.NominalResidualBias_mV(k), ...
        ResidualAttribution.BiasMSEPercent(k), ...
        ResidualAttribution.EquivalentACResistanceCorrection_mOhm(k), ...
        ResidualAttribution.ResidualFundamentalAmplitude_mV(k));
end

fprintf("\nAggregate:\n");
fprintf("  Median nominal absolute RMSE   : %.3f mV\n",medianAbsRMSE);
fprintf("  Median nominal centered RMSE   : %.3f mV\n",medianCenteredRMSE);
fprintf("  Median |residual bias|          : %.3f mV\n",medianAbsBias);
fprintf("  Median bias contribution to MSE : %.1f %%\n",medianBiasMSEPct);
fprintf("  Bias-majority windows            : %d / 18\n",nBiasMajority);
fprintf("  Bias sign                        : %d negative / %d positive\n", ...
    nBiasNegative,nBiasPositive);
fprintf("  Median current-regression RMSE   : %.3f mV\n",medianCurrentRegRMSE);
fprintf("  Median residual fundamental amp  : %.3f mV\n",medianHarmonicAmp);
fprintf("  Median harmonic-regression RMSE  : %.3f mV\n",medianHarmonicRegRMSE);
fprintf("  Median SOC-trend regression RMSE : %.3f mV\n",medianSOCTREGRMSE);
fprintf("  Descriptive failure class        : %s\n",descriptiveClass);
fprintf("  Protected assets unchanged       : %s\n",pass_text(assetsUnchanged));

fprintf("\nNo B2 progression decision is changed by B1-2C.\n");
fprintf("B1-2B remains FAIL / B2 STOP unless a later explicitly defined robustness study justifies reopening it.\n\n");

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
    error('EXT2:B12C:RCVectorLength', ...
        't/I/R/tau vectors must have equal length.');
end

v = zeros(N,1);

for k = 1:N-1
    dt = t(k+1)-t(k);

    if dt <= 0
        error('EXT2:B12C:NonPositiveDt', ...
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
    error('EXT2:B12C:HashOpenFailed', ...
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
    error('EXT2:B12C:HashFailed', ...
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
    error('EXT2:B12C:AssetSnapshotMismatch', ...
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
