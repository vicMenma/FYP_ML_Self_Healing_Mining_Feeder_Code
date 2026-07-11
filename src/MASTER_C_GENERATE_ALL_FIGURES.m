%% =========================================================================
%  MASTER_C_GENERATE_ALL_FIGURES.m   (v4 — final thesis-ready generator, Chapters 4-6 only)
%  ─────────────────────────────────────────────────────────────────────────
%  Thesis: ML-Assisted Self-Healing of a 33/11 kV Mining Distribution Feeder
%  Author: Victoire Chinyanta Chimundu — CU-BEE-100-7229  |  Supervisor: Mr Charles Kasonde
%
%  Generates the thesis figures for Chapters 4-6 (Chapter 3 figure generation disabled):
%    - Simulink model canvas (print -s of the real model)
%    - Block "parameter dialog" summaries recreated cleanly from get_param
%    - Scope-style V/I waveforms at every measurement point (source, T1, T2, B2..B5)
%    - Thesis-ready fault signatures, ML results, and restoration figures
%    - Revised Chapter 6 comparison and performance-summary figures
%    - The 12 severe fault+restoration waveforms rendered from MASTER_B's live data
%  Every figure is wrapped in a safe call so one failure cannot abort the run,
%  and a manifest (figure_manifest.csv) is always written.
%
%  Output tree: outputs_v2_topology/figures/thesis_rewrite/chapter_4|5|6/
%  Note: Chapter 3 and the future-work roadmap are intentionally not generated.
% =========================================================================

clc; close all;
MODEL   = 'mining_feeder_layer_FINAL_baseline';
OUT_ROOT = fullfile(pwd,'outputs_v2_topology');
FIGROOT  = fullfile(OUT_ROOT,'figures','thesis_rewrite');
CH = struct('c4',fullfile(FIGROOT,'chapter_4'), ...
            'c5',fullfile(FIGROOT,'chapter_5'),'c6',fullfile(FIGROOT,'chapter_6'));
fn=fieldnames(CH); for i=1:numel(fn); if ~exist(CH.(fn{i}),'dir'); mkdir(CH.(fn{i})); end; end
MAN = {};

load_system(MODEL);
BL = discover_blocks(MODEL);

% measurement points: label, chapter-dir, V-signal candidates, I-signal candidates
PTS = { ...
 '33kV Source', CH.c4, {'RMS_V_33KV_Source'}, {'RMS_I_33KV_Source'}, 'source'; ...
 'T1 11kV',     CH.c4, {'RMS_V_T1'},          {'RMS_I_T1'},          'T1'; ...
 'T2 11kV',     CH.c4, {'RMS_V_T2'},          {'RMS_I_T2'},          'T2'; ...
 'Bus B2',      CH.c4, {'RMS_V_B2'},          {'RMS_I_B2'},          'B2'; ...
 'Bus B3',      CH.c4, {'RMS_V_B3'},          {'RMS_I_B3'},          'B3'; ...
 'Bus B4',      CH.c4, {'RMS_V_B4'},          {'RMS_I_B4'},          'B4'; ...
 'Bus B5',      CH.c4, {'RMS_V_B5','RMS_V_SXEW'}, {'RMS_I_B5','RMS_I_SXEW'}, 'B5'};

%% ================================================== CH3: TOPOLOGY ========
% Chapter 3 topology figures are intentionally NOT generated in this version.
% The previously prepared topology / SLD / protection-zone graphics are kept
% for manual use, but MASTER_C now starts automated generation from Chapter 4.

%% ================================================== CH4: MODEL CANVAS =======
fout=fullfile(CH.c4,'Figure_4_01_full_simulink_model.png');
if safefig(fout,@(f) print(['-s' MODEL],'-dpng','-r150',f))
    MAN=addrow(MAN,'Figure_4_01','Full Simulink model of the sectionalised feeder','simulink_screenshot',MODEL,relp(fout));
end

%% ================================================== CH4: PARAMETER TABLES ===
grp = { ...
 'Figure_4_02','Source parameters',            @() param_rows(MODEL,{{namef(MODEL,'33KV_Source'),{}}}); ...
 'Figure_4_03','Transformer T1 parameters',    @() param_rows(MODEL,{{namef(MODEL,'T1'),{}}}); ...
 'Figure_4_04','Transformer T2 parameters',    @() param_rows(MODEL,{{namef(MODEL,'T2'),{}}}); ...
 'Figure_4_05','Section breaker parameters',   @() breaker_rows(BL,{'CB_MAIN','CB_BUS1_B3','CB_BUS1_B4','CB_T2_BUS5'}); ...
 'Figure_4_06','Tie-switch parameters',        @() breaker_rows(BL,{'TIE'}); ...
 'Figure_4_07','Load parameters (DL_B2..B5)',  @() load_rows(BL); ...
 'Figure_4_08','Fault block parameters',       @() fault_rows(BL); ...
 'Figure_4_09','Line (PI section) parameters', @() line_rows(MODEL); ...
 'Figure_4_10','RMS measurement configuration',@() rms_rows(MODEL); ...
 'Figure_4_11','Solver / model configuration', @() solver_rows(MODEL) };
for i=1:size(grp,1)
    fout=fullfile(CH.c4,[grp{i,1} '_' slug(grp{i,2}) '.png']);
    rows = safeeval(grp{i,3});
    if ~isempty(rows) && safefig(fout,@(f) table_figure(grp{i,2},rows,f))
        MAN=addrow(MAN,grp{i,1},grp{i,2},'get_param_table','(model blocks)',relp(fout));
    end
end

%% ================================================== CH4: HEALTHY WAVEFORMS ==
set_normal_state(BL); clear_all_faults(BL); set_loads(BL,1.0);
sH = simrun(MODEL);
for i=1:size(PTS,1)
    fout=fullfile(PTS{i,2}, sprintf('Figure_4_1%d_healthy_%s_VI.png', i+1, PTS{i,5}));
    if safefig(fout, @(f) scope_fig(sH, PTS{i,3}, PTS{i,4}, PTS{i,1}, 'Healthy', f))
        MAN=addrow(MAN, sprintf('Figure_4_1%d',i+1), ...
            sprintf('Healthy RMS voltage & current — %s', PTS{i,1}), ...
            'logged_signal', strjoin([PTS{i,3} PTS{i,4}],','), relp(fout));
    end
end

%% ================================================== CH5: FAULT SIGNATURES ===
dfile = fullfile(OUT_ROOT,'fault_dataset_v2.mat');
if exist(dfile,'file')
    fout=fullfile(CH.c5,'Figure_5_08_voltage_sag_by_class.png');
    if safefig(fout,@(f) signature_fig(dfile,'V',f))
        MAN=addrow(MAN,'Figure_5_08','Per-class voltage signature (RMS)','data','fault_dataset_v2.mat',relp(fout)); end
    fout=fullfile(CH.c5,'Figure_5_09_current_rise_by_class.png');
    if safefig(fout,@(f) signature_fig(dfile,'I',f))
        MAN=addrow(MAN,'Figure_5_09','Per-class current signature (RMS)','data','fault_dataset_v2.mat',relp(fout)); end
end

%% ================================================== CH5: ML FIGURES =========
if exist(fullfile(OUT_ROOT,'confusion_v2.mat'),'file')
    Sc=load(fullfile(OUT_ROOT,'confusion_v2.mat'));
    fout=fullfile(CH.c5,'Figure_5_01_confusion_matrix.png');
    if safefig(fout,@(f) plot_confusion(Sc.Cm,Sc.CLASS_NAMES,f)); MAN=addrow(MAN,'Figure_5_01','Test-set confusion matrix','data','confusion_v2.mat',relp(fout)); end
    fout=fullfile(CH.c5,'Figure_5_02_per_class_metrics.png');
    if safefig(fout,@(f) plot_prf_from_cm(Sc.Cm,Sc.CLASS_NAMES,f)); MAN=addrow(MAN,'Figure_5_02','Per-class precision/recall/F1','data','confusion_v2.mat',relp(fout)); end
