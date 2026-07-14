%% ========================================================================
%  BASELINE_RULE_VS_RF.m
%  Addresses the "is machine learning necessary?" question by comparing the
%  trained Random Forest against two much simpler baselines on the SAME
%  held-out test set (no re-simulation):
%    (a) a max current-ratio ZONE detector:  zone = argmax_k ( I_k / I_k,healthy ),
%        declared Healthy if the largest ratio is below a threshold;
%    (b) a single (unpruned) decision tree for the full 13-class problem.
%  Output: table + outputs_v2_topology/summaries/baseline_rule_vs_rf_v2.{txt,csv}
%  Run from the scripts/ folder.
%% ========================================================================
clc;
cand = {fullfile('outputs_v2_topology','fault_dataset_v2.mat'),'fault_dataset_v2.mat', ...
        fullfile('outputs','dataset','fault_dataset_v2.mat')};
S=[]; for i=1:numel(cand); if exist(cand{i},'file'); S=load(cand{i}); break; end; end
assert(~isempty(S),'fault_dataset_v2.mat not found — run this from the scripts/ folder.');
X = S.X; y = S.y(:);
Mm = load(local_find('rf_model_v2.mat')); rf = Mm.rf;

rng(42); cv = cvpartition(y,'HoldOut',0.20);
Xtr=X(training(cv),:); ytr=y(training(cv)); Xte=X(test(cv),:); yte=y(test(cv));
zoneof = @(c) (c>0).*(floor((max(c,0)-1)/3)+1);   % 0 Healthy, 1..4 = B2..B5
ztrue  = arrayfun(zoneof, yte);

% ---- (0) Random Forest ----
yrf   = str2double(predict(rf, Xte));
accRF = mean(yrf==yte);
zaccRF= mean(arrayfun(zoneof,yrf)==ztrue);

% ---- (a) max current-ratio zone rule ----
Iidx = {4:6, 10:12, 16:18, 22:24};        % 3-phase current columns per zone B2..B5
h = (ytr==0); base = zeros(1,4);
for k=1:4; base(k) = mean(mean(Xtr(h,Iidx{k}),2)); end
THRESH = 3;                                % ratio above which a zone is "faulted"
zrule = zeros(numel(yte),1);
for i=1:numel(yte)
    r = zeros(1,4);
    for k=1:4; r(k) = mean(Xte(i,Iidx{k})) / max(base(k),1); end
    [mx,km] = max(r);
    if mx < THRESH; zrule(i) = 0; else; zrule(i) = km; end
end
zaccRule = mean(zrule==ztrue);

% ---- (b) single decision tree (full 13-class) ----
tree   = fitctree(Xtr, ytr);
ytree  = predict(tree, Xte);
accTree = mean(ytree==yte);
zaccTree= mean(arrayfun(zoneof,ytree)==ztrue);
nSplits = sum(tree.IsBranchNode);

% ---- report ----
L = {'RULE-BASED BASELINE vs RANDOM FOREST', sprintf('Generated: %s',datestr(now)), '', ...
 sprintf('Held-out test set: %d samples (%d fault, %d healthy). Same split as MASTER_B (rng 42).', ...
         numel(yte), sum(yte~=0), sum(yte==0)), '', ...
 sprintf('%-30s %14s %16s %s','Method','Zone accuracy','Full 13-class','Interpretability'), ...
 repmat('-',1,78), ...
 sprintf('%-30s %13.2f%% %15s   High (one threshold)','Max current-ratio rule', 100*zaccRule, 'n/a (magnitude)'), ...
 sprintf('%-30s %13.2f%% %14.2f%%   High (%d splits)','Single decision tree', 100*zaccTree, 100*accTree, nSplits), ...
 sprintf('%-30s %13.2f%% %14.2f%%   Moderate (500 trees)','Random Forest (this work)', 100*zaccRF, 100*accRF), '', ...
 'INTERPRETATION: on this highly separable dataset the zone localisation that', ...
 'drives the switching action is achievable with a trivial current-ratio rule,', ...
 'and the full 13-class classification with a single decision tree; the Random', ...
 'Forest is not strictly necessary here. Its ensemble robustness (graceful noise', ...
 'degradation, off-grid generalisation) would become material only for the harder,', ...
 'less separable regimes (NER-limited earth faults, noisy/missing measurements).'};
txt = strjoin(L, char(10)); disp(' '); disp(txt);

outdir=''; for od={fullfile('outputs_v2_topology','summaries'),fullfile('outputs','summaries')}
    if exist(od{1},'dir'); outdir=od{1}; break; end; end
if isempty(outdir); outdir=pwd; end
fid=fopen(fullfile(outdir,'baseline_rule_vs_rf_v2.txt'),'w'); fprintf(fid,'%s\n',txt); fclose(fid);
T = table({'Max current-ratio rule';'Single decision tree';'Random Forest (this work)'}, ...
    [zaccRule; zaccTree; zaccRF], [NaN; accTree; accRF], ...
    'VariableNames',{'Method','ZoneAccuracy','FullClassAccuracy'});
writetable(T, fullfile(outdir,'baseline_rule_vs_rf_v2.csv'));
fprintf('\nSaved: %s\n', fullfile(outdir,'baseline_rule_vs_rf_v2.txt'));

function p=local_find(n); c={fullfile('outputs_v2_topology',n),n,fullfile('outputs','model',n), ...
        fullfile('outputs','dataset',n)}; p='';
    for i=1:numel(c); if exist(c{i},'file'); p=c{i}; return; end; end; error('%s not found',n); end
