% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_B1_2E_independent_capacity_plausibility_v1.m
% MJ1 2RC-EKF EXT2-B1
% B1-2E Independent Capacity Plausibility Audit v1
%
% PURPOSE
%   Test whether the B1-2D voltage-derived effective qRef (~best qRef scale)
%   is physically supported by independent full charge/discharge records.
%
% IMPORTANT
%   This is NOT a capacity-fit stage and NOT an adaptation stage.
%   It does not re-fit R2/tau2 and does not change B1-2B FAIL / B2 STOP.
%
% INPUT EVIDENCE
%   - B1-2A terminal-SOC=1 anchored charge profiles
%   - B1-2D qRef sensitivity result
%   - historical independent full charge:
%       raw_original/1C/1C_full_charge.csv
%   - historical independent full discharge:
%       raw_original/1C/1C_full_discharge.csv
%
% SOURCE IDENTITY
%   The 1C charge/discharge files are locked by exact path + SHA-256.
%
% OUTPUTS
%   All generated scientific outputs go only to EXT2/results.
%
% INTERPRETATION
%   If the voltage-derived qRef is larger than all independent capacity
%   references, it should be treated as an EFFECTIVE SOC-axis correction,
%   not accepted as a physical capacity estimate without new evidence.
%
% MATLAB compatibility
%   Base MATLAB only. No Statistics/Econometrics Toolbox.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-B1-2E | Independent Capacity Plausibility Audit v1\n");
fprintf(" B1-2D qRef explanation check | No fitting / no adaptation\n");
fprintf("============================================================\n\n");

%% ------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
scriptDir = string(fileparts(mfilename('fullpath')));