end
if exist(fullfile(OUT_ROOT,'feature_importance_v2.mat'),'file')
    Si=load(fullfile(OUT_ROOT,'feature_importance_v2.mat'));
    fout=fullfile(CH.c5,'Figure_5_03_feature_importance.png');
    if safefig(fout,@(f) plot_importance(Si.imp,Si.featNames,f)); MAN=addrow(MAN,'Figure_5_03','OOB permutation feature importance','data','feature_importance_v2.mat',relp(fout)); end
end
if exist(fullfile(OUT_ROOT,'oob_error_curve_v2.mat'),'file')
    So=load(fullfile(OUT_ROOT,'oob_error_curve_v2.mat'));
    fout=fullfile(CH.c5,'Figure_5_06_oob_error_curve.png');
    if safefig(fout,@(f) plot_curve(So.oobErr,'Number of trees','OOB error','Random Forest OOB error convergence',f)); MAN=addrow(MAN,'Figure_5_06','Random Forest OOB error convergence','data','oob_error_curve_v2.mat',relp(fout)); end
end
if exist(fullfile(OUT_ROOT,'cv_accuracy_v2.mat'),'file')
    Sv=load(fullfile(OUT_ROOT,'cv_accuracy_v2.mat'));
    fout=fullfile(CH.c5,'Figure_5_07_cv_accuracy.png');
    if safefig(fout,@(f) plot_cv(Sv.cvACC,f)); MAN=addrow(MAN,'Figure_5_07','Five-fold cross-validation accuracy','data','cv_accuracy_v2.mat',relp(fout)); end
end

%% ================================================== CH5: RESTORATION ========
rcsv=fullfile(OUT_ROOT,'restoration_results_v2.csv');
if exist(rcsv,'file')
    Rt=readtable(rcsv);
    fout=fullfile(CH.c5,'Figure_5_04_restoration_decision_summary.png');
    if safefig(fout,@(f) plot_restoration_summary(Rt,f))
        MAN=addrow(MAN,'Figure_5_04','Restoration decision outcomes by status','data','restoration_results_v2.csv',relp(fout)); end
    fout=fullfile(CH.c5,'Figure_5_05_post_restoration_voltage_comparison.png');
    if safefig(fout,@(f) plot_post_restoration_v(Rt,f))
        MAN=addrow(MAN,'Figure_5_05','Post-restoration voltage (eligible RESTORED cases)','data','restoration_results_v2.csv',relp(fout)); end
end

%% ============================ CH5: SEVERE FAULT+RESTORATION WAVEFORMS (12) ==
% MASTER_B captured these during its LIVE restoration simulations; we only render.
WAVE=fullfile(OUT_ROOT,'waveforms_v2'); wf=dir(fullfile(WAVE,'wave_*.mat'));
if isempty(wf)
    warning('No waveform data in %s. Run MASTER_B first to capture the 12 severe cases.',WAVE);
end
for i=1:numel(wf)
    W=load(fullfile(WAVE,wf(i).name));
    fout=fullfile(CH.c5,sprintf('Figure_5B_%02d_%s_%s_fault_restoration.png',W.nfig,W.ftype,W.zone));
    if safefig(fout,@(f) plot_fault_restoration(W,f))
        MAN=addrow(MAN,sprintf('Figure_5B_%02d',W.nfig), ...
            sprintf('%s fault at %s — fault & restoration waveform',W.ftype,W.zone), ...
            'logged_signal (MASTER_B live sim)',wf(i).name,relp(fout));
    end
end

%% ================================================== CH6: CONCLUSIONS ========
fout=fullfile(CH.c6,'Figure_6_01_scenario_comparison.png');
if safefig(fout,@(f) draw_scenarios(OUT_ROOT,f))
    MAN=addrow(MAN,'Figure_6_01', ...
        'Healthy zones remaining de-energised after fault isolation', ...
        'data','restoration_results_v2.csv',relp(fout));
end

fout=fullfile(CH.c6,'Figure_6_02_performance_summary.png');
if safefig(fout,@(f) draw_performance(OUT_ROOT,f))
    MAN=addrow(MAN,'Figure_6_02', ...
        'Computed performance summary of the proposed protection scheme', ...
        'data','rf_model_v2.mat + restoration_results_v2.csv',relp(fout));
end

% Figure 6.03 (future-work roadmap) is intentionally disabled. Remove any
% stale copy from an earlier MASTER_C run so it cannot be mistaken for a
% newly generated thesis figure.
oldRoadmaps=dir(fullfile(CH.c6,'Figure_6_03_future_work_roadmap*.png'));
for k=1:numel(oldRoadmaps)
    delete(fullfile(oldRoadmaps(k).folder,oldRoadmaps(k).name));
end

%% ================================================== MANIFEST ================
manFile=fullfile(OUT_ROOT,'figures','figure_manifest.csv');
if ~isempty(MAN)
    writetable(cell2table(MAN,'VariableNames', ...
        {'figure_id','suggested_caption','source_type','block_or_data_source','output_file'}), manFile);
end
fprintf('\nMASTER_C (v4) complete. %d figures generated (Chapters 4-6; roadmap disabled).\nManifest -> %s\n', size(MAN,1), manFile);

%% =========================================================================
%%  LOCAL FUNCTIONS
%% =========================================================================
function M = addrow(M,id,cap,st,src,out)
    M(end+1,:) = {id,cap,st,src,out};
end
function ok = safefig(fout, fn)
    ok=false;
    try, fn(fout); ok=true;
    catch ME, warning('Figure %s failed: %s', fout, ME.message); end
end
function r = safeeval(fn)
    try, r=fn(); catch, r={}; end
end
function s = slug(t)
    s=lower(regexprep(t,'[^a-zA-Z0-9]+','_')); s=regexprep(s,'^_|_$','');
end
function p=relp(f); p=strrep(f,[pwd filesep],''); end
function h=namef(MODEL,tok)
% Resolve a root-level block from the LIVE model by normalised name:
% exact match first, then prefix, then substring — so 'T2' resolves to the
% 'T2 33KV-11KV AUX' transformer, not CB_T2_BUS5 or the T2 measurement.
% (No BlockType filter: linked library blocks do not report BlockType
% 'Reference' at runtime.)
    h=''; blks=find_system(MODEL,'SearchDepth',1);
    nms=repmat({''},numel(blks),1);
    for i=1:numel(blks)
        if ~strcmp(blks{i},MODEL)
            nms{i}=strtrim(regexprep(get_param(blks{i},'Name'),'\s+',' '));
        end
    end
    for i=1:numel(blks); if strcmp(nms{i},tok);     h=blks{i}; return; end; end
    for i=1:numel(blks); if startsWith(nms{i},tok); h=blks{i}; return; end; end
    for i=1:numel(blks); if contains(nms{i},tok);   h=blks{i}; return; end; end
end

% -------------------------- schematic drawings ----------------------------
function draw_topology(fout)
    fig=figure('Visible','off','Position',[40 40 1120 470],'Color','w'); ax=axes(fig); hold(ax,'on'); axis(ax,'off');
    B=@(x,y,w,h,c) rectangle(ax,'Position',[x y w h],'Curvature',0.12,'FaceColor',c,'EdgeColor','k','LineWidth',1);
    Tx=@(x,y,s) text(ax,x,y,s,'HorizontalAlignment','center','FontSize',9,'FontWeight','bold');
    L=@(x1,y1,x2,y2,varargin) plot(ax,[x1 x2],[y1 y2],'k-','LineWidth',1.6,varargin{:});
    c1=[.80 .90 1]; c2=[1 .88 .78];
    B(0.2,3,1,.8,c1);Tx(.7,3.4,'33 kV Src');L(1.2,3.4,1.8,3.4);
    B(1.8,3,1,.8,c1);Tx(2.3,3.4,'T1');L(2.8,3.4,3.4,3.4);
    B(3.4,3,1,.6,c2);Tx(3.9,3.3,'CB\_MAIN');L(4.4,3.3,5.0,3.3);
    B(5.0,3,.9,.6,c1);Tx(5.45,3.3,'B2');L(5.9,3.3,6.4,3.3);
    B(6.4,3,1,.6,c2);Tx(6.9,3.3,'CB\_B3');L(7.4,3.3,7.9,3.3);
    B(7.9,3,.9,.6,c1);Tx(8.35,3.3,'B3');L(8.8,3.3,9.3,3.3);
    B(9.3,3,1,.6,c2);Tx(9.8,3.3,'CB\_B4');L(10.3,3.3,10.8,3.3);
    B(10.8,3,.9,.6,c1);Tx(11.25,3.3,'B4');
    B(1.8,1,1,.8,c1);Tx(2.3,1.4,'T2 AUX');L(2.8,1.4,3.4,1.4);
    B(3.4,1,1,.6,c2);Tx(3.9,1.3,'CB\_T2');L(4.4,1.3,10.8,1.3);
    B(10.8,1,.9,.6,c1);Tx(11.25,1.3,'B5');
    plot(ax,[11.25 11.25],[3.0 1.6],'r--','LineWidth',1.8);Tx(11.85,2.3,'TIE (NO)');
    xlim(ax,[0 12.8]); ylim(ax,[.5 4.2]);
    title(ax,'Sectionalised radial feeder — T1 main (B2-B3-B4), T2 auxiliary (B5), B4-B5 tie');
    exportgraphics(fig,fout,'Resolution',200); close(fig);
