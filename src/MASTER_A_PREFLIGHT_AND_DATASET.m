%% =========================================================================
%  MASTER_A_PREFLIGHT_AND_DATASET.m
%  ─────────────────────────────────────────────────────────────────────────
%  Thesis: ML-Assisted Self-Healing of a 33/11 kV Mining Distribution Feeder
%  Author: Victoire — CU-BEE-100-7229  |  Supervisor: Mr Charles Kasonde
%
%  PURPOSE
%  -------
%  This is the ONLY script you need to run before training.
%  It does, in order:
%    [0]  All configuration — every block name confirmed from your model
%    [1]  SLG grounding fix — checks and corrects ground resistance before
%         any simulation runs, so your SLG fault currents are physically correct
%    [2]  Model load and block verification — confirms every block exists
%    [3]  Signal verification — 2-second test sim confirms To-Workspace signals
%    [4]  Healthy dataset generation — 100 samples (Class 0)
%    [5]  Fault dataset generation — 900 samples (Classes 1–12)
%    [6]  Dataset export — .mat, .csv, .xlsx, 4 diagnostic plots
%
%  OUTPUT FILES
%  ────────────
%    fault_dataset_1000.mat      ← load this in MASTER_B
%    fault_dataset_1000.csv      ← for inspection
%    fault_dataset_1000.xlsx     ← 3-sheet workbook
%    dataset_class_dist.png      ← class balance bar chart
%    dataset_voltage_heatmap.png ← voltage sag per class
%    dataset_current_heatmap.png ← fault current per class
%    dataset_scatter_B2.png      ← feature separability scatter
%
%  RUN TIME: ~16 hours. Run overnight. All progress is checkpointed.
%
%  ─────────────────────────────────────────────────────────────────────────
%  CONFIRMED BLOCK NAMES (read from your model by the author):
%
%    Fault blocks : Fault_B2, Fault_B3, Fault_B4, Fault_SXEW  (B5 = SXEW)
%    Load blocks  : DL_B2, DL_B3, DL_B4, DL_SXEW
%    Breakers     : CB_BUS1_B2, CB_BUS1_B3, CB_BUS1_B4, CB_T2_BUS5
%    Tie-switch   : TIE_B4_B5
%    V signals    : RMS_V_B2, RMS_V_B3, RMS_V_B4, RMS_V_SXEW
%    I signals    : RMS_I_B2, RMS_I_B3, RMS_I_B4, RMS_I_SXEW
%    Fault params : FaultA, FaultB, FaultC, GroundFault,
%                   FaultResistance, SwitchTimes, InitialStates
%    Load param   : auto-detected (P | ActivePower | NominalPower)
% =========================================================================

clc; close all;
fprintf('=================================================================\n');
fprintf('  MASTER A — PREFLIGHT + DATASET GENERATION\n');
fprintf('  %s\n', datestr(now));
fprintf('=================================================================\n\n');

%% =========================================================================
%%  SECTION 0 — CONFIGURATION  (do not edit below this section)
%% =========================================================================

MODEL         = 'mining_feeder_layer_FINAL_baseline';
SIM_STOP_TIME = 2.0;    % seconds — fault at t=1.0, extract at t=1.5

%% — Confirmed fault block full paths ——————————————————————————————————————
FB = struct(...
    'B2',   [MODEL '/Fault_B2'],   ...
    'B3',   [MODEL '/Fault_B3'],   ...
    'B4',   [MODEL '/Fault_B4'],   ...
    'SXEW', [MODEL '/Fault_SXEW']);    % Bus B5 is named SXEW in this model

%% — Confirmed load block full paths ————————————————————————————————————————
LB = struct(...
    'B2',   [MODEL '/DL_B2'],   ...
    'B3',   [MODEL '/DL_B3'],   ...
    'B4',   [MODEL '/DL_B4'],   ...
    'SXEW', [MODEL '/DL_SXEW']);

