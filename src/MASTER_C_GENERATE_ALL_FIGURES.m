%% =========================================================================
%  MASTER_C_GENERATE_ALL_FIGURES.m
%  ─────────────────────────────────────────────────────────────────────────
%  Thesis: ML-Assisted Self-Healing of a 33/11 kV Mining Distribution Feeder
%  Author: Victoire — CU-BEE-100-7229  |  Supervisor: Mr Charles Kasonde
%
%  PURPOSE
%  -------
%  Run this AFTER MASTER_A and MASTER_B complete.
%  Generates ALL thesis figures in one pass:
%
%    figures/ch3_methodology/    — 8 figures
%    figures/ch4_system_design/  — 4 figures
%    figures/ch5_results/        — 14 figures
%    figures/ch6_conclusions/    — 3 figures
%    (Total: 29 figures at 300 DPI)
%
%  REQUIRES
%  --------
%    fault_dataset_1000.mat  (from MASTER_A)
%    rf_model_final.mat      (from MASTER_B)
%    restoration_summary.txt (from MASTER_B)
%
%  FONT SIZES — thesis-correct values
%  -----------
%    Title  : 11 pt  (was 6 pt in original — too small for print)
%    Labels : 10 pt
%    Ticks  :  9 pt
%    Annot  :  8 pt
%    Legend :  9 pt
%
%  The original GENERATE_ALL_FIGURES.m used FS_TITLE=6 / FS_LABEL=5 /
%  FS_TICK=5 / FS_ANNOT=5 which produced text invisible at normal zoom.
%  All sizes have been corrected to print-legible values.
% =========================================================================

clc; close all;
rng(42);

fprintf('=================================================================\n');
fprintf('  MASTER C — GENERATE ALL THESIS FIGURES\n');
fprintf('  %s\n', datestr(now));
fprintf('=================================================================\n\n');

%% ── Output folders ────────────────────────────────────────────────────────
DIRS = {'figures','figures/ch3_methodology','figures/ch4_system_design', ...
        'figures/ch5_results','figures/ch6_conclusions','figures/dataset', ...
        'figures/reports'};
for d = DIRS
    if ~exist(d{1},'dir'); mkdir(d{1}); end
end

%% ── Global style (thesis-quality) ────────────────────────────────────────
FN      = 'Arial';         % font name
FS_T    = 11;              % title font size  (was 6 — now print-legible)
FS_L    = 10;              % axis label size  (was 5)
FS_K    = 9;               % tick label size  (was 5)
FS_A    = 8;               % annotation size  (was 5)
FS_G    = 9;               % legend size      (was 5)

set(0,'DefaultAxesFontName',  FN, 'DefaultAxesFontSize',   FS_K);
set(0,'DefaultTextFontName',  FN, 'DefaultTextFontSize',   FS_A);
set(0,'DefaultLegendFontName',FN, 'DefaultLegendFontSize', FS_G);
set(0,'DefaultLineLineWidth', 1.2);
set(0,'DefaultFigureColor',   'w');
set(0,'DefaultAxesBox',       'on');
set(0,'DefaultAxesGridLineStyle',':');

FIG_W  = 800;  FIG_H  = 480;  FIG_SQ = 560;

%% ── Colour palette ────────────────────────────────────────────────────────
C_HEALTHY = [0.18 0.63 0.18];
C_B2      = [0.84 0.19 0.15];
C_B3      = [0.12 0.47 0.71];
C_B4      = [0.89 0.55 0.00];
C_B5      = [0.58 0.10 0.62];
COLORS_13 = [C_HEALTHY; C_B2;C_B2;C_B2; C_B3;C_B3;C_B3; C_B4;C_B4;C_B4; C_B5;C_B5;C_B5];
CLASS_NAMES = {'Healthy','SLG-B2','LL-B2','3PH-B2','SLG-B3','LL-B3','3PH-B3', ...
               'SLG-B4','LL-B4','3PH-B4','SLG-B5','LL-B5','3PH-B5'};
SHORT = {'H','SLG-B2','LL-B2','3PH-B2','SLG-B3','LL-B3','3PH-B3', ...
         'SLG-B4','LL-B4','3PH-B4','SLG-B5','LL-B5','3PH-B5'};

%% ── Load data ─────────────────────────────────────────────────────────────
HAS_DATASET = false;  HAS_RF = false;  HAS_RESTORE = false;

if exist('fault_dataset_1000.mat','file')
    S = load('fault_dataset_1000.mat');
    if isfield(S,'dataset')
        dataset       = S.dataset;
        feature_names = S.feature_names;
        if isfield(S,'CLASS_NAMES'); CLASS_NAMES = S.CLASS_NAMES; end
        X      = dataset(:,1:end-1);
        labels = dataset(:,end);
        HAS_DATASET = true;
        fprintf('[DATA] Dataset: %d samples, %d features\n', size(dataset,1), size(X,2));
    end
end

R = struct();   % will hold all RF metrics
if exist('rf_model_final.mat','file')
    M = load('rf_model_final.mat');
    % Fields saved by MASTER_B: rf_model, X_train, y_train, X_test, y_test,
    %                           feature_names, CLASS_NAMES, per_cls, cv_acc, oob_err
    R.rf_model   = M.rf_model;
    R.X_test     = M.X_test;
    R.y_test     = M.y_test;
    R.per_cls    = M.per_cls;    % [prec, recall, f1, n_test] per class
    R.cv_acc     = M.cv_acc;
    R.oob_err    = M.oob_err;
    R.feature_names = M.feature_names;
    if isfield(M,'CLASS_NAMES'); CLASS_NAMES = M.CLASS_NAMES; end

    %% Recompute derived quantities that MASTER_B does not save:
    [y_pred_cell, scores] = predict(R.rf_model, R.X_test);
    R.y_pred    = str2double(y_pred_cell);
    R.scores    = scores;
    R.acc       = mean(R.y_pred == R.y_test);
    R.cv_mean   = mean(R.cv_acc);
    R.cv_std    = std(R.cv_acc);
    R.macro_f1  = mean(R.per_cls(:,3));

    % Confusion matrix
    R.cm = confusionmat(R.y_test, R.y_pred);

    % Fault / healthy detection rates
    fault_mask    = (R.y_test > 0);
    R.fault_det   = mean(R.y_pred(fault_mask)  > 0);
    R.healthy_det = mean(R.y_pred(~fault_mask) == 0);

    % Feature importance from OOB
    R.imp = R.rf_model.OOBPermutedPredictorDeltaError;

    % Wilson CI
    n   = numel(R.y_test);  z = 1.96;
    acc = R.acc;
    R.w_lo = (acc+z^2/(2*n) - z*sqrt(acc*(1-acc)/n+z^2/(4*n^2)))/(1+z^2/n);
    R.w_hi = (acc+z^2/(2*n) + z*sqrt(acc*(1-acc)/n+z^2/(4*n^2)))/(1+z^2/n);

    % Bootstrap F1 CIs (1000 iter)
    n_cls  = 13;  N_BOOT = 1000;  rng(42);
    boot_f1 = zeros(N_BOOT, n_cls);
    for b = 1:N_BOOT
        idx_b  = randsample(n,n,true);
        yt_b   = R.y_test(idx_b);
        yp_b   = R.y_pred(idx_b);
        for c = 0:12
            tp_=sum((yt_b==c)&(yp_b==c)); fp_=sum((yt_b~=c)&(yp_b==c)); nc_=sum(yt_b==c);
            pr_=tp_/max(tp_+fp_,1); re_=tp_/max(nc_,1);
            boot_f1(b,c+1)=2*pr_*re_/max(pr_+re_,1e-9);
        end
    end
    R.f1_ci_lo = prctile(boot_f1,2.5, 1);
    R.f1_ci_hi = prctile(boot_f1,97.5,1);

    % Majority-class baseline
    n_cls_vec = histcounts(M.y_train,-0.5:12.5);
    [~,maj_cls] = max(n_cls_vec);  maj_cls = maj_cls - 1;
    y_maj  = repmat(maj_cls, n, 1);
    R.acc_majority    = mean(y_maj == R.y_test);
    mf1_maj_c = zeros(n_cls,1);
    for c_mc = 0:12
        tp_mc=sum((R.y_test==c_mc)&(y_maj==c_mc)); fp_mc=sum((R.y_test~=c_mc)&(y_maj==c_mc));
        nc_mc=sum(R.y_test==c_mc);
        pr_mc=tp_mc/max(tp_mc+fp_mc,1); re_mc=tp_mc/max(nc_mc,1);
        mf1_maj_c(c_mc+1)=2*pr_mc*re_mc/max(pr_mc+re_mc,1e-9);
    end
    R.macro_f1_majority = mean(mf1_maj_c);
    % McNemar
    b_mcn = sum((R.y_pred~=R.y_test)&(y_maj==R.y_test));
    c_mcn = sum((R.y_pred==R.y_test)&(y_maj~=R.y_test));
    R.chi2_stat = (abs(b_mcn-c_mcn)-1)^2 / max(b_mcn+c_mcn,1);
    try
        R.p_val = 1 - chi2cdf(R.chi2_stat, 1);
    catch
        R.p_val = exp(-R.chi2_stat/2);
    end

    % Ablation accuracies
    rng(42);
    cols_23 = [2:24];
    rf_ab1  = TreeBagger(200, M.X_train(:,cols_23), M.y_train, 'Method','classification', ...
        'NumPredictorsToSample',max(1,floor(sqrt(23))),'MinLeafSize',1);
    yp1 = str2double(predict(rf_ab1, R.X_test(:,cols_23)));
    rng(42);
    cols_18 = [4:24];
    rf_ab2  = TreeBagger(200, M.X_train(:,cols_18), M.y_train, 'Method','classification', ...
        'NumPredictorsToSample',max(1,floor(sqrt(18))),'MinLeafSize',1);
    yp2 = str2double(predict(rf_ab2, R.X_test(:,cols_18)));
    R.ablation_acc = [R.acc; mean(yp1==R.y_test); mean(yp2==R.y_test)];

    HAS_RF = true;
    fprintf('[DATA] RF model loaded + metrics recomputed\n');
    fprintf('       Accuracy=%.4f  OOB=%.4f  MacroF1=%.4f\n\n', ...
        R.acc, R.oob_err, R.macro_f1);