end
function draw_sld(fout)
    fig=figure('Visible','off','Position',[40 40 900 560],'Color','w'); ax=axes(fig); hold(ax,'on'); axis(ax,'off');
    plot(ax,[1 1],[1 9],'k-','LineWidth',2); text(ax,1.1,9,'33 kV busbar','FontWeight','bold');
    for k=0:3
        y=7-k*1.8; plot(ax,[1 3],[y y],'k-','LineWidth',1.5);
        text(ax,3.1,y,sprintf('Zone B%d',k+2),'FontWeight','bold');
    end
    title(ax,'Simplified single-line diagram (illustrative)');
    xlim(ax,[0 6]); ylim(ax,[0 10]);
    exportgraphics(fig,fout,'Resolution',200); close(fig);
end
function draw_zones(fout)
    fig=figure('Visible','off','Position',[40 40 900 480],'Color','w'); ax=axes(fig); hold(ax,'on'); axis(ax,'off');
    cols=lines(4); nm={'B2','B3','B4','B5'};
    for k=1:4
        rectangle(ax,'Position',[k*2-1 3 1.6 1.2],'Curvature',0.15,'FaceColor',cols(k,:),'EdgeColor','k');
        text(ax,k*2-0.2,3.6,nm{k},'HorizontalAlignment','center','FontWeight','bold','Color','w');
    end
    text(ax,4,5.2,'Protection zones — one fault zone isolated at a time','FontWeight','bold','HorizontalAlignment','center');
    plot(ax,[6.6 8.9],[3.6 3.6],'r--','LineWidth',1.8); text(ax,7.5,4,'B4-B5 tie (NO)','Color','r','HorizontalAlignment','center');
    xlim(ax,[0 10]); ylim(ax,[2 6]); exportgraphics(fig,fout,'Resolution',200); close(fig);
end
function draw_scenarios(OUT_ROOT, fout)
% Comparison computed from restoration_results_v2.csv. An annotated matrix
% is used instead of grouped bars so zero de-energised zones remain visible.
    T=readtable(fullfile(OUT_ROOT,'restoration_results_v2.csv'));
    zones={'B2','B3','B4','B5'};
    zoneCol=strtrim(string(T.Zone));

    conventional=[2 1 0 0];
    proposed=nan(1,4);

    for k=1:4
        i=find(zoneCol==string(zones{k}) & abs(T.LoadMult-1.00)<1e-6,1);
        if isempty(i); continue; end

        healthy=setdiff(zones,zones(k),'stable');
        energised=[split_zones(table_text(T,'RestoredZones',i)); ...
                   split_zones(table_text(T,'RemainsOnT1',i))];

        if ~strcmp(zones{k},'B5')
            energised{end+1,1}='B5'; %#ok<AGROW>
        end
        energised=unique(energised,'stable');
        proposed(k)=numel(setdiff(healthy,energised));
    end

    M=[conventional; proposed];
    finiteVals=M(isfinite(M));
    if isempty(finiteVals); maxVal=3; else; maxVal=max(3,max(finiteVals)); end

    fig=figure('Visible','off','Position',[40 40 1050 520],'Color','w');
    ax=axes(fig,'Position',[0.17 0.22 0.69 0.60]);
    imagesc(ax,M,[0 maxVal]);

    nmap=256;
    cmap=[linspace(0.96,0.10,nmap)' linspace(0.98,0.45,nmap)' ones(nmap,1)];
    colormap(ax,cmap);
    cb=colorbar(ax);
    cb.Label.String='Number of healthy zones remaining de-energised';

    set(ax,'XTick',1:4,'XTickLabel',zones, ...
        'YTick',1:2,'YTickLabel',{'Conventional wide trip','Proposed self-healing scheme'}, ...
        'FontName','Times New Roman','FontSize',12,'Layer','top','Box','on');
    xlabel(ax,'Faulted zone');
    ylabel(ax,'Protection strategy');

    for r=1:2
        for c=1:4
            if isnan(M(r,c))
                lab='N/A'; tc=[0.25 0.25 0.25];
            else
                lab=sprintf('%d',M(r,c));
                if M(r,c)>=0.55*maxVal; tc='w'; else; tc='k'; end
            end
            text(ax,c,r,lab,'HorizontalAlignment','center', ...
                'VerticalAlignment','middle','FontWeight','bold', ...
                'FontSize',16,'Color',tc,'FontName','Times New Roman');
        end
    end

    title(ax,'Healthy zones remaining de-energised after fault isolation', ...
        'FontWeight','bold','FontSize',16);
    text(ax,0.5,-0.23,'Load multiplier = 1.00; lower values indicate better service continuity', ...
        'Units','normalized','HorizontalAlignment','center', ...
        'FontAngle','italic','FontSize',10,'FontName','Times New Roman', ...
        'Color',[0.30 0.30 0.30]);

    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function c = split_zones(s)
    if isempty(s); c = {}; else; c = strsplit(char(s),'+')'; end
    c = c(~cellfun(@isempty,c));