%% — Confirmed breaker / tie-switch full paths ——————————————————————————————
CB = struct(...
    'B2',  [MODEL '/CB_BUS1_B2'], ...
    'B3',  [MODEL '/CB_BUS1_B3'], ...
    'B4',  [MODEL '/CB_BUS1_B4'], ...
    'B5',  [MODEL '/CB_T2_BUS5'], ...
    'TIE', [MODEL '/TIE_B4_B5']);

%% — Confirmed workspace signal names ————————————————————————————————————————
SIG_V = {'RMS_V_B2','RMS_V_B3','RMS_V_B4','RMS_V_SXEW'};
SIG_I = {'RMS_I_B2','RMS_I_B3','RMS_I_B4','RMS_I_SXEW'};
BUS_LABELS = {'B2','B3','B4','B5'};    % display labels for feature vector

%% — Confirmed fault block parameter names —————————————————————————————————
FP_A  = 'FaultA';
FP_B  = 'FaultB';
FP_C  = 'FaultC';
FP_G  = 'GroundFault';
FP_RF = 'FaultResistance';    % confirmed — NOT Ron
FP_ST = 'SwitchTimes';
FP_IS = 'InitialStates';

%% — Base loads at 1.0 pu ——————————————————————————————————————————————————
BASE_P = [1.5e6,  2.0e6,  2.5e6,  1.65e6];   % [B2, B3, B4, SXEW]
BASE_Q = [0.44e6, 0.59e6, 0.74e6, 0.49e6];

%% — Fault parameter sweep ——————————————————————————————————————————————————
FAULT_RF   = [0.001, 0.1, 0.5, 1.0, 5.0];      % fault resistance (ohm)
FAULT_LM   = [0.70, 0.85, 1.00, 1.10, 1.30];   % load multiplier (pu)
FAULT_TON  = [0.50, 0.75, 1.00];                % fault onset time (s)
EXTRACT_DT = 0.5;                               % extract 0.5s after onset

%% — Healthy sweep ———————————————————————————————————————————————————————————
HEALTHY_LM      = linspace(0.55, 1.35, 10);
HEALTHY_REPEATS = 10;      % 10 levels x 10 repeats = 100 healthy samples
HEALTHY_T       = 1.5;     % steady-state extraction time (s)

%% — Class definitions ————————————————————————————————————————————————————————
BUS_KEYS       = {'B2','B3','B4','SXEW'};
FAULT_TYPES    = {'SLG','LL','3PH'};
CLASS_BASE_IDX = [1, 4, 7, 10];   % first class label per bus

%  Phase configuration per fault type
PH(1) = struct('A','on', 'B','off','C','off','G','on' );  % SLG
PH(2) = struct('A','on', 'B','on', 'C','off','G','off');  % LL
PH(3) = struct('A','on', 'B','on', 'C','on', 'G','off');  % 3PH

CLASS_NAMES = {'Healthy', ...
    'SLG-B2','LL-B2','3PH-B2', ...
    'SLG-B3','LL-B3','3PH-B3', ...
    'SLG-B4','LL-B4','3PH-B4', ...
    'SLG-B5','LL-B5','3PH-B5'};

%% =========================================================================
%%  SECTION 1 — SLG GROUNDING FIX
%%  Run BEFORE any simulation. Corrects near-zero SLG currents at B3/B4/B5.
%% =========================================================================

fprintf('[1/6] SLG GROUNDING FIX\n');
fprintf('      Checking and correcting GroundResistance on all fault blocks...\n\n');

load_system(MODEL);

grnd_param = 'UNKNOWN';

% Discover the ground resistance parameter name from the B2 fault block
try
    mn = get_param(FB.B2, 'MaskNames');
    for cand = {'GroundResistance','Rground','Rg','ground_resistance','Rneutral'}
        if any(strcmpi(mn, cand{1}))
            grnd_param = cand{1};
            break;
        end
    end
catch
end

