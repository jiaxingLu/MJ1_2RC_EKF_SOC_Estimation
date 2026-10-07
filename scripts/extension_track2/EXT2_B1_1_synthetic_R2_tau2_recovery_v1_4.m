% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_B1_1_synthetic_R2_tau2_recovery_v1_2.m
% MJ1 2RC-EKF EXT2-B1
% B1-1 Synthetic Injected-Ground-Truth Recovery for [R2, tau2]
% v1.2: MATLAB table name-value compatibility fix; protocol unchanged.
%
% PURPOSE
%   Test whether known injected multiplicative changes in R2 and tau2 can
%   be recovered from the same real MID/SLOW current waveforms used in
%   EXT2-A2, while all non-target quantities remain frozen.
%
% NON-NEGOTIABLE BOUNDARY
%   - NO edits to frozen MJ1 v0.2 EKF assets.
%   - NO edits to Bayesian R0 v1.0.
%   - NO edits to EXT1 K4.
%   - NO measured voltage fitting.
%   - NO online adaptation.
%   - This script writes ONLY to:
%       EXT2_dynamic_parameter_identifiability/results/
%
% PARAMETERIZATION
%   R2    = alpha_R2   * R2_frozen(SOC)
%   tau2  = alpha_tau2 * tau2_frozen(SOC)
%   C2    = tau2/R2  (derived only inside this EXT2 shadow calculation)
%
% IMPORTANT INTERPRETATION
%   This is an exact synthetic-truth recoverability audit. A PASS means
%   only that the R2/tau2 target is numerically recoverable under matched
%   synthetic plant/search assumptions. It is NOT evidence that measured
%   real-voltage targets are stable, physical, or safe for online use.
%
% DESIGN NOTES
%   1) Real historical MID/SLOW NGU current waveforms are used read-only.
%   2) The DC component is removed, matching the fixed-SOC identifiability
%      framing of EXT2-A2 and preventing SOC drift from contaminating B1-1.
%   3) The RC2 state is initialized at the periodic fixed point for every
%      candidate tau2. This removes artificial information from arbitrary
%      zero-state initialization.
%   4) alpha_R2 is profiled analytically for each alpha_tau2. alpha_tau2 is
%      then recovered with a bounded one-dimensional search (fminbnd).
%   5) A dense 2D cost surface is still exported for nominal truth at 50% SOC.
%
% MATLAB: base MATLAB only. No Optimization Toolbox is required.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-1 | Synthetic R2/tau2 Ground-Truth Recovery v1.4\n");
fprintf(" Matched synthetic truth | Real MID/SLOW current profiles\n");
fprintf("============================================================\n\n");
fprintf("MATLAB table compatibility: legacy char/cell VariableNames mode\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS — preserve the same project separation used by successful EXT2-A1
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));
if strlength(scriptDir) == 0
    error('EXT2:B1:RunAsFile', ...
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
    error('EXT2:B1:WrongFolder', ...
        'This script must live inside %s. Current folder: %s', ...
        char(expectedExt2Name),char(ext2Dir));
end

% Authoritative local Git working tree for frozen model/code references.
% This matches the successful EXT2-A1 script structure.
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
        error('EXT2:B1:MissingFrozenInput', ...
            'Required frozen input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

requiredFields = ["soc","ocv","R0","R1","C1","R2","C2","qRefAh"];
for f = requiredFields
    if ~isfield(model,f)
        error('EXT2:B1:ModelFieldMissing','Frozen model missing field: %s',char(f));
    end
end

fprintf("EXT2 work folder : %s\n",ext2Dir);
fprintf("Results only     : %s\n",resultsDir);
fprintf("Local Git repo   : %s\n",cfg.repoRoot);
fprintf("GitHub remote    : %s\n",cfg.githubRemote);
fprintf("Frozen model     : %s\n\n",modelFile);

% Early compatibility preflight. Fail before the expensive recovery matrix.
try
    Tcompat = table((1:2).',(3:4).', ...
        'VariableNames',{'A','B'}); %#ok<NASGU>
catch ME
    error('EXT2:B1:TableCompatibility', ...
        'MATLAB table compatibility preflight failed before recovery: %s',ME.message);
end

% Snapshot protected assets before any analysis. This script never writes them.
protectedRel = [ ...
    "matlab/mj1_ekf_step.m"
    "matlab/mj1_state_transition.m"
    "matlab/mj1_measurement.m"
    "matlab/mj1_interp_params.m"
    "matlab/ope_r0_bayes_online_core_v2.m"
    "matlab/ope_excitation_gate_online_v2.m"
    "ope_r0_bayes_online_core_v2.m"
    "ope_excitation_gate_online_v2.m"
    "model/MJ1_2RC_EKF_v02_S2_A1d_AutonomousGate.slx"
    "MJ1_2RC_EKF_v02_S2_A1d_AutonomousGate.slx"
    "matlab/ope_r0_bayes_rolling_k4_core_v1.m"
    "ope_r0_bayes_rolling_k4_core_v1.m"
    "model/MJ1_2RC_EKF_EXT1_K4_Integrated_v1.slx"
    "MJ1_2RC_EKF_EXT1_K4_Integrated_v1.slx"
    ];

protectedBefore = snapshot_assets(cfg.repoRoot,protectedRel);

%% ------------------------------------------------------------------------
% 2. Prospective B1-1 protocol — freeze BEFORE recovery results are viewed
% -------------------------------------------------------------------------
socList = [0.30 0.50 0.70];

% Handoff primary truth grid: 5 x 5 = 25 truths.
primaryAlpha = [0.90 0.95 1.00 1.05 1.10];
[ARp,ATp] = ndgrid(primaryAlpha,primaryAlpha);
primaryTruth = [ARp(:),ATp(:)];

% Additional off-grid challenge. These values do not lie on the 0.005
% exported cost-surface grid and guard against "truth happens to be a node".
offGridAlpha = [0.917 0.967 1.033 1.083];
[ARo,ATo] = ndgrid(offGridAlpha,offGridAlpha);
offGridTruth = [ARo(:),ATo(:)];

truthMatrix = [primaryTruth; offGridTruth];
truthType = [repmat("PRIMARY_GRID",size(primaryTruth,1),1); ...
             repmat("OFFGRID_CHALLENGE",size(offGridTruth,1),1)];

alphaBounds = [0.85 1.15];
surfaceGrid = (0.85:0.005:1.15).';

% Exact synthetic recovery criteria, fixed prospectively.
passTolAlphaAbs = 1.0e-3;       % <= 0.001 in alpha = <= 0.1 percentage point
passTolRMSE_mV  = 1.0e-3;       % <= 0.001 mV = <= 1 microvolt
passMaxCondJ    = 20;            % expected MID/SLOW geometry should remain well below this
assumedSigmaV_V = 1.0e-3;       % 1 mV iid normalization ONLY for local covariance reporting

% fminbnd is base MATLAB.
opt1D = optimset("TolX",1e-10,"MaxIter",250,"MaxFunEvals",500,"Display","off");

%% ------------------------------------------------------------------------
% 3. Real current profile definitions
%
% v1.3 continuity rule:
%   DO NOT rediscover/guess A2 sources by approximate descriptors.
%   The six MID/SLOW source identities are frozen explicitly by:
%       exact relative path + SHA-256
%
% A2 descriptor values are retained as REFERENCE METADATA ONLY.
% In particular, the A2 "mean current" field is not assumed to equal the
% arithmetic mean of the first 4200 replay samples.
% -------------------------------------------------------------------------
nReplay = 4200;

userProfile = string(getenv("USERPROFILE"));
profileRoot = fullfile(userProfile,"Desktop", ...
    "MJ1_Experimental_Data_Reconstruction","raw_original");

if ~isfolder(profileRoot)
    error('EXT2:B1:ProfileRootMissing', ...
        'Read-only historical profile root not found: %s',char(profileRoot));
end

fprintf("Read-only frozen profile root:\n  %s\n\n",profileRoot);

% Frozen A2/B1 source manifest.
% expected = [A2_reference_DC_or_mean_A, excitation_rms_A, excitation_pp_A, dominant_period_s]
profileDefs = make_profile_def( ...
    "A_MID_02p03","MID","0.2C+0.3C","FILE_0035", ...
    "0.2C/NGU/处理后0.2+0.3 1tau.csv", ...
    "d6a8551be57f8ab78949a1ea11529dde8f70411d20db5437553a5d64d2234b4b", ...
    [0.679971,0.720952,2.039891,70.0]);

profileDefs(end+1) = make_profile_def( ...
    "A_SLOW_02p03","SLOW","0.2C+0.3C","FILE_0037", ...
    "0.2C/NGU/处理后0.2+0.3C 10tau.csv", ...
    "170436214c515fc0a2fe5423b2422f45ecdd9b0e680f821f20997e36d5eaccef", ...
    [0.679922,0.720894,2.039932,700.0]);

profileDefs(end+1) = make_profile_def( ...
    "B_MID_03p04","MID","0.3C+0.4C","FILE_0093", ...
    "0.3C/NGU/处理后0.3+0.4C 1tau.csv", ...
    "260d45543c057f5021b1e8282873f4a0dbe67597afc2675c3b442343e3fbc3b8", ...
    [1.020012,0.961302,2.719934,70.0]);

profileDefs(end+1) = make_profile_def( ...
    "B_SLOW_03p04","SLOW","0.3C+0.4C","FILE_0092", ...
    "0.3C/NGU/处理后0.3+0.4C 10tau.csv", ...
    "21ed81dffb7aa4fcee303931c436373ecff84aa6592add7149de455d0375044f", ...
    [1.019917,0.961212,2.719928,700.0]);

profileDefs(end+1) = make_profile_def( ...
    "DEV_MID_03p07","MID","0.3C+0.7C","FILE_0140", ...
    "0.3C/处理后/处理后 0.3+0.7 (切换).csv", ...
    "7a69b86c1ea840d176af01f7e1c41b2c2798b01a15a6bcfc4d934186ea1e6f1d", ...
    [1.019851,1.682349,4.759950,70.0]);

profileDefs(end+1) = make_profile_def( ...
    "DEV_SLOW_03p07","SLOW","0.3C+0.7C","FILE_0159", ...
    "0.3C/处理后/处理后0.3+0.7 10 tau.csv", ...
    "536c429b12e1b6909f59c1588eeb92f57296367eecd9dc1776744d850b16675a", ...
    [1.019944,1.682163,4.759930,700.0]);

% Environment manifest: keep path roles explicit.
environmentManifest = fullfile(resultsDir,"EXT2_B1_1_environment_manifest_v1_4.txt");
fidEnv = fopen(environmentManifest,'w');
if fidEnv < 0
    error('EXT2:B1:EnvironmentManifestOpenFailed', ...
        'Could not open %s',char(environmentManifest));
end

fprintf(fidEnv,"MJ1 EXT2-B1-1 Environment Manifest v1.4\n");
fprintf(fidEnv,"=======================================\n\n");
fprintf(fidEnv,"EXT2 work folder : %s\n",ext2Dir);
fprintf(fidEnv,"Work package root: %s\n",workRoot);
fprintf(fidEnv,"Results folder   : %s\n",resultsDir);
fprintf(fidEnv,"Local Git repo   : %s\n",cfg.repoRoot);
fprintf(fidEnv,"GitHub remote    : %s\n",cfg.githubRemote);
fprintf(fidEnv,"Frozen model     : %s\n",modelFile);
fprintf(fidEnv,"Frozen MATLAB dir: %s\n",repoMatlab);
fprintf(fidEnv,"Profile root     : %s\n\n",profileRoot);
fprintf(fidEnv,"Frozen MID/SLOW A2 source identity:\n");

for k = 1:numel(profileDefs)
    fprintf(fidEnv,"%s | %s | %s | %s\n", ...
        profileDefs(k).case_id,profileDefs(k).source_file_id, ...
        profileDefs(k).relative_path,profileDefs(k).expected_sha256);
end
fclose(fidEnv);

profiles = struct([]);
profileRows = cell(numel(profileDefs),1);

for k = 1:numel(profileDefs)
    [Pk,profileRows{k}] = load_frozen_profile(profileDefs(k),profileRoot,nReplay);
    profiles = [profiles; Pk]; %#ok<AGROW>

    fprintf("%-18s | %-4s | sample mean=% .6f A | RMS=% .6f A | pp=% .6f A | T=%8.3f s\n", ...
        profiles(k).case_id,profiles(k).band,profiles(k).sample_mean_A, ...
        profiles(k).exc_rms_A,profiles(k).exc_pp_A,profiles(k).dominant_period_s);
    fprintf("  A2 reference DC/mean = %.6f A | source ID=%s | SHA256 PASS\n", ...
        profiles(k).a2_reference_mean_A,profiles(k).source_file_id);
    fprintf("  source: %s\n",profiles(k).source_file);
end
fprintf("\n");

profileTable = vertcat(profileRows{:});
writetable(profileTable,fullfile(resultsDir,"EXT2_B1_1_profile_characterization_v1_4.csv"));

% Fail-fast downstream field contract.
% This executes BEFORE the expensive 738-case recovery loop.
requiredProfileFields = { ...
    'case_id','band','amplitude_group','source_file_id','source_file','source_sha256', ...
    'I_exc_A','dt_interval_s','sample_mean_A','a2_reference_mean_A', ...
    'exc_rms_A','exc_pp_A','dominant_period_s'};

for ipre = 1:numel(profiles)
    missingProfileFields = requiredProfileFields( ...
        ~cellfun(@(f) isfield(profiles(ipre),f),requiredProfileFields));
    if ~isempty(missingProfileFields)
        error('EXT2:B1:ProfileFieldContract', ...
            'Profile %s is missing downstream field(s): %s', ...
            char(profiles(ipre).case_id),strjoin(missingProfileFields,', '));
    end
end

fprintf("Downstream profile-field contract: PASS\n\n");

%% ------------------------------------------------------------------------
% 4. Recovery matrix
% -------------------------------------------------------------------------
nP = numel(profiles);
nS = numel(socList);
nT = size(truthMatrix,1);
nRows = nP*nS*nT;

CaseID = strings(nRows,1);
Band = strings(nRows,1);
AmplitudeGroup = strings(nRows,1);
SOC = nan(nRows,1);
TruthType = strings(nRows,1);
AlphaR2Truth = nan(nRows,1);
AlphaTau2Truth = nan(nRows,1);
AlphaR2Hat = nan(nRows,1);
AlphaTau2Hat = nan(nRows,1);
ErrR2 = nan(nRows,1);
ErrTau2 = nan(nRows,1);
AbsErrR2 = nan(nRows,1);
AbsErrTau2 = nan(nRows,1);
RecoveryRMSE_mV = nan(nRows,1);
CondJ = nan(nRows,1);
CondJTJ = nan(nRows,1);
JacobianCosine = nan(nRows,1);
SigmaAlphaR2_1mV = nan(nRows,1);
SigmaAlphaTau2_1mV = nan(nRows,1);
CovCorr_1mV = nan(nRows,1);
HitR2Bound = false(nRows,1);
HitTau2Bound = false(nRows,1);
NumericallyFinite = false(nRows,1);

row = 0;

fprintf("Running %d recovery cases ...\n",nRows);

for ip = 1:nP
    Iexc = profiles(ip).I_exc_A;
    dtVec = profiles(ip).dt_interval_s;

    for is = 1:nS
        soc = socList(is);

        p = mj1_interp_params(model,soc);
        if ~all(isfinite([p.R2 p.tau2])) || p.R2 <= 0 || p.tau2 <= 0
            error('EXT2:B1:InvalidFrozenParams', ...
                'Invalid frozen R2/tau2 at SOC %.1f%%.',100*soc);
        end

        R2base = p.R2;
        tau2base = p.tau2;

        for it = 1:nT
            row = row + 1;
            aRtrue = truthMatrix(it,1);
            aTtrue = truthMatrix(it,2);

            yTruth = rc2_voltage_response_periodic( ...
                Iexc,dtVec,R2base*aRtrue,tau2base*aTtrue);

            % Global coarse scan over alpha_tau2, with alpha_R2 profiled.
            coarseCost = nan(numel(surfaceGrid),1);
            for ig = 1:numel(surfaceGrid)
                coarseCost(ig) = profiled_mse( ...
                    surfaceGrid(ig),yTruth,Iexc,dtVec,R2base,tau2base,alphaBounds);
            end
            [~,iBest] = min(coarseCost);

            iLo = max(1,iBest-1);
            iHi = min(numel(surfaceGrid),iBest+1);
            lo = surfaceGrid(iLo);
            hi = surfaceGrid(iHi);

            if iLo == iHi
                lo = alphaBounds(1);
                hi = alphaBounds(2);
            elseif hi-lo < eps
                lo = max(alphaBounds(1),surfaceGrid(iBest)-0.01);
                hi = min(alphaBounds(2),surfaceGrid(iBest)+0.01);
            end

            % Continuous refinement.
            [aThat,~] = fminbnd( ...
                @(aT) profiled_mse(aT,yTruth,Iexc,dtVec,R2base,tau2base,alphaBounds), ...
                lo,hi,opt1D);

            [mseHat,aRhat] = profiled_mse( ...
                aThat,yTruth,Iexc,dtVec,R2base,tau2base,alphaBounds);

            yHat = rc2_voltage_response_periodic( ...
                Iexc,dtVec,R2base*aRhat,tau2base*aThat);

            % Local Jacobian / curvature at exact injected truth.
            [J,condJ,condJTJ,jcos,sigR,sigT,covCorr] = local_geometry( ...
                Iexc,dtVec,R2base,tau2base,aRtrue,aTtrue,assumedSigmaV_V);

            CaseID(row) = profiles(ip).case_id;
            Band(row) = profiles(ip).band;
            AmplitudeGroup(row) = profiles(ip).amplitude_group;
            SOC(row) = soc;
            TruthType(row) = truthType(it);
            AlphaR2Truth(row) = aRtrue;
            AlphaTau2Truth(row) = aTtrue;
            AlphaR2Hat(row) = aRhat;
            AlphaTau2Hat(row) = aThat;
            ErrR2(row) = aRhat-aRtrue;
            ErrTau2(row) = aThat-aTtrue;
            AbsErrR2(row) = abs(ErrR2(row));
            AbsErrTau2(row) = abs(ErrTau2(row));
            RecoveryRMSE_mV(row) = sqrt(mean((yHat-yTruth).^2))*1e3;
            CondJ(row) = condJ;
            CondJTJ(row) = condJTJ;
            JacobianCosine(row) = jcos;
            SigmaAlphaR2_1mV(row) = sigR;
            SigmaAlphaTau2_1mV(row) = sigT;
            CovCorr_1mV(row) = covCorr;
            HitR2Bound(row) = abs(aRhat-alphaBounds(1)) < 1e-6 || ...
                              abs(aRhat-alphaBounds(2)) < 1e-6;
            HitTau2Bound(row) = abs(aThat-alphaBounds(1)) < 1e-6 || ...
                                abs(aThat-alphaBounds(2)) < 1e-6;
            NumericallyFinite(row) = all(isfinite([mseHat,aRhat,aThat,J(:).']));
        end
    end
end

recoveryTable = table( ...
    CaseID,Band,AmplitudeGroup,SOC,TruthType, ...
    AlphaR2Truth,AlphaTau2Truth,AlphaR2Hat,AlphaTau2Hat, ...
    ErrR2,ErrTau2,AbsErrR2,AbsErrTau2,RecoveryRMSE_mV, ...
    CondJ,CondJTJ,JacobianCosine, ...
    SigmaAlphaR2_1mV,SigmaAlphaTau2_1mV,CovCorr_1mV, ...
    HitR2Bound,HitTau2Bound,NumericallyFinite);

writetable(recoveryTable,fullfile(resultsDir,"EXT2_B1_1_recovery_matrix_v1_4.csv"));

%% ------------------------------------------------------------------------
% 5. Aggregate geometry / recovery dependence on frequency, amplitude, SOC
% -------------------------------------------------------------------------
summaryRows = struct([]);
js = 0;

for ip = 1:nP
    for is = 1:nS
        mask = recoveryTable.CaseID == profiles(ip).case_id & ...
               abs(recoveryTable.SOC-socList(is)) < 1e-12;

        T = recoveryTable(mask,:);

        js = js + 1;
        summaryRows(js).CaseID = profiles(ip).case_id;
        summaryRows(js).Band = profiles(ip).band;
        summaryRows(js).AmplitudeGroup = profiles(ip).amplitude_group;
        summaryRows(js).SOC = socList(is);
        summaryRows(js).SampleMeanCurrent_A = profiles(ip).sample_mean_A;
        summaryRows(js).A2ReferenceMeanOrDC_A = profiles(ip).a2_reference_mean_A;
        summaryRows(js).ExcitationRMS_A = profiles(ip).exc_rms_A;
        summaryRows(js).ExcitationPP_A = profiles(ip).exc_pp_A;
        summaryRows(js).DominantPeriod_s = profiles(ip).dominant_period_s;
        summaryRows(js).MaxAbsErrR2 = max(T.AbsErrR2);
        summaryRows(js).MaxAbsErrTau2 = max(T.AbsErrTau2);
        summaryRows(js).MaxRecoveryRMSE_mV = max(T.RecoveryRMSE_mV);
        summaryRows(js).MedianCondJ = median(T.CondJ);
        summaryRows(js).MaxCondJ = max(T.CondJ);
        summaryRows(js).MedianJacobianCosine = median(T.JacobianCosine);
        summaryRows(js).MedianSigmaAlphaR2_1mV = median(T.SigmaAlphaR2_1mV);
        summaryRows(js).MedianSigmaAlphaTau2_1mV = median(T.SigmaAlphaTau2_1mV);
        summaryRows(js).MaxSigmaAlphaR2_1mV = max(T.SigmaAlphaR2_1mV);
        summaryRows(js).MaxSigmaAlphaTau2_1mV = max(T.SigmaAlphaTau2_1mV);
        summaryRows(js).AnyBoundaryHit = any(T.HitR2Bound | T.HitTau2Bound);
    end
end

geometrySummary = struct2table(summaryRows);
writetable(geometrySummary,fullfile(resultsDir,"EXT2_B1_1_geometry_summary_v1_4.csv"));

%% ------------------------------------------------------------------------
% 6. Nominal 2D cost surfaces at SOC = 50%
% -------------------------------------------------------------------------
surfaceSOC = 0.50;
nG = numel(surfaceGrid);
nSurfRows = nP*nG*nG;

SurfCaseID = strings(nSurfRows,1);
SurfBand = strings(nSurfRows,1);
SurfAlphaR2 = nan(nSurfRows,1);
SurfAlphaTau2 = nan(nSurfRows,1);
SurfRMSE_mV = nan(nSurfRows,1);

sr = 0;

for ip = 1:nP
    p = mj1_interp_params(model,surfaceSOC);
    R2base = p.R2;
    tau2base = p.tau2;
    Iexc = profiles(ip).I_exc_A;
    dtVec = profiles(ip).dt_interval_s;

    yNominal = rc2_voltage_response_periodic(Iexc,dtVec,R2base,tau2base);

    % Cache response at each tau grid value.
    Z = nan(numel(Iexc),nG);
    for jt = 1:nG
        Z(:,jt) = rc2_voltage_response_periodic( ...
            Iexc,dtVec,R2base,tau2base*surfaceGrid(jt));
    end

    rmseMap = nan(nG,nG); % rows alpha_tau2, cols alpha_R2

    for jt = 1:nG
        z = Z(:,jt);
        for jr = 1:nG
            residual = surfaceGrid(jr)*z-yNominal;
            rmseMap(jt,jr) = sqrt(mean(residual.^2))*1e3;

            sr = sr + 1;
            SurfCaseID(sr) = profiles(ip).case_id;
            SurfBand(sr) = profiles(ip).band;
            SurfAlphaR2(sr) = surfaceGrid(jr);
            SurfAlphaTau2(sr) = surfaceGrid(jt);
            SurfRMSE_mV(sr) = rmseMap(jt,jr);
        end
    end

    % Diagnostic contour; failure to render never changes numerical result.
    try
        fig = figure("Visible","off","Color","w");
        contourf(surfaceGrid,surfaceGrid,log10(rmseMap + 1e-12),20);
        hold on;
        plot(1,1,"kx","MarkerSize",10,"LineWidth",2);
        xlabel("\alpha_{R2}");
        ylabel("\alpha_{\tau2}");
        title(sprintf("EXT2 B1-1 %s | SOC 50%% | log10 RMSE [mV]",profiles(ip).case_id), ...
            "Interpreter","none");
        cb = colorbar;
        cb.Label.String = "log10(RMSE / mV)";
        grid on;
        exportgraphics(fig,fullfile(resultsDir, ...
            "EXT2_B1_1_cost_surface_SOC50_"+profiles(ip).case_id+"_v1_4.png"), ...
            "Resolution",180);
        close(fig);
    catch MEfig
        warning('EXT2:B1:PlotSkipped','Plot skipped for %s: %s', ...
            char(profiles(ip).case_id),MEfig.message);
    end
end

% Explicitly verify the cost-surface row count and use backward-compatible
% table name-value syntax. Some MATLAB releases can interpret a string
% "VariableNames" token as ordinary table data, which causes row mismatch.
if sr ~= nSurfRows
    error('EXT2:B1:SurfaceRowCountMismatch', ...
        'Expected %d cost-surface rows but wrote %d.',nSurfRows,sr);
end

SurfCaseID = SurfCaseID(1:sr,1);
SurfBand = SurfBand(1:sr,1);
SurfAlphaR2 = SurfAlphaR2(1:sr,1);
SurfAlphaTau2 = SurfAlphaTau2(1:sr,1);
SurfRMSE_mV = SurfRMSE_mV(1:sr,1);
SurfaceSOC = repmat(surfaceSOC,sr,1);

surfaceTable = table( ...
    SurfCaseID,SurfBand,SurfaceSOC,SurfAlphaR2,SurfAlphaTau2,SurfRMSE_mV, ...
    'VariableNames', {'CaseID','Band','SOC','AlphaR2','AlphaTau2','RMSE_mV'});

writetable(surfaceTable, ...
    fullfile(resultsDir,"EXT2_B1_1_nominal_cost_surfaces_SOC50_v1_4.csv"));

%% ------------------------------------------------------------------------
% 7. B1-1 pass/fail decision
% -------------------------------------------------------------------------
primaryMask = recoveryTable.TruthType == "PRIMARY_GRID";
offGridMask = recoveryTable.TruthType == "OFFGRID_CHALLENGE";

primaryRecoveryPass = ...
    all(recoveryTable.AbsErrR2(primaryMask) <= passTolAlphaAbs) && ...
    all(recoveryTable.AbsErrTau2(primaryMask) <= passTolAlphaAbs) && ...
    all(recoveryTable.RecoveryRMSE_mV(primaryMask) <= passTolRMSE_mV);

offGridRecoveryPass = ...
    all(recoveryTable.AbsErrR2(offGridMask) <= passTolAlphaAbs) && ...
    all(recoveryTable.AbsErrTau2(offGridMask) <= passTolAlphaAbs) && ...
    all(recoveryTable.RecoveryRMSE_mV(offGridMask) <= passTolRMSE_mV);

finitePass = all(recoveryTable.NumericallyFinite);
boundaryPass = ~any(recoveryTable.HitR2Bound | recoveryTable.HitTau2Bound);
geometryPass = all(recoveryTable.CondJ <= passMaxCondJ);

overallPass = primaryRecoveryPass && offGridRecoveryPass && ...
              finitePass && boundaryPass && geometryPass;

maxPrimaryErrR2 = max(recoveryTable.AbsErrR2(primaryMask));
maxPrimaryErrTau2 = max(recoveryTable.AbsErrTau2(primaryMask));
maxOffGridErrR2 = max(recoveryTable.AbsErrR2(offGridMask));
maxOffGridErrTau2 = max(recoveryTable.AbsErrTau2(offGridMask));
maxRMSE = max(recoveryTable.RecoveryRMSE_mV);
maxCond = max(recoveryTable.CondJ);

reportPath = fullfile(resultsDir,"EXT2_B1_1_pass_fail_v1_4.txt");
fid = fopen(reportPath,"w");
if fid < 0
    error('EXT2:B1:ReportOpenFailed','Could not open %s',char(reportPath));
end

fprintf(fid,"MJ1 EXT2-B1-1 Synthetic R2/tau2 Recovery v1.4\n");
fprintf(fid,"===========================================\n\n");
fprintf(fid,"Scope\n");
fprintf(fid,"-----\n");
fprintf(fid,"Matched synthetic plant/search model; real MID/SLOW current excitation.\n");
fprintf(fid,"No measured voltage fitted. No online adaptation. Frozen EKF/R0/K4 untouched.\n\n");

fprintf(fid,"Prospective criteria\n");
fprintf(fid,"--------------------\n");
fprintf(fid,"|alpha recovery error| <= %.6g\n",passTolAlphaAbs);
fprintf(fid,"recovery RMSE <= %.6g mV\n",passTolRMSE_mV);
fprintf(fid,"max local cond(J) <= %.6g\n",passMaxCondJ);
fprintf(fid,"no optimizer boundary hits; all outputs finite\n\n");

fprintf(fid,"Results\n");
fprintf(fid,"-------\n");
fprintf(fid,"Primary grid max |err alpha_R2|   = %.12g\n",maxPrimaryErrR2);
fprintf(fid,"Primary grid max |err alpha_tau2| = %.12g\n",maxPrimaryErrTau2);
fprintf(fid,"Off-grid max |err alpha_R2|       = %.12g\n",maxOffGridErrR2);
fprintf(fid,"Off-grid max |err alpha_tau2|     = %.12g\n",maxOffGridErrTau2);
fprintf(fid,"Max recovery RMSE                 = %.12g mV\n",maxRMSE);
fprintf(fid,"Max cond(J)                       = %.12g\n\n",maxCond);

fprintf(fid,"Primary recovery : %s\n",pass_text(primaryRecoveryPass));
fprintf(fid,"Off-grid recovery: %s\n",pass_text(offGridRecoveryPass));
fprintf(fid,"Finite numerics   : %s\n",pass_text(finitePass));
fprintf(fid,"No boundary hit   : %s\n",pass_text(boundaryPass));
fprintf(fid,"Geometry screen   : %s\n",pass_text(geometryPass));
fprintf(fid,"OVERALL B1-1      : %s\n\n",pass_text(overallPass));

fprintf(fid,"Claim boundary\n");
fprintf(fid,"--------------\n");
fprintf(fid,"A B1-1 PASS establishes matched-model synthetic recoverability only.\n");
fprintf(fid,"The 1 mV covariance columns are an iid-noise normalization, not measured sensor noise.\n");
fprintf(fid,"B1-2 real-voltage target consistency remains mandatory before any adaptive prototype.\n");
if overallPass
    fprintf(fid,"Decision: B1-2 MAY PROCEED. No adaptation claim is authorized yet.\n");
else
    fprintf(fid,"Decision: STOP before B1-2 and diagnose the failed recovery/geometry condition.\n");
end
fclose(fid);

%% ------------------------------------------------------------------------
% 8. Verify protected assets unchanged during this run
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets(cfg.repoRoot,protectedRel);
[assetsUnchanged,assetAudit] = compare_asset_snapshots(protectedBefore,protectedAfter);
writetable(assetAudit,fullfile(resultsDir,"EXT2_B1_1_protected_asset_audit_v1_4.csv"));

if ~assetsUnchanged
    error('EXT2:B1:ProtectedAssetChanged', ...
        'A protected frozen/EXT1 asset changed during the run. STOP.');
end

save(fullfile(resultsDir,"EXT2_B1_1_run_bundle_v1_4.mat"), ...
    "recoveryTable","geometrySummary","surfaceTable","profileTable", ...
    "primaryTruth","offGridTruth","socList","alphaBounds","surfaceGrid", ...
    "passTolAlphaAbs","passTolRMSE_mV","passMaxCondJ","assumedSigmaV_V", ...
    "overallPass","assetsUnchanged");

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-1 COMPLETE\n");
fprintf("============================================================\n");
fprintf("Primary max |err|: R2=%.6g, tau2=%.6g\n", ...
    maxPrimaryErrR2,maxPrimaryErrTau2);
fprintf("Off-grid max |err|: R2=%.6g, tau2=%.6g\n", ...
    maxOffGridErrR2,maxOffGridErrTau2);
fprintf("Max cond(J): %.6g\n",maxCond);
fprintf("Protected assets unchanged: %s\n",pass_text(assetsUnchanged));
fprintf("OVERALL B1-1: %s\n",pass_text(overallPass));
if overallPass
    fprintf("Decision: B1-2 may proceed, but no real-voltage/adaptation claim yet.\n");
else
    fprintf("Decision: STOP before B1-2 and diagnose B1-1.\n");
end
fprintf("\nSaved under:\n%s\n\n",resultsDir);


%% =========================================================================
% Local functions
% =========================================================================

function d = make_profile_def(caseID,band,ampGroup,sourceFileID,relativePath,expectedSHA256,expected)
d = struct();
d.case_id = string(caseID);
d.band = string(band);
d.amplitude_group = string(ampGroup);
d.source_file_id = string(sourceFileID);
d.relative_path = string(relativePath);
d.expected_sha256 = lower(string(expectedSHA256));

% A2 reference metadata only. Not used as source-identity authority.
d.expected_mean_A = expected(1);
d.expected_rms_A = expected(2);
d.expected_pp_A = expected(3);
d.expected_period_s = expected(4);
end


function [P,rowT] = load_frozen_profile(def,profileRoot,nReplay)
% Deterministic A2 -> B1 source continuity.
% Exact relative path + SHA-256 are the identity authority.
% No basename fallback and no descriptor-based source substitution.

filePath = fullfile(profileRoot,replace(def.relative_path,"/",filesep));

if ~isfile(filePath)
    error('EXT2:B1:FrozenProfileMissing', ...
        'Frozen source %s (%s) not found at: %s', ...
        char(def.case_id),char(def.source_file_id),char(filePath));
end

actualSHA256 = sha256_file(filePath);
if ~strcmpi(actualSHA256,char(def.expected_sha256))
    error('EXT2:B1:FrozenProfileHashMismatch', ...
        ['Frozen source identity mismatch for %s (%s).\n' ...
         'Expected SHA-256: %s\nActual SHA-256:   %s\nPath: %s\nSTOP.'], ...
        char(def.case_id),char(def.source_file_id), ...
        char(def.expected_sha256),actualSHA256,char(filePath));
end

D = load_ngu_current(filePath);

if numel(D.I_A) < nReplay
    error('EXT2:B1:FrozenProfileTooShort', ...
        'Frozen source %s has only %d valid-prefix samples; %d required.', ...
        char(def.case_id),numel(D.I_A),nReplay);
end

t = D.t_s(1:nReplay);
I = D.I_A(1:nReplay);

if any(~isfinite(t)) || any(~isfinite(I)) || any(diff(t) <= 0)
    error('EXT2:B1:FrozenProfileInvalidReplay', ...
        'Frozen source %s failed finite/monotonic replay checks.',char(def.case_id));
end

dt = diff(t);
dtMed = median(dt);
if abs(dtMed-1) > 0.05 || max(abs(dt-dtMed)) > 0.10
    error('EXT2:B1:FrozenProfileTimebaseMismatch', ...
        'Frozen source %s is not compatible with the A2 1-s replay window.',char(def.case_id));
end

% B1 fixed-SOC replay uses a zero-mean finite-window excitation.
% This arithmetic sample mean is deliberately kept distinct from the
% A2 reference DC/mean descriptor used in the earlier characterization.
sampleMean = mean(I);
Iexc = I-sampleMean;

r = sqrt(mean(Iexc.^2));
pp = max(Iexc)-min(Iexc);
period = dominant_period_fft(Iexc,dtMed);

% Sanity screen only; source identity is already locked by path + SHA.
% These wide checks catch gross parser/timebase mistakes without forcing
% the A2 descriptor to equal a different finite-window statistic.
if abs(r-def.expected_rms_A) > 0.005
    error('EXT2:B1:FrozenProfileRMSSanity', ...
        'Frozen source %s RMS differs from A2 reference by >5 mA.',char(def.case_id));
end

if abs(pp-def.expected_pp_A) > 0.010
    error('EXT2:B1:FrozenProfilePPSanity', ...
        'Frozen source %s p-p differs from A2 reference by >10 mA.',char(def.case_id));
end

if def.band == "MID"
    periodTol = 2.0;
else
    periodTol = 10.0;
end

if abs(period-def.expected_period_s) > periodTol
    error('EXT2:B1:FrozenProfilePeriodSanity', ...
        'Frozen source %s dominant period %.6f s is inconsistent with A2 reference %.6f s.', ...
        char(def.case_id),period,def.expected_period_s);
end

P = struct();
P.case_id = def.case_id;
P.band = def.band;
P.amplitude_group = def.amplitude_group;
P.source_file_id = def.source_file_id;
P.source_file = string(filePath);
P.source_sha256 = string(actualSHA256);
P.t_s = t;
P.I_A = I;
P.I_exc_A = Iexc;
P.sample_mean_A = sampleMean;
P.a2_reference_mean_A = def.expected_mean_A;
P.exc_rms_A = r;
P.a2_reference_rms_A = def.expected_rms_A;
P.exc_pp_A = pp;
P.a2_reference_pp_A = def.expected_pp_A;
P.dominant_period_s = period;
P.a2_reference_period_s = def.expected_period_s;
P.dt_median_s = dtMed;
P.dt_interval_s = [diff(t); dtMed];

rowT = table( ...
    P.case_id,P.band,P.amplitude_group,P.source_file_id,P.source_file,P.source_sha256, ...
    numel(P.I_A),P.t_s(1),P.t_s(end),P.dt_median_s, ...
    P.sample_mean_A,P.a2_reference_mean_A, ...
    P.exc_rms_A,P.a2_reference_rms_A, ...
    P.exc_pp_A,P.a2_reference_pp_A, ...
    P.dominant_period_s,P.a2_reference_period_s, ...
    'VariableNames', { ...
    'CaseID','Band','AmplitudeGroup','SourceFileID','SourceFile','SourceSHA256', ...
    'NSamples','StartTime_s','EndTime_s','MedianDt_s', ...
    'SampleMeanCurrent_A','A2ReferenceMeanOrDC_A', ...
    'ExcitationRMS_A','A2ReferenceRMS_A', ...
    'ExcitationPP_A','A2ReferencePP_A', ...
    'DominantPeriod_s','A2ReferencePeriod_s'});
end


function h = sha256_file(filePath)
% Windows-first SHA-256 verification with Java fallback.
% This function is read-only.

cmd = sprintf('certutil -hashfile "%s" SHA256',char(filePath));
[status,out] = system(cmd);

if status == 0
    token = regexp(out,'[0-9A-Fa-f]{64}','match','once');
    if ~isempty(token)
        h = lower(token);
        return
    end
end

% Java fallback.
fid = fopen(filePath,'rb');
if fid < 0
    error('EXT2:B1:HashOpenFailed','Could not open for SHA-256: %s',char(filePath));
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
    error('EXT2:B1:HashFailed','SHA-256 failed for %s: %s',char(filePath),ME.message);
end
end


function D = load_ngu_current(filePath)
% Minimal local read-only NGU parser. No interpolation, no smoothing,
% no filling, no rewriting.

txt = fileread(filePath);
lines = splitlines(string(txt));

if isempty(lines)
    error('EXT2:B1:EmptyProfile','Empty profile: %s',char(filePath));
end

if strlength(lines(1)) > 0
    lines(1) = erase(lines(1),string(char(65279)));
end

mask = contains(lower(lines),"timestamp") & ...
       contains(lower(lines),"u1[v]") & ...
       contains(lower(lines),"i1[a]");
headerIdx = find(mask,1,"first");
if isempty(headerIdx)
    error('EXT2:B1:NGUHeaderMissing','NGU header not found: %s',char(filePath));
end

headers = split(lines(headerIdx),",");
headers = strtrim(erase(headers,'"'));
headers = erase(headers,string(char(65279)));

iT = find(strcmpi(headers,"Timestamp"),1);
iI = find(strcmpi(headers,"I1[A]"),1);
if isempty(iT) || isempty(iI)
    error('EXT2:B1:NGUColumnsMissing','Timestamp/I1[A] missing: %s',char(filePath));
end

dataLines = lines(headerIdx+1:end);
dataLines(strlength(strtrim(dataLines)) == 0) = [];

n = numel(dataLines);
tRaw = nan(n,1);
I = nan(n,1);

for k = 1:n
    tok = split(dataLines(k),",");
    if numel(tok) < max(iT,iI)
        continue
    end
    tRaw(k) = parse_time_token(tok(iT));
    I(k) = str2double(strtrim(erase(tok(iI),'"')));
end

valid = isfinite(tRaw) & isfinite(I);
firstBad = find(~valid,1,"first");
if isempty(firstBad)
    nPrefix = n;
else
    nPrefix = firstBad-1;
end

if nPrefix < 2
    error('EXT2:B1:NoValidPrefix','No valid contiguous NGU prefix: %s',char(filePath));
end

t = tRaw(1:nPrefix);
I = I(1:nPrefix);

% Convert to elapsed time and unwrap only obvious clock wrap. This does not
% modify source data; it reconstructs elapsed time in memory.
t = unwrap_elapsed_time(t);
t = t-t(1);

D = struct("t_s",t,"I_A",I);
end


function t = parse_time_token(token)
s = strtrim(erase(string(token),'"'));
t = NaN;

% If a date is present, keep only the trailing clock field.
if contains(s," ")
    partsSpace = split(s);
    s = partsSpace(end);
end

parts = split(s,":");
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
        jump = prev-current;
        % Common clock wraps. Pick the smallest plausible positive wrap.
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


function v = rc2_voltage_response_periodic(I,dtVec,R,tau)
% Exact ZOH first-order RC branch:
%   v(k+1) = exp(-dt/tau)*v(k) + R*(1-exp(-dt/tau))*I(k)
% Periodic fixed-point initialization removes arbitrary start-up transient.

I = I(:);
dtVec = dtVec(:);
N = numel(I);

if numel(dtVec) ~= N
    error('EXT2:B1:DtLength','dtVec must have the same length as I.');
end
if R <= 0 || tau <= 0 || any(dtVec <= 0)
    error('EXT2:B1:InvalidRC','R, tau and all dt values must be positive.');
end

% Unit-R periodic state z = v/R.
A = 1;
c = 0;
for k = 1:N
    a = exp(-dtVec(k)/tau);
    c = a*c + (1-a)*I(k);
    A = a*A;
end

den = 1-A;
if abs(den) < 1e-14
    error('EXT2:B1:PeriodicSingular','Periodic fixed-point denominator is too small.');
end
z0 = c/den;

z = nan(N,1);
z(1) = z0;
for k = 1:N-1
    a = exp(-dtVec(k)/tau);
    z(k+1) = a*z(k)+(1-a)*I(k);
end

v = R*z;
end


function [mse,aR] = profiled_mse(aT,yTruth,I,dtVec,R2base,tau2base,bounds)
if ~isfinite(aT) || aT <= 0
    mse = inf;
    aR = NaN;
    return
end

z = rc2_voltage_response_periodic(I,dtVec,R2base,tau2base*aT);

den = dot(z,z);
if den <= eps
    mse = inf;
    aR = NaN;
    return
end

aR = dot(z,yTruth)/den;
aR = min(max(aR,bounds(1)),bounds(2));

res = aR*z-yTruth;
mse = mean(res.^2);
end


function [J,condJ,condJTJ,jcos,sigR,sigT,covCorr] = local_geometry( ...
    I,dtVec,R2base,tau2base,aR,aT,sigmaV)

% dV/d alpha_R2 is exact because branch voltage is linear in alpha_R2.
z = rc2_voltage_response_periodic(I,dtVec,R2base,tau2base*aT);
dR = z;

% Central finite difference for alpha_tau2.
h = 1e-4;
vp = rc2_voltage_response_periodic(I,dtVec,R2base*aR,tau2base*(aT+h));
vm = rc2_voltage_response_periodic(I,dtVec,R2base*aR,tau2base*(aT-h));
dT = (vp-vm)/(2*h);

J = [dR,dT];

s = svd(J,"econ");
if numel(s) < 2 || s(2) <= eps
    condJ = inf;
else
    condJ = s(1)/s(2);
end

F = J.'*J;
condJTJ = cond(F);

nr = norm(dR);
nt = norm(dT);
if nr <= eps || nt <= eps
    jcos = NaN;
else
    jcos = dot(dR,dT)/(nr*nt);
end

C = sigmaV^2*pinv(F);
sigR = sqrt(max(C(1,1),0));
sigT = sqrt(max(C(2,2),0));

if sigR > 0 && sigT > 0
    covCorr = C(1,2)/(sigR*sigT);
else
    covCorr = NaN;
end
end


function snap = snapshot_assets(rootDir,relPaths)
n = numel(relPaths);
Path = strings(n,1);
Exists = false(n,1);
Bytes = nan(n,1);
ModifiedDatenum = nan(n,1);

for k = 1:n
    p = fullfile(rootDir,replace(relPaths(k),"/",filesep));
    Path(k) = string(p);
    Exists(k) = isfile(p);
    if Exists(k)
        d = dir(p);
        Bytes(k) = d.bytes;
        ModifiedDatenum(k) = d.datenum;
    end
end

snap = table(Path,Exists,Bytes,ModifiedDatenum);
end


function [ok,audit] = compare_asset_snapshots(a,b)
if height(a) ~= height(b) || any(a.Path ~= b.Path)
    error('EXT2:B1:AssetSnapshotMismatch','Protected asset snapshot structure mismatch.');
end

Unchanged = a.Exists == b.Exists & ...
    ( (~a.Exists & ~b.Exists) | ...
      (a.Bytes == b.Bytes & abs(a.ModifiedDatenum-b.ModifiedDatenum) < 1e-12) );

audit = table(a.Path,a.Exists,b.Exists,a.Bytes,b.Bytes, ...
    a.ModifiedDatenum,b.ModifiedDatenum,Unchanged, ...
    'VariableNames', { ...
    'Path','ExistsBefore','ExistsAfter','BytesBefore','BytesAfter', ...
    'DatenumBefore','DatenumAfter','Unchanged'});

ok = all(Unchanged);
end


function s = pass_text(tf)
if tf
    s = "PASS";
else
    s = "FAIL";
end
end