end
function draw_performance(OUT_ROOT, fout)
% KPI summary derived only from saved model and restoration results.
    acc=NaN;
    try
        S=load(fullfile(OUT_ROOT,'rf_model_v2.mat'));
        if isfield(S,'acc'); acc=double(S.acc); end
    catch
    end

    nTotal=0; nCorrect=0; nIsolated=0; nB45=0; nTieSafe=0; nRestored=0;
    haveRestoration=false;
    try
        T=readtable(fullfile(OUT_ROOT,'restoration_results_v2.csv'));
        haveRestoration=true;
        nTotal=height(T);

        pred=strtrim(upper(string(T.PredictionCorrect)));
        nCorrect=sum(pred=="YES");

        vFault=double(T.FaultBusVoltage_pu);
        nIsolated=sum(vFault<0.8);

        z=strtrim(upper(string(T.Zone)));
        b45=ismember(z,["B4","B5"]);
        nB45=sum(b45);
        tie=strtrim(upper(string(T.TieState)));
        nTieSafe=sum(tie(b45)=="OPEN");

        status=strtrim(upper(string(T.Status)));
        nRestored=sum(status=="RESTORED");
    catch
    end

    if isfinite(acc)
        if acc<=1.0; accPct=100*acc; else; accPct=acc; end
        accValue=sprintf('%.2f%%',accPct);
        accDetail='Independent test-set classification accuracy';
        accState='info';
    else
        accValue='Unavailable';
        accDetail='Run MASTER_B to generate rf_model_v2.mat';
        accState='neutral';
    end

    if haveRestoration && nTotal>0
        predValue=sprintf('%s  (%d/%d)',passfail(nCorrect==nTotal),nCorrect,nTotal);
        isoValue=sprintf('%s  (%d/%d)',passfail(nIsolated==nTotal),nIsolated,nTotal);
        if nB45>0
            tieValue=sprintf('%s  (%d/%d)',passfail(nTieSafe==nB45),nTieSafe,nB45);
        else
            tieValue='N/A';
        end
        restValue=sprintf('%d/%d  (%.1f%%)',nRestored,nTotal,100*nRestored/nTotal);
    else
        predValue='Unavailable'; isoValue='Unavailable'; tieValue='Unavailable'; restValue='Unavailable';
    end

    metrics={ ...
        'Test-set classification accuracy', accValue, accDetail, accState; ...
        'Correct fault-zone prediction', predValue, 'All restoration scenarios', state_from_value(predValue); ...
        'Faulted-zone isolation', isoValue, 'Fault-bus voltage below 0.80 pu', state_from_value(isoValue); ...
        'Tie security for B4/B5 faults', tieValue, 'Tie remains open for terminal-zone faults', state_from_value(tieValue); ...
        'Successful restoration actions', restValue, 'Scenarios ending with status RESTORED', 'info'};

    fig=figure('Visible','off','Position',[40 40 1120 680],'Color','w');
    ax=axes(fig,'Position',[0 0 1 1]); hold(ax,'on'); axis(ax,'off');
    xlim(ax,[0 1]); ylim(ax,[0 1]);

    text(ax,0.5,0.94,'Computed performance summary', ...
        'HorizontalAlignment','center','FontWeight','bold', ...
        'FontSize',22,'FontName','Times New Roman');
    text(ax,0.5,0.895,'Results derived from rf_model_v2.mat and restoration_results_v2.csv', ...
        'HorizontalAlignment','center','FontAngle','italic', ...
        'FontSize',11,'FontName','Times New Roman','Color',[0.35 0.35 0.35]);

    y0=0.77; dy=0.145;
    for k=1:size(metrics,1)
        y=y0-(k-1)*dy;
        [face,edge,valcol]=status_colours(metrics{k,4});
        rectangle(ax,'Position',[0.07 y-0.052 0.86 0.108], ...
            'Curvature',[0.08 0.08],'FaceColor',face,'EdgeColor',edge,'LineWidth',1.2);
        text(ax,0.10,y+0.018,metrics{k,1}, ...
            'FontWeight','bold','FontSize',13,'FontName','Times New Roman', ...
            'VerticalAlignment','middle');
        text(ax,0.10,y-0.024,metrics{k,3}, ...
            'FontSize',10,'FontName','Times New Roman', ...
            'Color',[0.35 0.35 0.35],'VerticalAlignment','middle');
        text(ax,0.89,y,metrics{k,2}, ...
            'HorizontalAlignment','right','VerticalAlignment','middle', ...
            'FontWeight','bold','FontSize',14,'FontName','Times New Roman', ...
            'Color',valcol,'Interpreter','none');
    end

    text(ax,0.5,0.055,'PASS indicates that every evaluated scenario satisfied the stated criterion.', ...
        'HorizontalAlignment','center','FontAngle','italic', ...
        'FontSize',10,'FontName','Times New Roman','Color',[0.35 0.35 0.35]);

    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function s = passfail(b); if b; s='PASS'; else; s='FAIL'; end; end
function s = table_text(T, varName, row)
    s='';
    if ~ismember(varName,T.Properties.VariableNames); return; end
    raw=T.(varName)(row);
    if iscell(raw); raw=raw{1}; end
    if iscategorical(raw); raw=char(raw); end
    if isstring(raw)
        if ismissing(raw); return; end
        raw=char(raw);
    end
    if isnumeric(raw)
        if isempty(raw) || all(isnan(raw)); return; end
        raw=num2str(raw);
    end
    s=strtrim(char(raw));
end

function st = state_from_value(v)
    u=upper(string(v));
    if startsWith(u,'PASS')
        st='pass';
    elseif startsWith(u,'FAIL')
        st='fail';
    else
        st='neutral';
    end
end

function [face,edge,valcol] = status_colours(st)
    switch lower(char(st))
        case 'pass'
            face=[0.92 0.98 0.93]; edge=[0.25 0.62 0.31]; valcol=[0.10 0.45 0.18];
        case 'fail'
            face=[1.00 0.93 0.93]; edge=[0.78 0.25 0.25]; valcol=[0.65 0.08 0.08];
        case 'info'
            face=[0.93 0.96 1.00]; edge=[0.30 0.50 0.78]; valcol=[0.10 0.30 0.62];
        otherwise
            face=[0.96 0.96 0.96]; edge=[0.60 0.60 0.60]; valcol=[0.30 0.30 0.30];
    end
end

% ----------------------------- parameter tables ---------------------------
function rows = param_rows(MODEL, spec)
    rows={};
    for i=1:numel(spec)
        blk=spec{i}{1}; if isempty(blk); continue; end
        if ~contains(blk,'/'); blk=[MODEL '/' blk]; end
        try mn=get_param(blk,'MaskNames'); catch; mn={}; end
        wanted=spec{i}{2}; if isempty(wanted); wanted=mn; end
        for j=1:numel(wanted)
            if any(strcmp(mn,wanted{j}))
                rows(end+1,:)={lastname(blk),wanted{j},tostr(get_param(blk,wanted{j}))}; %#ok<AGROW>
            end
        end
    end
end
function rows = breaker_rows(BL, keys)
    rows={};
    for i=1:numel(keys)
        if strcmp(keys{i},'TIE'); b=BL.cb.TIE; nm='TIE'; else; b=BL.cb.(keys{i}); nm=keys{i}; end
        for pn={'InitialState','SwitchA','SwitchB','SwitchC','External','BreakerResistance'}
            rows(end+1,:)={nm,pn{1},sgp(b,pn{1})}; %#ok<AGROW>
        end
    end
end
function rows = load_rows(BL)
    rows={}; z={'B2','B3','B4','B5'};
    for i=1:numel(z)
        if ~isfield(BL.load,z{i}); continue; end
        b=BL.load.(z{i});
        rows(end+1,:)={['DL_' z{i}],'ActivePower(W)',sgp(b,'ActivePower')}; %#ok<AGROW>
        rows(end+1,:)={['DL_' z{i}],'InductiveReactivePower(var)',sgp(b,'InductiveReactivePower')}; %#ok<AGROW>
        rows(end+1,:)={['DL_' z{i}],'NominalVoltage(V)',sgp(b,'NominalVoltage')}; %#ok<AGROW>
    end
end

function rows = fault_rows(BL)
    rows={}; z={'B2','B3','B4','B5'};
    for i=1:numel(z)
        if ~isfield(BL.fault,z{i}); continue; end
        b=BL.fault.(z{i});
        for pn={'FaultResistance','GroundResistance','FaultA','FaultB','FaultC','GroundFault'}
            rows(end+1,:)={['Fault_' z{i}],pn{1},sgp(b,pn{1})}; %#ok<AGROW>
        end
    end
end

function rows = line_rows(MODEL)
    rows={}; want={'LINE_B1_B2','LINE_B1_B3','LINE_B1_B4','LINE_B5_TIE'};
    for i=1:numel(want)
        b=localget(MODEL,want{i});
        if isempty(b); continue; end
        for pn={'Frequency','Length','Resistance','Inductance'}
            v=sgp(b,pn{1});
            if ~strcmp(v,'(n/a)')
                rows(end+1,:)={lastname(b),pn{1},v}; %#ok<AGROW>
            end
        end
    end
    if isempty(rows); rows={'LINE_*','(PI section line)','see model'}; end
end

function rows = rms_rows(MODEL)
    rows={};
    reps={{'RMS_V_B2','Voltage RMS blocks'},{'RMS_I_B2','Current RMS blocks'}};
    wanted={'TrueRMS','Freq','RMSInit','Ts'};
    for i=1:numel(reps)
        b=localget(MODEL,reps{i}{1});
        if isempty(b); continue; end
        try
            mn=get_param(b,'MaskNames');
            for j=1:numel(wanted)
                if any(strcmp(mn,wanted{j}))
                    rows(end+1,:)={reps{i}{2},wanted{j},sgp(b,wanted{j})}; %#ok<AGROW>
                end
            end
        catch
        end
    end
    if isempty(rows); rows={'RMS blocks','Configuration','1-cycle fundamental-frequency RMS measurement'}; end
end

function rows = solver_rows(MODEL)
    rows={};
    for pn={'Solver','SolverType','StopTime','FixedStep','MaxStep','SimulationMode'}
        rows(end+1,:)={'Model configuration',pn{1},tostr(get_param(MODEL,pn{1}))}; %#ok<AGROW>
    end
end