if strcmp(grnd_param, 'UNKNOWN')
    fprintf('      [WARN] Could not auto-detect ground resistance parameter name.\n');
    fprintf('      Listing all mask parameters for Fault_B2:\n');
    try
        mn = get_param(FB.B2, 'MaskNames');
        for k = 1:numel(mn)
            v = get_param(FB.B2, mn{k});
            fprintf('        %-35s = %s\n', mn{k}, mat2str(v));
        end
    catch
    end
    fprintf('\n      *** MANUAL ACTION REQUIRED ***\n');
    fprintf('      Find the ground resistance parameter above, open your Simulink\n');
    fprintf('      model, and set it to 0.001 ohm on Fault_B3, Fault_B4, Fault_SXEW.\n');
    fprintf('      Then re-run this script.\n\n');
else
    fprintf('      Ground resistance parameter name: %s\n\n', grnd_param);

    TARGET_RGROUND = 0.001;   % ohm — same as FaultResistance
    for k = 1:numel(BUS_KEYS)
        blk = FB.(BUS_KEYS{k});
        try
            cur_val = str2double(get_param(blk, grnd_param));
            if isnan(cur_val) || cur_val > 10
                set_param(blk, grnd_param, num2str(TARGET_RGROUND));
                fprintf('      [FIXED] %-30s %s: %.4f -> %.4f ohm\n', ...
                    blk, grnd_param, cur_val, TARGET_RGROUND);
            else
                fprintf('      [OK]    %-30s %s = %.4f ohm\n', ...
                    blk, grnd_param, cur_val);
            end
        catch ME
            fprintf('      [WARN]  %-30s Could not set: %s\n', blk, ME.message);
        end
    end

    % Quick verification: one SLG-B3 test sim to confirm current is now >> baseline
    fprintf('\n      Running quick SLG-B3 verification (15 s)...\n');
    try
        disable_all_faults(MODEL, FB, BUS_KEYS, FP_A, FP_B, FP_C, FP_G, FP_ST, FP_IS);
        set_param(FB.B3, FP_A, 'on', FP_G, 'on', ...
            FP_RF, '0.001', grnd_param, '0.001', ...
            FP_ST, '[1.0 1.5]', FP_IS, '0');
        set_param(MODEL, 'StopTime', '2.0');
        sOut = sim(MODEL, 'SimulationMode','normal','FastRestart','off', ...
            'SaveOutput','on','SignalLogging','on', ...
            'SignalLoggingName','logsout','SaveFormat','Dataset');
        raw_I  = sOut.get('RMS_I_B3');
        t_vec  = raw_I.time;
        i_vals = raw_I.signals.values(:,1);
        I_fault   = mean(i_vals(t_vec > 1.2 & t_vec < 1.4));
        I_healthy = mean(i_vals(t_vec > 0.3 & t_vec < 0.8));
        fprintf('      SLG-B3 current: healthy=%.1f A  fault=%.1f A  ratio=%.1fx\n', ...
            I_healthy, I_fault, I_fault/max(I_healthy,1));
        if I_fault > 5 * I_healthy
            fprintf('      [PASS] SLG current is >> healthy — grounding fix is working.\n\n');
        else
            fprintf('      [WARN] SLG current still low (%.1fx).\n', I_fault/max(I_healthy,1));
            fprintf('             The issue may be a canvas wiring problem.\n');
            fprintf('             Open Simulink and check that each fault block neutral\n');
            fprintf('             port is connected to the transformer neutral, not global ground.\n\n');
        end
        % Reset B3 fault
        set_param(FB.B3, FP_A,'off', FP_G,'off', FP_ST,'[1000000 1000001]', FP_IS,'0');
    catch ME
        fprintf('      [WARN] SLG verification sim failed: %s\n', ME.message);
        fprintf('             Continuing — this will not stop dataset generation.\n\n');
        disable_all_faults(MODEL, FB, BUS_KEYS, FP_A, FP_B, FP_C, FP_G, FP_ST, FP_IS);
    end
end

%% =========================================================================
%%  SECTION 2 — BLOCK VERIFICATION
%% =========================================================================

