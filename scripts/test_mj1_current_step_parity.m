function test_mj1_current_step_parity(a8Dir)
% TEST_MJ1_CURRENT_STEP_PARITY Synthetic 1 s current-step implementation test.
% Uses the audited A8a MATLAB helpers, frozen MAT and saved Simulink observer.
% No model fitting, online adaptation, original-file edits or Git operations.
% This is NOT HPPC, measured cell data, independent SOC validation or SIL/HIL.
%
% All external inputs are synthetic. Voltage is generated BEFORE either EKF
% run using a separately written frozen-LUT forward calculation plus a small
% deterministic voltage test signal. The two observers receive identical U/I.
% The generated SOC is fixture metadata, not an independently measured truth.
%
% Two MATLAB-only negative controls deliberately misuse current indices at
% the call boundary. They do not modify any helper or the Simulink observer.
% These faults should be invisible under constant current and detected with
% steps. Their detection is separate from actual MATLAB/Simulink parity.
%
% Run from the original project directory: test_mj1_current_step_parity
% Optional argument: an explicit path to the completed A8a audit directory.

root = fileparts(mfilename('fullpath'));
res = fullfile(root,'results');
assert(isfolder(res),'Save this function in the original project root.');
if nargin<1 || strlength(string(a8Dir))==0
    a8Dir = fullfile(res,'A8a_20261001_095757_186');
    if ~isfolder(a8Dir)
        a8Dir = uigetdir(res,'Select the COMPLETED A8a audit folder');
        if isequal(a8Dir,0), return; end
    end
end
a8Dir = char(a8Dir);
A = readtable(fullfile(a8Dir,'A8a_status.csv'),'VariableNamingRule','preserve');
assert(height(A)==1 && string(A.BaselineReplay(1))=="MATCHED_A7A_BASELINE", ...
    'A8a baseline has not passed.');
manifest = readtable(fullfile(a8Dir,'A8a_source_manifest.csv'), ...
    'VariableNamingRule','preserve');
slx = dir(fullfile(a8Dir,'saved_slx','*.slx'));
assert(numel(slx)==1,'Expected one audited SLX file.');
sourceSLX = fullfile(slx(1).folder,slx(1).name);
helpers = ["mj1_ekf_step";"mj1_interp_params";"mj1_state_transition"; ...
           "mj1_measurement";"mj1_F_jacobian";"mj1_H_jacobian"];
sourceFiles = [fullfile(a8Dir,'snapshot',helpers+".m"); ...
    string(fullfile(a8Dir,'snapshot','mj1_v02_model.mat'));string(sourceSLX)];
roles = [repmat("CORE",7,1);"SAVED_SLX"];
for k=1:numel(sourceFiles)
    verifySnapshot(sourceFiles(k),roles(k),manifest);
end
R = load(fullfile(a8Dir,'A8a_baseline_reference.mat'), ...
    'model','data','cfg','cases','z0','Runs');
M = load(sourceFiles(7),'model');
model = M.model;
assert(isequaln(model,R.model),'A8a reference/model mismatch.');
validateModel(model);

% Tolerances are implementation-comparison tolerances, not sensor accuracy.
cfg = struct('Q',diag([1e-7 1e-7 1e-9]),'R',0.020^2, ...
    'P0',diag([0.02^2 0.02^2 0.20^2]),'dt_s',1, ...
    'SOCParityTolerance_pp',1e-6,'VoltageParityTolerance_mV',1e-5, ...
    'TimeTolerance_s',1e-9,'CurrentTolerance_A',1e-10, ...
    'InputVoltageTolerance_mV',1e-7,'EdgeBefore_s',1,'EdgeAfter_s',5, ...
    'FixtureSOC0',0.55,'Scope',"Synthetic step/reversal, 1 s, three initial SOC cases");
assert(isequal(cfg.Q,R.cfg.Q) && isequal(cfg.R,R.cfg.R) ...
    && isequal(cfg.P0,R.cfg.P0),'Frozen covariance settings differ.');

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
out = fullfile(res,['StepParity_' stamp]);
work = fullfile(out,'sandbox');
mkdir(work);
mdl = ['MJ1_steps_' stamp];
testSLX = fullfile(work,[mdl '.slx']);
Sources = table(sourceFiles,strings(8,1),strings(8,1),strings(8,1), ...
    'VariableNames',{'Original','SandboxCopy','BeforeSHA256','AfterSHA256'});
