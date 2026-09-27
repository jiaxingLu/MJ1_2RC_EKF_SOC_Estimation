%% ============================================================
% MJ1 2RC-EKF validation summary and convergence plots
%% ============================================================

projectRoot = ...
    'C:\Users\louis\Downloads\MJ1_MATLAB_EKF_v02_package\MJ1_MATLAB_EKF_v02';

resultsDir = fullfile(projectRoot,'results');

%% ============================================================
% 1. Combine metric tables
%% ============================================================

T_correct = readtable( ...
    fullfile(resultsDir,'EKF_metrics_correct_init.csv'));

T_minus20 = readtable( ...
    fullfile(resultsDir,'EKF_metrics_minus20pp.csv'));

T_plus15 = readtable( ...
    fullfile(resultsDir,'EKF_metrics_plus15pp.csv'));

summaryTable = [
    T_correct;
    T_minus20;
    T_plus15
];

writetable(summaryTable, ...
    fullfile(resultsDir,'EKF_validation_summary.csv'));

fprintf('\n=== EKF Validation Summary ===\n');
disp(summaryTable);

fprintf('Saved:\n%s\n', ...
    fullfile(resultsDir,'EKF_validation_summary.csv'));


%% ============================================================
% 2. Generate SOC convergence plots
%% ============================================================

caseNames = { ...
    'correct_init', ...
    'minus20pp', ...
    'plus15pp'};

traceFiles = { ...
    'EKF_trace_correct_init.csv', ...
    'EKF_trace_minus20pp.csv', ...
    'EKF_trace_plus15pp.csv'};

for i = 1:numel(caseNames)

    caseName = caseNames{i};

    T = readtable( ...
        fullfile(resultsDir,traceFiles{i}));

    t = T.time_s;

    SOC_ref = T.SOC_ref;
    SOC_hat = T.SOC_hat;

    soc_error_pp = ...
        (SOC_hat - SOC_ref)*100;

    %% Figure
    fig = figure;

    tiledlayout(2,1);

    % ----------------------------------------------------------
    % SOC trajectories
    % ----------------------------------------------------------
    nexttile;

    plot(t,SOC_ref*100,'LineWidth',1.4);
    hold on;

    plot(t,SOC_hat*100,'LineWidth',1.4);

    grid on;

    xlabel('Time (s)');
    ylabel('SOC (%)');

    legend( ...
        'SOC reference', ...
        'EKF estimate', ...
        'Location','best');

    title( ...
        ['MJ1 2RC-EKF SOC estimation — ', ...
        strrep(caseName,'_',' ')]);


    % ----------------------------------------------------------
    % Estimation error
    % ----------------------------------------------------------
    nexttile;

    plot(t,soc_error_pp,'LineWidth',1.4);
    hold on;

    yline(0,'--');

    grid on;

    xlabel('Time (s)');
    ylabel('SOC error (pp)');

    title('SOC estimation error');


    %% Save PNG for GitHub
    pngName = sprintf( ...
        'SOC_convergence_%s.png', ...
        caseName);

    exportgraphics( ...
        fig, ...
        fullfile(resultsDir,pngName), ...
        'Resolution',300);


    %% Save vector PDF for reports / papers
    pdfName = sprintf( ...
        'SOC_convergence_%s.pdf', ...
        caseName);

    exportgraphics( ...
        fig, ...
        fullfile(resultsDir,pdfName), ...
        'ContentType','vector');

end

fprintf('\nAll EKF validation plots generated successfully.\n');