fprintf('[2/6] BLOCK VERIFICATION\n');

all_ok = true;
all_blocks = [fieldnames(FB); fieldnames(LB); fieldnames(CB)];
all_paths  = [struct2cell(FB); struct2cell(LB); struct2cell(CB)];

for k = 1:numel(all_paths)
    blk = all_paths{k};
    try
        get_param(blk, 'Name');
        fprintf('      [OK]  %s\n', blk);
    catch
        fprintf('      [FAIL] NOT FOUND: %s\n', blk);
        all_ok = false;
    end
end

if ~all_ok
    error('[STOPPED] Fix missing blocks before continuing.');
end
fprintf('\n');

%% =========================================================================
%%  SECTION 3 — SIGNAL VERIFICATION (test simulation)
%% =========================================================================

fprintf('[3/6] SIGNAL VERIFICATION\n');
fprintf('      Running 2-second test simulation...\n');

disable_all_faults(MODEL, FB, BUS_KEYS, FP_A, FP_B, FP_C, FP_G, FP_ST, FP_IS);
reset_all_loads(MODEL, LB, BUS_KEYS, BASE_P, BASE_Q);
set_param(MODEL, 'StopTime', '2.0');

try
    sOut_test = sim(MODEL, 'SimulationMode','normal','FastRestart','off', ...
        'SaveOutput','on','SignalLogging','on', ...
        'SignalLoggingName','logsout','SaveFormat','Dataset');
catch ME
    error('Test simulation failed: %s\nCheck your model is correctly configured.', ME.message);
end

sigs_ok = true;
for k = 1:4
    for grp = {SIG_V, SIG_I}
        sn = grp{1}{k};
        try
            raw = sOut_test.get(sn);
            if isstruct(raw)
                sz = size(raw.signals.values);
                % Also verify healthy voltage is in expected range
                if contains(sn,'V')
                    v_mean = mean(abs(raw.signals.values(end-50:end, 1)));
                    v_pu   = v_mean / 11000;
                    if v_pu < 0.90 || v_pu > 1.10
                        fprintf('      [WARN] %s: mean=%.0f V (%.3f pu) — outside 0.90-1.10 pu\n', sn, v_mean, v_pu);
                    else
                        fprintf('      [OK]  %-18s  size=[%d %d]  V=%.0f V (%.3f pu)\n', sn, sz(1), sz(2), v_mean, v_pu);
                    end
                else
                    fprintf('      [OK]  %-18s  size=[%d %d]\n', sn, sz(1), sz(2));
                end
            else
                fprintf('      [WARN] %s exists but is not Structure With Time format.\n', sn);
                sigs_ok = false;
            end
        catch
            fprintf('      [FAIL] %s NOT FOUND in simOut.\n', sn);
            sigs_ok = false;
        end
    end
end

if ~sigs_ok
    fprintf('\n      Some signals missing. Check your To Workspace block names.\n');
    fprintf('      Available blocks:\n');
    tw = find_system(MODEL,'BlockType','ToWorkspace');
    for k = 1:numel(tw)
        fprintf('        %s  ->  %s\n', tw{k}, get_param(tw{k},'VariableName'));
    end
    error('Signal verification failed. Update SIG_V and SIG_I in Section 0.');
end

rng(42);
fprintf('\n      All signals verified.\n\n');

%% =========================================================================
%%  SECTION 4 — GENERATE HEALTHY SAMPLES (Class 0, n=100)
%% =========================================================================

t_pipeline_start = datetime('now');   % start timer before dataset generation
fprintf('[4/6] HEALTHY SAMPLE GENERATION (target: 100 samples)\n');

N_FEATURES = 24;
dataset    = zeros(1000, N_FEATURES + 1);
n_saved    = 0;

% Feature names (consistent with thesis Table 4.1)
feature_names = {};
for b = BUS_LABELS
    for ph = {'A','B','C'}
        feature_names{end+1} = sprintf('V_%s_%s', b{1}, ph{1}); %#ok<AGROW>
    end
