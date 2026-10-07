% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
%% EXT2_CLOSEOUT_dynamic_parameter_adaptation_qualification_v1.m
% EXT2 FINAL CLOSEOUT — Dynamic-Parameter Adaptation Qualification
% No new fitting, no new optimizer, no new adaptation implementation.
% This script freezes the already-reviewed EXT2 evidence chain.

clear; clc;

fprintf("\n============================================================\n");
fprintf(" EXT2-CLOSEOUT | Dynamic-Parameter Adaptation Qualification v1\n");
fprintf(" Evidence freeze | No new fitting | Final claim boundary\n");
fprintf("============================================================\n\n");

%% PATHS
ext2Dir = string(fileparts(mfilename('fullpath')));
if strlength(ext2Dir)==0
    error('EXT2:CLOSEOUT:RunAsFile','Run this saved .m file.');
end

[~,nm] = fileparts(ext2Dir);
if ~strcmpi(string(nm),"EXT2_dynamic_parameter_identifiability")
    error('EXT2:CLOSEOUT:WrongFolder', ...
        'Place this script in EXT2_dynamic_parameter_identifiability.');
end

resultsDir = fullfile(ext2Dir,'results');
docsDir = fullfile(ext2Dir,'docs');
protocolDir = fullfile(docsDir,'protocols');
auditDir = fullfile(docsDir,'audits');
handoffDir = fullfile(docsDir,'handoff');

for p = {resultsDir,docsDir,protocolDir,auditDir,handoffDir}
    if ~exist(p{1},'dir'), mkdir(p{1}); end
end

repoRoot = "<REPO_ROOT>";

b12hFile = fullfile(resultsDir,'EXT2_B1_2H_run_bundle_v1_2.mat');
c1File   = fullfile(resultsDir,'EXT2_C1_run_bundle_v1_1.mat');
c1aFile  = fullfile(resultsDir,'EXT2_C1A_run_bundle_v1_1.mat');

for f = {b12hFile,c1File,c1aFile}
    if ~exist(f{1},'file')
        error('EXT2:CLOSEOUT:MissingBundle', ...
            'Required latest-stage bundle missing:\n%s',f{1});
    end
end

fprintf("EXT2 root   : %s\n",ext2Dir);
fprintf("Results     : %s\n",resultsDir);
fprintf("Frozen repo : %s\n\n",repoRoot);