if strlength(scriptDir) == 0
    error('EXT2:B12E:RunAsFile', ...
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
    error('EXT2:B12E:WrongFolder', ...
        'This script must live inside %s. Current folder: %s', ...
        char(expectedExt2Name),char(ext2Dir));
end

cfg.repoRoot = ...
    "<REPO_ROOT>";

modelFile = fullfile(cfg.repoRoot,'data','mj1_v02_model.mat');
repoMatlab = fullfile(cfg.repoRoot,'matlab');

b12aFile = fullfile(resultsDir,'EXT2_B1_2A_run_bundle_v1.mat');
b12dFile = fullfile(resultsDir,'EXT2_B1_2D_qref_sensitivity_v1.csv');

profileRoot = fullfile(string(getenv("USERPROFILE")), ...
    'Desktop','MJ1_Experimental_Data_Reconstruction','raw_original');

chargeFile = fullfile(profileRoot,'1C','1C_full_charge.csv');
dischargeFile = fullfile(profileRoot,'1C','1C_full_discharge.csv');

chargeSHA = ...
    "9df6afbf73b78742e0449803d8f2eae8e9506583b5ff2f5161fabc65934d72f2";
dischargeSHA = ...
    "df1671e7809ba8d6f20e6ab814eb64cea98d8d98e787e66d575e5aff8088f572";

required = { ...
    modelFile, ...
    b12aFile, ...
    b12dFile, ...
    chargeFile, ...
    dischargeFile, ...
    fullfile(repoMatlab,'mj1_load_model.m')};

for k = 1:numel(required)
    if ~exist(required{k},'file')
        error('EXT2:B12E:MissingInput', ...
            'Required input not found:\n%s',required{k});
    end
end

addpath(repoMatlab);
model = mj1_load_model(modelFile);

A = load(b12aFile);
Qscan = readtable(b12dFile);

if ~isfield(A,'overallPass') || ~logical(A.overallPass) || ...
   ~isfield(A,'profileData')
    error('EXT2:B12E:B12ABundleContract', ...
        'B1-2A bundle is missing required PASS/profileData evidence.');
end

requiredQ = { ...
    'QrefScale','Qref_Ah','Valid','PooledRMSE_mV', ...
    'MedianAbsWindowBias_mV'};

missingQ = setdiff(requiredQ,Qscan.Properties.VariableNames);

if ~isempty(missingQ)
    error('EXT2:B12E:B12DTableContract', ...
        'B1-2D qRef table missing variable(s): %s', ...
        strjoin(missingQ,', '));
end

fprintf("EXT2 work folder : %s\n",ext2Dir);
fprintf("Results only     : %s\n",resultsDir);
fprintf("Frozen model qRef: %.6f Ah\n\n",model.qRefAh);

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
% 2. EXACT SOURCE IDENTITY
% -------------------------------------------------------------------------
chargeActualSHA = sha256_file(chargeFile);
dischargeActualSHA = sha256_file(dischargeFile);

if ~strcmpi(chargeActualSHA,char(chargeSHA))
    error('EXT2:B12E:ChargeHashMismatch', ...
        '1C full-charge SHA-256 mismatch. STOP.');
end

if ~strcmpi(dischargeActualSHA,char(dischargeSHA))
    error('EXT2:B12E:DischargeHashMismatch', ...
        '1C full-discharge SHA-256 mismatch. STOP.');
end

fprintf("1C full charge source    : SHA256 PASS\n");
fprintf("1C full discharge source : SHA256 PASS\n\n");

%% ------------------------------------------------------------------------
% 3. INDEPENDENT FULL-PROFILE CAPACITY INTEGRATION
% -------------------------------------------------------------------------
Dchg = load_ngu_uiv_full(chargeFile);
Ddsg = load_ngu_uiv_full(dischargeFile);

% Positive charge throughput and negative discharge throughput.
Ipos = max(Dchg.I_A,0);
Ineg = min(Ddsg.I_A,0);

Qcharge_Ah = trapz(Dchg.t_s,Ipos)/3600;
Qdischarge_Ah = -trapz(Ddsg.t_s,Ineg)/3600;

% Signed net values for audit.
QchargeNet_Ah = trapz(Dchg.t_s,Dchg.I_A)/3600;
QdischargeNet_Ah = trapz(Ddsg.t_s,Ddsg.I_A)/3600;

% End-condition diagnostics only.
chargeEndV = Dchg.V_V(end);
chargeEndI = Dchg.I_A(end);
dischargeEndV = Ddsg.V_V(end);
dischargeEndI = Ddsg.I_A(end);

chargeEndNearProjectFull = ...
    abs(chargeEndV-4.2) <= 0.01 && ...
    abs(chargeEndI-0.05) <= 0.01;

dischargeEndNearProjectEmpty = ...
    abs(dischargeEndV-2.5) <= 0.01 && ...
    abs(dischargeEndI+0.025) <= 0.015;

%% ------------------------------------------------------------------------
% 4. B1-2D EFFECTIVE qRef
% -------------------------------------------------------------------------
validMask = logical(Qscan.Valid) & isfinite(Qscan.PooledRMSE_mV);

if ~any(validMask)
    error('EXT2:B12E:NoValidB12DQref', ...
        'B1-2D contains no valid qRef sensitivity point.');
end

idxValid = find(validMask);
[~,jLocal] = min(Qscan.PooledRMSE_mV(validMask));
idxBest = idxValid(jLocal);

effectiveQref_Ah = Qscan.Qref_Ah(idxBest);
effectiveQrefScale = Qscan.QrefScale(idxBest);
effectiveMedianBias_mV = Qscan.MedianAbsWindowBias_mV(idxBest);

% Manufacturer/product-spec context only; not the method used by the
% historical 1C files.
cfg.MJ1_nominal_Ah = 3.500;
cfg.MJ1_minimum_Ah = 3.350;

ReferenceName = [ ...
    "Frozen model qRef"
    "Historical 1C full-charge throughput"
    "Historical 1C full-discharge throughput"
    "MJ1 nominal capacity (product spec)"
    "MJ1 minimum capacity (product spec)"
    "B1-2D voltage-derived effective qRef"
    ];

Reference_Ah = [ ...
    model.qRefAh
    Qcharge_Ah
    Qdischarge_Ah
    cfg.MJ1_nominal_Ah
    cfg.MJ1_minimum_Ah
    effectiveQref_Ah
    ];

DeltaVsEffective_Ah = effectiveQref_Ah-Reference_Ah;
DeltaVsEffective_pct = 100*(effectiveQref_Ah./Reference_Ah-1);

CapacityReferenceSummary = table( ...
    ReferenceName,Reference_Ah,DeltaVsEffective_Ah,DeltaVsEffective_pct, ...
    'VariableNames', { ...
    'Reference','Capacity_Ah','EffectiveMinusReference_Ah', ...
    'EffectiveMinusReference_pct'});

%% ------------------------------------------------------------------------
% 5. IMPLIED START SOC UNDER ALTERNATIVE qRef VALUES
% -------------------------------------------------------------------------
profileData = A.profileData;

nP = numel(profileData);
rows = struct([]);

candidateNames = [ ...
    "Frozen_qRef"
    "1C_full_charge"
    "1C_full_discharge"
    "MJ1_nominal"
    "B12D_effective"
    ];

candidateQ = [ ...
    model.qRefAh
    Qcharge_Ah
    Qdischarge_Ah
    cfg.MJ1_nominal_Ah
    effectiveQref_Ah
    ];

ir = 0;

for ip = 1:nP

    P = profileData(ip);

    idxAnchor = P.idx_anchor;

    tA = P.t_s(1:idxAnchor);
    IA = P.I_A(1:idxAnchor);

    QtoAnchor_Ah = trapz(tA,IA)/3600;

    for iq = 1:numel(candidateQ)

        zStart = 1-QtoAnchor_Ah/candidateQ(iq);

        ir = ir+1;
        rows(ir).CaseID = P.case_id; %#ok<SAGROW>
        rows(ir).Band = P.band;
        rows(ir).QrefCandidate = candidateNames(iq);
        rows(ir).Qref_Ah = candidateQ(iq);
        rows(ir).ChargeToTerminalAnchor_Ah = QtoAnchor_Ah;
        rows(ir).ImpliedStartSOC = zStart;
        rows(ir).ImpliedStartSOC_pct = 100*zStart;
    end
end

ImpliedStartSOC = struct2table(rows);

% Extract effective-qRef start-SOC range.
Teff = ImpliedStartSOC( ...
    ImpliedStartSOC.QrefCandidate == "B12D_effective",:);

effectiveStartSOC_Min_pct = min(Teff.ImpliedStartSOC_pct);
effectiveStartSOC_Max_pct = max(Teff.ImpliedStartSOC_pct);
effectiveStartSOC_Median_pct = median(Teff.ImpliedStartSOC_pct);

Tfrozen = ImpliedStartSOC( ...
    ImpliedStartSOC.QrefCandidate == "Frozen_qRef",:);

frozenStartSOC_Min_pct = min(Tfrozen.ImpliedStartSOC_pct);
frozenStartSOC_Max_pct = max(Tfrozen.ImpliedStartSOC_pct);
frozenStartSOC_Median_pct = median(Tfrozen.ImpliedStartSOC_pct);

%% ------------------------------------------------------------------------
% 6. DESCRIPTIVE PLAUSIBILITY CLASS
% -------------------------------------------------------------------------
independentReferenceMax = max([ ...
    Qcharge_Ah,Qdischarge_Ah,cfg.MJ1_nominal_Ah]);

effectiveAboveAllIndependent = ...
    effectiveQref_Ah > independentReferenceMax;

if effectiveAboveAllIndependent
    descriptiveClass = ...
        "EFFECTIVE_QREF_EXCEEDS_ALL_INDEPENDENT_CAPACITY_REFERENCES";
else
    descriptiveClass = ...
        "EFFECTIVE_QREF_WITHIN_INDEPENDENT_CAPACITY_REFERENCE_ENVELOPE";
end

% This is not a PASS/FAIL gate. It is a physical-interpretation audit.
fprintf("Independent capacity integration:\n");
fprintf("  1C full charge throughput    : %.6f Ah\n",Qcharge_Ah);
fprintf("  1C full discharge throughput : %.6f Ah\n",Qdischarge_Ah);
fprintf("  Charge endpoint              : %.6f V / %.6f A | %s\n", ...
    chargeEndV,chargeEndI,pass_text(chargeEndNearProjectFull));
fprintf("  Discharge endpoint           : %.6f V / %.6f A | %s\n\n", ...
    dischargeEndV,dischargeEndI,pass_text(dischargeEndNearProjectEmpty));

fprintf("B1-2D effective qRef:\n");
fprintf("  scale                         : %.3f\n",effectiveQrefScale);
fprintf("  qRef                          : %.6f Ah\n",effectiveQref_Ah);
fprintf("  residual median |bias|        : %.3f mV\n\n", ...
    effectiveMedianBias_mV);

%% ------------------------------------------------------------------------
% 7. SAVE
% -------------------------------------------------------------------------
capFile = fullfile( ...
    resultsDir,'EXT2_B1_2E_capacity_reference_summary_v1.csv');
startSOCFile = fullfile( ...
    resultsDir,'EXT2_B1_2E_implied_start_SOC_v1.csv');

writetable(CapacityReferenceSummary,capFile);
writetable(ImpliedStartSOC,startSOCFile);

reportFile = fullfile( ...
    resultsDir,'EXT2_B1_2E_capacity_plausibility_report_v1.txt');

fid = fopen(reportFile,'w');

if fid < 0
    error('EXT2:B12E:ReportOpenFailed', ...
        'Could not open report file: %s',char(reportFile));
end

fprintf(fid,"MJ1 EXT2-B1-2E Independent Capacity Plausibility Audit v1\n");
fprintf(fid,"==========================================================\n\n");
fprintf(fid,"Diagnostic only. No parameter fitting/adaptation.\n\n");

fprintf(fid,"Independent historical capacities / throughput:\n");
fprintf(fid,"1C full charge throughput     = %.9f Ah\n",Qcharge_Ah);
fprintf(fid,"1C full discharge throughput  = %.9f Ah\n",Qdischarge_Ah);
fprintf(fid,"MJ1 nominal product capacity  = %.9f Ah\n",cfg.MJ1_nominal_Ah);
fprintf(fid,"MJ1 minimum product capacity  = %.9f Ah\n",cfg.MJ1_minimum_Ah);
fprintf(fid,"Frozen model qRef             = %.9f Ah\n",model.qRefAh);
fprintf(fid,"\n");

fprintf(fid,"B1-2D voltage-derived effective qRef:\n");
fprintf(fid,"scale                         = %.6f\n",effectiveQrefScale);
fprintf(fid,"effective qRef                = %.9f Ah\n",effectiveQref_Ah);
fprintf(fid,"effective median |bias|       = %.6f mV\n",effectiveMedianBias_mV);
fprintf(fid,"\n");

fprintf(fid,"Effective qRef relative to:\n");
fprintf(fid,"frozen qRef                   = %+8.3f %%\n", ...
    100*(effectiveQref_Ah/model.qRefAh-1));
fprintf(fid,"1C full charge                = %+8.3f %%\n", ...
    100*(effectiveQref_Ah/Qcharge_Ah-1));
fprintf(fid,"1C full discharge             = %+8.3f %%\n", ...
    100*(effectiveQref_Ah/Qdischarge_Ah-1));
fprintf(fid,"MJ1 nominal 3.500 Ah          = %+8.3f %%\n", ...
    100*(effectiveQref_Ah/cfg.MJ1_nominal_Ah-1));
fprintf(fid,"\n");

fprintf(fid,"Implied start SOC range:\n");
fprintf(fid,"frozen qRef                   = %.3f ... %.3f %% (median %.3f %%)\n", ...
    frozenStartSOC_Min_pct,frozenStartSOC_Max_pct,frozenStartSOC_Median_pct);
fprintf(fid,"B1-2D effective qRef          = %.3f ... %.3f %% (median %.3f %%)\n", ...
    effectiveStartSOC_Min_pct,effectiveStartSOC_Max_pct,effectiveStartSOC_Median_pct);
fprintf(fid,"\n");

fprintf(fid,"Descriptive class             = %s\n",descriptiveClass);
fprintf(fid,"\n");

fprintf(fid,"Interpretation boundary:\n");
fprintf(fid,"The B1-2D effective qRef is a voltage/SOC-axis sensitivity result, not an independently measured capacity.\n");
fprintf(fid,"B1-2B remains FAIL and B2 remains STOP.\n");
fclose(fid);

%% ------------------------------------------------------------------------
% 8. PROTECTED ASSET AUDIT
% -------------------------------------------------------------------------
protectedAfter = snapshot_assets_hash(cfg.repoRoot,protectedRel);
[assetsUnchanged,AssetAudit] = ...
    compare_asset_snapshots_hash(protectedBefore,protectedAfter);

assetAuditFile = fullfile( ...
    resultsDir,'EXT2_B1_2E_protected_asset_audit_v1.csv');
writetable(AssetAudit,assetAuditFile);

if ~assetsUnchanged
    error('EXT2:B12E:ProtectedAssetChanged', ...
        'A protected frozen asset changed during B1-2E. STOP.');
end

%% ------------------------------------------------------------------------
% 9. CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf("============================================================\n");
fprintf(" EXT2-B1-2E COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Capacity references:\n");
fprintf("  Frozen model qRef             : %.6f Ah\n",model.qRefAh);
fprintf("  1C full charge throughput     : %.6f Ah\n",Qcharge_Ah);
fprintf("  1C full discharge throughput  : %.6f Ah\n",Qdischarge_Ah);
fprintf("  MJ1 nominal capacity          : %.6f Ah\n",cfg.MJ1_nominal_Ah);
fprintf("  MJ1 minimum capacity          : %.6f Ah\n",cfg.MJ1_minimum_Ah);

fprintf("\nB1-2D voltage-derived effective qRef:\n");
fprintf("  Scale                         : %.3f\n",effectiveQrefScale);
fprintf("  Effective qRef                : %.6f Ah\n",effectiveQref_Ah);
fprintf("  vs frozen qRef                : %+6.2f %%\n", ...
    100*(effectiveQref_Ah/model.qRefAh-1));
fprintf("  vs 1C full charge             : %+6.2f %%\n", ...
    100*(effectiveQref_Ah/Qcharge_Ah-1));
fprintf("  vs 1C full discharge          : %+6.2f %%\n", ...
    100*(effectiveQref_Ah/Qdischarge_Ah-1));
fprintf("  vs nominal 3.500 Ah           : %+6.2f %%\n", ...
    100*(effectiveQref_Ah/cfg.MJ1_nominal_Ah-1));

fprintf("\nImplied DC-AC start SOC:\n");
fprintf("  Frozen qRef                   : %.2f ... %.2f %% | median %.2f %%\n", ...
    frozenStartSOC_Min_pct,frozenStartSOC_Max_pct,frozenStartSOC_Median_pct);
fprintf("  Effective qRef                : %.2f ... %.2f %% | median %.2f %%\n", ...
    effectiveStartSOC_Min_pct,effectiveStartSOC_Max_pct,effectiveStartSOC_Median_pct);

fprintf("\nDescriptive class:\n  %s\n",descriptiveClass);
fprintf("Protected assets unchanged     : %s\n",pass_text(assetsUnchanged));
fprintf("B1-2B remains FAIL / B2 remains STOP.\n\n");

fprintf("Saved under:\n%s\n\n",resultsDir);


%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function D = load_ngu_uiv_full(filePath)
txt = fileread(filePath);
lines = splitlines(string(txt));

if isempty(lines)
    error('EXT2:B12E:EmptyProfile', ...
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
    error('EXT2:B12E:NGUHeaderMissing', ...
        'NGU header not found: %s',char(filePath));
end

headers = split(lines(headerIdx),',');
headers = strtrim(erase(headers,'"'));
headers = erase(headers,string(char(65279)));

iT = find(strcmpi(headers,'Timestamp'),1);
iV = find(strcmpi(headers,'U1[V]'),1);
iI = find(strcmpi(headers,'I1[A]'),1);

if isempty(iT) || isempty(iV) || isempty(iI)
    error('EXT2:B12E:NGUColumnsMissing', ...
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
    error('EXT2:B12E:NoValidData', ...
        'Too few valid rows: %s',char(filePath));
end

t = unwrap_elapsed_time(tRaw);
t = t-t(1);

if any(diff(t) <= 0)
    error('EXT2:B12E:NonMonotonicTime', ...
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
    error('EXT2:B12E:HashOpenFailed', ...
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
    error('EXT2:B12E:HashFailed', ...
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
    error('EXT2:B12E:AssetSnapshotMismatch', ...
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