function h=localget(MODEL,nm); h=find_system(MODEL,'SearchDepth',1,'Name',nm); if ~isempty(h); h=getfullname(h{1}); else; h=''; end; end
function v=sgp(b,p); if isempty(b); v='(n/a)'; return; end; try v=get_param(b,p); catch; v='(n/a)'; end; if ~ischar(v); v=mat2str(v); end; end
function s=lastname(b); parts=strsplit(b,'/'); s=regexprep(parts{end},'\s+',' '); end
function s=tostr(v); if ischar(v); s=v; else; s=mat2str(v); end; end

function table_figure(ttl, rows, fout)
    rows = beautify_rows(rows);
    rows = suppress_repeated_blocks(rows);
    n=size(rows,1);

    figH=max(420,140+28*(n+1));
    fig=figure('Visible','off','Position',[40 40 1500 figH],'Color','w');
    ax=axes(fig,'Position',[0 0 1 1]); axis(ax,'off');

    text(ax,0.5,0.965,ttl,'HorizontalAlignment','center', ...
        'FontWeight','bold','FontSize',19,'FontName','Times New Roman');
    text(ax,0.5,0.93,'Parameters extracted directly from the Simulink model', ...
        'HorizontalAlignment','center','FontAngle','italic', ...
        'Color',[0.35 0.35 0.35],'FontSize',11,'FontName','Times New Roman');

    bg=zeros(max(n,1),3);
    for i=1:max(n,1)
        if mod(i,2)==1
            bg(i,:)=[0.980 0.988 0.998];
        else
            bg(i,:)=[0.945 0.965 0.990];
        end
    end

    t=uitable(fig,'Data',rows, ...
        'ColumnName',{'Block','Parameter','Value / setting'}, ...
        'RowName',[], ...
        'Units','normalized','Position',[0.02 0.035 0.96 0.86], ...
        'ColumnWidth',{260 360 760}, ...
        'FontName','Times New Roman','FontSize',11, ...
        'BackgroundColor',bg,'ForegroundColor',[0 0 0]);
    try, t.ColumnEditable=[false false false]; catch, end
    try, t.ColumnFormat={'char','char','char'}; catch, end

    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end

function rows = beautify_rows(rows)
    for i=1:size(rows,1)
        blk = string(rows{i,1});
        prm = string(rows{i,2});
        val = string(rows{i,3});
        rows{i,1} = char(pretty_block_name(blk));
        rows{i,2} = char(pretty_param_name(prm));
        rows{i,3} = char(pretty_value(prm,val));
    end
end

function rows = suppress_repeated_blocks(rows)
    last='';
    for i=1:size(rows,1)
        cur=string(rows{i,1});
        if strcmp(cur,last)
            rows{i,1}='';
        else
            last=cur;
        end
    end
end

function s = pretty_block_name(s)
    s=strrep(string(s),'_','_');
    s=replace(s,'Voltage RMS blocks','RMS voltage blocks');
    s=replace(s,'Current RMS blocks','RMS current blocks');
end

function s = pretty_param_name(p)
    p=string(p);
    p=replace(p,'InternalConnection','Internal connection');
    p=replace(p,'VoltagePhases','Voltage phases');
    p=replace(p,'Voltage_phases','Per-phase voltage expression');
    p=replace(p,'PhaseAngles_phases','Phase angles');
    p=replace(p,'PhaseAngle','Phase angle');
    p=replace(p,'ShortCircuitLevel','Short-circuit level');
    p=replace(p,'BaseVoltage','Base voltage');
    p=replace(p,'XRratio','X/R ratio');
    p=replace(p,'BusType','Bus type');
    p=replace(p,'Prefabc','Per-phase active power reference');
    p=replace(p,'Qrefabc','Per-phase reactive power reference');
    p=replace(p,'Winding1Connection','Winding 1 connection');
    p=replace(p,'Winding2Connection','Winding 2 connection');
    p=replace(p,'CoreType','Core type');
    p=replace(p,'SetSaturation','Enable saturation');
    p=replace(p,'SetInitialFlux','Set initial flux');
    p=replace(p,'InitialFluxes','Initial fluxes');
    p=replace(p,'NominalPower','Nominal power / frequency');
    p=replace(p,'Measurements','Measurements');
    p=replace(p,'BreakLoop','Break loop');
    p=replace(p,'DiscreteSolver','Discrete solver');
    p=replace(p,'TransfoNumber','Transformer number');
    p=replace(p,'InitialState','Initial state');
    p=replace(p,'SwitchA','Switch A');
    p=replace(p,'SwitchB','Switch B');
    p=replace(p,'SwitchC','Switch C');
    p=replace(p,'External','External control');
    p=replace(p,'BreakerResistance','Breaker resistance');
    p=replace(p,'ActivePower(W)','Active power');
    p=replace(p,'InductiveReactivePower(var)','Reactive power');
    p=replace(p,'NominalVoltage(V)','Nominal voltage');
    p=replace(p,'FaultResistance','Fault resistance');
    p=replace(p,'GroundResistance','Ground resistance');
    p=replace(p,'GroundFault','Ground fault');
    p=replace(p,'Length','Length');
    p=replace(p,'Freq','Fundamental frequency');
    p=replace(p,'RMSInit','Initial RMS output');
    p=replace(p,'Ts','Sample time');
    p=replace(p,'StopTime','Stop time');
    p=replace(p,'FixedStep','Fixed-step size');
    p=replace(p,'MaxStep','Maximum step size');
    p=replace(p,'SimulationMode','Simulation mode');
    p=replace(p,'SolverType','Solver type');
end

function s = pretty_value(p, v)
    p=char(string(p));
    s=char(string(v));
    s=strtrim(s);
    if isempty(s)
        s='-'; return;
    end
    if strcmpi(s,'(n/a)')
        s='Not specified'; return;
    end
    switch lower(s)
        case 'on',     s='On'; return;
        case 'off',    s='Off'; return;
        case 'open',   s='Open'; return;
        case 'closed', s='Closed'; return;
        case 'swing',  s='Swing'; return;
        case 'inf',    s='+Inf'; return;
        case '-inf',   s='-Inf'; return;
    end

    num=str2double(s);
    if ~isnan(num)
        lp=lower(regexprep(p,'[^a-zA-Z]',''));
        if contains(lp,'frequency') || strcmpi(p,'Freq')
            s=sprintf('%g Hz',num); return;
        elseif contains(lp,'length')
            s=sprintf('%.2f km',num); return;
        elseif contains(lp,'activepower')
            s=sprintf('%.3f MW',num/1e6); return;
        elseif contains(lp,'reactivepower')
            s=sprintf('%.3f MVAr',num/1e6); return;
        elseif contains(lp,'shortcircuitlevel')
            s=sprintf('%.0f MVA',num/1e6); return;
        elseif contains(lp,'nominalvoltage') || contains(lp,'basevoltage') || strcmpi(p,'Voltage')
            s=sprintf('%.3g kV',num/1e3); return;
        elseif contains(lp,'resistance')
            s=sprintf('%.4g Ω',num); return;
        elseif contains(lp,'inductance') || strcmpi(p,'Lm') || strcmpi(p,'L0')
            s=sprintf('%.4g H',num); return;
        elseif strcmpi(p,'StopTime') || strcmpi(p,'FixedStep') || strcmpi(p,'MaxStep') || strcmpi(p,'Ts')
            s=sprintf('%g s',num); return;
        elseif strcmpi(p,'PhaseAngle')
            s=sprintf('%g°',num); return;
        elseif strcmpi(p,'RMSInit')
            s=sprintf('%g',num); return;
        end
    end

    if strcmpi(p,'NominalPower')
        a=sscanf(strrep(strrep(s,'[',''),']',''),'%f');
        if numel(a)>=2
            s=sprintf('%.0f MVA, %.0f Hz',a(1)/1e6,a(2));
            return;
        end
    end
    if strcmpi(p,'Winding1') || strcmpi(p,'Winding2')
        a=sscanf(strrep(strrep(s,'[',''),']',''),'%f');
        if numel(a)>=3
            s=sprintf('[Vn, R, L] = [%.0f kV, %.4f pu, %.4f pu]',a(1)/1e3,a(2),a(3));
            return;
        end
    end

    s = regexprep(s,'\s+',' ');
end