end
for b = BUS_LABELS
    for ph = {'A','B','C'}
        feature_names{end+1} = sprintf('I_%s_%s', b{1}, ph{1}); %#ok<AGROW>
    end
end

healthy_count = 0;
for lm = HEALTHY_LM
    for rep = 1:HEALTHY_REPEATS
        lm_v = lm * (1 + 0.04*(rand-0.5));
        lm_v = max(0.50, min(1.40, lm_v));
        disable_all_faults(MODEL, FB, BUS_KEYS, FP_A, FP_B, FP_C, FP_G, FP_ST, FP_IS);
        scale_all_loads(MODEL, LB, BUS_KEYS, BASE_P, BASE_Q, lm_v);
        try
            sO = run_sim(MODEL, SIM_STOP_TIME);
            f  = extract_features(sO, SIG_V, SIG_I, HEALTHY_T);
            n_saved = n_saved + 1;
            dataset(n_saved,:) = [f, 0];
            healthy_count = healthy_count + 1;
        catch ME
            fprintf('  [skip healthy lm=%.2f rep=%d: %s]\n', lm_v, rep, ME.message(1:min(50,end)));
        end
    end
end
fprintf('      Generated: %d healthy samples\n\n', healthy_count);

% Checkpoint after healthy phase
try
    partial = dataset(1:n_saved,:);
    save('dataset_checkpoint.mat','partial','feature_names','CLASS_NAMES','n_saved');
    fprintf('      [CHECKPOINT saved: %d samples]\n\n', n_saved);
catch; end

%% =========================================================================
%%  SECTION 5 — GENERATE FAULT SAMPLES (Classes 1-12, 75 each = 900)
%% =========================================================================

fprintf('[5/6] FAULT SAMPLE GENERATION (75 per class x 12 classes = 900)\n');

% t_pipeline_start already set in Section 4
total_runs  = numel(BUS_KEYS) * numel(FAULT_TYPES) * numel(FAULT_RF) * numel(FAULT_LM) * numel(FAULT_TON);
run_count   = 0;
last_checkpoint_n = n_saved;

for b_idx = 1:numel(BUS_KEYS)
    bus_key  = BUS_KEYS{b_idx};
    flt_blk  = FB.(bus_key);

    for ft_idx = 1:numel(FAULT_TYPES)
        class_label = CLASS_BASE_IDX(b_idx) + (ft_idx - 1);
        ph          = PH(ft_idx);
        class_count = 0;

        fprintf('  Class %2d %-8s at bus %-4s — ', class_label, FAULT_TYPES{ft_idx}, bus_key);

        for Rf = FAULT_RF
            for lm = FAULT_LM
                for t_on = FAULT_TON
                    t_extract = t_on + EXTRACT_DT;
                    stop_t    = max(SIM_STOP_TIME, t_extract + 0.2);
                    run_count = run_count + 1;

                    disable_all_faults(MODEL, FB, BUS_KEYS, FP_A, FP_B, FP_C, FP_G, FP_ST, FP_IS);
                    scale_all_loads(MODEL, LB, BUS_KEYS, BASE_P, BASE_Q, lm);

                    % Enable the fault for this run
                    set_param(flt_blk, ...
                        FP_A,  ph.A, ...
                        FP_B,  ph.B, ...
                        FP_C,  ph.C, ...
                        FP_G,  ph.G, ...
                        FP_RF, num2str(Rf), ...
                        FP_ST, sprintf('[%.3f %.3f]', t_on, stop_t - 0.05), ...
                        FP_IS, '0');

                    % Set ground resistance if known
                    if ~strcmp(grnd_param,'UNKNOWN')
                        if strcmp(ph.G,'on')
                            try; set_param(flt_blk, grnd_param, num2str(Rf)); catch; end
                        else
                            try; set_param(flt_blk, grnd_param, '500'); catch; end
                        end
                    end

                    try
                        sO   = run_sim(MODEL, stop_t);
                        f    = extract_features(sO, SIG_V, SIG_I, t_extract);
                        n_saved = n_saved + 1;
                        dataset(n_saved,:) = [f, class_label];
                        class_count = class_count + 1;
                    catch ME
                        fprintf('[skip Rf=%.3f lm=%.2f t=%.2f: %s] ', ...
                            Rf, lm, t_on, ME.message(1:min(30,end)));
                    end
                end
            end
        end

        fprintf('%d samples\n', class_count);

        % Checkpoint every 3 classes (~225 samples)
        if n_saved - last_checkpoint_n >= 225
            try
                partial = dataset(1:n_saved,:);
                save('dataset_checkpoint.mat','partial','feature_names','CLASS_NAMES','n_saved');
                elapsed = datetime('now') - t_pipeline_start;
                fprintf('    [CHECKPOINT: %d/%d samples, elapsed %s]\n', ...
                    n_saved, 1000, char(elapsed));
                last_checkpoint_n = n_saved;
            catch; end
        end
    end