for k=1:8
    [~,n,e] = fileparts(sourceFiles(k));
    destination = fullfile(work,string(n)+string(e));
    if k==8, destination = string(testSLX); end
    [ok,msg] = copyfile(sourceFiles(k),destination);
    assert(ok,'%s',msg);
    Sources.SandboxCopy(k) = destination;
    Sources.BeforeSHA256(k) = sha256(sourceFiles(k));
    assert(sha256(destination)==Sources.BeforeSHA256(k),'Copy mismatch.');
end
copyfile([mfilename('fullpath') '.m'],fullfile(out,'test_mj1_current_step_parity.m'));
writetable(Sources,fullfile(out,'source_manifest.csv'));
status = struct('Execution',"STARTED",'TestResult',"NOT_RUN",'ReferenceReplay',"NOT_RUN", ...
    'FixtureCheck',"NOT_RUN",'Parity',"NOT_RUN",'StepWindows',"NOT_RUN", ...
    'NegativeControls',"NOT_RUN",'InputFiles',"NOT_CHECKED", ...
    'EvidenceType',"SYNTHETIC_SOFTWARE_TEST_ONLY",'Plots',"NOT_RUN",'Message',"");
writeStatus(out,status);
fprintf('\nResults will be saved to:\n%s\n',out);
oldDir=pwd; oldPath=path;
g = Simulink.fileGenControl('getConfig');
oldGen = struct('CacheFolder',g.CacheFolder,'CodeGenFolder',g.CodeGenFolder, ...
    'CodeGenFolderStructure',g.CodeGenFolderStructure);
cleanup = onCleanup(@()restoreEnvironment(mdl,oldDir,oldPath,oldGen)); %#ok<NASGU>
SignalChecks=table(); EdgeChecks=table(); Summary=table(); Trace=table();

