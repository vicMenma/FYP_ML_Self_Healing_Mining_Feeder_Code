%% ========================================================================
%  ABLATION_COST_SENSITIVITY.m
%  Research-Question-2 ablation: does the 12.5x cost matrix actually change
%  the missed-fault outcome, or is the dataset already so separable that a
%  STANDARD Random Forest gives the same zero-missed-fault result?
%
%  Uses the EXISTING dataset (no re-simulation). Reproduces MASTER_B's exact
%  stratified 80/20 split (rng 42 + cvpartition HoldOut 0.20) and trains two
%  500-tree forests on the SAME training data with the SAME bootstrap seed,
%  the only difference being the Cost argument.
%
%  Output: prints an ablation table and writes
%     outputs_v2_topology/summaries/ablation_cost_sensitivity_v2.{txt,csv}
%
%  Run from the scripts/ folder (same folder as MASTER_B).
%% ========================================================================
clc; close all;

% ---- locate and load the dataset ----
cand = {fullfile('outputs_v2_topology','fault_dataset_v2.mat'), ...
        'fault_dataset_v2.mat', ...
        fullfile('outputs','dataset','fault_dataset_v2.mat')};
dsfile = '';
for i = 1:numel(cand); if exist(cand{i},'file'); dsfile = cand{i}; break; end; end
assert(~isempty(dsfile), 'fault_dataset_v2.mat not found — run this from the scripts/ folder.');
S = load(dsfile);
X = S.X; y = S.y(:);
fprintf('Loaded %s  (%d samples x %d features, %d classes)\n', dsfile, size(X,1), size(X,2), numel(unique(y)));

% ---- reproduce MASTER_B's exact split ----
rng(42);                              % same seed as MASTER_B line 32
cv  = cvpartition(y,'HoldOut',0.20);  % same call as MASTER_B line 70
Xtr = X(training(cv),:); ytr = y(training(cv));
Xte = X(test(cv),:);     yte = y(test(cv));
classes = 0:12;

% ---- cost matrix (identical to MASTER_B) ----
K = 13; C = ones(K) - eye(K); C(2:13,1) = 12.5;

% ---- train both forests on identical data + identical bootstrap seed ----
SEED = 100;   % fixed so the ONLY difference between the two models is Cost
rng(SEED);
rf_std  = TreeBagger(500, Xtr, ytr, 'Method','classification');            % NO cost
rng(SEED);
rf_cost = TreeBagger(500, Xtr, ytr, 'Method','classification','Cost',C);   % cost-sensitive

% ---- evaluate ----
res    = eval_cfg('Standard RF (no cost)',      rf_std,  Xte, yte, classes);
res(2) = eval_cfg('Cost-sensitive RF (12.5x)',  rf_cost, Xte, yte, classes);

% ---- print + save ----
nFaultTest = sum(yte ~= 0);
hdr = sprintf('%-28s %10s %13s %13s %13s', 'Configuration','Accuracy','Fault recall','Missed faults','False alarms');
lines = {'RESEARCH-QUESTION-2 ABLATION — cost sensitivity', ...
         sprintf('Generated: %s', datestr(now)), '', ...
         sprintf('Test set: %d samples (%d fault, %d healthy). Same split as MASTER_B (rng 42).', ...
                 numel(yte), nFaultTest, sum(yte==0)), '', hdr, repmat('-',1,length(hdr))};
for k = 1:2
    lines{end+1} = sprintf('%-28s %9.2f%% %12d%% %13d %13d', ...
        res(k).name, res(k).acc*100, round(res(k).faultRecall*100), res(k).missed, res(k).falseAlarm); %#ok<AGROW>
end
lines{end+1} = '';
if res(1).missed == res(2).missed
    lines{end+1} = sprintf(['INTERPRETATION: both models produce %d missed faults, so on this dataset the ' ...
        'cost matrix does not change the missed-fault outcome. The zero-missed-fault result reflects the ' ...
        'high separability of the corrected near-bolted classes; the cost matrix is a safety-oriented design ' ...
        'choice whose effect would only become material for a harder (e.g. NER-limited) problem.'], res(1).missed);
else
    lines{end+1} = sprintf(['INTERPRETATION: the cost-sensitive model reduces missed faults from %d to %d, ' ...
        'so cost sensitivity measurably improves fault recall on this dataset.'], res(1).missed, res(2).missed);
end

txt = strjoin(lines, char(10));
disp(' '); disp(txt);

outdir = fullfile('outputs_v2_topology','summaries');
if ~exist(outdir,'dir'); outdir = pwd; end
fid = fopen(fullfile(outdir,'ablation_cost_sensitivity_v2.txt'),'w');
fprintf(fid,'%s\n',txt); fclose(fid);

T = table({res.name}', [res.acc]', [res.faultRecall]', [res.missed]', [res.falseAlarm]', ...
    'VariableNames', {'Configuration','Accuracy','FaultRecall','MissedFaults','FalseAlarms'});
writetable(T, fullfile(outdir,'ablation_cost_sensitivity_v2.csv'));
fprintf('\nSaved: %s\n', fullfile(outdir,'ablation_cost_sensitivity_v2.txt'));

% ======================================================================
function r = eval_cfg(name, mdl, Xte, yte, classes)
    yhat = str2double(predict(mdl, Xte));
    r.name       = name;
    r.acc        = mean(yhat == yte);
    faultIdx     = (yte ~= 0);
    r.missed     = sum(faultIdx & (yhat == 0));          % fault predicted Healthy
    r.faultRecall= 1 - r.missed / max(sum(faultIdx),1);  % fraction of faults flagged as a fault
    r.falseAlarm = sum((yte == 0) & (yhat ~= 0));         % Healthy predicted as fault
end