function scope_fig(sOut, Vc, Ic, label, cond, fout)
    fig=figure('Visible','off','Position',[40 40 920 640],'Color','w');
    subplot(2,1,1); M=getM(sOut,Vc); plot(M(:,1),M(:,2:4),'LineWidth',1.1); grid on; box on;
    ylabel('RMS voltage (V)'); legend({'A','B','C'},'Location','best');
    title(sprintf('%s — %s: RMS voltage', cond, label));
    subplot(2,1,2); M=getM(sOut,Ic); plot(M(:,1),M(:,2:4),'LineWidth',1.1); grid on; box on;
    ylabel('RMS current (A)'); xlabel('Time (s)'); legend({'A','B','C'},'Location','best');
    title(sprintf('%s — %s: RMS current', cond, label));
    exportgraphics(fig,fout,'Resolution',200); close(fig);
end
function signature_fig(dfile, kind, fout)
    S=load(dfile); X=S.X; y=S.y; names=S.featNames;
    idx = find(startsWith(names, [kind '_']));      % V_* or I_*
    cls=0:12; M=zeros(13,numel(idx));
    for c=cls
        M(c+1,:)=mean(X(y==c,idx),1);
    end

    % Use the healthy class as the per-feature reference.
    ref=M(1,:);
    ref(abs(ref)<1e-9)=1e-9;

    if strcmpi(kind,'V')
        H=100*(1-M./ref);
        ttl='Voltage sag relative to the healthy operating point';
        cbtxt='Voltage sag (%)';
    else
        H=M./ref;
        ttl='RMS current relative to the healthy operating point';
        cbtxt='Current ratio (x healthy)';
    end

    fig=figure('Visible','off','Position',[40 40 1180 650],'Color','w');
    ax=axes(fig);
    imagesc(ax,H);
    colormap(ax,parula);
    cb=colorbar(ax);
    cb.Label.String=cbtxt;

    lo=min(H(:)); hi=max(H(:));
    if strcmpi(kind,'V') && lo>0; lo=0; end
    if hi<=lo; hi=lo+1; end
    caxis(ax,[lo hi]);

    set(ax,'YTick',1:13,'YTickLabel',S.CLASS_NAMES, ...
        'XTick',1:numel(idx),'XTickLabel',names(idx), ...
        'XTickLabelRotation',45,'FontSize',9, ...
        'TickLabelInterpreter','none','FontName','Times New Roman', ...
        'Layer','top','Box','on');

    hold(ax,'on');
    for x=[3.5 6.5 9.5]
        xline(ax,x,'k-','LineWidth',0.7);
    end

    title(ax,ttl,'FontWeight','bold');
    xlabel(ax,'Measured feature');
    ylabel(ax,'Fault class');
    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function plot_fault_restoration(W, fout)
    Vf=W.Vf; If=W.If; Vpu=W.Vpu; VBAND=W.VBAND;

    % Vf and If are stored as [time, channel-1, channel-2, channel-3].
    % Plot one representative disturbed-voltage trace instead of sending the
    % complete Nx3 voltage matrix to plot(). Because RMS_V is line-to-line,
    % the minimum of the three channels is the clearest single fault-severity
    % indicator for SLG, LL and 3PH cases.
    Vfault_kV = min(Vf(:,2:4),[],2)/1000;
    Ia_A      = If(:,2);

    fig=figure('Visible','off','Position',[40 40 1000 740],'Color','w');

    ax1=subplot(2,1,1);
    yyaxis(ax1,'left');
    hV=plot(ax1,Vf(:,1),Vfault_kV,'-','LineWidth',1.3);
    ylabel(ax1,'Minimum line-to-line RMS voltage (kV)');

    yyaxis(ax1,'right');
    hI=plot(ax1,If(:,1),Ia_A,'-','LineWidth',1.3);
    ylabel(ax1,'Faulted-bus RMS I_A (A)');

    grid(ax1,'on'); box(ax1,'on'); xlabel(ax1,'Time (s)');
    legend(ax1,[hV hI],{'Minimum V_{LL,RMS}','I_{A,RMS}'},'Location','best');

    if isfield(W,'predZone')
        title(ax1,sprintf('Stage 1 — %s fault at %s (normal network, tie open) | RF predicted: %s', ...
            W.ftype, W.zone, W.predZone));
    else
        title(ax1,sprintf('Stage 1 — %s fault at %s (normal network, tie open)', W.ftype, W.zone));
    end

    ax2=subplot(2,1,2); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
    busn={'B2','B3','B4','B5'}; cols=lines(4);
    for b=1:4
        plot(ax2,Vpu.(busn{b})(:,1),Vpu.(busn{b})(:,2),'-', ...
            'Color',cols(b,:),'LineWidth',1.2);
    end
    yline(ax2,VBAND(1),'r--'); yline(ax2,VBAND(2),'r--'); ylim(ax2,[0 1.15]);
    xlabel(ax2,'Time (s)'); ylabel(ax2,'Bus voltage (pu)');
    legend(ax2,[busn {'0.95 pu','1.05 pu'}],'Location','eastoutside');
    title(ax2,sprintf('Stage 2 — after isolation (%s) + tie %s : %s   [isolated=%s, restored=%s]', ...
        strjoin(W.brk,'+'), tern2(W.tieClosed,'CLOSED','OPEN'), W.status, W.zone, ...
        tern2(isempty(W.restored),'(none)',strjoin(W.restored,'+'))), 'Interpreter','none');

    exportgraphics(fig,fout,'Resolution',200); close(fig);
end
function s=tern2(c,a,b); if c; s=a; else; s=b; end; end