try
    cd(work); addpath(work,'-begin');
    clear mj1_ekf_step mj1_interp_params mj1_state_transition
    clear mj1_measurement mj1_F_jacobian mj1_H_jacobian
    rehash;
    for name=helpers.'
        assert(strcmpi(which(char(name)),fullfile(work,char(name+".m"))), ...
            'A frozen helper is shadowed: %s',name);
    end
    assert(strcmpi(which('mj1_v02_model.mat'),fullfile(work,'mj1_v02_model.mat')), ...
        'The compile-time model MAT is shadowed.');
    Simulink.fileGenControl('set','CacheFolder',fullfile(out,'cache'), ...
        'CodeGenFolder',fullfile(out,'codegen'),'createDir',true);

    %% 1. Reproduce one archived constant-current MATLAB run first.
    d=R.data;
    r0=runEKF(model,double(d.time_s(:)),double(d.current_A(:)), ...
        double(d.voltage_V(:)),double(R.z0(1)),cfg,"nominal");
    [pReplay,dr] = compareOutputs(r0,R.Runs{1},cfg,1:numel(d.time_s));
    ReferenceCheck=table(dr(1),dr(2),dr(3),pReplay,'VariableNames', ...
        {'SOC_Max_pp','Vpost_Max_mV','Innovation_Max_mV','Passed'});
    writetable(ReferenceCheck,fullfile(out,'reference_replay_check.csv'));
    assert(pReplay,'The archived MATLAB baseline did not reproduce.');
    status.ReferenceReplay="MATCHED_A8A_CORRECT_INIT";

    %% 2. Synthetic fixture: 9 successive 30 s plateaus, 8 transitions.
    t=(0:270)';
    levels=[0 -1.7 -3.4 0 1.7 0 -1.7 1.7 0]';
    block=min(floor(t/30)+1,numel(levels));
    I=levels(block);
    F=makeFixture(model,t,I,cfg.FixtureSOC0);
    edge=find(diff(I)~=0)+1;
    assert(numel(edge)==8 && I(1)==0 && all(diff(t)==1),'Fixture schedule mismatch.');
    assert(all(F.X(3,:)>model.socMin+0.02 & F.X(3,:)<model.socMax-0.02), ...
        'Fixture SOC is too close to a LUT boundary.');
    assert(all(F.V>2.5 & F.V<4.2),'Unexpected synthetic voltage range.');
    Fixture=table(t,I,F.V,F.Vclean,F.Perturbation,F.X(3,:)',F.X(1,:)',F.X(2,:)', ...
        ismember((1:numel(t))',edge),'VariableNames', ...
        {'Time_s','Current_A','VoltageInput_V','ForwardModelVoltage_V', ...
         'DeterministicVoltageTestSignal_V','FixtureSOC','FixtureV1_V', ...
         'FixtureV2_V','IsCurrentTransition'});
    writetable(Fixture,fullfile(out,'synthetic_input.csv'));
    Schedule=table((0:30:240)',(30:30:270)',levels,'VariableNames', ...
        {'StartInclusive_s','EndExclusive_s','Current_A'});
    writetable(Schedule,fullfile(out,'current_schedule.csv'));
    % Final t=270 sample holds the last value (0 A); no extrapolation.

    % Independently coded fixture vs existing model primitives.
    dx=0; dv=0; jumpError=0;
    for k=1:numel(t)
        dv=max(dv,abs(mj1_measurement(F.X(:,k),I(k),model)-F.Vclean(k)));
        if k>1
            xp=mj1_state_transition(F.X(:,k-1),I(k-1),1,model);
            dx=max(dx,max(abs(xp-F.X(:,k))));
        end
    end
    for k=edge.'
        % Instantaneous jump at the SAME state, not adjacent-sample delta V.
        p=lookup(model,F.X(3,k));
        observed=mj1_measurement(F.X(:,k),I(k),model) ...
            -mj1_measurement(F.X(:,k),I(k-1),model);
        jumpError=max(jumpError,abs(observed-p(2)*(I(k)-I(k-1))));
    end
    FixtureCheck=table(dx,dv,jumpError,dx<1e-10 && dv<1e-10 && jumpError<1e-10, ...
        'VariableNames',{'StateStepMax','VoltageMax_V','OhmicJumpMax_V','Passed'});
    writetable(FixtureCheck,fullfile(out,'fixture_implementation_check.csv'));
    assert(FixtureCheck.Passed,'Fixture/model primitive consistency failed.');
    status.FixtureCheck="PASS_FOR_DISCRETE_FIXTURE";

    %% 3. MATLAB reference runs, and timing-fault negative controls.
    cases=["correct_init";"minus20pp";"plus15pp"];
    z0=cfg.FixtureSOC0+[0;-0.20;0.15];
    assert(all(z0>model.socMin & z0<model.socMax),'Initial SOC out of range.');
    References=cell(3,1);
    for c=1:3
        References{c}=runEKF(model,t,I,F.V,z0(c),cfg,"nominal");
        assert(all(References{c}.X(3,:)>model.socMin+1e-4 ...
            & References{c}.X(3,:)<model.socMax-1e-4), ...
            'A nominal reference reached a SOC clamp; review before interpreting.');
    end
    [Negative,NegativeTrace]=negativeControls(model,t,I,F,cfg,References{1},edge);
    writetable(Negative,fullfile(out,'negative_control_summary.csv'));
    writetable(NegativeTrace,fullfile(out,'negative_control_trace.csv'));
    if all(Negative.MetExpectation)
        status.NegativeControls="EXPECTED_FAULT_BEHAVIOUR_CONFIRMED";
    else
        status.NegativeControls="SENSITIVITY_CHECK_FAILED";
    end
    save(fullfile(out,'step_reference.mat'),'model','cfg','cases','z0', ...
        't','I','F','References','edge','levels','-v7');
    writeStatus(out,status);

    %% 4. Load the separate SLX copy and preserve the observer/wiring.
    load_system(testSLX);
    assert(strcmp(get_param(mdl,'Solver'),'FixedStepDiscrete') ...
        && str2double(get_param(mdl,'FixedStep'))==1,'Unexpected saved solver.');
    observer=[mdl '/EKF_Observer'];
    sr=sfroot;
    ch=sr.find('-isa','Stateflow.EMChart','Path',observer);
    assert(numel(ch)==1,'Expected one EKF MATLAB Function block.');
    scriptBefore=ch.Script;
    assert(~isempty(regexp(scriptBefore,'dt\s*=\s*1\.0\s*;','once')), ...
        'Saved observer sample-time definition changed.');
    writeText(fullfile(out,'observer_source.txt'),string(scriptBefore));
    op=get_param(observer,'PortHandles');
    sourceBlocks={'Current_Input','Measured_Voltage','SOC_Init'};
    for k=1:3
        p=get_param([mdl '/' sourceBlocks{k}],'PortHandles');
        ln=get_param(op.Inport(k),'Line');
        assert(ln~=-1 && get_param(ln,'SrcPortHandle')==p.Outport(1), ...
            'Observer input wiring mismatch.');
    end
    assert(strcmp(get_param([mdl '/SOC_Init'],'Value'),'SOC0'),'SOC0 source changed.');
    inputBlocks={'Current_Input','Measured_Voltage','SOC_Reference'};
    varNames={'I_ts','Vmeas_ts','SOCref_ts'};
    for k=1:3
        b=[mdl '/' inputBlocks{k}];
        assert(strcmp(get_param(b,'VariableName'),varNames{k}) ...
            && strcmp(get_param(b,'Interpolate'),'off') ...
            && str2double(get_param(b,'SampleTime'))==1,'Input configuration changed.');
    end
    markSignal(observer,1,'Step_SOC');
    markSignal(observer,2,'Step_Vpost');
    markSignal(observer,3,'Step_Innovation');
    markSignal([mdl '/Current_Input'],1,'Step_Current');
    markSignal([mdl '/Measured_Voltage'],1,'Step_VoltageInput');
    set_param(mdl,'FastRestart','off','SignalLogging','on', ...
        'SignalLoggingName','Step_logs','ReturnWorkspaceOutputs','on');
    save_system(mdl,testSLX); % Instrumentation metadata in the test copy only.

    %% 5. Simulate each initial condition; compare without shifting samples.
    for c=1:3
        fprintf('\nSimulating synthetic steps: %s (SOC0=%.2f%%)\n',cases(c),100*z0(c));
        ref=References{c};
        vars=struct('I_ts',timeseries(I,t),'Vmeas_ts',timeseries(F.V,t), ...
            'SOCref_ts',timeseries(F.X(3,:)',t),'Ts',1,'StopTime',t(end), ...
            'SOC0',z0(c),'Qref_Ah',model.qRefAh,'SOC_bp',model.soc, ...
            'OCV_table',model.ocv,'R0_table',model.R0,'R1_table',model.R1, ...
            'C1_table',model.C1,'R2_table',model.R2,'C2_table',model.C2, ...
            'v1_0',ref.X(1,1),'v2_0',ref.X(2,1));
        in=Simulink.SimulationInput(mdl);
        vn=fieldnames(vars);
        for j=1:numel(vn)
            in=in.setVariable(vn{j},vars.(vn{j}),'Workspace',mdl);
        end
        in=in.setModelParameter('StartTime','0','StopTime',sprintf('%.17g',t(end)), ...
            'SimulationMode','normal','FastRestart','off','ReturnWorkspaceOutputs','on');
        simOut=sim(in);
        save(fullfile(out,['sim_' char(cases(c)) '.mat']),'simOut','-v7.3');
        logs=simOut.get('Step_logs');
        assert(isa(logs,'Simulink.SimulationData.Dataset'),'Missing output logs.');
        logNames={'Step_SOC','Step_Vpost','Step_Innovation','Step_Current','Step_VoltageInput'};
        E=[ref.X(3,:)',ref.Vpost,ref.Innovation,I,F.V];
        Y=zeros(numel(t),5);
        scale=[100 1000 1000 1 1000];
        units=["pp","mV","mV","A","mV"];
        tol=[cfg.SOCParityTolerance_pp,cfg.VoltageParityTolerance_mV, ...
             cfg.VoltageParityTolerance_mV,cfg.CurrentTolerance_A,cfg.InputVoltageTolerance_mV];
        edgeMask=false(size(t));
        for e=edge.'
            edgeMask=edgeMask | (t>=t(e)-cfg.EdgeBefore_s & t<=t(e)+cfg.EdgeAfter_s);
        end
        for j=1:5
            item=logs.getElement(logNames{j});
            [tj,y]=readTS(item.Values);
            assert(numel(tj)==numel(t),'Wrong logged sample count; no resampling permitted.');
            td=max(abs(tj-t));
            assert(td<=cfg.TimeTolerance_s,'Wrong timestamps; no alignment repair permitted.');
            Y(:,j)=y;
            err=scale(j)*(y-E(:,j));
            row=table(cases(c),string(logNames{j}),numel(t),td,max(abs(err)), ...
                sqrt(mean(err.^2)),abs(err(1)),max(abs(err(edgeMask))),tol(j),units(j), ...
                max(abs(err))<=tol(j),'VariableNames', ...
                {'InitialCase','Signal','Samples','TimeMaxDifference_s','MaxAbsDifference', ...
                 'RMSDifference','FirstSampleDifference','StepWindowMaxDifference', ...
                 'Tolerance','Unit','Passed'});
            SignalChecks=[SignalChecks;row]; %#ok<AGROW>
        end
        % Verify existing logging outputs also address the observer outputs.
        [tt,ys]=readTS(simOut.get('SOC_hat_sim'));
        assert(numel(tt)==numel(t) && max(abs(tt-t))<=cfg.TimeTolerance_s ...
            && max(abs(100*(ys-Y(:,1))))<=cfg.SOCParityTolerance_pp,'SOC output interface mismatch.');
        [tt,yv]=readTS(simOut.get('Vhat_EKF_sim'));
        assert(numel(tt)==numel(t) && max(abs(tt-t))<=cfg.TimeTolerance_s ...
            && max(abs(1000*(yv-Y(:,2))))<=cfg.VoltageParityTolerance_mV,'Vpost interface mismatch.');
        errs=[100*(Y(:,1)-E(:,1)),1000*(Y(:,2)-E(:,2)),1000*(Y(:,3)-E(:,3))];
        for e=edge.'
            w=t>=t(e)-cfg.EdgeBefore_s & t<=t(e)+cfg.EdgeAfter_s;
            mx=max(abs(errs(w,:)),[],1);
            row=table(cases(c),t(e),I(e-1),I(e),sum(w),mx(1),mx(2),mx(3), ...
                all(mx<=tol(1:3)),'VariableNames', ...
                {'InitialCase','StepTime_s','CurrentBefore_A','CurrentAfter_A','WindowSamples', ...
                 'SOC_Max_pp','Vpost_Max_mV','Innovation_Max_mV','Passed'});
            EdgeChecks=[EdgeChecks;row]; %#ok<AGROW>
        end
        clip=sum(Y(:,1)<=model.socMin+1e-10 | Y(:,1)>=model.socMax-1e-10);
        mx=max(abs(errs),[],1);
        pass=all(SignalChecks.Passed(SignalChecks.InitialCase==cases(c))) ...
            && all(EdgeChecks.Passed(EdgeChecks.InitialCase==cases(c))) && clip==0;
        row=table(cases(c),z0(c),numel(t),numel(edge),mx(1),mx(2),mx(3),clip,pass, ...
            'VariableNames',{'InitialCase','SOC0','Samples','StepEvents','SOC_MaxDifference_pp', ...
            'Vpost_MaxDifference_mV','Innovation_MaxDifference_mV','SOCClampSamples','Passed'});
        Summary=[Summary;row]; %#ok<AGROW>
        tr=table(repmat(cases(c),numel(t),1),t,I,F.V,F.X(3,:)', ...
            E(:,1),Y(:,1),E(:,2),Y(:,2),E(:,3),Y(:,3),Y(:,4),Y(:,5),edgeMask, ...
            'VariableNames',{'InitialCase','Time_s','Current_A','VoltageInput_V','FixtureSOC', ...
             'MATLAB_SOC','Simulink_SOC','MATLAB_Vpost','Simulink_Vpost', ...
             'MATLAB_Innovation','Simulink_Innovation','LoggedCurrent_A', ...
             'LoggedVoltageInput_V','IsInStepWindow'});
        Trace=[Trace;tr]; %#ok<AGROW>
        writetable(SignalChecks,fullfile(out,'signal_checks.csv'));
        writetable(EdgeChecks,fullfile(out,'step_window_checks.csv'));
        writetable(Summary,fullfile(out,'summary.csv'));
        writetable(Trace,fullfile(out,'parity_trace.csv'));
        fprintf('Max differences: SOC %.4g pp, Vpost %.4g mV, innovation %.4g mV\n',mx);
    end

    %% 6. Final identity checks and report.
    assert(strcmp(scriptBefore,ch.Script),'Observer algorithm text changed.');
    for k=1:8
        Sources.AfterSHA256(k)=sha256(Sources.Original(k));
        assert(Sources.AfterSHA256(k)==Sources.BeforeSHA256(k),'An audited source file changed.');
        if k<=7
            assert(sha256(Sources.SandboxCopy(k))==Sources.BeforeSHA256(k), ...
                'Frozen sandbox helper/model changed.');
        end
    end
    writetable(Sources,fullfile(out,'source_manifest.csv'));
    status.InputFiles="FROZEN_SOURCE_BYTES_UNCHANGED";
    if all(SignalChecks.Passed) && all(Summary.Passed)
        status.Parity="PASS_FOR_SYNTHETIC_1S_STEP_CASES";
    else
        status.Parity="NUMERICAL_MISMATCH_REVIEW_REQUIRED";
    end
    if all(EdgeChecks.Passed)
        status.StepWindows="ALL_STEP_WINDOWS_PASSED";
    else
        status.StepWindows="STEP_WINDOW_MISMATCH";
    end
    status.Execution="COMPLETED";
    if all(Summary.Passed) && all(EdgeChecks.Passed) && all(Negative.MetExpectation)
        status.TestResult="PASS_WITHIN_TEST_SCOPE";
    else
        status.TestResult="REVIEW_REQUIRED";
    end
    status.Message="No fitting, reindexing, first-sample removal or original-file edits.";
    writeText(fullfile(out,'README.txt'),[ ...
        "Synthetic current-step MATLAB/Simulink implementation test."; ...
        "This is software-only evidence, not HPPC or independent SOC validation."; ...
        "All cases use the same 271 input samples, 0:1:270 seconds, and 8 transitions."; ...
        "The final t=270 sample holds the final 0 A plateau."; ...
        "Fixture SOC starts at 0.55. Observer SOC starts at 0.55, 0.35, or 0.70."; ...
        "Input voltage is independently coded discrete frozen-LUT forward voltage"; ...
        "+ 0.001*sin(2*pi*t/47) + 0.0005*sin(2*pi*t/19) volts."; ...
        "That deterministic signal is not a measured or calibrated noise model."; ...
        "Both observers receive the same I and V. FixtureSOC is never an observer input."; ...
        "SOC0 is a constant initialization input, not a streamed SOC truth input."; ...
        "The first output is initialization only; no first-sample correction is made."; ...
        "Event windows include step-1 through step+5 seconds, inclusive."; ...
        "Global metrics and event maxima are both checked; no averaging hides an edge error."; ...
        "Negative controls use MATLAB-only call-argument substitutions, not edited production code."; ...
        "They test two selected timing faults, not exhaustive fault coverage."; ...
        "Internal RC states and full covariance parity are not logged in Simulink."; ...
        "The original published baseline and Git repository are not modified."; ...
        "Raw sim MATs and generated cache stay local; the review ZIP contains CSV evidence."; ...
        "A passing result does not establish hardware timing, variable-step support or deployment readiness."]);
    try
        plotOutputs(out,t,I,Trace,cases);
        status.Plots="SAVED";
    catch ME
        status.Plots="FAILED: "+string(ME.message);
        warning('StepParity:Plot','CSV files are saved; plot failure: %s',ME.message);
    end
    env=struct('MATLABVersion',version,'Release',version('-release'),'Computer',computer,'Products',ver);
    save(fullfile(out,'environment.mat'),'env','cfg');
    writeStatus(out,status);
    bundle=makeBundle(out,res,stamp);
    fprintf('\n===== SYNTHETIC STEP TEST COMPLETE =====\n');
    disp(Summary);
    disp(Negative);
    fprintf('Test result: %s\n',status.TestResult);
    fprintf('Parity: %s\nStep windows: %s\nNegative controls: %s\n', ...
        status.Parity,status.StepWindows,status.NegativeControls);
    fprintf('Evidence: SYNTHETIC_SOFTWARE_TEST_ONLY\nReview ZIP: %s\n',bundle);
catch ME
    status.Execution="STOPPED";
    status.TestResult="NOT_ESTABLISHED";
    status.Parity="NOT_ESTABLISHED";
    status.Message=string(ME.message);
    writeStatus(out,status);
    writeText(fullfile(out,'error.txt'),string(getReport(ME,'extended','hyperlinks','off')));
    try
        bundle=makeBundle(out,res,stamp);
        fprintf(2,'\nStopped; diagnostic ZIP: %s\n',bundle);
    catch
        fprintf(2,'\nStopped; diagnostic folder: %s\n',out);
    end
    rethrow(ME);
end
end

function F=makeFixture(m,t,I,z0)
% Separately coded synthetic forward calculation; no EKF helper calls.
N=numel(t); F.X=zeros(3,N); F.Vclean=zeros(N,1);
p=lookup(m,z0);
F.X(:,1)=[p(3)*I(1);p(5)*I(1);z0];
for k=1:N
    if k>1
        x=F.X(:,k-1); p=lookup(m,x(3)); dt=t(k)-t(k-1);
        a1=exp(-dt/(p(3)*p(4))); a2=exp(-dt/(p(5)*p(6)));
        F.X(:,k)=[a1*x(1)+p(3)*(1-a1)*I(k-1); ...
            a2*x(2)+p(5)*(1-a2)*I(k-1);x(3)+I(k-1)*dt/(3600*m.qRefAh)];
    end
    p=lookup(m,F.X(3,k));
    F.Vclean(k)=p(1)+sum(F.X(1:2,k))+p(2)*I(k);
end
F.Perturbation=0.001*sin(2*pi*t/47)+0.0005*sin(2*pi*t/19);
F.V=F.Vclean+F.Perturbation;
end

function p=lookup(m,z)
assert(z>=m.socMin && z<=m.socMax,'Synthetic forward model cannot extrapolate.');
names={'ocv','R0','R1','C1','R2','C2'}; p=zeros(1,6);
for j=1:6
    v=m.(names{j});
    p(j)=interp1(m.soc(:),v(:),z,'linear');
end
assert(all(isfinite(p)),'Invalid fixture lookup.');
end

function r=runEKF(m,t,I,V,z0,cfg,mode)
N=numel(t); r.X=zeros(3,N); r.Vpost=zeros(N,1); r.Innovation=zeros(N,1);
p=mj1_interp_params(m,z0); r.X(:,1)=[p.R1*I(1);p.R2*I(1);z0]; P=cfg.P0;
r.Vpost(1)=mj1_measurement(r.X(:,1),I(1),m);
r.Innovation(1)=V(1)-r.Vpost(1);
for k=2:N
    ip=I(k-1); im=I(k);
    if mode=="predict_uses_current_sample", ip=I(k); end
    if mode=="measurement_uses_previous_sample", im=I(k-1); end
    [r.X(:,k),P,r.Vpost(k),r.Innovation(k)]=mj1_ekf_step( ...
        r.X(:,k-1),P,ip,im,V(k),t(k)-t(k-1),m,cfg.Q,cfg.R);
    assert(all(isfinite(P(:))) && all(isfinite(r.X(:,k))),'Non-finite EKF state.');
end
assert(all(isfinite([r.Vpost;r.Innovation])),'Non-finite EKF output.');
end

function [T,Trace]=negativeControls(m,t,I,F,cfg,ref,edge)
T=table(); Trace=table();
faults=["predict_uses_current_sample";"measurement_uses_previous_sample"];
for profile=["Step" "Constant"]
    tt=t; ii=I; ff=F; rr=ref; ee=edge;
    if profile=="Constant"
        tt=(0:60)'; ii=-1.7*ones(size(tt));
        ff=makeFixture(m,tt,ii,cfg.FixtureSOC0);
        rr=runEKF(m,tt,ii,ff.V,cfg.FixtureSOC0,cfg,"nominal"); ee=[];
    end
    for fault=faults.'
        bad=runEKF(m,tt,ii,ff.V,cfg.FixtureSOC0,cfg,fault);
        [same,mx]=compareOutputs(bad,rr,cfg,1:numel(tt));
        count=0;
        for k=ee.'
            w=find(tt>=tt(k) & tt<=tt(k)+cfg.EdgeAfter_s);
            [indistinguishable,~]=compareOutputs(bad,rr,cfg,w);
            count=count+double(~indistinguishable);
        end
        if profile=="Step"
            before=find(tt<tt(ee(1)));
            [preSame,~]=compareOutputs(bad,rr,cfg,before);
            expectation=~same && count==numel(ee) && preSame;
        else
            preSame=same; expectation=same;
        end
        row=table(profile,fault,mx(1),mx(2),mx(3),numel(ee),count,preSame,expectation, ...
            'VariableNames',{'Profile','DeliberateFault','SOC_MaxDifference_pp', ...
            'Vpost_MaxDifference_mV','Innovation_MaxDifference_mV','StepEvents', ...
            'EventsDetectingFault','NoUnexpectedPreStepDifference','MetExpectation'});
        T=[T;row]; %#ok<AGROW>
        tr=table(repmat(profile,numel(tt),1),repmat(fault,numel(tt),1),tt,ii, ...
            100*(bad.X(3,:)'-rr.X(3,:)'),1000*(bad.Vpost-rr.Vpost), ...
            1000*(bad.Innovation-rr.Innovation),'VariableNames', ...
            {'Profile','DeliberateFault','Time_s','Current_A','SOC_Difference_pp', ...
            'Vpost_Difference_mV','Innovation_Difference_mV'});
        Trace=[Trace;tr]; %#ok<AGROW>
    end
end
end

function [pass,mx]=compareOutputs(a,b,cfg,ix)
x=[100*(a.X(3,ix)'-b.X(3,ix)'),1000*(a.Vpost(ix)-b.Vpost(ix)), ...
    1000*(a.Innovation(ix)-b.Innovation(ix))];
mx=max(abs(x),[],1);
pass=all(mx<=[cfg.SOCParityTolerance_pp cfg.VoltageParityTolerance_mV cfg.VoltageParityTolerance_mV]);
end

function markSignal(block,port,name)
p=get_param(block,'PortHandles');
set_param(p.Outport(port),'DataLogging','on','DataLoggingNameMode','Custom', ...
    'DataLoggingName',name,'DataLoggingDecimateData','off','DataLoggingLimitDataPoints','off');
end

function [t,y]=readTS(ts)
assert(isa(ts,'timeseries'),'Expected scalar timeseries output.');
t=double(ts.Time(:)); y=double(ts.Data(:));
assert(numel(t)==numel(y) && all(isfinite([t;y])) && all(diff(t)>0), ...
    'Invalid log: repeated times, vector signal, or non-finite values.');
end

function verifySnapshot(file,role,T)
assert(isfile(file),'Missing snapshot: %s',file);
[~,n,e]=fileparts(file); names=strings(height(T),1);
for j=1:height(T)
    ss=regexp(char(string(T.Source(j))),'[\\/]','split'); names(j)=string(ss{end});
end
ix=names==(string(n)+string(e)) & string(T.Role)==role;
assert(nnz(ix)==1 && sha256(file)==string(T.SnapshotSHA256(ix)), ...
    'Snapshot fingerprint mismatch: %s',file);
end

function validateModel(m)
names={'soc','ocv','R0','R1','C1','R2','C2','qRefAh','socMin','socMax'};
for j=1:numel(names), assert(isfield(m,names{j}),'Model field missing.'); end
bp=double(m.soc(:));
assert(numel(bp)>=2 && all(isfinite(bp)) && all(diff(bp)>0),'Invalid SOC breakpoints.');
assert(isscalar(m.qRefAh) && isfinite(m.qRefAh) && m.qRefAh>0,'Invalid Qref.');
assert(m.socMin>=bp(1) && m.socMax<=bp(end) && m.socMin<m.socMax,'Invalid SOC limits.');
for j=2:7
    a=double(m.(names{j}));
    assert(numel(a)==numel(bp) && all(isfinite(a(:))),'Invalid LUT length/value.');
    if j>=3, assert(all(a(:)>0),'R/C values must be positive.'); end
end
end

function h=sha256(file)
fid=fopen(file,'rb'); assert(fid>=0,'Cannot hash file: %s',file);
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
md=javaMethod('getInstance','java.security.MessageDigest','SHA-256');
while true
    b=fread(fid,1048576,'*uint8'); if isempty(b), break; end
    md.update(typecast(b,'int8'));
end
b=typecast(md.digest(),'uint8');
h=string(lower(reshape(dec2hex(b,2).',1,[])));
end

function writeStatus(folder,s)
writetable(struct2table(s),fullfile(folder,'status.csv'));
end

function writeText(file,s)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0,'Cannot write report.');
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
for line=string(s(:)).', fprintf(fid,'%s\n',line); end
end

function bundle=makeBundle(out,res,stamp)
% Exclude compiler caches and large raw Simulink output MATs.
files=dir(fullfile(out,'*')); include={};
for k=1:numel(files)
    if files(k).isdir || startsWith(files(k).name,'sim_'), continue; end
    include{end+1}=files(k).name; %#ok<AGROW>
end
bundle=fullfile(res,['StepParity_' stamp '_review.zip']);
zip(bundle,include,out);
end

function plotOutputs(out,t,I,T,cases)
fig=figure('Name','Synthetic current step input','Position',[100 100 1100 420]);
stairs(t,I,'LineWidth',1.2); grid on;
xlabel('Time [s]'); ylabel('Synthetic current [A]');
title('Synthetic 1 s step/reversal input - not measured HPPC');
set(fig,'PaperPositionMode','auto'); drawnow;
print(fig,fullfile(out,'step_current.png'),'-dpng','-r200');
fig=figure('Name','Innovation parity error','Position',[100 100 1100 420]);
hold on;
for c=1:numel(cases)
    G=T(T.InitialCase==cases(c),:);
    plot(G.Time_s,1000*(G.Simulink_Innovation-G.MATLAB_Innovation),'LineWidth',1);
end
grid on; xlabel('Time [s]'); ylabel('Simulink - MATLAB innovation [mV]');
title('Synthetic step test - innovation parity error');
legend(strrep(cases,'_',' '),'Location','best');
set(fig,'PaperPositionMode','auto'); drawnow;
print(fig,fullfile(out,'innovation_parity_error.png'),'-dpng','-r200');
end

function restoreEnvironment(mdl,folder,p,gen)
try
    if bdIsLoaded(mdl), close_system(mdl,0); end
catch ME
    warning('StepParity:Cleanup','Could not close test copy: %s',ME.message);
end
cd(folder);
try
    Simulink.fileGenControl('set','CacheFolder',gen.CacheFolder, ...
        'CodeGenFolder',gen.CodeGenFolder,'CodeGenFolderStructure',gen.CodeGenFolderStructure);
catch ME
    warning('StepParity:Cleanup','Could not restore cache settings: %s',ME.message);
end
path(p);
clear mj1_ekf_step mj1_interp_params mj1_state_transition
clear mj1_measurement mj1_F_jacobian mj1_H_jacobian
end
