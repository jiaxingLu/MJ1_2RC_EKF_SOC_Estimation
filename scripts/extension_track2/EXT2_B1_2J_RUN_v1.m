% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
clear; clc;
fprintf('============================================================\n');
fprintf(' EXT2-B1-2J | HPPC SOC provenance and independent alignment audit\n');
fprintf(' AUDIT ONLY | no frozen model changes | STOP after delivery\n');
fprintf('============================================================\n');
%% PATHS and frozen-input preflight
ext2Dir=string(fileparts(mfilename('fullpath')));
repoRoot="<REPO_ROOT>";
modelFile=fullfile(repoRoot,'data','mj1_v02_model.mat');
pythonExe="<PYTHON_EXECUTABLE>";
assert(isfile(modelFile) && isfile(pythonExe));
assert(isfile(fullfile(ext2Dir,'results','EXT2_B1_2J_protected_before_v1.json')),'Original protected baseline required; never recreate it silently.');
assert(isfile(fullfile(ext2Dir,'results','EXT2_B1_2J_input_addendum_v1.json')),'Explicit two-NGU-source addendum required.');
%% Read frozen model metadata only. No parameter or state calculation.
S=load(modelFile);
metadata=struct('source',modelFile,'variables',{fieldnames(S)},'model',S.model,'operation','READ_ONLY_METADATA_NO_FITTING');
out=fullfile(ext2Dir,'results','EXT2_B1_2J_frozen_model_metadata_v1.json');
fid=fopen(out,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(metadata,PrettyPrint=true));fclose(fid);
%% Schema/source identity, independent reconstruction, final SHA and AUTODOC
% Python is used for native REC metadata and DOCX/XLSX provenance inspection.
% Every Python stage enforces scoped writes. Current is integrated by native
% adjacent finite samples only. NaNs/gaps remain unknown. B1-2D is loaded by
% the final stage only after independent reconstruction is saved and hashed.
stages=["EXT2_B1_2J_inspect_v1.py","EXT2_B1_2J_reconstruct_v1.py","EXT2_B1_2J_finalize_v1.py"];
for stage=stages
    command=sprintf('"%s" -B -X utf8 "%s"',pythonExe,fullfile(ext2Dir,stage));
    [code,output]=system(command);fprintf('%s',output);
    assert(code==0,'EXT2:B12J:AuditFailed','Audit stage failed; STOP.');
end
%% Explicit stopping boundary
fprintf('B1-2J complete. No follow-on model work executed. STOP.\n');