end

elapsed_total = datetime('now') - t_pipeline_start;
fprintf('\n      Done: %d fault samples  |  Total: %d samples  |  Elapsed: %s\n\n', ...
    n_saved - healthy_count, n_saved, char(elapsed_total));

%% =========================================================================
%%  SECTION 6 — SAVE AND EXPORT
%% =========================================================================

fprintf('[6/6] EXPORT\n');

dataset = dataset(1:n_saved,:);

% — Save .mat ——————————————————————————————————————————————————————————————
save('fault_dataset_1000.mat','dataset','feature_names','CLASS_NAMES');
fprintf('      Saved: fault_dataset_1000.mat  (%d samples)\n', n_saved);

X      = dataset(:,1:end-1);
labels = dataset(:,end);

% — Save .csv ——————————————————————————————————————————————————————————————
try
    hdr = [feature_names, {'class_label','class_name'}];
    cnames = CLASS_NAMES(labels+1)';
    full_cell = [hdr; [num2cell([X, labels]), cnames]];
    writecell(full_cell, 'fault_dataset_1000.csv');
    fprintf('      Saved: fault_dataset_1000.csv\n');
catch ME
    fprintf('      [WARN] CSV export failed: %s\n', ME.message);
end

% — Save .xlsx ————————————————————————————————————————————————————————————
try
    hdr = [feature_names, {'class_label','class_name'}];
    cnames = CLASS_NAMES(labels+1)';
    writecell([hdr; [num2cell([X,labels]), cnames]], 'fault_dataset_1000.xlsx', ...
        'Sheet','Full Dataset','WriteMode','overwritesheet');
    % Summary stats sheet
    shdr = [{'class_label','class_name','n_samples'}, ...
            strcat(feature_names,'_mean'), strcat(feature_names,'_std')];
    srows = {};
    for c = 0:12
        idx = (labels==c);
        nc  = sum(idx);
        if nc > 0
            srows{end+1} = [{c, CLASS_NAMES{c+1}, nc}, num2cell(mean(X(idx,:))), num2cell(std(X(idx,:)))]; %#ok<AGROW>
        end
    end
    writecell([shdr; srows], 'fault_dataset_1000.xlsx', ...
        'Sheet','Summary Stats','WriteMode','overwritesheet');
    fprintf('      Saved: fault_dataset_1000.xlsx\n');
catch ME
    fprintf('      [WARN] Excel export failed: %s\n', ME.message);
end

% — 4 diagnostic plots ————————————————————————————————————————————————————
colors13 = [0.2 0.6 0.2; repmat([0.84 0.19 0.15],3,1); repmat([0.12 0.47 0.71],3,1); ...
            repmat([0.89 0.55 0.00],3,1); repmat([0.58 0.10 0.62],3,1)];
counts   = arrayfun(@(c) sum(labels==c), 0:12);