%% PROTECTED ASSET SNAPSHOT
protectedRel = {
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

before = snapshot_assets(repoRoot,protectedRel);

%% LATEST BUNDLE CONSISTENCY
H = load(b12hFile);
C1ref = load(c1File);
C1Aref = load(c1aFile);

needH = {'independentChargeOCVSupported','descriptiveClass'};
needC1 = {'c1Pass','descriptiveClass','FullMetrics','BinMetrics'};
needC1A = {'descriptiveClass','parityPass','maxParity_mV', ...
    'bestAxis','fullGainVsFrozen_pct','lowBinGainVsFrozen_mV'};

assert_fields(H,needH,'B1-2H');
assert_fields(C1ref,needC1,'C1');
assert_fields(C1Aref,needC1A,'C1A');

if ~logical(H.independentChargeOCVSupported)
    error('EXT2:CLOSEOUT:B12HUnexpected','B1-2H support flag changed.');
end
if logical(C1ref.c1Pass)
    error('EXT2:CLOSEOUT:C1Unexpected','C1 latest bundle unexpectedly PASS.');
end
if ~logical(C1Aref.parityPass) || C1Aref.maxParity_mV > 0.05
    error('EXT2:CLOSEOUT:C1AParity','C1A parity contract failed.');
end
if string(C1Aref.descriptiveClass) ~= "SOC_AXIS_MAPPING_NOT_PRIMARY"
    error('EXT2:CLOSEOUT:C1AClass', ...
        'Unexpected C1A class: %s',char(string(C1Aref.descriptiveClass)));
end

C1full = C1ref.FullMetrics;

fprintf("Latest-stage contracts:\n");
fprintf("  B1-2H local/window correction : PASS\n");
fprintf("  C1 full-trajectory transfer   : FAIL confirmed\n");
fprintf("  C1A parity                    : PASS | %.6g mV\n",C1Aref.maxParity_mV);
fprintf("  C1A class                     : %s\n\n",string(C1Aref.descriptiveClass));

%% FINAL STAGE MATRIX
Stage = [
"B1-1";"B1-2A";"B1-2B";"B1-2C";"B1-2D";"B1-2E";"B1-2F";
"B1-2G";"B1-2H";"B1-2I";"B1-2J";"C1";"C1A"];

Status = [
"PASS";"PASS";"FAIL";"DIAGNOSTIC";"DIAGNOSTIC";"DIAGNOSTIC";
"DIAGNOSTIC";"DIAGNOSTIC";"PASS_LOCAL_WINDOW";"FAIL";
"INCONCLUSIVE";"FAIL_PARTIAL_SUPPORT";"CLOSED_DIAGNOSTIC"];

KeyEvidence = [
"738 matched synthetic cases; max cond(J)=8.95"
"18 SOC/state windows ready"
"Measured R2/tau2 targets fail cross-condition consistency"
"Baseline bias dominates measured-voltage error"
"Effective qRef=3.64182 Ah reduces bias but is confounded"
"Independent capacities do not support 3.64182 Ah as physical capacity"
"Charge/discharge pseudo-OCV shows rate/history/direction dependence"
"Directionality robust across tested SOC-axis conventions"
"18/18 DC-AC windows improve; median RMSE 36.940->7.621 mV"
"R2/tau2 target inconsistency remains after baseline control"
"Absolute HPPC SOC provenance cannot be closed to a physical anchor"
"1C full trajectory RMSE 23.165->19.286 mV; all 7 gates fail"
"C1 parity 0 mV; SOC-axis mapping not primary"];

Decision = [
"Synthetic recoverability only"
"Proceed to measured-data qualification"
"Do not implement continuous adaptation"
"Treat baseline/model-form as confounder"
"Do not reinterpret effective qRef as physical capacity"
"Reject physical-capacity explanation"
"Do not label baseline correction equilibrium hysteresis"
"SOC-axis alone cannot explain directionality"
"Retain only as condition-compatible local/window evidence"
"R2/tau2 continuous candidate CLOSED"
"Do not relocate frozen LUT SOC nodes"
"Do not promote correction to universal charge OCV branch"
"Close SOC-axis explanation as non-primary"];

StageEvidence = table(Stage,Status,KeyEvidence,Decision, ...
    'VariableNames',{'Stage','Status','KeyEvidence','Decision'});

writetable(StageEvidence, ...
    fullfile(resultsDir,'EXT2_CLOSEOUT_stage_evidence_matrix_v1.csv'));

%% FINAL CANDIDATE DISPOSITION
Candidate = [
"R0"
"R1 + tau1"
"R2 + tau2"
"R1 + tau1 + R2 + tau2"
"Charge-baseline correction"
"SOC-axis remapping"];

ContinuousOnline = [
"QUALIFIED_WITHIN_GATED_BAYESIAN_V1_SCOPE"
"NOT_QUALIFIED"
"NOT_QUALIFIED_CLOSED"
"NOT_QUALIFIED"
"NOT_AN_ONLINE_PARAMETER_TARGET"
"NOT_JUSTIFIED_AS_MODEL_REPLACEMENT"];

EventBasedOrDiagnostic = [
"EXISTING_RELEASED_SCOPE"
"PULSE_CALIBRATION_CANDIDATE_ONLY"
"EVENT_BASED_REIDENTIFICATION_CANDIDATE_ONLY"
"HPPC_BATCH_REID_CANDIDATE_ONLY"
"CONDITION_COMPATIBLE_MODEL_FORM_EVIDENCE_ONLY"
"SENSITIVITY_ONLY"];

Reason = [
"Existing gated Bayesian R0 adaptation passed released-scope validation"
"Periodic signal too weak for robust continuous R1/tau1 estimation"
"Identifiable but measured optimum is non-transferable across SOC/frequency/amplitude"
"Joint dynamic4 geometry poor under ordinary waveform; HPPC helps only dedicated event identification"
"Strong local transfer but incomplete 1C full-trajectory transfer"
"C1A alternate pre-existing axes do not recover transfer"];

CandidateDisposition = table( ...
    Candidate,ContinuousOnline,EventBasedOrDiagnostic,Reason, ...
    'VariableNames',{'Candidate','ContinuousOnline','EventBasedOrDiagnostic','Reason'});

writetable(CandidateDisposition, ...
    fullfile(resultsDir,'EXT2_CLOSEOUT_candidate_disposition_v1.csv'));

%% NUMERICAL SNAPSHOT
Metric = [
"B1-2H windows improved"
"B1-2H median frozen RMSE mV"
"B1-2H median corrected RMSE mV"
"B1-2H median bias reduction pct"
"C1 frozen full RMSE mV"
"C1 corrected full RMSE mV"
"C1 full RMSE improvement pct"
"C1 frozen centered RMSE mV"
"C1 corrected centered RMSE mV"
"C1A parity max delta mV"
"C1A best tested axis"
"C1A full gain vs FROZEN_QREF pct"
"C1A low-SOC gain vs FROZEN_QREF mV"];

Value = [
"18/18"
"36.940"
"7.621"
"85.98"
string(sprintf('%.6f',C1full.FrozenRMSE_mV(1)))
string(sprintf('%.6f',C1full.CorrectedRMSE_mV(1)))
string(sprintf('%.6f',C1full.RMSEImprovement_pct(1)))
string(sprintf('%.6f',C1full.FrozenCenteredRMSE_mV(1)))
string(sprintf('%.6f',C1full.CorrectedCenteredRMSE_mV(1)))
string(sprintf('%.9g',C1Aref.maxParity_mV))
string(C1Aref.bestAxis)
string(sprintf('%.6f',C1Aref.fullGainVsFrozen_pct))
string(sprintf('%.6f',C1Aref.lowBinGainVsFrozen_mV))];

NumericalSnapshot = table(Metric,Value, ...
    'VariableNames',{'Metric','Value'});

writetable(NumericalSnapshot, ...
    fullfile(resultsDir,'EXT2_CLOSEOUT_numerical_snapshot_v1.csv'));

%% FUTURE EXPERIMENT REQUIREMENTS
Priority = (1:8).';
Requirement = [
"Multiple fresh LG MJ1 cells"
"Controlled chamber temperature"
"Continuous authoritative NGU201 current logging"
"Explicit full and empty SOC anchors"
"Charge/discharge low-rate OCV characterization"
"Multiple C-rate full trajectories"
"New HPPC pulse+relaxation campaign"
"Independent holdout cell"];

Rationale = [
"Separate single-cell history from transferable behavior"
"Remove temperature as uncontrolled resistance/kinetics confounder"
"Prevent missing-current gaps that blocked absolute SOC provenance"
"Make physical SOC traceable"
"Separate rate/history/direction effects from equilibrium-like baseline"
"Test rate dependence of baseline and dynamic residuals"
"Support event-based re-ID under well-conditioned transients"
"Prevent repeated development on one cell from masquerading as independent validation"];

FuturePlan = table(Priority,Requirement,Rationale, ...
    'VariableNames',{'Priority','Requirement','Rationale'});

writetable(FuturePlan, ...
    fullfile(resultsDir,'EXT2_CLOSEOUT_future_experiment_requirements_v1.csv'));

%% SAFE / UNSAFE CLAIMS
SafeClaim = [
"Developed and validated SOC estimation using a SOC-dependent 2RC Thevenin model and EKF for LG MJ1 data."
"Implemented gated Bayesian online R0 adaptation while preserving the frozen plant/EKF architecture."
"Qualified dynamic-parameter adaptation targets through synthetic recovery, identifiability, real-voltage consistency and confounder-controlled holdout tests."
"Rejected continuous R2/tau2 adaptation because the measured target was not transferable across operating conditions."
"Demonstrated a condition-compatible charging-baseline correction with strong local transfer but limited full-trajectory generalization."];

UnsafeOverclaim = [
"All 2RC parameters are estimated online."
"R2/tau2 adaptation is validated for real-time BMS use."
"The charging correction is proven electrochemical hysteresis."
"The HPPC SOC labels have been proven wrong."
"The model is validated across cells and temperatures."];

writetable(table(SafeClaim,'VariableNames',{'SafeClaim'}), ...
    fullfile(resultsDir,'EXT2_CLOSEOUT_safe_claims_v1.csv'));

writetable(table(UnsafeOverclaim,'VariableNames',{'UnsafeOverclaim'}), ...
    fullfile(resultsDir,'EXT2_CLOSEOUT_unsafe_overclaims_v1.csv'));

%% PROTECTED ASSET AUDIT
after = snapshot_assets(repoRoot,protectedRel);
[assetsUnchanged,AssetAudit] = compare_snapshots(before,after);

writetable(AssetAudit, ...
    fullfile(resultsDir,'EXT2_CLOSEOUT_protected_asset_audit_v1.csv'));

if ~assetsUnchanged
    error('EXT2:CLOSEOUT:ProtectedAssetChanged', ...
        'A protected frozen asset changed during closeout.');
end

%% FINAL REPORT
report = {
'MJ1 EXT2 — Dynamic-Parameter Adaptation Qualification Closeout v1'
'================================================================'
''
'FINAL DISPOSITION'
'- R0: QUALIFIED within gated Bayesian v1.0 scope.'
'- R1/tau1: NOT qualified for continuous online adaptation.'
'- R2/tau2: NOT qualified; continuous candidate CLOSED.'
'- Dynamic4: NOT qualified for simultaneous continuous adaptation.'
'- HPPC pulse+relaxation: future event-based / batch re-identification candidate only.'
'- Charge-baseline correction: condition-compatible local/window evidence only.'
'- SOC-axis remapping: NOT PRIMARY explanation of C1 failure.'
''
sprintf('C1 full RMSE: %.3f -> %.3f mV', ...
    C1full.FrozenRMSE_mV(1),C1full.CorrectedRMSE_mV(1))
sprintf('C1 centered RMSE: %.3f -> %.3f mV', ...
    C1full.FrozenCenteredRMSE_mV(1),C1full.CorrectedCenteredRMSE_mV(1))
sprintf('C1A parity max delta: %.9g mV',C1Aref.maxParity_mV)
sprintf('C1A best tested axis: %s',string(C1Aref.bestAxis))
sprintf('C1A class: %s',string(C1Aref.descriptiveClass))
''
'FINAL CLAIM BOUNDARY'
'Only gated R0 adaptation is qualified among the evaluated online adaptation targets under the current evidence.'
'R2/tau2 is identifiable under useful excitation but not a stable transferable measured-data target.'
'The low-rate charge-baseline correction is not a universal OCV or proven hysteresis branch.'
'HPPC absolute SOC provenance remains inconclusive.'
''
'STOP RULE'
'Do not continue post-hoc correction mining on the same historical single-cell dataset.'
'Next high-value step: controlled multi-cell experiments with temperature control, continuous current logging, explicit SOC anchors, low-rate charge/discharge OCV, multiple C-rates, new HPPC, and an independent holdout cell.'
''
sprintf('Protected assets unchanged: %s',pass_text(assetsUnchanged))
};

write_lines(fullfile(resultsDir,'EXT2_CLOSEOUT_final_qualification_report_v1.txt'),report);

%% AUTODOC
protocol = {
'# EXT2 Closeout Protocol v1'
''
'No new fitting, parameter optimization, SOC correction or adaptation implementation is permitted in closeout.'
''
'## Final qualification'
'- R0: qualified within existing gated Bayesian v1.0 scope.'
'- R1/tau1: not qualified for continuous online adaptation.'
'- R2/tau2: identifiable but non-transferable measured target; continuous candidate closed.'
'- Dynamic4: not qualified for continuous simultaneous adaptation.'
'- HPPC pulse+relaxation: future event-based/batch re-identification path only.'
''
'## Stop rule'
'Do not continue post-hoc correction mining on the same historical single-cell dataset. Reopen only with new controlled multi-cell evidence.'
};

write_lines(fullfile(protocolDir,'EXT2_CLOSEOUT_PROTOCOL_v1.md'),protocol);

audit = {
'# EXT2 Final Qualification — CLOSEOUT v1'
''
'`EXT2 HISTORICAL-DATA ADAPTATION QUALIFICATION CLOSED`'
''
'## Final candidate disposition'
'| Candidate | Continuous online | Other disposition |'
'|---|---|---|'
'| R0 | QUALIFIED within v1 scope | existing gated Bayesian implementation |'
'| R1/tau1 | NOT QUALIFIED | event/pulse calibration candidate only |'
'| R2/tau2 | NOT QUALIFIED — CLOSED | event-based re-ID candidate only |'
'| Dynamic4 | NOT QUALIFIED | HPPC batch re-ID candidate only |'
'| Charge baseline | not an online parameter target | condition-compatible evidence only |'
'| SOC remapping | not justified | sensitivity only |'
''
sprintf('- B1-2H: 18/18 windows improved; median RMSE 36.940 -> 7.621 mV.')
sprintf('- C1: full RMSE %.3f -> %.3f mV; prospective transfer gates FAIL.', ...
    C1full.FrozenRMSE_mV(1),C1full.CorrectedRMSE_mV(1))
sprintf('- C1A: parity %.6g mV; class `%s`.', ...
    C1Aref.maxParity_mV,string(C1Aref.descriptiveClass))
''
'## Claim boundary'
'Only gated R0 adaptation is qualified among evaluated online adaptation targets. Dynamic RC adaptation beyond R0 is not qualified by the current historical-data evidence.'
''
sprintf('Protected assets unchanged: **%s**',pass_text(assetsUnchanged))
};

write_lines(fullfile(auditDir,'EXT2_CLOSEOUT_FINAL_QUALIFICATION_v1.md'),audit);

handoff = {
'# EXT2 Current Handoff — CLOSED'
''
'- B1-2H local/window charging-baseline correction: PASS.'
'- B1-2I R2/tau2 target consistency after confounder control: FAIL; continuous candidate CLOSED.'
'- B1-2J HPPC SOC provenance: INCONCLUSIVE.'
'- C1 full-trajectory transfer: FAIL / PARTIAL support.'
'- C1A SOC-axis sensitivity: SOC_AXIS_MAPPING_NOT_PRIMARY.'
''
'## Final adaptation qualification'
'- R0: gated online adaptation qualified within existing v1 scope.'
'- R1/tau1: not qualified continuous.'
'- R2/tau2: not qualified continuous.'
'- Dynamic4: not qualified continuous.'
'- Pulse+relaxation remains a future event-based/batch re-ID path.'
''
'## Reopen condition'
'New controlled multi-cell data with temperature control, continuous authoritative current, explicit SOC anchors and independent validation.'
};

write_lines(fullfile(handoffDir,'EXT2_CURRENT_HANDOFF.md'),handoff);

continuity = {
'# EXT2 Project Continuity — CLOSED'
''
'Recoverability/identifiability is necessary but not sufficient for online adaptation.'
'R2/tau2 passed synthetic recovery and showed useful excitation sensitivity, but failed measured-data target transfer before and after charging-baseline confounder control.'
'The historical-data campaign therefore closes without a new continuous dynamic-parameter updater.'
''
'Do not modify the frozen MJ1 v0.2 EKF, Bayesian R0 v1.0, EXT1 K4, frozen Simulink assets or released history as part of EXT2 closeout.'
};

write_lines(fullfile(handoffDir,'EXT2_PROJECT_CONTINUITY_CURRENT.md'),continuity);

readmeSnippet = {
'## Dynamic-parameter adaptation qualification (EXT2)'
''
'EXT2 tested whether additional 2RC dynamic parameters should be adapted online rather than assumed transferable from the frozen SOC-dependent parameterization.'
''
'Synthetic recovery and practical-identifiability studies showed that `R2/tau2` can be informative under suitable excitation, while HPPC pulse+relaxation improves multi-timescale separation. However, measured-voltage qualification showed that the optimum `R2/tau2` target was not stable across SOC, excitation amplitude and frequency, even after an independently validated charging-baseline confounder was controlled.'
''
'Continuous `R2/tau2` adaptation was therefore rejected under the available evidence rather than promoted on fit improvement alone. Gated Bayesian `R0` adaptation remains the only qualified online parameter adaptation in the released scope. Dynamic RC parameters remain candidates for dedicated event-based / HPPC-style batch re-identification.'
''
'> Scope: single historical LG MJ1 cell dataset; cross-cell and cross-temperature generalization require a new controlled multi-cell campaign.'
};

write_lines(fullfile(handoffDir,'EXT2_CLOSEOUT_README_SNIPPET_v1.md'),readmeSnippet);

%% CONSOLE
fprintf("============================================================\n");
fprintf(" EXT2 CLOSEOUT COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Final adaptation qualification:\n");
fprintf("  R0                      : QUALIFIED within gated Bayesian v1 scope\n");
fprintf("  R1 + tau1               : NOT QUALIFIED continuous\n");
fprintf("  R2 + tau2               : NOT QUALIFIED continuous | CLOSED\n");
fprintf("  Dynamic4                : NOT QUALIFIED continuous\n");
fprintf("  HPPC pulse+relaxation   : EVENT-BASED / BATCH RE-ID CANDIDATE\n\n");

fprintf("Model-form findings:\n");
fprintf("  B1-2H local/window      : PASS | 18/18 windows\n");
fprintf("  C1 full trajectory      : FAIL / PARTIAL\n");
fprintf("  C1 RMSE                 : %.3f -> %.3f mV\n", ...
    C1full.FrozenRMSE_mV(1),C1full.CorrectedRMSE_mV(1));
fprintf("  C1 centered RMSE        : %.3f -> %.3f mV\n", ...
    C1full.FrozenCenteredRMSE_mV(1),C1full.CorrectedCenteredRMSE_mV(1));
fprintf("  C1A parity              : PASS | %.6g mV\n",C1Aref.maxParity_mV);
fprintf("  C1A best tested axis    : %s\n",string(C1Aref.bestAxis));
fprintf("  C1A class               : %s\n",string(C1Aref.descriptiveClass));
fprintf("  HPPC SOC provenance     : INCONCLUSIVE\n\n");

fprintf("Historical-data EXT2      : CLOSED\n");
fprintf("Reopen only with          : NEW CONTROLLED MULTI-CELL DATA\n");
fprintf("Protected assets unchanged: %s\n",pass_text(assetsUnchanged));
fprintf("AUTODOC closeout dossier  : PASS\n\n");

%% LOCAL FUNCTIONS
function assert_fields(S,names,label)
missing = names(~cellfun(@(f) isfield(S,f),names));
if ~isempty(missing)
    error('EXT2:CLOSEOUT:BundleContract', ...
        '%s bundle missing: %s',label,strjoin(missing,', '));
end
end

function h = sha256_file(filePath)
cmd = sprintf('certutil -hashfile "%s" SHA256',char(filePath));
[status,out] = system(cmd);
if status==0
    token = regexp(out,'[0-9A-Fa-f]{64}','match','once');
    if ~isempty(token), h=lower(token); return; end
end
fid=fopen(filePath,'rb');
if fid<0, error('EXT2:CLOSEOUT:HashOpen','Cannot open %s',char(filePath)); end
c=onCleanup(@() fclose(fid)); %#ok<NASGU>
md=java.security.MessageDigest.getInstance('SHA-256');
while true
    b=fread(fid,1024*1024,'*uint8');
    if isempty(b), break; end
    md.update(typecast(b(:),'int8'));
end
u=typecast(md.digest(),'uint8');
h=lower(reshape(dec2hex(u,2).',1,[]));
end

function T = snapshot_assets(rootDir,relPaths)
n=numel(relPaths);
Path=strings(n,1); Exists=false(n,1); Bytes=nan(n,1); SHA256=strings(n,1);
for k=1:n
    p=fullfile(rootDir,relPaths{k});
    Path(k)=string(p); Exists(k)=isfile(p);
    if Exists(k)
        d=dir(p); Bytes(k)=d.bytes; SHA256(k)=string(sha256_file(p));
    end
end
T=table(Path,Exists,Bytes,SHA256, ...
    'VariableNames',{'Path','Exists','Bytes','SHA256'});
end

function [ok,A] = compare_snapshots(a,b)
if height(a)~=height(b) || any(a.Path~=b.Path)
    error('EXT2:CLOSEOUT:SnapshotMismatch','Protected snapshot mismatch.');
end
Unchanged=false(height(a),1);
for k=1:height(a)
    if ~a.Exists(k) && ~b.Exists(k)
        Unchanged(k)=true;
    elseif a.Exists(k) && b.Exists(k)
        Unchanged(k)=a.Bytes(k)==b.Bytes(k) && strcmpi(a.SHA256(k),b.SHA256(k));
    end
end
A=table(a.Path,a.Exists,b.Exists,a.SHA256,b.SHA256,Unchanged, ...
    'VariableNames',{'Path','ExistsBefore','ExistsAfter','SHA256Before','SHA256After','Unchanged'});
ok=all(Unchanged);
end

function write_lines(filePath,lines)
fid=fopen(filePath,'w','n','UTF-8');
if fid<0, error('EXT2:CLOSEOUT:WriteFail','Cannot write %s',char(filePath)); end
c=onCleanup(@() fclose(fid)); %#ok<NASGU>
for k=1:numel(lines), fprintf(fid,'%s\n',char(string(lines{k}))); end
end

function s=pass_text(tf)
if tf, s='PASS'; else, s='FAIL'; end
end