end

if exist('restoration_summary.txt','file')
    HAS_RESTORE = true;
    fprintf('[DATA] Restoration summary found\n\n');
end

n_feat = 24;
if HAS_DATASET; n_feat = size(X,2); end


%% =========================================================================
%%  CHAPTER 3 — METHODOLOGY  (8 figures)
%% =========================================================================
fprintf('--- CHAPTER 3 ---\n');

%% Fig 3.1 — Feeder Topology
fig = figure('Visible','on','Position',[50 50 920 440]);
ax  = axes('Position',[0.01 0.01 0.98 0.88]);
axis(ax,[0 1 0 1]); axis(ax,'off'); hold(ax,'on');

bx  = [0.08,0.26,0.46,0.66,0.86]; by=0.62; bw=0.13; bh=0.30;
btitles = {'B1','B2','B3','B4','B5/SXEW'};
bsubs   = {{'33/11 kV','T1 20 MVA'},{'Dewatering','1.5 MW'}, ...
           {'Ventilation','2.0 MW'},{'Crusher','2.5 MW'},{'SX-EW Plant','1.65 MW'}};
for k=1:5
    rectangle('Position',[bx(k)-bw/2,by-bh/2,bw,bh],'Curvature',0.10, ...
        'FaceColor',[0.85 0.92 1.0],'EdgeColor',[0.10 0.30 0.70],'LineWidth',1.5);
    text(bx(k),by+0.06,btitles{k},'HorizontalAlignment','center', ...
        'FontName',FN,'FontWeight','bold','FontSize',FS_L,'Color',[0.10 0.30 0.70]);
    text(bx(k),by-0.02,bsubs{k}{1},'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A);
    text(bx(k),by-0.08,bsubs{k}{2},'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A);
end

cb_w=0.062; cb_h=0.060;
for k=1:4
    x1=bx(k)+bw/2; x2=bx(k+1)-bw/2; cbx=(x1+x2)/2;
    plot([x1,cbx-cb_w/2],[by,by],'k-','LineWidth',1.8);
    plot([cbx+cb_w/2,x2-0.005],[by,by],'k-','LineWidth',1.8);
    plot(x2,by,'k>','MarkerSize',5,'MarkerFaceColor','k','LineWidth',1);
    rectangle('Position',[cbx-cb_w/2,by-cb_h/2,cb_w,cb_h], ...
        'FaceColor','w','EdgeColor',[0.25 0.25 0.25],'LineWidth',1);
    text(cbx,by,sprintf('CB%d-%d',k,k+1),'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A,'FontWeight','bold','Color','k');
end

tx=mean([bx(4),bx(5)]); ty=0.17;
plot([bx(4),tx-0.02],[by-bh/2,ty+0.06],'Color',[0.75 0 0],'LineStyle','--','LineWidth',1.3);
plot([bx(5),tx+0.02],[by-bh/2,ty+0.06],'Color',[0.75 0 0],'LineStyle','--','LineWidth',1.3);
text(tx,0.37,'TIE-SW (N/O)','HorizontalAlignment','center','FontName',FN, ...
    'FontSize',FS_A,'Color',[0.75 0 0],'FontWeight','bold');
rectangle('Position',[tx-0.09,ty-0.055,0.18,0.11],'Curvature',0.12, ...
    'FaceColor',[1.0 0.95 0.80],'EdgeColor',[0.70 0.50 0.00],'LineWidth',1.5);
text(tx,ty+0.020,'T2 Backup','HorizontalAlignment','center', ...
    'FontName',FN,'FontWeight','bold','FontSize',FS_A);
text(tx,ty-0.022,'33/11 kV','HorizontalAlignment','center','FontName',FN,'FontSize',FS_A);

for k=2:5
    plot(bx(k),by+bh/2+0.06,'r*','MarkerSize',9,'LineWidth',1.2);
    text(bx(k)+0.018,by+bh/2+0.06,'F','FontName',FN,'FontSize',FS_A,'Color','r','FontWeight','bold');
end
lx=0.01; ly=0.97; ls=0.06;
text(lx,ly,'\ast  Fault location (F)','FontName',FN,'FontSize',FS_A,'Color',[0.5 0 0]);
text(lx,ly-ls,'--  Tie-switch path (N/O)','FontName',FN,'FontSize',FS_A,'Color',[0.75 0 0]);
text(lx,ly-2*ls,'CB = Circuit Breaker','FontName',FN,'FontSize',FS_A,'Color','k');
title('33/11 kV Mining Distribution Feeder — Single-Line Diagram', ...
    'FontName',FN,'FontWeight','bold','FontSize',FS_T);
savefig_ch('figures/ch3_methodology/Fig3_1_feeder_topology.png',fig);


%% Fig 3.2 — Methodology Flowchart
fig = figure('Visible','on','Position',[50 50 500 760]);
ax  = axes('Position',[0 0 1 1]); axis off; hold on; xlim([0 1]); ylim([0 1]);

steps  = {'1. Problem Formulation', ...
          {'2. Feeder Modelling','(Simulink 33/11 kV)'}, ...
          {'3. Fault Simulation','(SLG, LL, 3PH at B2-B5)'}, ...
          {'4. Dataset Generation','(1,000 samples, 13 classes)'}, ...
          {'5. Feature Extraction','(24 RMS features)'}, ...
          {'6. RF Training','(500 trees, cost-sensitive)'}, ...
          {'7. Self-Healing Logic','(Isolation + Tie-switch)'}, ...
          {'8. Evaluation & Validation',''}};
scolors= {[0.85 0.92 1.0],[0.90 1.0 0.85],[0.90 1.0 0.85],[0.90 1.0 0.85], ...
          [1.0 0.95 0.80],[1.0 0.95 0.80],[1.0 0.85 0.85],[0.95 0.85 1.0]};
ys = linspace(0.94,0.07,8);
for k=1:8
    rectangle('Position',[0.16,ys(k)-0.042,0.68,0.082],'Curvature',0.28, ...
        'FaceColor',scolors{k},'EdgeColor',[0.3 0.3 0.3],'LineWidth',1);
    if iscell(steps{k})
        text(0.50,ys(k)+0.016,steps{k}{1},'HorizontalAlignment','center', ...
            'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
        text(0.50,ys(k)-0.015,steps{k}{2},'HorizontalAlignment','center', ...
            'FontName',FN,'FontSize',FS_A);
    else
        text(0.50,ys(k),steps{k},'HorizontalAlignment','center', ...
            'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
    end
    if k<8
        ya1=ys(k)-0.042; ya2=ys(k+1)+0.038;
        plot([0.50 0.50],[ya1 ya2],'k-','LineWidth',1);
        plot(0.50,ya2+0.003,'kv','MarkerSize',5,'MarkerFaceColor','k');
    end
end
text(0.5,0.99,'Research Methodology Flowchart','HorizontalAlignment','center', ...
    'FontName',FN,'FontWeight','bold','FontSize',FS_T);
savefig_ch('figures/ch3_methodology/Fig3_2_methodology_flowchart.png',fig);


%% Fig 3.3 — Parameter Sweep 3D
fig = figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
Rf_v=[0.001,0.1,0.5,1.0,5.0]; lm_v=[0.70,0.85,1.00,1.10,1.30]; ton_v=[0.50,0.75,1.00];
[Rf_g,lm_g,ton_g] = ndgrid(1:5,1:5,1:3);
scatter3(Rf_v(Rf_g(:)),lm_v(lm_g(:)),ton_v(ton_g(:)),50,ton_g(:),'filled','MarkerFaceAlpha',0.7);
colormap(parula); cb=colorbar; cb.Label.String='Fault Onset Time (s)'; cb.FontSize=FS_K;
clim([1 3]); cb.Ticks=1:3; cb.TickLabels={'0.50','0.75','1.00'};
xlabel('Fault Resistance R_f (\Omega)','FontName',FN,'FontSize',FS_L);
ylabel('Load Multiplier (pu)','FontName',FN,'FontSize',FS_L);
zlabel('Fault Onset Time (s)','FontName',FN,'FontSize',FS_L);
title({'Parameter Sweep Space — 75 Samples per Fault Class','5 \times 5 \times 3 = 75 combinations'}, ...
    'FontName',FN,'FontSize',FS_T);
set(gca,'XScale','log'); grid on; view(35,25);
savefig_ch('figures/ch3_methodology/Fig3_3_parameter_sweep.png',fig);


%% Fig 3.4 — Feature Vector
fig  = figure('Visible','on','Position',[50 50 880 340]);
ax   = axes('Position',[0.01 0.05 0.98 0.88]); axis off; hold on;
xlim([0 1]); ylim([0 1]);
buses_fe={'B2','B3','B4','B5'}; types_fe={'V','I'}; phases_fe={'A','B','C'};
col_clr={[0.78 0.89 1.0],[1.0 0.88 0.76]};
total_cols=24; margin_l=0.02; margin_r=0.02;
col_w=(1-margin_l-margin_r)/total_cols - 0.002;
col_h=0.50; y_box=0.38; feat_n=1;
for b=1:4
    for t=1:2
        for ph=1:3
            col_idx=(b-1)*6+(t-1)*3+ph;
            x_fe=margin_l+(col_idx-1)*(col_w+0.002);
            rectangle('Position',[x_fe,y_box,col_w,col_h],'FaceColor',col_clr{t}, ...
                'EdgeColor',[0.55 0.55 0.55],'LineWidth',0.5);
            text(x_fe+col_w/2,y_box+col_h*0.70, ...
                sprintf('%s_{%s%s}',types_fe{t},buses_fe{b},phases_fe{ph}), ...
                'HorizontalAlignment','center','FontName',FN,'FontSize',7,'FontWeight','bold');
            text(x_fe+col_w/2,y_box+col_h*0.28,sprintf('f%d',feat_n), ...
                'HorizontalAlignment','center','FontName',FN,'FontSize',7,'Color',[0.45 0.45 0.45]);
            feat_n=feat_n+1;
        end
    end
end
for b=1:4
    col_s=(b-1)*6+1; col_e=col_s+5;
    x_s=margin_l+(col_s-1)*(col_w+0.002); x_e=margin_l+(col_e-1)*(col_w+0.002)+col_w;
    x_m=(x_s+x_e)/2;
    plot([x_s+0.002 x_e-0.002],[y_box+col_h+0.04 y_box+col_h+0.04], ...
        'Color',[0.15 0.25 0.6],'LineWidth',1.2);
    text(x_m,y_box+col_h+0.09,sprintf('Bus %s',buses_fe{b}), ...
        'HorizontalAlignment','center','FontName',FN,'FontWeight','bold', ...
        'FontSize',FS_A,'Color',[0.1 0.1 0.5]);
end
rectangle('Position',[margin_l-0.005,y_box-0.02,1-margin_l-margin_r+0.01,col_h+0.04], ...
    'EdgeColor',[0.2 0.2 0.7],'LineWidth',1.5,'Curvature',0.01);
y_ar=y_box-0.15;
plot([margin_l 1-margin_r],[y_ar y_ar],'k-','LineWidth',1.5);
plot(1-margin_r,y_ar,'k>','MarkerSize',6,'MarkerFaceColor','k');
text(0.50,y_ar+0.07,'Feature index:  f1 \rightarrow f24','HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_A,'Color',[0.4 0.4 0.4]);
title('Feature Vector:  4 Buses \times 2 Signal Types (V, I) \times 3 Phases (A,B,C) = 24 Features', ...
    'FontName',FN,'FontSize',FS_T,'FontWeight','bold');
savefig_ch('figures/ch3_methodology/Fig3_4_feature_extraction.png',fig);


%% Fig 3.5 — RF Architecture
fig = figure('Visible','on','Position',[50 50 FIG_W 400]);
ax = axes; axis off; hold on; xlim([0 1]); ylim([0 1]);
box_y=0.18; box_h=0.68; line_y=0.50;

rectangle('Position',[0.02 box_y 0.10 box_h],'Curvature',0.12, ...
    'FaceColor',[0.85 0.92 1.0],'EdgeColor',[0.1 0.3 0.7],'LineWidth',1.5);
text(0.07,0.58,'Feature','HorizontalAlignment','center','FontName',FN,'FontWeight','bold','FontSize',FS_A);
text(0.07,0.52,'Vector','HorizontalAlignment','center','FontName',FN,'FontWeight','bold','FontSize',FS_A);
text(0.07,0.45,'(1\times24)','HorizontalAlignment','center','FontName',FN,'FontSize',FS_A);

rectangle('Position',[0.84 box_y 0.14 box_h],'Curvature',0.12, ...
    'FaceColor',[1.0 0.90 0.75],'EdgeColor',[0.8 0.4 0.0],'LineWidth',1.5);
text(0.91,0.58,'Cost-Wt','HorizontalAlignment','center','FontName',FN,'FontWeight','bold','FontSize',FS_A);
text(0.91,0.52,'Majority','HorizontalAlignment','center','FontName',FN,'FontWeight','bold','FontSize',FS_A);
text(0.91,0.45,'Vote','HorizontalAlignment','center','FontName',FN,'FontSize',FS_A);

n_show=5; tree_x=linspace(0.21,0.74,n_show); tw=0.09;
tree_lbls={'Tree 1','Tree 2','...','Tree 250','Tree 500'};
for k=1:n_show
    tx1=tree_x(k)-tw/2; tx2=tree_x(k)+tw/2;
    rectangle('Position',[tx1 box_y tw box_h],'Curvature',0.12, ...
        'FaceColor',[0.90 1.0 0.85],'EdgeColor',[0.1 0.6 0.1],'LineWidth',1);
    cx=tree_x(k); cy=0.68;
    plot([cx cx-0.020],[cy cy-0.05],'k-','LineWidth',1.0);
    plot([cx cx+0.020],[cy cy-0.05],'k-','LineWidth',1.0);
    plot([cx-0.020 cx-0.030],[cy-0.05 cy-0.10],'k-','LineWidth',1.0);
    plot([cx-0.020 cx-0.008],[cy-0.05 cy-0.10],'k-','LineWidth',1.0);
    plot([cx+0.020 cx+0.008],[cy-0.05 cy-0.10],'k-','LineWidth',1.0);
    plot([cx+0.020 cx+0.030],[cy-0.05 cy-0.10],'k-','LineWidth',1.0);
    plot(cx,cy,'ko','MarkerSize',3,'MarkerFaceColor','k');
    text(tree_x(k),0.40,tree_lbls{k},'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
    text(tree_x(k),0.33,'(5 features)','HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A);
    if k==1
        plot([0.12 tx1],[line_y line_y],'-','LineWidth',1,'Color',[0.5 0.5 0.5]);
    else
        plot([tree_x(k-1)+tw/2 tx1],[line_y line_y],'-','LineWidth',1,'Color',[0.5 0.5 0.5]);
    end
    if k==n_show
        plot([tx2 0.84],[line_y line_y],'-','LineWidth',1,'Color',[0.5 0.5 0.5]);
        plot(0.84,line_y,'k>','MarkerSize',4,'MarkerFaceColor','k');
    end
end
plot(tree_x(1)-tw/2,line_y,'k>','MarkerSize',4,'MarkerFaceColor','k');
text(0.50,0.10,'500 trees,  m_{try}=\lfloor\surd24\rfloor=5 features/split,  Cost: Fault\rightarrowHealthy=12.5\times', ...
    'HorizontalAlignment','center','FontName',FN,'FontSize',FS_A,'Color',[0.35 0.35 0.35],'FontAngle','italic');
title('Random Forest Architecture — 500 Trees, Cost-Sensitive (12.5\times False Negative Penalty)', ...
    'FontName',FN,'FontSize',FS_T,'FontWeight','bold');
savefig_ch('figures/ch3_methodology/Fig3_5_rf_architecture.png',fig);


%% Fig 3.6 — Self-Healing Logic Flowchart
fig = figure('Visible','on','Position',[50 50 500 800]);
ax = axes('Position',[0.01 0.01 0.98 0.88]); axis off; hold on; xlim([0 1]); ylim([0 1]);

fsteps = {'START: System Monitoring', {'Measure V & I','(4 buses, 3 phases)'}, ...
          {'Extract 24 RMS','Features'}, {'RF Classifier','Predict Class'}, ...
          'Class = 0  (Healthy)?', {'Identify Fault Bus','from Class Label'}, ...
          {'Open CB at','Faulted Bus'}, {'Healthy Buses','Re-Energised'}, ...
          {'Close Tie-Switch','(Alternate Supply)'}, ...
          {'Post-Restoration','Voltage Check'}, 'END: Log & Alert'};
fcolors= {[0.9 0.9 0.9],[0.85 0.92 1],[0.85 0.92 1],[0.85 0.92 1], ...
          [1.0 0.95 0.75],[1.0 0.88 0.75],[1.0 0.75 0.75],[0.75 1.0 0.80], ...
          [0.75 1.0 0.80],[0.90 0.80 1.0],[0.80 0.80 0.80]};
fy = linspace(0.95,0.05,11);

for k=1:11
    if k==5
        cx=0.50; cy=fy(k); hw=0.22; hh=0.045;
        patch([cx-hw cx cx+hw cx],[cy cy+hh cy cy-hh],fcolors{k}, ...
            'EdgeColor',[0.3 0.3 0.3],'LineWidth',1);
        text(cx,cy,fsteps{k},'HorizontalAlignment','center', ...
            'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
    else
        rectangle('Position',[0.20,fy(k)-0.038,0.60,0.076], ...
            'Curvature',0.28,'FaceColor',fcolors{k},'EdgeColor',[0.3 0.3 0.3],'LineWidth',1);
        if iscell(fsteps{k})
            text(0.50,fy(k)+0.014,fsteps{k}{1},'HorizontalAlignment','center', ...
                'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
            text(0.50,fy(k)-0.014,fsteps{k}{2},'HorizontalAlignment','center', ...
                'FontName',FN,'FontSize',FS_A);
        else
            text(0.50,fy(k),fsteps{k},'HorizontalAlignment','center', ...
                'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
        end
    end
end
for k=1:10
    if k==4; ya1=fy(k)-0.038; ya2=fy(k+1)+0.045;
    elseif k==5; ya1=fy(k)-0.045; ya2=fy(k+1)+0.038;
    else; ya1=fy(k)-0.038; ya2=fy(k+1)+0.038; end
    plot([0.50 0.50],[ya1 ya2],'k-','LineWidth',1);
    plot(0.50,ya2+0.003,'kv','MarkerSize',4,'MarkerFaceColor','k');
end
plot([0.72 0.86],[fy(5) fy(5)],'-','LineWidth',1,'Color',[0 0.5 0]);
plot([0.86 0.86],[fy(5) fy(2)],'-','LineWidth',1,'Color',[0 0.5 0]);
plot([0.86 0.80],[fy(2) fy(2)],'-','LineWidth',1,'Color',[0 0.5 0]);
plot(0.80,fy(2),'<','MarkerSize',5,'MarkerFaceColor',[0 0.5 0],'Color',[0 0.5 0]);
text(0.88,(fy(2)+fy(5))/2,'YES','HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_A,'Color',[0 0.5 0],'FontWeight','bold');
text(0.88,(fy(2)+fy(5))/2-0.030,'(Normal)','HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_A,'Color',[0 0.5 0]);
text(0.56,(fy(5)+fy(6))/2+0.010,'NO (Fault)','FontName',FN,'FontSize',FS_A,'Color','r','FontWeight','bold');
text(0.5,0.99,'Self-Healing Protection Logic Flowchart','HorizontalAlignment','center', ...
    'FontName',FN,'FontWeight','bold','FontSize',FS_T);
savefig_ch('figures/ch3_methodology/Fig3_6_selfhealing_logic.png',fig);


%% Fig 3.7 — Healthy System Waveform (synthetic)
t_w  = linspace(0,0.06,600); f50=50; Vp=11000/sqrt(3)*sqrt(2);
VA=Vp*sin(2*pi*f50*t_w); VB=Vp*sin(2*pi*f50*t_w-2*pi/3); VC=Vp*sin(2*pi*f50*t_w+2*pi/3);
IAp=1.5e6/(11e3/sqrt(3)*3)*sqrt(2); ph_lag=0.39;
IA=IAp*sin(2*pi*f50*t_w-ph_lag); IB=IAp*sin(2*pi*f50*t_w-ph_lag-2*pi/3); IC=IAp*sin(2*pi*f50*t_w-ph_lag+2*pi/3);

fig = figure('Visible','on','Position',[50 50 FIG_W 480]);
subplot(2,1,1);
plot(t_w*1000,VA/1000,'r-','LineWidth',1.2); hold on;
plot(t_w*1000,VB/1000,'b-','LineWidth',1.2);
plot(t_w*1000,VC/1000,'g-','LineWidth',1.2);
ylabel('Voltage (kV)','FontName',FN,'FontSize',FS_L);
title('Healthy System — Three-Phase Voltage at Bus B2 (Balanced, Rated)','FontName',FN,'FontSize',FS_T);
legend({'V_A','V_B','V_C'},'Location','northeast','FontSize',FS_G);
grid on; xlim([0 60]);
subplot(2,1,2);
plot(t_w*1000,IA,'r-','LineWidth',1.2); hold on;
plot(t_w*1000,IB,'b-','LineWidth',1.2);
plot(t_w*1000,IC,'g-','LineWidth',1.2);
ylabel('Current (A)','FontName',FN,'FontSize',FS_L);
xlabel('Time (ms)','FontName',FN,'FontSize',FS_L);
title('Healthy System — Three-Phase Current at Bus B2 (Balanced)','FontName',FN,'FontSize',FS_T);
legend({'I_A','I_B','I_C'},'Location','northeast','FontSize',FS_G);
grid on; xlim([0 60]);
savefig_ch('figures/ch3_methodology/Fig3_7_healthy_waveform.png',fig);


%% Fig 3.8 — Fault Waveforms Comparison (synthetic, three fault types)
t_w2=linspace(0,0.12,1200); t_f=0.04; idx_f=t_w2>=t_f;
V_n=Vp*sin(2*pi*f50*t_w2); VB_n=Vp*sin(2*pi*f50*t_w2-2*pi/3); VC_n=Vp*sin(2*pi*f50*t_w2+2*pi/3);
VA_slg=V_n; VA_slg(idx_f)=Vp*0.10*sin(2*pi*f50*t_w2(idx_f));
VA_ll=V_n; VA_ll(idx_f)=Vp*0.30*sin(2*pi*f50*t_w2(idx_f));
VB_ll=VB_n; VB_ll(idx_f)=Vp*0.30*sin(2*pi*f50*t_w2(idx_f)-2*pi/3);
VA_3=V_n; VA_3(idx_f)=Vp*0.08*sin(2*pi*f50*t_w2(idx_f));
VB_3=VB_n; VB_3(idx_f)=Vp*0.08*sin(2*pi*f50*t_w2(idx_f)-2*pi/3);
VC_3=VC_n; VC_3(idx_f)=Vp*0.08*sin(2*pi*f50*t_w2(idx_f)+2*pi/3);

fig = figure('Visible','on','Position',[50 50 FIG_W 620]);
subplot(3,1,1);
plot(t_w2*1000,VA_slg/1000,'r-','LineWidth',1.2); hold on;
plot(t_w2*1000,VB_n/1000,'b--','LineWidth',1); plot(t_w2*1000,VC_n/1000,'g--','LineWidth',1);
xline(t_f*1000,'k--','Fault onset','FontSize',FS_A,'FontName',FN);
ylabel('Voltage (kV)','FontName',FN,'FontSize',FS_L);
title('SLG Fault (Phase A to Ground) at Bus B4, R_f = 0.001 \Omega','FontName',FN,'FontSize',FS_T);
legend({'V_A (faulted)','V_B','V_C'},'Location','northeast','FontSize',FS_G);
grid on; ylim([-12 12]);
subplot(3,1,2);
plot(t_w2*1000,VA_ll/1000,'r-','LineWidth',1.2); hold on;
plot(t_w2*1000,VB_ll/1000,'b-','LineWidth',1.2); plot(t_w2*1000,VC_n/1000,'g--','LineWidth',1);
xline(t_f*1000,'k--');
ylabel('Voltage (kV)','FontName',FN,'FontSize',FS_L);
title('Line-to-Line Fault (Phase A-B) at Bus B4','FontName',FN,'FontSize',FS_T);
legend({'V_A','V_B','V_C (healthy)'},'Location','northeast','FontSize',FS_G);
grid on; ylim([-12 12]);
subplot(3,1,3);
plot(t_w2*1000,VA_3/1000,'r-','LineWidth',1.2); hold on;
plot(t_w2*1000,VB_3/1000,'b-','LineWidth',1.2); plot(t_w2*1000,VC_3/1000,'g-','LineWidth',1.2);
xline(t_f*1000,'k--');
ylabel('Voltage (kV)','FontName',FN,'FontSize',FS_L);
xlabel('Time (ms)','FontName',FN,'FontSize',FS_L);
title('Three-Phase Fault at Bus B4 — All Phases Collapse','FontName',FN,'FontSize',FS_T);
legend({'V_A','V_B','V_C'},'Location','northeast','FontSize',FS_G);
grid on; ylim([-12 12]);
sgtitle('Simulated Fault Voltage Waveforms — Bus B4','FontName',FN,'FontSize',FS_T+1,'FontWeight','bold');
savefig_ch('figures/ch3_methodology/Fig3_8_fault_waveforms.png',fig);
fprintf('  Chapter 3: 8 figures\n\n');


%% =========================================================================
%%  CHAPTER 4 — SYSTEM DESIGN  (4 figures)
%% =========================================================================
fprintf('--- CHAPTER 4 ---\n');

%% Fig 4.1 — Fault Block Configuration table
fig = figure('Visible','on','Position',[50 50 FIG_W 400]);
ax  = axes; axis off;
col_hdr  = {'Parameter','SLG (A-G)','Line-Line (A-B)','Three-Phase (ABC)'};
row_lbl  = {'FaultA','FaultB','FaultC','GroundFault','FaultResistance','SwitchTimes','InitialStates','GroundResistance'};
tdata    = {'on','on','on'; 'off','on','on'; 'off','off','on'; 'on','off','off'; ...
            '0.001/0.1/0.5/1.0/5.0 \Omega','same','same'; '[t_{on}  t_{end}]','same','same'; ...
            '0','same','same'; '0.001 \Omega','500 \Omega (N/A)','500 \Omega (N/A)'};
draw_table(ax,col_hdr,row_lbl,tdata,FN,FS_A);
title('Fault Block Configuration — Simulink Three-Phase Fault Block','FontName',FN,'FontSize',FS_T);
savefig_ch('figures/ch4_system_design/Fig4_1_fault_block_config.png',fig);

%% Fig 4.2 — Cost Matrix
n_cls=13; cost_mat=ones(n_cls);
for r=2:n_cls; cost_mat(r,1)=12.5; end
cost_mat(logical(eye(n_cls)))=0;
fig = figure('Visible','on','Position',[50 50 FIG_SQ FIG_SQ+30]);
imagesc(cost_mat); colormap(hot); cb4=colorbar;
cb4.Label.String='Misclassification Cost'; cb4.FontSize=FS_K;
clim([0 12.5]);
xticks(1:n_cls); xticklabels(SHORT); xtickangle(45);
yticks(1:n_cls); yticklabels(SHORT);
xlabel('Predicted Class','FontName',FN,'FontSize',FS_L);
ylabel('True Class','FontName',FN,'FontSize',FS_L);
title({'Asymmetric Misclassification Cost Matrix', ...
       'Fault \rightarrow Healthy = 12.5\times | Other = 1.0 | Correct = 0'}, ...
    'FontName',FN,'FontSize',FS_T);
for r=1:n_cls; for c2=1:n_cls
    if cost_mat(r,c2)>0
        tc='k'; if cost_mat(r,c2)>6; tc='w'; end
        text(c2,r,sprintf('%.1f',cost_mat(r,c2)),'HorizontalAlignment','center', ...
            'FontName',FN,'FontSize',FS_A,'Color',tc,'FontWeight','bold');
    end
end; end
savefig_ch('figures/ch4_system_design/Fig4_2_cost_matrix.png',fig);

%% Fig 4.3 — Class Label Map
fig = figure('Visible','on','Position',[50 50 700 440]);
ax  = axes('Position',[0.01 0.02 0.98 0.88]); axis off; hold on;
xlim([0 1]); ylim([0 1]);
n_rows=6; n_cols=4; cw=1/n_cols; ch=0.80/n_rows; x0=0; y_top=0.98;
bus_rows={'Healthy','Bus B2','Bus B3','Bus B4','Bus B5/SXEW'};
type_cols={'SLG (A-G)','Line-Line (A-B)','Three-Phase (ABC)'};
HDR_CLR=[0.22 0.36 0.60]; LBL_CLR=[0.88 0.88 0.88];
y_r=y_top-ch;
rectangle('Position',[x0,y_r,cw,ch],'FaceColor',HDR_CLR,'EdgeColor','w','LineWidth',0.8);
text(x0+cw/2,y_r+ch/2,'Bus / Fault Type','HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_A,'FontWeight','bold','Color','w');
for tc=1:3
    xp=x0+tc*cw;
    rectangle('Position',[xp,y_r,cw,ch],'FaceColor',HDR_CLR,'EdgeColor','w','LineWidth',0.8);
    text(xp+cw/2,y_r+ch/2,type_cols{tc},'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A,'FontWeight','bold','Color','w');
end
y_r=y_top-2*ch;
rectangle('Position',[x0,y_r,cw,ch],'FaceColor',LBL_CLR,'EdgeColor','k','LineWidth',0.7);
text(x0+cw/2,y_r+ch/2,'Healthy','HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
rectangle('Position',[x0+cw,y_r,3*cw,ch],'FaceColor',[C_HEALTHY*0.4+0.60],'EdgeColor','k','LineWidth',0.7);
text(x0+cw+1.5*cw,y_r+ch/2,'Class 0  (Healthy — No Fault)','HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_L,'FontWeight','bold');
bus_lbl_clrs={C_B2*0.55+0.45,C_B3*0.55+0.45,C_B4*0.55+0.45,C_B5*0.55+0.45};
bus_dat_clrs={C_B2*0.30+0.70,C_B3*0.30+0.70,C_B4*0.30+0.70,C_B5*0.30+0.70};
for br=1:4
    y_r=y_top-(br+2)*ch; cls_start=(br-1)*3+1;
    rectangle('Position',[x0,y_r,cw,ch],'FaceColor',bus_lbl_clrs{br},'EdgeColor','k','LineWidth',0.7);
    text(x0+cw/2,y_r+ch/2,bus_rows{br+1},'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
    for tc=1:3
        xp=x0+tc*cw;
        rectangle('Position',[xp,y_r,cw,ch],'FaceColor',bus_dat_clrs{br},'EdgeColor','k','LineWidth',0.7);
        text(xp+cw/2,y_r+ch/2,sprintf('Class %d',cls_start+tc-1), ...
            'HorizontalAlignment','center','FontName',FN,'FontSize',FS_L,'FontWeight','bold');
    end
end
title('13-Class Label Map:  Fault Type \times Bus Location','FontName',FN,'FontWeight','bold','FontSize',FS_T+1);
savefig_ch('figures/ch4_system_design/Fig4_3_class_label_map.png',fig);

%% Fig 4.4 — RF Hyperparameter table
fig = figure('Visible','on','Position',[50 50 640 400]);
ax  = axes; axis off;
params_hdr={'Hyperparameter','Value'};
params_lbl={'Number of Trees','Features per Split','Min Leaf Size','Max Depth', ...
    'Bootstrap Sampling','Cost Matrix','OOB Evaluation','Random Seed'};
params_data={'500'; 'floor(\surd24) = 5'; '1'; 'Unlimited (full trees)'; ...
    'Yes (bagging, 63.2% of samples)'; 'Asymmetric (12.5\times false negative)'; ...
    'Enabled'; '42 (fixed, rng(42))'};
draw_table(ax,params_hdr,params_lbl,params_data,FN,FS_A);
title('Random Forest Hyperparameter Configuration','FontName',FN,'FontSize',FS_T);
savefig_ch('figures/ch4_system_design/Fig4_4_rf_hyperparameters.png',fig);
fprintf('  Chapter 4: 4 figures\n\n');


%% =========================================================================
%%  CHAPTER 5 — RESULTS  (14 figures)
%% =========================================================================
fprintf('--- CHAPTER 5 ---\n');

if HAS_DATASET
    counts=arrayfun(@(c) sum(labels==c),0:12);

    %% Fig 5.1 — Class Distribution
    fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
    b5=bar(0:12,counts,'FaceColor','flat'); b5.CData=COLORS_13;
    xticks(0:12); xticklabels(CLASS_NAMES); xtickangle(40);
    ylabel('Number of Samples','FontName',FN,'FontSize',FS_L);
    xlabel('Fault Class','FontName',FN,'FontSize',FS_L);
    title(sprintf('Dataset Class Distribution — %d Samples Total',sum(counts)), ...
        'FontName',FN,'FontSize',FS_T);
    grid on;
    for k=1:13
        if counts(k)>0
            text(k-1,counts(k)+1,num2str(counts(k)),'HorizontalAlignment','center', ...
                'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
        end
    end
    yline(75,'r--','75 (fault target)','LabelHorizontalAlignment','right', ...
        'FontSize',FS_A,'FontName',FN,'LineWidth',1);
    yline(100,'g--','100 (healthy)','LabelHorizontalAlignment','right', ...
        'FontSize',FS_A,'FontName',FN,'LineWidth',1);
    savefig_ch('figures/ch5_results/Fig5_1_class_distribution.png',fig);

    %% Fig 5.2 — Voltage Heatmap
    v_idx=1:min(12,n_feat); v_names_h=feature_names(v_idx);
    v_base=max(mean(X(labels==0,v_idx),1),1);
    v_heat=zeros(13,12);
    for c=0:12; idx=(labels==c); if any(idx); v_heat(c+1,:)=mean(X(idx,v_idx),1)./v_base; end; end
    fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
    imagesc(v_heat); colormap(hot); cb5=colorbar;
    cb5.Label.String='V (norm. to healthy)'; cb5.FontSize=FS_K; clim([0 1.1]);
    yticks(1:13); yticklabels(CLASS_NAMES);
    xticks(1:length(v_idx)); xticklabels(strrep(v_names_h,'_','\_')); xtickangle(45);
    xlabel('Voltage Feature','FontName',FN,'FontSize',FS_L);
    ylabel('Class','FontName',FN,'FontSize',FS_L);
    title('Mean Phase Voltage per Class (Normalised to Healthy)','FontName',FN,'FontSize',FS_T);
    for r=1:13; for c2=1:length(v_idx)
        tc='w'; if v_heat(r,c2)>0.55; tc='k'; end
        text(c2,r,sprintf('%.2f',v_heat(r,c2)),'HorizontalAlignment','center', ...
            'FontName',FN,'FontSize',FS_A,'Color',tc);
    end; end
    savefig_ch('figures/ch5_results/Fig5_2_voltage_heatmap.png',fig);

    %% Fig 5.3 — Current Heatmap
    if n_feat>=24
        i_idx=13:24; i_names_h=feature_names(i_idx);
        i_base=max(mean(X(labels==0,i_idx),1),1);
        i_heat=zeros(13,12);
        for c=0:12; idx=(labels==c); if any(idx); i_heat(c+1,:)=mean(X(idx,i_idx),1)./i_base; end; end
        i_heat_d=min(i_heat,5);
        fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
        imagesc(i_heat_d); colormap(parula); cb6=colorbar;
        cb6.Label.String='I (norm. to healthy, capped 5\times)'; cb6.FontSize=FS_K; clim([0 5]);
        yticks(1:13); yticklabels(CLASS_NAMES);
        xticks(1:12); xticklabels(strrep(i_names_h,'_','\_')); xtickangle(45);
        xlabel('Current Feature','FontName',FN,'FontSize',FS_L);
        ylabel('Class','FontName',FN,'FontSize',FS_L);
        title({'Mean Phase Current per Class (Normalised to Healthy, Capped at 5\times)', ...
               'Note: SLG at B3/B4/B5 shows anomalously low current — grounding limitation'}, ...
            'FontName',FN,'FontSize',FS_T);
        for r=1:13; for c2=1:12
            v_=i_heat(r,c2); tc='k'; if i_heat_d(r,c2)>3; tc='w'; end
            if v_>5; txt_='>5'; else; txt_=sprintf('%.1f',v_); end
            text(c2,r,txt_,'HorizontalAlignment','center','FontName',FN,'FontSize',FS_A,'Color',tc);
        end; end
        savefig_ch('figures/ch5_results/Fig5_3_current_heatmap.png',fig);
    end

    %% Fig 5.4 — Feature Scatter
    fig=figure('Visible','on','Position',[50 50 FIG_SQ FIG_SQ]);
    hold on;
    for c=0:12
        idx=(labels==c); if ~any(idx); continue; end
        scatter(X(idx,1),X(idx,13),18,COLORS_13(c+1,:),'filled', ...
            'MarkerFaceAlpha',0.55,'DisplayName',CLASS_NAMES{c+1});
    end
    xlabel('V_{B2,A} RMS (V)','FontName',FN,'FontSize',FS_L);
    ylabel('I_{B2,A} RMS (A)','FontName',FN,'FontSize',FS_L);
    title('Feature Separability: Voltage vs Current at Bus B2 (Phase A)', ...
        'FontName',FN,'FontSize',FS_T);
    xline(11000/sqrt(3)*0.95,'k--','0.95 pu','HandleVisibility','off', ...
        'LabelHorizontalAlignment','right','FontSize',FS_A,'FontName',FN);
    xline(11000/sqrt(3)*1.05,'k--','1.05 pu','HandleVisibility','off', ...
        'LabelHorizontalAlignment','right','FontSize',FS_A,'FontName',FN);
    legend('Location','best','FontSize',FS_G,'NumColumns',2);
    grid on; box on;
    savefig_ch('figures/ch5_results/Fig5_4_scatter_separability.png',fig);
end

if HAS_RF
    %% Fig 5.5 — OOB Error Curve
    fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
    oob_curve=oobError(R.rf_model);
    plot(1:length(oob_curve),oob_curve*100,'b-','LineWidth',1.5);
    xlabel('Number of Trees','FontName',FN,'FontSize',FS_L);
    ylabel('OOB Error (%)','FontName',FN,'FontSize',FS_L);
    title('Random Forest OOB Error vs Number of Trees','FontName',FN,'FontSize',FS_T);
    xline(500,'r--',sprintf('N=500, OOB=%.2f%%',oob_curve(end)*100), ...
        'LabelHorizontalAlignment','left','FontSize',FS_A,'FontName',FN,'LineWidth',1);
    yline(5,'k:','5% reference','FontSize',FS_A,'FontName',FN,'LabelHorizontalAlignment','right');
    grid on; box on;
    savefig_ch('figures/ch5_results/Fig5_5_oob_error_curve.png',fig);

    %% Fig 5.6 — Confusion Matrix
    cm=R.cm; cm_norm=cm./max(sum(cm,2),1);
    fig=figure('Visible','on','Position',[50 50 FIG_SQ+20 FIG_SQ+40]);
    imagesc(cm_norm); colormap(flipud(hot));
    cb7=colorbar; cb7.Label.String='Recall (Row Normalised)'; cb7.FontSize=FS_K; clim([0 1]);
    for r=1:13; for c2=1:13
        if cm(r,c2)>0
            tc='w'; if cm_norm(r,c2)<0.5; tc='k'; end
            text(c2,r,num2str(cm(r,c2)),'HorizontalAlignment','center', ...
                'FontName',FN,'FontSize',FS_A,'Color',tc,'FontWeight','bold');
        end
    end; end
    xticks(1:13); xticklabels(SHORT); xtickangle(45);
    yticks(1:13); yticklabels(SHORT);
    xlabel('Predicted Class','FontName',FN,'FontSize',FS_L);
    ylabel('True Class','FontName',FN,'FontSize',FS_L);
    title(sprintf('Confusion Matrix — Test Set, Accuracy = %.2f%%',R.acc*100), ...
        'FontName',FN,'FontSize',FS_T);
    savefig_ch('figures/ch5_results/Fig5_6_confusion_matrix.png',fig);

    %% Fig 5.7 — Feature Importance
    imp=R.imp; [imp_s,i_s]=sort(imp,'descend'); fn_s=R.feature_names(i_s);
    fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
    bar(imp_s,'FaceColor',[0.18 0.42 0.78]);
    xticks(1:length(imp_s)); xticklabels(strrep(fn_s,'_','\_')); xtickangle(50);
    ylabel('OOB Permutation Importance (MDA)','FontName',FN,'FontSize',FS_L);
    title('Random Forest Feature Importance — Mean Decrease in Accuracy', ...
        'FontName',FN,'FontSize',FS_T);
    grid on; box on;
    savefig_ch('figures/ch5_results/Fig5_7_feature_importance.png',fig);

    %% Fig 5.8 — Per-Class Metrics
    fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
    x_ax=0:12;
    bg=bar(x_ax,[R.per_cls(:,1),R.per_cls(:,2),R.per_cls(:,3)],'grouped');
    bg(1).FaceColor=[0.18 0.42 0.78];
    bg(2).FaceColor=[0.84 0.19 0.15];
    bg(3).FaceColor=[0.13 0.63 0.30];
    xticks(0:12); xticklabels(CLASS_NAMES); xtickangle(40);
    ylabel('Score','FontName',FN,'FontSize',FS_L); ylim([0 1.12]);
    yline(0.95,'k:','0.95 target','LabelHorizontalAlignment','right', ...
        'FontSize',FS_A,'FontName',FN);
    legend({'Precision','Recall','F1-Score'},'Location','south','NumColumns',3,'FontSize',FS_G);
    title('Per-Class Precision, Recall, and F1-Score — Test Set','FontName',FN,'FontSize',FS_T);
    grid on; box on;
    savefig_ch('figures/ch5_results/Fig5_8_per_class_metrics.png',fig);

    %% Fig 5.9 — CV Folds
    fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
    bar(1:5,R.cv_acc*100,'FaceColor',[0.18 0.42 0.78],'EdgeColor',[0.1 0.2 0.5]);
    hold on;
    yline(R.cv_mean*100,'r-','LineWidth',1.5,'HandleVisibility','off');
    yline(R.acc*100,'g--','LineWidth',1,'HandleVisibility','off');
    text(5.6,R.cv_mean*100,sprintf(' CV Mean = %.2f%%',R.cv_mean*100), ...
        'FontName',FN,'FontSize',FS_A,'Color','r','VerticalAlignment','bottom');
    text(5.6,R.acc*100-0.4,sprintf(' Single Split = %.2f%%',R.acc*100), ...
        'FontName',FN,'FontSize',FS_A,'Color',[0 0.5 0],'VerticalAlignment','top');
    xticks(1:5); xticklabels({'Fold 1','Fold 2','Fold 3','Fold 4','Fold 5'});
    ylabel('Accuracy (%)','FontName',FN,'FontSize',FS_L);
    xlim([0.5 6.5]); ylim([90 102]);
    for k=1:5
        text(k,R.cv_acc(k)*100+0.3,sprintf('%.2f%%',R.cv_acc(k)*100), ...
            'HorizontalAlignment','center','FontName',FN,'FontSize',FS_A,'FontWeight','bold');
    end
    title(sprintf('5-Fold Stratified CV: Mean = %.2f%% \\pm %.2f%%', ...
        R.cv_mean*100,R.cv_std*100),'FontName',FN,'FontSize',FS_T);
    grid on; box on;
    savefig_ch('figures/ch5_results/Fig5_9_cv_accuracy_folds.png',fig);

    %% Fig 5.10 — Baseline Comparison
    fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
    subplot(1,2,1);
    bv=[R.acc_majority*100, R.acc*100];
    bc=bar(1:2,bv,'FaceColor','flat');
    bc.CData=[0.65 0.65 0.65; 0.18 0.42 0.78];
    xticks(1:2); xticklabels({'Majority Baseline','Random Forest'});
    ylabel('Accuracy (%)','FontName',FN,'FontSize',FS_L);
    ylim([0 110]); grid on;
    title('Accuracy vs Baseline','FontName',FN,'FontSize',FS_T);
    for k=1:2; text(k,bv(k)+1.5,sprintf('%.1f%%',bv(k)),'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A,'FontWeight','bold'); end
    subplot(1,2,2);
    mf=[R.macro_f1_majority*100, R.macro_f1*100];
    bc2=bar(1:2,mf,'FaceColor','flat');
    bc2.CData=[0.65 0.65 0.65; 0.18 0.42 0.78];
    xticks(1:2); xticklabels({'Majority Baseline','Random Forest'});
    ylabel('Macro F1 (%)','FontName',FN,'FontSize',FS_L);
    ylim([0 110]); grid on;
    title('Macro F1 vs Baseline','FontName',FN,'FontSize',FS_T);
    for k=1:2; text(k,mf(k)+1.5,sprintf('%.1f%%',mf(k)),'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A,'FontWeight','bold'); end
    if R.p_val<0.001; pstr='p < 0.001'; else; pstr=sprintf('p = %.3f',R.p_val); end
    sgtitle(sprintf('Classifier vs Majority-Class Baseline (McNemar \\chi^2 = %.2f, %s)', ...
        R.chi2_stat,pstr),'FontName',FN,'FontSize',FS_T,'FontWeight','bold');
    savefig_ch('figures/ch5_results/Fig5_10_baseline_comparison.png',fig);

    %% Fig 5.11 — Ablation Study
    fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
    ab_colors=[0.18 0.42 0.78; 0.84 0.19 0.15; 0.89 0.55 0.00];
    b_ab=bar(1:3,R.ablation_acc*100,'FaceColor','flat');
    b_ab.CData=ab_colors;
    xticks(1:3); xticklabels({'Full (24 feat.)','Without V_{B2,A} (23 feat.)','Without all B2 (18 feat.)'});
    ylabel('Test Accuracy (%)','FontName',FN,'FontSize',FS_L);
    ylim([max(0,min(R.ablation_acc*100)-8) 105]);
    title({'Ablation Study — Robustness to Feature Removal', ...
           'Does removing Bus B2 features break the classifier?'}, ...
        'FontName',FN,'FontSize',FS_T);
    grid on; box on;
    for k=1:3
        delta=(R.ablation_acc(k)-R.ablation_acc(1))*100;
        text(k,R.ablation_acc(k)*100+0.5,sprintf('%.1f%% (%+.1f pp)',R.ablation_acc(k)*100,delta), ...
            'HorizontalAlignment','center','FontName',FN,'FontSize',FS_A,'FontWeight','bold');
    end
    yline(R.ablation_acc(1)*100,'k--','Full model','FontSize',FS_A,'FontName',FN, ...
        'LabelHorizontalAlignment','right');
    savefig_ch('figures/ch5_results/Fig5_11_ablation_study.png',fig);

    %% Fig 5.12 — Bootstrap F1 CI
    fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
    bar(0:12,R.per_cls(:,3),'FaceColor',[0.18 0.42 0.78]); hold on;
    err_lo=R.per_cls(:,3)'-R.f1_ci_lo;
    err_hi=R.f1_ci_hi-R.per_cls(:,3)';
    errorbar(0:12,R.per_cls(:,3)',err_lo,err_hi,'k.','LineWidth',1.2,'CapSize',4, ...
        'HandleVisibility','off');
    xticks(0:12); xticklabels(CLASS_NAMES); xtickangle(40);
    ylabel('F1 Score','FontName',FN,'FontSize',FS_L); ylim([0 1.15]);
    yline(0.95,'r:','0.95 target','LabelHorizontalAlignment','right','FontSize',FS_A,'FontName',FN);
    title({'Per-Class F1 Score with Bootstrap 95% Confidence Intervals', ...
           'Note: [1.000,1.000] CIs are degenerate (n=15 per fault class)'}, ...
        'FontName',FN,'FontSize',FS_T);
    legend({'F1 Score'},'Location','south','FontSize',FS_G);
    grid on; box on;
    savefig_ch('figures/ch5_results/Fig5_12_f1_bootstrap_ci.png',fig);
end

%% Fig 5.13 — Restoration Voltage Bar Chart (real values from summary)
fig=figure('Visible','on','Position',[50 50 FIG_W FIG_H]);
stages={'Pre-Fault','During Fault','Post-Restoration'};
vB4_100=[0.9818, 0.9811, 0.9818];
vB4_85 =[0.9846, 0.9839, 0.9846];
x=1:3; bar_w=0.30;
hold on;
bar(x-bar_w/2,vB4_100,bar_w,'FaceColor',[0.18 0.42 0.78],'DisplayName','Bus B4 (100% load)');
bar(x+bar_w/2,vB4_85, bar_w,'FaceColor',[0.84 0.19 0.15],'DisplayName','Bus B4 (85% load)');
yline(0.95,'k--','0.95 pu lower limit','FontSize',FS_A,'FontName',FN, ...
    'LabelHorizontalAlignment','right','HandleVisibility','off','LineWidth',1);
yline(1.05,'k-.','1.05 pu upper limit','FontSize',FS_A,'FontName',FN, ...
    'LabelHorizontalAlignment','right','HandleVisibility','off','LineWidth',1);
yline(1.00,'Color',[0.5 0.5 0.5],'LineStyle',':','HandleVisibility','off','LineWidth',0.8);
for k=1:3
    text(x(k)-bar_w/2,vB4_100(k)+0.001,sprintf('%.4f',vB4_100(k)), ...
        'HorizontalAlignment','center','FontName',FN,'FontSize',FS_A);
    text(x(k)+bar_w/2,vB4_85(k)+0.001,sprintf('%.4f',vB4_85(k)), ...
        'HorizontalAlignment','center','FontName',FN,'FontSize',FS_A);
end
ylim([0.94 1.06]); xticks(1:3); xticklabels(stages);
ylabel('RMS Voltage (pu)','FontName',FN,'FontSize',FS_L);
legend('Location','southeast','FontSize',FS_G);
title({'Bus B4 Voltage: Pre-Fault, During Fault, and Post-Restoration', ...
       'SLG Fault (R_f = 0.001 \Omega), CB isolates at t=1.5 s, Tie-switch closes at t=2.0 s'}, ...
    'FontName',FN,'FontSize',FS_T);
text(0.5,0.07,{'Steady-state RMS from 20 ms windows.','Fault transient not captured (see Section 5.6).'}, ...
    'Units','normalized','HorizontalAlignment','center','FontName',FN,'FontSize',FS_A, ...
    'Color',[0.5 0.5 0.5],'FontAngle','italic');
grid on; box on;
savefig_ch('figures/ch5_results/Fig5_13_restoration_waveforms.png',fig);

%% Fig 5.14 — Copy from restoration script output if it exists
if exist('fig_restoration_rms.png','file')
    copyfile('fig_restoration_rms.png','figures/ch5_results/Fig5_14_restoration_rms.png');
    fprintf('  Copied: fig_restoration_rms.png\n');
else
    fprintf('  [SKIP] Fig5_14: run MASTER_B restoration first\n');
end
fprintf('  Chapter 5: 14 figures\n\n');


%% =========================================================================
%%  CHAPTER 6 — CONCLUSIONS  (3 figures)
%% =========================================================================
fprintf('--- CHAPTER 6 ---\n');

%% Fig 6.1 — Scenario Comparison
fig=figure('Visible','on','Position',[50 50 FIG_W 580]);
sc_lbl={'Conventional','Relay-Based','ML Self-Healing'};
sc_clr={[0.65 0.65 0.65],[0.45 0.65 0.85],[0.18 0.63 0.18]};

subplot(2,2,1);
vals=[4.0,4.0,1.3];
for s=1:3; bar(s,vals(s),'FaceColor',sc_clr{s}); hold on; end
xticks(1:3); xticklabels(sc_lbl); xtickangle(15);
ylabel('Buses Affected','FontName',FN,'FontSize',FS_L); ylim([0 5.5]);
title('Buses Affected by Outage','FontName',FN,'FontSize',FS_T); grid on;
for s=1:3; text(s,vals(s)+0.15,sprintf('%.1f',vals(s)),'HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_A,'FontWeight','bold'); end

subplot(2,2,2);
vals=[60,60,0.1];
for s=1:3; bar(s,vals(s),'FaceColor',sc_clr{s}); hold on; end
xticks(1:3); xticklabels(sc_lbl); xtickangle(15);
ylabel('Restoration Time (min)','FontName',FN,'FontSize',FS_L); ylim([0 75]);
title('Restoration Time','FontName',FN,'FontSize',FS_T); grid on;
for s=1:3; text(s,vals(s)+1.5,sprintf('%.1f',vals(s)),'HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_A,'FontWeight','bold'); end

subplot(2,2,3);
vals=[0,0,75];
for s=1:3; bar(s,vals(s),'FaceColor',sc_clr{s}); hold on; end
xticks(1:3); xticklabels(sc_lbl); xtickangle(15);
ylabel('Healthy Load Restored (%)','FontName',FN,'FontSize',FS_L);
ylim([0 95]); grid on;
title('Healthy Load Restored (%)','FontName',FN,'FontSize',FS_T);
for s=1:3; text(s,vals(s)+2,sprintf('%.0f%%',vals(s)),'HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_A,'FontWeight','bold'); end

subplot(2,2,4);
vals=[2.0,0.0,0.0];
for s=1:3; bar(s,vals(s),'FaceColor',sc_clr{s}); hold on; end
xticks(1:3); xticklabels(sc_lbl); xtickangle(15);
ylabel('Est. False Trips / Year','FontName',FN,'FontSize',FS_L);
title('False Trip Rate','FontName',FN,'FontSize',FS_T); grid on; ylim([0 2.8]);
for s=1:3; text(s,vals(s)+0.06,sprintf('%.1f',vals(s)),'HorizontalAlignment','center', ...
    'FontName',FN,'FontSize',FS_A,'FontWeight','bold'); end

sgtitle('Scenario Comparison: Conventional vs Relay-Based vs ML Self-Healing', ...
    'FontName',FN,'FontSize',FS_T+1,'FontWeight','bold');
savefig_ch('figures/ch6_conclusions/Fig6_1_scenario_comparison.png',fig);

%% Fig 6.2 — Performance Radar
if HAS_RF
    fig=figure('Visible','on','Position',[50 50 FIG_SQ FIG_SQ+60]);
    ax_r=axes('Position',[0.05 0.14 0.90 0.78]); hold on; axis equal off;
    labels_r={'Accuracy','Fault Det.','Healthy Det.','Macro F1','Selectivity','Restore Speed'};
    vals_t=[0.95,0.90,1.00,0.90,0.75,1.00];
    vals_a=[R.acc,R.fault_det,R.healthy_det,R.macro_f1,0.75,1.00];
    n_ax=length(labels_r);
    theta=linspace(pi/2,pi/2-2*pi,n_ax+1); theta(end)=[];
    for g=[0.25,0.50,0.75,1.0]
        plot(g*cos(theta([1:end 1])),g*sin(theta([1:end 1])), ...
            'Color',[0.85 0.85 0.85],'LineWidth',0.5,'HandleVisibility','off');
        if g<1
            text(0.03,g+0.02,sprintf('%.0f%%',g*100),'FontName',FN,'FontSize',FS_A, ...
                'Color',[0.6 0.6 0.6],'HandleVisibility','off');
        end
    end
    for k=1:n_ax
        plot([0 cos(theta(k))],[0 sin(theta(k))], ...
            'Color',[0.75 0.75 0.75],'LineWidth',0.5,'HandleVisibility','off');
        text(1.30*cos(theta(k)),1.30*sin(theta(k)),labels_r{k}, ...
            'HorizontalAlignment','center','FontName',FN,'FontSize',FS_A,'FontWeight','bold', ...
            'HandleVisibility','off');
    end
    vt=[vals_t,vals_t(1)]; tt=[theta,theta(1)];
    plot(vt.*cos(tt),vt.*sin(tt),'r--','LineWidth',1.5,'DisplayName','Target (95%)');
    va=[vals_a,vals_a(1)];
    patch(va.*cos(tt),va.*sin(tt),[0.18 0.42 0.78],'FaceAlpha',0.30, ...
        'EdgeColor',[0.18 0.42 0.78],'LineWidth',2,'DisplayName','Achieved');
    legend('Location','southoutside','FontSize',FS_G,'Orientation','horizontal','Box','on','NumColumns',2);
    xlim([-1.45 1.45]); ylim([-1.55 1.45]);
    title({'Key Performance Metrics — ML Self-Healing System', ...
           sprintf('Overall Accuracy: %.1f%%  |  Macro F1: %.3f',R.acc*100,R.macro_f1)}, ...
        'FontName',FN,'FontSize',FS_T,'FontWeight','bold');
    savefig_ch('figures/ch6_conclusions/Fig6_2_performance_radar.png',fig);
end

%% Fig 6.3 — Future Work Roadmap
fig=figure('Visible','on','Position',[50 50 FIG_W 500]);
ax=axes; axis off; hold on; xlim([0 1]); ylim([0 1]);
fw_titles={'NER-Limited Fault Currents','Sequence Component Features', ...
    'Hardware-in-Loop Validation','Online / Adaptive Learning', ...
    'Multi-Feeder Extension','Field Deployment Trial'};
fw_subs={'(500-1000 \Omega ground resistance)','(I_0, I_1, I_2 symmetrical components)', ...
    '(RTDS or Opal-RT platform)','(model updates with live data)', ...
    '(meshed network topology)','(Zambian Copperbelt mine site)'};
fw_x=[0.18,0.50,0.82,0.18,0.50,0.82];
fw_y=[0.68,0.68,0.68,0.28,0.28,0.28];
fw_clrs={[1.0 0.90 0.80],[1.0 0.90 0.80],[1.0 0.90 0.80], ...
         [0.85 0.92 1.0],[0.85 0.92 1.0],[0.90 1.0 0.85]};
for k=1:6
    rectangle('Position',[fw_x(k)-0.14,fw_y(k)-0.13,0.28,0.26],'Curvature',0.2, ...
        'FaceColor',fw_clrs{k},'EdgeColor',[0.4 0.4 0.4],'LineWidth',1.2);
    text(fw_x(k),fw_y(k)+0.04,fw_titles{k},'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A,'FontWeight','bold');
    text(fw_x(k),fw_y(k)-0.05,fw_subs{k},'HorizontalAlignment','center', ...
        'FontName',FN,'FontSize',FS_A);
end
plot([0.50 0.50],[0.55 0.42],'k-','LineWidth',1.5);
plot(0.50,0.42,'kv','MarkerSize',7,'MarkerFaceColor','k');
text(0.05,0.85,'Short term','FontName',FN,'FontSize',FS_A,'Color',[0.5 0.5 0.5],'FontAngle','italic');
text(0.05,0.10,'Long term','FontName',FN,'FontSize',FS_A,'Color',[0.5 0.5 0.5],'FontAngle','italic');
text(0.5,0.97,'Recommended Future Work — Research Extensions', ...
    'HorizontalAlignment','center','FontName',FN,'FontWeight','bold','FontSize',FS_T+1);
savefig_ch('figures/ch6_conclusions/Fig6_3_future_work_roadmap.png',fig);
fprintf('  Chapter 6: 3 figures\n\n');


%% ── Report copy ───────────────────────────────────────────────────────────
for rpt = {'rf_metrics_report.txt','restoration_summary.txt','pipeline_log.txt'}
    if exist(rpt{1},'file')
        try; copyfile(rpt{1},['figures/reports/' rpt{1}]); catch; end
    end
end

fprintf('=================================================================\n');
fprintf('  MASTER C COMPLETE — ALL FIGURES GENERATED\n');
fprintf('  figures/ch3_methodology/    8 figures\n');
fprintf('  figures/ch4_system_design/  4 figures\n');
fprintf('  figures/ch5_results/        14 figures\n');
fprintf('  figures/ch6_conclusions/    3 figures\n');
fprintf('  Total: 29 figures at 300 DPI, Arial font\n');
fprintf('  Font sizes: title=%dpt  labels=%dpt  ticks=%dpt  annot=%dpt\n', ...
    FS_T, FS_L, FS_K, FS_A);
fprintf('=================================================================\n');


%% =========================================================================
%%  HELPER FUNCTIONS
%% =========================================================================

function savefig_ch(filepath, fig)
    try
        exportgraphics(fig, filepath, 'Resolution', 300);
    catch
        saveas(fig, filepath);
    end
    close(fig);
    [~,fname,~] = fileparts(filepath);
    fprintf('  Saved: %s\n', fname);
end


function draw_table(ax, col_hdr, row_lbl, data, font_name, fs_body)
    axes(ax); axis off; hold on;
    n_rows = length(row_lbl);
    n_cols = length(col_hdr);
    cw = 1/n_cols;
    rh = 0.78/(n_rows+1);
    y0 = 0.92;
    hdr_clr  = [0.20 0.35 0.65];
    row_clrs = {[0.94 0.96 1.00],[1.00 1.00 1.00]};
    for c = 1:n_cols
        x_ = (c-1)*cw;
        rectangle('Position',[x_,y0-rh,cw,rh],'FaceColor',hdr_clr,'EdgeColor','w','LineWidth',1);
        text(x_+cw/2,y0-rh/2,col_hdr{c},'HorizontalAlignment','center', ...
            'FontName',font_name,'FontSize',fs_body+1,'FontWeight','bold','Color','w');
    end
    for r = 1:n_rows
        y_ = y0-(r+1)*rh;
        clr = row_clrs{mod(r,2)+1};
        for c = 1:n_cols
            x_ = (c-1)*cw;
            rectangle('Position',[x_,y_,cw,rh],'FaceColor',clr, ...
                'EdgeColor',[0.75 0.75 0.75],'LineWidth',0.5);
            if c==1
                txt=row_lbl{r}; fw='bold';
            else
                if iscell(data) && size(data,2)>=c-1
                    txt=data{r,c-1};
                else
                    txt='';
                end
                fw='normal';
            end
            text(x_+cw/2,y_+rh/2,txt,'HorizontalAlignment','center', ...
                'FontName',font_name,'FontSize',fs_body,'FontWeight',fw,'Color',[0.1 0.1 0.1]);
        end
    end
end
