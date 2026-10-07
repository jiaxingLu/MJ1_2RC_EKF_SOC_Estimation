% PUBLIC SNAPSHOT NOTICE
% This file is published as an analysis-source snapshot from the reviewed
% EXT2 working tree. Machine-specific local paths have been redacted.
% It is NOT a one-click reproduction entry point: some raw experimental
% inputs and upstream MAT/provenance bundles are not distributed here.
% See scripts/extension_track2/README.md and the EXT2 closeout document.
%
clear; clc;
fprintf('EXT2-B1-2J | Read-only frozen MAT provenance metadata\n');
scriptDir=string(fileparts(mfilename('fullpath')));
repoRoot="<REPO_ROOT>";
modelFile=fullfile(repoRoot,'data','mj1_v02_model.mat');
assert(isfile(modelFile));
S=load(modelFile);
metadata=struct('source',modelFile,'variables',{fieldnames(S)},'model',S.model,'operation','READ_ONLY_METADATA_NO_FITTING');
if isfield(S,'meta'), metadata.meta=S.meta;end
out=fullfile(scriptDir,'results','EXT2_B1_2J_frozen_model_metadata_v1.json');
fid=fopen(out,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(metadata,PrettyPrint=true));
fprintf('Model variables: %s\n',strjoin(string(fieldnames(S)),', '));
fprintf('Model fields: %s\n',strjoin(string(fieldnames(S.model)),', '));
fprintf('qRefAh: %.12g\n',S.model.qRefAh);
fprintf('Read-only metadata output: %s\n',out);
