%% =========================================================================
%  RUN_ALL_PIPELINE.m
%  ─────────────────────────────────────────────────────────────────────────
%  Thesis: ML-Assisted Self-Healing of a 33/11 kV Mining Distribution Feeder
%  Author: Victoire Chinyanta Chimundu — CU-BEE-100-7229  |  Supervisor: Mr Charles Kasonde
%
%  WHAT THIS DOES
%  ──────────────
%  Runs all three master scripts in sequence, automatically:
%
%    Step 1 → MASTER_A_PREFLIGHT_AND_DATASET.m   (~16 hours)
%    Step 2 → MASTER_B_TRAIN_AND_RESTORE.m        (~3-4 hours)
%    Step 3 → MASTER_C_GENERATE_ALL_FIGURES.m     (~15 minutes)
%
%  SMART SKIP LOGIC
%  ─────────────────
%  The launcher checks what already exists before running each step:
%    - If fault_dataset_1000.mat exists  → asks whether to skip Step 1
%    - If rf_model_final.mat exists      → asks whether to skip Step 2
%    - Step 3 always runs (figures are fast to regenerate)
%
%  HOW TO RUN
%  ──────────
%  1. Open MATLAB R2024a
%  2. Set Current Folder to the folder containing all .m files and the .slx model
%  3. Type in the Command Window:
%       >> RUN_ALL_PIPELINE
%  4. Answer the two skip prompts (y/n), then leave running overnight
%
%  OUTPUTS
%  ───────
%    fault_dataset_1000.mat           (Step 1)
%    fault_dataset_1000.csv / .xlsx   (Step 1)
%    rf_model_final.mat               (Step 2)
%    rf_metrics_report.txt            (Step 2)
%    restoration_results_full.csv     (Step 2)
%    restoration_summary.txt          (Step 2)
%    figures/ch3_methodology/*.png    (Step 3)
%    figures/ch4_system_design/*.png  (Step 3)
%    figures/ch5_results/*.png        (Step 3)
%    figures/ch6_conclusions/*.png    (Step 3)
%    pipeline_full_log.txt            (this launcher)
%
%  ESTIMATED TOTAL TIME
%  ────────────────────
%    Step 1 only (first run)  : ~16 hours
%    Step 2 only              : ~3-4 hours
%    Step 3 only              : ~15 minutes
%    Full pipeline from zero  : ~20 hours
% =========================================================================

clc;
LINE = repmat('=', 1, 65);

fprintf('\n%s\n', LINE);
fprintf('  FULL THESIS PIPELINE LAUNCHER\n');
fprintf('  ML-Assisted Self-Healing Mining Feeder\n');
fprintf('  Started: %s\n', datestr(now));
fprintf('%s\n\n', LINE);

%% ── Setup ────────────────────────────────────────────────────────────────
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir); script_dir = pwd; end
cd(script_dir);
addpath(script_dir);

LOG_FILE = fullfile(script_dir, 'pipeline_full_log.txt');
fid_log = fopen(LOG_FILE, 'w');
log_write(fid_log, 'Pipeline started');
log_write(fid_log, sprintf('Working directory: %s', script_dir));

%% ── Check all required script files exist ────────────────────────────────
required_scripts = {
    'MASTER_A_PREFLIGHT_AND_DATASET.m',
    'MASTER_B_TRAIN_AND_RESTORE.m',
    'MASTER_C_GENERATE_ALL_FIGURES.m',
};
required_model = 'mining_feeder_layer_FINAL_baseline.slx';

fprintf('[CHECK] Required files:\n');
all_files_ok = true;
for k = 1:numel(required_scripts)
    if exist(required_scripts{k}, 'file')
        fprintf('  [OK]  %s\n', required_scripts{k});
    else
        fprintf('  [!!]  %s  — NOT FOUND\n', required_scripts{k});
        all_files_ok = false;
    end
end
if exist(required_model, 'file')
    fprintf('  [OK]  %s\n', required_model);
else
    fprintf('  [!!]  %s  — NOT FOUND\n', required_model);
    all_files_ok = false;
end

if ~all_files_ok
    fclose(fid_log);
    error('Missing required files. Make sure all scripts and the .slx model are in: %s', script_dir);
end
fprintf('\n');

%% ── Check MATLAB version ─────────────────────────────────────────────────
v = version('-release');
fprintf('[SYSTEM] MATLAB %s\n', v);
if str2double(v(1:4)) < 2022
    fprintf('[WARN]  R2022a or later recommended. Some features may differ.\n');
end

%% ── Prevent Windows sleep ────────────────────────────────────────────────
sleep_disabled = false;
try
    system('powercfg /change standby-timeout-ac 0');
    system('powercfg /change monitor-timeout-ac 0');
    sleep_disabled = true;
    fprintf('[SYSTEM] Windows sleep disabled for pipeline duration.\n');
catch
    fprintf('[SYSTEM] Could not disable sleep — set manually: Settings > Power > Sleep > Never\n');
end
fprintf('\n');

%% ── Step 1: Dataset generation ───────────────────────────────────────────
SKIP_A = false;
if exist('fault_dataset_1000.mat', 'file')
    d = dir('fault_dataset_1000.mat');
    fprintf('[STEP 1] fault_dataset_1000.mat already exists (%.1f MB, %s).\n', ...
        d.bytes/1e6, datestr(d.datenum));
    resp = input('         Skip dataset generation and use existing file? (y/n): ', 's');
    SKIP_A = strcmpi(strtrim(resp), 'y');
    if SKIP_A
        fprintf('         Skipping Step 1.\n\n');
        log_write(fid_log, 'Step 1 SKIPPED — existing dataset reused');
    else
        fprintf('         Re-running Step 1 (will overwrite existing dataset).\n\n');
    end
end

if ~SKIP_A
    fprintf('%s\n  STEP 1/3 — PREFLIGHT + DATASET GENERATION\n%s\n\n', LINE, LINE);
    log_write(fid_log, 'Step 1 START');
    t_A = datetime('now');
    
    try
        run(fullfile(script_dir, 'MASTER_A_PREFLIGHT_AND_DATASET.m'));
        dur_A = datetime('now') - t_A;
        fprintf('\n[STEP 1 DONE]  %s\n\n', duration_str(dur_A));
        log_write(fid_log, sprintf('Step 1 DONE — %s', duration_str(dur_A)));
    catch ME_A
        fprintf('\n[STEP 1 ERROR]\n  %s\n', ME_A.message);
        if ~isempty(ME_A.stack)
            fprintf('  File: %s  Line: %d\n', ME_A.stack(1).file, ME_A.stack(1).line);
        end
        log_write(fid_log, sprintf('Step 1 ERROR: %s', ME_A.message));
        
        % Check if partial dataset exists — try to continue with it
        if exist('dataset_checkpoint.mat', 'file')
            fprintf('  [RECOVER] Checkpoint file found — attempting partial recovery...\n');
            try
                C = load('dataset_checkpoint.mat');
                save('fault_dataset_1000.mat', '-struct', 'C');
                fprintf('  [RECOVER] Partial dataset (%d samples) saved as fault_dataset_1000.mat\n\n', C.n_saved);
                log_write(fid_log, sprintf('Step 1 PARTIAL RECOVERY — %d samples', C.n_saved));
            catch
                fprintf('  [RECOVER] Recovery failed. Cannot continue without dataset.\n');
                fclose(fid_log);
                restore_sleep(sleep_disabled);
                error('Step 1 failed and no recovery possible. Check error above.');
            end
        else
            fprintf('  No checkpoint found. Cannot continue without dataset.\n');
            fclose(fid_log);
            restore_sleep(sleep_disabled);
            error('Step 1 failed and no dataset exists. Check error above.');
        end
    end
    
    % Verify output
    if exist('fault_dataset_1000.mat', 'file')
        d = dir('fault_dataset_1000.mat');
        fprintf('[STEP 1] Output: fault_dataset_1000.mat (%.1f MB)\n\n', d.bytes/1e6);
    else
        fclose(fid_log);
        restore_sleep(sleep_disabled);
        error('fault_dataset_1000.mat was not created. Check Step 1 output above.');
    end
end

%% ── Step 2: Train, evaluate, restore ─────────────────────────────────────
SKIP_B = false;
if exist('rf_model_final.mat', 'file')
    d = dir('rf_model_final.mat');
    fprintf('[STEP 2] rf_model_final.mat already exists (%.1f MB, %s).\n', ...
        d.bytes/1e6, datestr(d.datenum));
    resp = input('         Skip RF training and restoration? (y/n): ', 's');
    SKIP_B = strcmpi(strtrim(resp), 'y');
    if SKIP_B
        fprintf('         Skipping Step 2.\n\n');
        log_write(fid_log, 'Step 2 SKIPPED — existing model reused');
    else
        fprintf('         Re-running Step 2.\n\n');
    end
end

if ~SKIP_B
    fprintf('%s\n  STEP 2/3 — TRAIN + EVALUATE + RESTORE\n%s\n\n', LINE, LINE);
    log_write(fid_log, 'Step 2 START');
    t_B = datetime('now');
    
    try
        run(fullfile(script_dir, 'MASTER_B_TRAIN_AND_RESTORE.m'));
        dur_B = datetime('now') - t_B;
        fprintf('\n[STEP 2 DONE]  %s\n\n', duration_str(dur_B));
        log_write(fid_log, sprintf('Step 2 DONE — %s', duration_str(dur_B)));
    catch ME_B
        fprintf('\n[STEP 2 ERROR]\n  %s\n', ME_B.message);
        if ~isempty(ME_B.stack)
            fprintf('  File: %s  Line: %d\n', ME_B.stack(1).file, ME_B.stack(1).line);
        end
        log_write(fid_log, sprintf('Step 2 ERROR: %s', ME_B.message));
        fprintf('\n  [CONTINUING to Step 3 — figures will use whatever was saved]\n\n');
    end
end

%% ── Step 3: Generate all figures ─────────────────────────────────────────
fprintf('%s\n  STEP 3/3 — GENERATE ALL THESIS FIGURES\n%s\n\n', LINE, LINE);
log_write(fid_log, 'Step 3 START');
t_C = datetime('now');

try
    run(fullfile(script_dir, 'MASTER_C_GENERATE_ALL_FIGURES.m'));
    dur_C = datetime('now') - t_C;
    fprintf('\n[STEP 3 DONE]  %s\n\n', duration_str(dur_C));
    log_write(fid_log, sprintf('Step 3 DONE — %s', duration_str(dur_C)));
catch ME_C
    fprintf('\n[STEP 3 ERROR]\n  %s\n', ME_C.message);
    if ~isempty(ME_C.stack)
        fprintf('  File: %s  Line: %d\n', ME_C.stack(1).file, ME_C.stack(1).line);
    end
    log_write(fid_log, sprintf('Step 3 ERROR: %s', ME_C.message));
end

%% ── Final summary ────────────────────────────────────────────────────────
fprintf('%s\n  PIPELINE COMPLETE\n  Finished: %s\n%s\n\n', LINE, datestr(now), LINE);

output_files = {
    'fault_dataset_1000.mat',   'Dataset (MAT)';
    'fault_dataset_1000.csv',   'Dataset (CSV)';
    'rf_model_final.mat',       'Trained RF model';
    'rf_metrics_report.txt',    'RF evaluation report';
    'restoration_results_full.csv', 'Restoration results (all 36 scenarios)';
    'restoration_summary.txt',  'Restoration summary';
    'pipeline_full_log.txt',    'Pipeline log';
};

fprintf('  Output files:\n');
for k = 1:size(output_files, 1)
    fname = output_files{k, 1};
    label = output_files{k, 2};
    if exist(fname, 'file')
        d = dir(fname);
        if d.bytes > 1e6
            sz = sprintf('%.1f MB', d.bytes/1e6);
        else
            sz = sprintf('%.0f KB', d.bytes/1e3);
        end
        fprintf('  [OK]  %-40s (%s)\n', label, sz);
    else
        fprintf('  [--]  %-40s (not found)\n', label);
    end
end

fprintf('\n  Figure folders:\n');
fig_dirs = {'figures/ch3_methodology', 'figures/ch4_system_design', ...
            'figures/ch5_results',     'figures/ch6_conclusions'};
for k = 1:numel(fig_dirs)
    if exist(fig_dirs{k}, 'dir')
        n = numel(dir(fullfile(fig_dirs{k}, '*.png')));
        fprintf('  [OK]  %-40s (%d figures)\n', fig_dirs{k}, n);
    else
        fprintf('  [--]  %s\n', fig_dirs{k});
    end
end

log_write(fid_log, 'Pipeline complete');
fclose(fid_log);
fprintf('\n  Full log saved to: pipeline_full_log.txt\n');
fprintf('%s\n\n', LINE);

%% ── Restore sleep settings ───────────────────────────────────────────────
restore_sleep(sleep_disabled);


%% =========================================================================
%%  LOCAL HELPER FUNCTIONS
%% =========================================================================

function log_write(fid, msg)
%LOG_WRITE  Append a timestamped line to the log file.
    try
        fprintf(fid, '[%s]  %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), msg);
    catch
        % silently ignore if file handle is invalid
    end
end


function s = duration_str(dur)
%DURATION_STR  Format a duration as "Xh Ym Zs".
    total_s = seconds(dur);
    h = floor(total_s / 3600);
    m = floor(mod(total_s, 3600) / 60);
    s_rem = floor(mod(total_s, 60));
    s = sprintf('%dh %dm %ds', h, m, s_rem);
end


function restore_sleep(was_disabled)
%RESTORE_SLEEP  Re-enable Windows power settings after pipeline finishes.
    if was_disabled
        try
            system('powercfg /change standby-timeout-ac 30');
            system('powercfg /change monitor-timeout-ac 15');
            fprintf('[SYSTEM] Windows sleep restored (30 min standby).\n');
        catch
        end
    end
end