% ------------------------------- ML plots ---------------------------------
function plot_confusion(Cm, names, fout)
    rowTotal=sum(Cm,2);
    rowTotal(rowTotal==0)=1;
    Cpct=100*(Cm./rowTotal);
    overall=100*sum(diag(Cm))/max(sum(Cm(:)),1);

    fig=figure('Visible','off','Position',[40 40 940 760],'Color','w');
    ax=axes(fig);
    imagesc(ax,Cpct,[0 100]);
    colormap(ax,parula);
    cb=colorbar(ax);
    cb.Label.String='Row-normalised classification rate (%)';

    axis(ax,'square');
    set(ax,'XTick',1:numel(names),'XTickLabel',names, ...
        'XTickLabelRotation',45,'YTick',1:numel(names), ...
        'YTickLabel',names,'FontSize',9,'FontName','Times New Roman', ...
        'TickLabelInterpreter','none','Layer','top','Box','on');

    for i=1:size(Cm,1)
        for j=1:size(Cm,2)
            if Cm(i,j)>0
                if Cpct(i,j)>=55; tc='w'; else; tc='k'; end
                text(ax,j,i,sprintf('%d\n%.1f%%',Cm(i,j),Cpct(i,j)), ...
                    'HorizontalAlignment','center','VerticalAlignment','middle', ...
                    'FontSize',8,'FontWeight','bold','Color',tc, ...
                    'FontName','Times New Roman');
            end
        end
    end

    title(ax,sprintf('Test-set confusion matrix — overall accuracy %.2f%%',overall), ...
        'FontWeight','bold');
    xlabel(ax,'Predicted class');
    ylabel(ax,'True class');
    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function plot_prf_from_cm(Cm, names, fout)
    n=size(Cm,1); P=zeros(n,1); R=zeros(n,1); F=zeros(n,1);
    for i=1:n
        tp=Cm(i,i); fp=sum(Cm(:,i))-tp; fn=sum(Cm(i,:))-tp;
        P(i)=tp/max(tp+fp,eps);
        R(i)=tp/max(tp+fn,eps);
        F(i)=2*P(i)*R(i)/max(P(i)+R(i),eps);
    end
    Q=[P R F];

    fig=figure('Visible','off','Position',[40 40 820 700],'Color','w');
    ax=axes(fig);
    imagesc(ax,Q,[0 1]);
    colormap(ax,parula);
    cb=colorbar(ax);
    cb.Label.String='Metric value';

    set(ax,'XTick',1:3,'XTickLabel',{'Precision','Recall','F1-score'}, ...
        'YTick',1:n,'YTickLabel',names,'FontSize',9, ...
        'FontName','Times New Roman','TickLabelInterpreter','none', ...
        'Layer','top','Box','on');

    for i=1:n
        for j=1:3
            if Q(i,j)>=0.55; tc='w'; else; tc='k'; end
            text(ax,j,i,sprintf('%.3f',Q(i,j)), ...
                'HorizontalAlignment','center','FontSize',8, ...
                'FontWeight','bold','Color',tc,'FontName','Times New Roman');
        end
    end

    title(ax,'Per-class precision, recall and F1-score','FontWeight','bold');
    xlabel(ax,'Performance metric');
    ylabel(ax,'Class');
    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function plot_importance(imp, names, fout)
    [s,ord]=sort(imp(:),'ascend');
    orderedNames=names(ord);

    fig=figure('Visible','off','Position',[40 40 900 720],'Color','w');
    ax=axes(fig);
    barh(ax,s,0.72);
    grid(ax,'on'); box(ax,'on');

    set(ax,'YTick',1:numel(orderedNames),'YTickLabel',orderedNames, ...
        'FontSize',9,'FontName','Times New Roman', ...
        'TickLabelInterpreter','none','Layer','top');

    xmax=max(s);
    if xmax<=0; xmax=1; end
    xlim(ax,[0 1.16*xmax]);

    for k=1:numel(s)
        text(ax,s(k)+0.015*xmax,k,sprintf('%.3f',s(k)), ...
            'VerticalAlignment','middle','FontSize',8, ...
            'FontName','Times New Roman');
    end

    xlabel(ax,'Increase in OOB error after feature permutation');
    ylabel(ax,'Input feature');
    title(ax,'Random Forest OOB permutation feature importance (sorted)', ...
        'FontWeight','bold');
    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function plot_curve(v, xl, yl, ttl, fout)
    v=v(:); n=numel(v);
    tol=1e-12;
    lastNonZero=find(v>tol,1,'last');
    if isempty(lastNonZero)
        convTree=1;
    elseif lastNonZero<n
        convTree=lastNonZero+1;
    else
        convTree=NaN;
    end

    fig=figure('Visible','off','Position',[40 40 900 520],'Color','w');
    ax=axes(fig);
    plot(ax,1:n,v,'LineWidth',1.6);
    grid(ax,'on'); box(ax,'on');
    xlabel(ax,xl); ylabel(ax,yl);
    title(ax,ttl,'FontWeight','bold');
    set(ax,'FontName','Times New Roman','FontSize',10,'Layer','top');

    ymax=max(v);
    if ymax<=0; ymax=1; end
    ylim(ax,[0 1.08*ymax]);
    xlim(ax,[1 max(n,2)]);

    if ~isnan(convTree)
        xline(ax,convTree,'--','LineWidth',1.0);
        convText=sprintf('Sustained zero OOB error from tree %d',convTree);
    else
        convText='OOB error did not remain at zero';
    end
    text(ax,0.98,0.92,sprintf('Final OOB error: %.4f\n%s',v(end),convText), ...
        'Units','normalized','HorizontalAlignment','right', ...
        'VerticalAlignment','top','FontSize',9, ...
        'BackgroundColor','w','Margin',5,'FontName','Times New Roman');

    % Inset shows the rapid early convergence while retaining all trees.
    if isnan(convTree)
        zoomN=min(n,60);
    else
        zoomN=min(n,max(40,convTree+10));
    end
    ax2=axes(fig,'Position',[0.54 0.46 0.34 0.31]);
    plot(ax2,1:zoomN,v(1:zoomN),'LineWidth',1.3);
    grid(ax2,'on'); box(ax2,'on');
    xlim(ax2,[1 max(zoomN,2)]);
    zy=max(v(1:zoomN)); if zy<=0; zy=1; end
    ylim(ax2,[0 1.08*zy]);
    title(ax2,sprintf('Early convergence: first %d trees',zoomN), ...
        'FontSize',9,'FontWeight','normal');
    xlabel(ax2,'Trees','FontSize',8);
    ylabel(ax2,'OOB error','FontSize',8);
    set(ax2,'FontName','Times New Roman','FontSize',8,'Layer','top');

    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function plot_cv(cvACC, fout)
    pct=100*cvACC(:);
    folds=(1:numel(pct))';

    fig=figure('Visible','off','Position',[40 40 720 480],'Color','w');
    ax=axes(fig);
    bar(ax,folds,pct,0.58);
    grid(ax,'on'); box(ax,'on');
    ylim(ax,[0 105]);
    xlim(ax,[0.4 numel(pct)+0.6]);
    set(ax,'XTick',folds,'FontName','Times New Roman', ...
        'FontSize',10,'Layer','top');

    m=mean(pct);
    yline(ax,m,'--','LineWidth',1.1);
    for k=1:numel(pct)
        text(ax,k,pct(k)+1.2,sprintf('%.2f%%',pct(k)), ...
            'HorizontalAlignment','center','FontSize',9, ...
            'FontName','Times New Roman');
    end

    xlabel(ax,'Cross-validation fold');
    ylabel(ax,'Accuracy (%)');
    title(ax,sprintf('Five-fold cross-validation accuracy — mean %.2f%%',m), ...
        'FontWeight','bold');
    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function plot_restoration_summary(Rt, fout)
    st=strtrim(string(Rt.Status));
    available=unique(st,'stable');
    preferred=["RESTORED";"ISOLATED_NO_TIE";"BLOCKED_BY_CAPACITY"; ...
               "MISPREDICTED_WRONG_ACTION";"ERROR"];

    ordered=strings(0,1);
    for k=1:numel(preferred)
        if any(st==preferred(k))
            ordered(end+1,1)=preferred(k); %#ok<AGROW>
        end
    end
    extras=available(~ismember(available,ordered));
    ordered=[ordered; extras];

    counts=zeros(numel(ordered),1);
    labels=cell(numel(ordered),1);
    for k=1:numel(ordered)
        counts(k)=sum(st==ordered(k));
        labels{k}=pretty_status(ordered(k));
    end

    fig=figure('Visible','off','Position',[40 40 900 500],'Color','w');
    ax=axes(fig);
    bar(ax,1:numel(counts),counts,0.58);
    grid(ax,'on'); box(ax,'on');

    total=max(sum(counts),1);
    ymax=max(counts);
    if ymax<=0; ymax=1; end
    ylim(ax,[0 ymax+max(1,0.18*ymax)]);
    xlim(ax,[0.4 numel(counts)+0.6]);

    set(ax,'XTick',1:numel(counts),'XTickLabel',labels, ...
        'XTickLabelRotation',15,'TickLabelInterpreter','none', ...
        'FontName','Times New Roman','FontSize',10,'Layer','top');

    for k=1:numel(counts)
        text(ax,k,counts(k)+0.04*ymax, ...
            sprintf('%d (%.1f%%)',counts(k),100*counts(k)/total), ...
            'HorizontalAlignment','center','FontWeight','bold', ...
            'FontSize',9,'FontName','Times New Roman');
    end

    ylabel(ax,'Number of evaluated scenarios');
    title(ax,'Restoration decision outcomes','FontWeight','bold');
    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function plot_post_restoration_v(Rt, fout)