% Plot 1: Class distribution
f1 = figure('Visible','on','Position',[50 50 900 400]);
b = bar(0:12, counts, 'FaceColor','flat'); b.CData = colors13;
xticks(0:12); xticklabels(CLASS_NAMES); xtickangle(40);
ylabel('Samples'); title(sprintf('Class Distribution — %d samples total', n_saved));
yline(75,'r--','75 (fault target)','LabelHorizontalAlignment','right');
yline(100,'g--','100 (healthy target)','LabelHorizontalAlignment','right');
grid on;
saveas(f1,'dataset_class_dist.png'); close(f1);
fprintf('      Saved: dataset_class_dist.png\n');

% Plot 2: Voltage heatmap (normalised to healthy)
Vh = mean(X(labels==0, 1:12), 1);
Vh(Vh==0) = 1;
V_hm = zeros(13,12);
for c=0:12; idx=(labels==c); if sum(idx)>0; V_hm(c+1,:)=mean(X(idx,1:12),1)./Vh; end; end
f2 = figure('Visible','on','Position',[50 50 950 460]);
imagesc(V_hm); colormap(hot); cb=colorbar; cb.Label.String='Normalised to healthy';
clim([0 1.1]);
yticks(1:13); yticklabels(CLASS_NAMES);
xticks(1:12); xticklabels(strrep(feature_names(1:12),'_','\_')); xtickangle(45);
title('Mean Voltage per Class (normalised to Healthy)');
saveas(f2,'dataset_voltage_heatmap.png'); close(f2);
fprintf('      Saved: dataset_voltage_heatmap.png\n');

% Plot 3: Current heatmap (normalised, capped at 5x)
Ih = mean(X(labels==0,13:24),1); Ih(Ih==0)=1;
I_hm = zeros(13,12);
for c=0:12; idx=(labels==c); if sum(idx)>0; I_hm(c+1,:)=mean(X(idx,13:24),1)./Ih; end; end
f3 = figure('Visible','on','Position',[50 50 950 460]);
imagesc(min(I_hm,5)); colormap(parula); cb3=colorbar;
cb3.Label.String='Normalised current (capped at 5x)'; clim([0 5]);
yticks(1:13); yticklabels(CLASS_NAMES);
xticks(1:12); xticklabels(strrep(feature_names(13:24),'_','\_')); xtickangle(45);
title('Mean Current per Class (normalised to Healthy, capped at 5x)');
saveas(f3,'dataset_current_heatmap.png'); close(f3);
fprintf('      Saved: dataset_current_heatmap.png\n');

% Plot 4: Feature scatter Bus B2 Phase A
f4 = figure('Visible','on','Position',[50 50 720 540]);
hold on;
cmap = lines(13);
for c=0:12
    idx=(labels==c); if sum(idx)==0; continue; end
    scatter(X(idx,1), X(idx,13), 18, cmap(c+1,:), 'filled', ...
        'MarkerFaceAlpha',0.5, 'DisplayName',CLASS_NAMES{c+1});
end
xlabel('V_{B2,A} RMS (V)'); ylabel('I_{B2,A} RMS (A)');
title('Feature Separability — Bus B2 Phase A');
xline(11000*0.95,'k--','0.95 pu','LabelHorizontalAlignment','right');
xline(11000*1.05,'k--','1.05 pu','LabelHorizontalAlignment','right');
legend('Location','best','FontSize',7); grid on;
saveas(f4,'dataset_scatter_B2.png'); close(f4);
fprintf('      Saved: dataset_scatter_B2.png\n');

% — Reset model to clean state ————————————————————————————————————————————
disable_all_faults(MODEL, FB, BUS_KEYS, FP_A, FP_B, FP_C, FP_G, FP_ST, FP_IS);
reset_all_loads(MODEL, LB, BUS_KEYS, BASE_P, BASE_Q);
try; set_param(MODEL,'StopTime','10.0'); catch; end
try; save_system(MODEL); catch; end

