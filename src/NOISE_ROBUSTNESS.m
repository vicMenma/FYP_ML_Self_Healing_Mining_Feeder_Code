%% ========================================================================
%  NOISE_ROBUSTNESS.m
%  Reviewer robustness test #6: how does the trained classifier hold up when
%  the (ideal) simulated measurements are corrupted by realistic measurement
%  error? No new simulations are required — Gaussian measurement error is
%  added to the EXISTING held-out test features and the EXISTING trained model
%  (rf_model_v2.mat) is re-evaluated. Runs in seconds.
%
%  Noise model: multiplicative per-reading Gaussian error, i.e. each RMS
%  feature x -> x*(1 + e), e ~ N(0, sigma^2), with sigma = p% of the reading.
%  This matches how instrument-transformer (CT/VT) accuracy is specified
%  (percentage of reading, e.g. class 0.5 = 0.5%).
%
%  Output: table + outputs_v2_topology/summaries/noise_robustness_v2.{txt,csv}
%          + figure outputs_v2_topology/figures/.../noise_robustness.png
%  Run from the scripts/ folder.
%% ========================================================================
clc; close all;

% ---- load dataset + trained model ----
S  = load(local_find('fault_dataset_v2.mat')); X = S.X; y = S.y(:);
M  = load(local_find('rf_model_v2.mat'));      rf = M.rf;
fprintf('Loaded %d samples x %d features and the trained RF.\n', size(X,1), size(X,2));

% ---- reproduce MASTER_B's exact held-out test set ----
rng(42); cv = cvpartition(y,'HoldOut',0.20);
Xte = X(test(cv),:); yte = y(test(cv));
nFault = sum(yte ~= 0);

% ---- sweep measurement-error levels ----
LEVELS = [0 0.5 1 2 5 10];     % percent per-reading Gaussian error
REPS   = 100;                  % Monte-Carlo repetitions per level
rng(7);                        % reproducible noise draws

acc_mean = zeros(size(LEVELS)); acc_min = zeros(size(LEVELS));
rec_mean = zeros(size(LEVELS)); miss_mean = zeros(size(LEVELS));
for li = 1:numel(LEVELS)
    p = LEVELS(li)/100;
    a = zeros(REPS,1); r = zeros(REPS,1); m = zeros(REPS,1);
    for k = 1:REPS
        if p == 0
            Xn = Xte;
        else
            Xn = Xte .* (1 + p*randn(size(Xte)));
        end
        yh = str2double(predict(rf, Xn));
        a(k) = mean(yh == yte);
        m(k) = sum((yte~=0) & (yh==0));         % missed faults
        r(k) = 1 - m(k)/max(nFault,1);          % fault-detection rate
        if p == 0; a(:)=a(k); m(:)=m(k); r(:)=r(k); break; end
    end
    acc_mean(li)=mean(a); acc_min(li)=min(a); rec_mean(li)=mean(r); miss_mean(li)=mean(m);
end

% ---- report ----
hdr = sprintf('%-14s %12s %12s %14s %14s','Error (%)','Mean acc','Worst acc','Fault recall','Missed faults');
L = {'MEASUREMENT-NOISE ROBUSTNESS', sprintf('Generated: %s',datestr(now)), '', ...
     sprintf('Held-out test set: %d samples (%d fault). %d Monte-Carlo reps per level.',numel(yte),nFault,REPS), ...
     'Noise: multiplicative per-reading Gaussian, sigma = stated %% of each RMS reading.', '', hdr, repmat('-',1,length(hdr))};
for li=1:numel(LEVELS)
    L{end+1}=sprintf('%-14.1f %11.2f%% %11.2f%% %13.1f%% %14.2f', ...
        LEVELS(li), acc_mean(li)*100, acc_min(li)*100, rec_mean(li)*100, miss_mean(li)); %#ok<SAGROW>
end
txt = strjoin(L,char(10)); disp(' '); disp(txt);

outdir = fullfile('outputs_v2_topology','summaries'); if ~exist(outdir,'dir'); outdir=pwd; end
fid=fopen(fullfile(outdir,'noise_robustness_v2.txt'),'w'); fprintf(fid,'%s\n',txt); fclose(fid);
T = table(LEVELS(:), acc_mean(:), acc_min(:), rec_mean(:), miss_mean(:), ...
    'VariableNames',{'ErrorPct','MeanAccuracy','WorstAccuracy','FaultRecall','MeanMissedFaults'});
writetable(T, fullfile(outdir,'noise_robustness_v2.csv'));

% ---- figure ----
figdir = fullfile('outputs_v2_topology','figures','thesis_rewrite','chapter_5');
if ~exist(figdir,'dir'); figdir = pwd; end
f=figure('Visible','off','Position',[60 60 720 420],'Color','w'); hold on; grid on; box on;
plot(LEVELS, acc_mean*100,'-o','LineWidth',1.6,'MarkerFaceColor','w');
plot(LEVELS, acc_min*100, '--s','LineWidth',1.1);
yline(95,'r:','95% target');
xlabel('Measurement error, \sigma (% of reading)'); ylabel('Test-set accuracy (%)');
ylim([min(80,floor(min(acc_min*100)/5)*5) 101]);
legend({'Mean accuracy','Worst-case accuracy','95% target'},'Location','southwest');
title('Classifier robustness to measurement noise');
exportgraphics(f, fullfile(figdir,'Figure_5_10b_noise_robustness.png'),'Resolution',200); close(f);
fprintf('\nSaved: %s\n      %s\n', fullfile(outdir,'noise_robustness_v2.txt'), ...
    fullfile(figdir,'Figure_5_10b_noise_robustness.png'));

% ======================================================================
function p = local_find(name)
    c = {fullfile('outputs_v2_topology',name), name, fullfile('outputs','dataset',name), ...
         fullfile('outputs','model',name)};
    p = '';
    for i=1:numel(c); if exist(c{i},'file'); p=c{i}; return; end; end
    error('%s not found — run from the scripts/ folder.', name);
end