% Plot every restored BUS voltage individually. This avoids averaging B3 and
% B4 together for a B2 fault and prevents multi-value CSV cells from being
% silently omitted.
    st=strtrim(string(Rt.Status));
    idx=find(st=="RESTORED");
    vals=[]; labs={};

    for k=1:numel(idx)
        i=idx(k);

        raw=Rt.RestoredVoltages_pu(i);
        if iscell(raw); raw=raw{1}; end
        if iscategorical(raw); raw=char(raw); end
        if isstring(raw)
            if ismissing(raw); raw=''; else; raw=char(raw); end
        end
        if isnumeric(raw)
            if isempty(raw) || all(isnan(raw)); raw=''; else; raw=num2str(raw); end
        end

        v=sscanf(regexprep(char(raw),'[^0-9.eE+\-]',' '),'%f').';
        if isempty(v); continue; end

        rz=Rt.RestoredZones(i);
        if iscell(rz); rz=rz{1}; end
        if iscategorical(rz); rz=char(rz); end
        rz=char(string(rz));
        restoredZones=regexp(rz,'B[2-5]','match');

        fz=Rt.Zone(i);
        if iscell(fz); fz=fz{1}; end
        if iscategorical(fz); fz=char(fz); end
        fz=char(string(fz));
        lm=Rt.LoadMult(i);

        for j=1:numel(v)
            vals(end+1)=v(j); %#ok<AGROW>
            if j<=numel(restoredZones)
                target=restoredZones{j};
            else
                target=sprintf('bus%d',j);
            end
            labs{end+1}=sprintf('%s -> %s @ %.2f pu load',fz,target,lm); %#ok<AGROW>
        end
    end

    fig=figure('Visible','off','Position',[40 40 1120 520],'Color','w');
    ax=axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');

    if ~isempty(vals)
        x=1:numel(vals);
        for k=1:numel(vals)
            plot(ax,[x(k) x(k)],[1.0 vals(k)],'-','LineWidth',1.0);
        end
        h=plot(ax,x,vals,'o','LineStyle','none','MarkerSize',8,'LineWidth',1.5);
        hNom=yline(ax,1.00,'k:','LineWidth',1.1);
        hLow=yline(ax,0.95,'r--','LineWidth',1.0);
        yline(ax,1.05,'r--','LineWidth',1.0);

        lo=min([0.94 vals-0.008]);
        hi=max([1.06 vals+0.008]);
        ylim(ax,[lo hi]);
        xlim(ax,[0.5 numel(vals)+0.5]);

        set(ax,'XTick',x,'XTickLabel',labs,'XTickLabelRotation',28, ...
            'TickLabelInterpreter','none');

        for k=1:numel(vals)
            text(ax,k,vals(k)+0.002,sprintf('%.3f',vals(k)), ...
                'HorizontalAlignment','center','FontSize',8, ...
                'FontName','Times New Roman');
        end
        legend(ax,[h hNom hLow], ...
            {'Restored bus voltage','Nominal voltage','Acceptance limits'}, ...
            'Location','best');
    else
        yline(ax,0.95,'r--'); yline(ax,1.05,'r--');
        text(ax,0.5,0.5,'No successful RESTORED cases were found', ...
            'Units','normalized','HorizontalAlignment','center');
        ylim(ax,[0.9 1.1]);
    end

    set(ax,'FontName','Times New Roman','FontSize',9,'Layer','top');
    ylabel(ax,'Post-restoration bus voltage (pu)');
    xlabel(ax,'Fault scenario, restored bus and load multiplier');
    title(ax,'Post-restoration voltages for successful restoration actions', ...
        'FontWeight','bold');
    exportgraphics(fig,fout,'Resolution',300);
    close(fig);
end
function s=pretty_status(st)
    switch char(st)
        case 'RESTORED'
            s='Restored';
        case 'ISOLATED_NO_TIE'
            s='Isolated (tie not required)';
        case 'BLOCKED_BY_CAPACITY'
            s='Tie closure blocked by capacity';
        case 'MISPREDICTED_WRONG_ACTION'
            s='Mispredicted / wrong action';
        case 'ERROR'
            s='Simulation error';
        otherwise
            s=strrep(char(st),'_',' ');
    end
end

function BL = discover_blocks(MODEL)
    z={'B2','B3','B4','B5'};
    fc={{'Fault_B2'},{'Fault_B3'},{'Fault_B4'},{'Fault_B5','Fault_SXEW'}};
    lc={{'DL_B2'},{'DL_B3'},{'DL_B4'},{'DL_B5','DL_SXEW'}};
    for k=1:4; BL.fault.(z{k})=pick(MODEL,fc{k},'Reference'); BL.load.(z{k})=pick(MODEL,lc{k},'Reference'); end
    BL.cb.CB_MAIN   =pick(MODEL,{'CB_MAIN','CB_BUS1_B2'},'Reference');
    BL.cb.CB_BUS1_B3=pick(MODEL,{'CB_BUS1_B3'},'Reference');
    BL.cb.CB_BUS1_B4=pick(MODEL,{'CB_BUS1_B4'},'Reference');
    BL.cb.CB_T2_BUS5=pick(MODEL,{'CB_T2_BUS5'},'Reference');
    BL.cb.TIE       =pick(MODEL,{'TIE_SWITCH','TIE_B4_B5'},'Reference');
    BL.ctrl.CB_MAIN   =pick_ctrl(MODEL,{'CB_MAIN','CB_BUS1_B2'});
    BL.ctrl.CB_BUS1_B3=pick_ctrl(MODEL,{'CB_BUS1_B3'});
    BL.ctrl.CB_BUS1_B4=pick_ctrl(MODEL,{'CB_BUS1_B4'});
    BL.ctrl.CB_T2_BUS5=pick_ctrl(MODEL,{'CB_T2_BUS5'});
    BL.ctrl.TIE       =pick_ctrl(MODEL,{'TIE_B4_B5','TIE'});
end
function p=pick(MODEL,cands,bt)
    p='';
    for i=1:numel(cands); nm=cands{i}; if isempty(nm); continue; end
        h=find_system(MODEL,'SearchDepth',1,'BlockType',bt,'Name',nm);
        if isempty(h); h=find_system(MODEL,'SearchDepth',1,'RegExp','on','Name', ...
            ['^' regexprep(regexptranslate('escape',nm),'\s+','\\s+') '$']); end
        if ~isempty(h); p=getfullname(h{1}); return; end
    end
    error('pick:notfound','none of: %s',strjoin(cands,', '));
end
function p=pick_ctrl(MODEL,cands)
    cs=find_system(MODEL,'SearchDepth',1,'BlockType','Constant');
    for j=1:numel(cands)
        for i=1:numel(cs); nm=regexprep(get_param(cs{i},'Name'),'\s+',' ');
            if contains(nm,cands{j}); p=getfullname(cs{i}); return; end; end
    end
    error('pick_ctrl:notfound','no Constant matching %s',strjoin(cands,', '));
end
function set_switch(ctrl,closed); set_param(ctrl,'Value',num2str(double(logical(closed)))); end
function set_normal_state(BL)
    set_switch(BL.ctrl.CB_MAIN,true); set_switch(BL.ctrl.CB_BUS1_B3,true);
    set_switch(BL.ctrl.CB_BUS1_B4,true); set_switch(BL.ctrl.CB_T2_BUS5,true);
    set_switch(BL.ctrl.TIE,false);
end
function clear_all_faults(BL)
    z=fieldnames(BL.fault);
    for k=1:numel(z); set_param(BL.fault.(z{k}),'FaultA','off','FaultB','off','FaultC','off', ...
        'GroundFault','off','SwitchTimes','[1000000 1000001]','InitialStates','0'); end
end
function set_loads(BL,lm)
    z=fieldnames(BL.load);
    for k=1:numel(z); b=BL.load.(z{k});
        for pn={'ActivePower','InductiveReactivePower'}
            try mn=get_param(b,'MaskNames');
                if any(strcmp(mn,pn{1}))
                    ud=get_param(b,'UserData'); key=matlab.lang.makeValidName(pn{1});
                    if ~isstruct(ud)||~isfield(ud,key); base=str2double(get_param(b,pn{1}));
                        if ~isstruct(ud); ud=struct(); end; ud.(key)=base; set_param(b,'UserData',ud);
                    else; base=ud.(key); end
                    set_param(b,pn{1},num2str(base*lm));
                end
            catch; end
        end
    end
end
function s=simrun(MODEL)
    set_param(MODEL,'StopTime','2.0');
    s=sim(MODEL,'SimulationMode','normal','FastRestart','off','SaveOutput','on','SaveTime','on', ...
        'SignalLogging','on','SignalLoggingName','logsout','SaveFormat','Dataset');
end
function M=getM(sOut,cands)
    if ischar(cands); cands={cands}; end
    s=[];
    for i=1:numel(cands)
        try, s=sOut.get(cands{i}); catch, s=[]; end
        if isempty(s) && evalin('base',['exist(''' cands{i} ''',''var'')']); s=evalin('base',cands{i}); end
        if ~isempty(s); break; end
    end
    if isstruct(s)&&isfield(s,'signals'); t=s.time; val=s.signals.values;
    elseif isa(s,'timeseries'); t=s.Time; val=s.Data;
    else; error('getM:fmt','cannot read any of %s',strjoin(cands,',')); end
    if size(val,2)<3; val=repmat(val(:,1),1,3); end
    M=[t(:),val(:,1:3)];
end