fprintf('\n=================================================================\n');
fprintf('  MASTER A COMPLETE — %d samples saved\n', n_saved);
fprintf('  Next: run MASTER_B_TRAIN_AND_RESTORE.m\n');
fprintf('  Elapsed: %s\n', char(datetime('now') - t_pipeline_start));
fprintf('=================================================================\n');


%% =========================================================================
%%  LOCAL HELPER FUNCTIONS
%% =========================================================================

function disable_all_faults(model, FB, bus_keys, PA, PB, PC, PG, PST, PIS)
    for k = 1:numel(bus_keys)
        blk = FB.(bus_keys{k});
        try
            set_param(blk, PA,'off', PB,'off', PC,'off', PG,'off', ...
                PST,'[1000000 1000001]', PIS,'0');
        catch; end
    end
end


function reset_all_loads(model, LB, bus_keys, BASE_P, BASE_Q)
    scale_all_loads(model, LB, bus_keys, BASE_P, BASE_Q, 1.0);
end


function scale_all_loads(model, LB, bus_keys, BASE_P, BASE_Q, lm)
%SCALE_ALL_LOADS  Set all loads to lm x rated.
%  Auto-detects per-block parameter: P/Q (Dynamic), ActivePower/InductivePower
%  (Series RLC), or NominalPower [P Q] (Parallel RLC).
    for k = 1:numel(bus_keys)
        blk = LB.(bus_keys{k});
        P   = BASE_P(k) * lm;
        Q   = BASE_Q(k) * lm;
        try
            mn = get_param(blk,'MaskNames');
        catch; continue; end

        if any(strcmpi(mn,'P'))
            try; set_param(blk,'P',num2str(P)); catch; end
            if any(strcmpi(mn,'Q'))
                try; set_param(blk,'Q',num2str(Q)); catch; end
            end
        elseif any(strcmpi(mn,'ActivePower'))
            try; set_param(blk,'ActivePower',num2str(P)); catch; end
            if any(strcmpi(mn,'InductivePower'))
                try; set_param(blk,'InductivePower',num2str(Q)); catch; end
            end
        elseif any(strcmpi(mn,'NominalPower'))
            try; set_param(blk,'NominalPower',sprintf('[%g %g]',P,Q)); catch; end
        end
    end
end


function simOut = run_sim(model, stop_t)
%RUN_SIM  Run simulation with correct R2024a output settings.
    set_param(model,'StopTime',num2str(stop_t));
    simOut = sim(model, ...
        'SimulationMode','normal','FastRestart','off', ...
        'SaveTime','on','SaveOutput','on', ...
        'SignalLogging','on','SignalLoggingName','logsout', ...
        'SaveFormat','Dataset');
end


function feats = extract_features(simOut, SIG_V, SIG_I, t_extract)
%EXTRACT_FEATURES  Returns 1x24 RMS feature vector at t_extract.
%  Format: [V_B2_A..C, V_B3..., V_B4..., V_B5...,
%            I_B2_A..C, I_B3..., I_B4..., I_B5...]
    all_sigs = [SIG_V, SIG_I];
    feats    = zeros(1,24);
    col      = 1;
    for s = 1:numel(all_sigs)
        try
            raw = simOut.get(all_sigs{s});
            if isstruct(raw)
                t_vec = raw.time;
                vals  = raw.signals.values;
            elseif isa(raw,'timeseries')
                t_vec = raw.Time;
                vals  = raw.Data;
            else
                feats(col:col+2) = NaN;
                col = col + 3; continue;
            end
            [~,idx] = min(abs(t_vec - t_extract));
            dt      = mean(diff(t_vec(max(1,idx-5):min(end,idx+5))));
            hw      = max(1, round(0.010/dt));
            i_lo    = max(1, idx-hw);
            i_hi    = min(size(vals,1), idx+hw);
            for ph = 1:3
                feats(col) = mean(abs(vals(i_lo:i_hi, ph)));
                col = col + 1;
            end
        catch
            feats(col:col+2) = NaN;
            col = col + 3;
        end
    end
end
