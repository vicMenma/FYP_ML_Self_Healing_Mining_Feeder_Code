%% =========================================================================
%  RUN_ALL_PIPELINE.m   (v2 — sectionalised radial topology)
%  ─────────────────────────────────────────────────────────────────────────
%  Thesis: ML-Assisted Self-Healing of a 33/11 kV Mining Distribution Feeder
%  Author: Victoire Chinyanta Chimundu — CU-BEE-100-7229  |  Supervisor: Mr Charles Kasonde
%
%  Two modes (set MODE below, or answer the prompt):
%    'smoke' : quick verification of the isolation/restoration logic on
%              Healthy + SLG at B2,B3,B4,B5 (a few short sims). No dataset.
%    'full'  : MASTER_A -> MASTER_B -> MASTER_C, writing to outputs_v2_topology/
%
%  ALWAYS run the smoke test and confirm it before launching the full run.
%  Old final-release outputs are never overwritten (everything goes to v2).
% =========================================================================

clc;
MODEL    = 'mining_feeder_layer_FINAL_baseline';
OUT_ROOT = fullfile(pwd,'outputs_v2_topology');
OUT_SUM  = fullfile(OUT_ROOT,'summaries');
if ~exist(OUT_SUM,'dir'); mkdir(OUT_SUM); end

MODE = '';   % '' -> ask ; or hard-set to 'smoke' / 'full'
if isempty(MODE)
    MODE = lower(strtrim(input('Mode? [smoke/full]: ','s')));
end

%% ---------------------------------------------------------------- SMOKE TEST
if strcmp(MODE,'smoke')
    fprintf('\n===== SMOKE TEST (isolation / restoration logic) =====\n');
    smoke_test(MODEL, OUT_SUM);
    fprintf('\nSmoke test complete. Review %s before running the full pipeline.\n', ...
        fullfile(OUT_SUM,'smoke_test_report_v2.txt'));
    return;
end

if strcmp(MODE,'full')
    % The smoke test is the cheap safety gate (~1 min) before the hours-long
    % full run. If a recent report exists you may skip the re-run — but note
    % that a report only reflects the model AS IT WAS when it was generated.
    runSmoke = true;
    rep = fullfile(OUT_SUM,'smoke_test_report_v2.txt');
    if exist(rep,'file')
        d = dir(rep); ageMin = (now - d.datenum)*24*60;
        fprintf('\nA smoke report already exists (%.0f min old):\n  %s\n', ageMin, rep);
        resp = lower(strtrim(input('Re-run the smoke test first? [y = re-run (recommended) / n = skip]: ','s')));
        runSmoke = ~strcmp(resp,'n');
        if ~runSmoke
            fprintf(['  Skipping smoke re-run. NOTE: the existing report reflects the model\n' ...
                     '  as it was when generated - if the model changed since, re-run smoke.\n']);
        end
    end
    if runSmoke
        fprintf('\n===== SMOKE TEST (isolation / restoration logic) =====\n');
        smoke_test(MODEL, OUT_SUM);
    end
    resp = lower(strtrim(input('\nProceed to FULL pipeline? [y/n]: ','s')));
    if ~strcmp(resp,'y'); fprintf('Aborted before full run.\n'); return; end
end

%% ------------------------------------------------------------ FULL PIPELINE
t0=tic;

% ---- STEP 1: MASTER_A — skippable when a COMPLETED dataset already exists.
% (fault_dataset_v2.mat is only written at the end of MASTER_A, so its
%  existence proves a finished run; interrupted runs resume via checkpoint.)
dsfile = fullfile(OUT_ROOT,'fault_dataset_v2.mat');
skipA = false;
if exist(dsfile,'file')
    d = dir(dsfile); nsamp = '?';
    try, S = load(dsfile,'y'); nsamp = num2str(numel(S.y)); catch, end
    fprintf('\nA completed dataset already exists:\n  %s\n  created: %s   samples: %s\n', ...
        dsfile, d.date, nsamp);
    fprintf(['  NOTE: reuse it ONLY if the Simulink model has NOT changed since that\n' ...
             '  date — skipping also skips the SLG pre-flight on the current model.\n']);
    r = lower(strtrim(input('Skip MASTER_A and reuse this dataset? [y = skip / n = regenerate]: ','s')));
    skipA = strcmp(r,'y');
end
if skipA
    fprintf('\n[STEP 1/4] MASTER_A SKIPPED — existing dataset reused.\n');
    % Refresh the CSV export from the reused .mat (no simulation needed) so it
    % always matches the current export format, incl. the scenario column.
    try
        S = load(dsfile);
        T = array2table(S.X,'VariableNames',S.featNames);
        T.class = S.y; T.label = S.CLASS_NAMES(S.y+1)';
        if isfield(S,'meta') && numel(S.meta)==numel(S.y); T.scenario = S.meta; end
        writetable(T, fullfile(OUT_ROOT,'fault_dataset_v2.csv'));
        xfile = fullfile(OUT_ROOT,'fault_dataset_v2.xlsx');
        writetable(T, xfile, 'Sheet','dataset');
        cnt  = histcounts(S.y, -0.5:1:12.5)';
        Tsum = table((0:12)', S.CLASS_NAMES(:), cnt, 'VariableNames', {'class','label','samples'});
        writetable(Tsum, xfile, 'Sheet','class_summary');
        fprintf('    fault_dataset_v2.csv and .xlsx refreshed from the reused dataset.\n');
    catch ME
        warning('CSV refresh failed (dataset itself unaffected): %s', ME.message);
    end
else
    fprintf('\n[STEP 1/4] MASTER_A — pre-flight + dataset\n');
    run('MASTER_A_PREFLIGHT_AND_DATASET.m');
end

% ---- STEP 2: MASTER_B — skippable only when ALL of its outputs exist -------
bOK = exist(fullfile(OUT_ROOT,'rf_model_v2.mat'),'file') && ...
      exist(fullfile(OUT_ROOT,'restoration_results_v2.csv'),'file') && ...
      numel(dir(fullfile(OUT_ROOT,'waveforms_v2','wave_*.mat'))) >= 12;
skipB = false;
if bOK
    r = lower(strtrim(input(['\nMASTER_B outputs already exist (model + restoration + 12 waveforms).\n' ...
                             'Skip MASTER_B? [y = skip / n = re-run]: '],'s')));
    skipB = strcmp(r,'y');
end
if skipB
    fprintf('\n[STEP 2/4] MASTER_B SKIPPED — existing model and restoration outputs reused.\n');
else
    fprintf('\n[STEP 2/4] MASTER_B — train + restore\n');
    run('MASTER_B_TRAIN_AND_RESTORE.m');
end

fprintf('\n[STEP 3/4] MASTER_C — thesis figures\n');
run('MASTER_C_GENERATE_ALL_FIGURES.m');

% ---- STEP 4: analysis & validation (ablation + robustness) ----------------
% These run after the model exists. The ablation and noise tests reuse the
% existing dataset/model and need NO new simulation (seconds). The off-grid
% interpolation test DOES simulate ~72 new cases (~1-1.5 h) and is therefore
% offered as an optional prompt so a routine pipeline run is not held up.
fprintf('\n[STEP 4/4] Analysis & validation scripts\n');
if exist(fullfile(OUT_ROOT,'rf_model_v2.mat'),'file')
    fprintf('  - Cost-sensitivity ablation (RQ2, no re-simulation) ...\n');
    try, run('ABLATION_COST_SENSITIVITY.m'); catch ME; warning('Ablation failed: %s', ME.message); end
    fprintf('  - Measurement-noise robustness (no re-simulation) ...\n');
    try, run('NOISE_ROBUSTNESS.m'); catch ME; warning('Noise test failed: %s', ME.message); end
    fprintf('  - Rule-based baseline vs Random Forest (no re-simulation) ...\n');
    try, run('BASELINE_RULE_VS_RF.m'); catch ME; warning('Baseline test failed: %s', ME.message); end
    ri = lower(strtrim(input(['  Run the off-grid INTERPOLATION test now? It simulates ~72 new\n' ...
        '  cases (~1-1.5 h). [y = run / n = skip]: '],'s')));
    if strcmp(ri,'y')
        try, run('INTERPOLATION_TEST.m'); catch ME; warning('Interpolation test failed: %s', ME.message); end
    else
        fprintf('    Interpolation test skipped (run INTERPOLATION_TEST.m separately when ready).\n');
    end
else
    fprintf('  Skipped — rf_model_v2.mat not found (run MASTER_B first).\n');
end

fprintf('\nFULL PIPELINE COMPLETE in %.1f min. Outputs in %s\n', toc(t0)/60, OUT_ROOT);

%% =========================================================================
%%  SMOKE TEST — self-contained
%% =========================================================================
function smoke_test(MODEL, OUT_SUM)
    load_system(MODEL);
    BL = discover_blocks(MODEL);
    % ALL electrical values below are read live from the model — no fallbacks.
    % If a read fails the smoke test ABORTS instead of using a built-in number.
    T2VA  = read_xfmr_va(MODEL,'T2');
    VBASE = read_xfmr_v2(MODEL,'T1');
    VBAND = [0.95 1.05];                 % design acceptance band (pu), not a model value
    loadVA = read_load_va(BL);
    fprintf('  [model read] loads: B2=%.2f  B3=%.2f  B4=%.2f  B5=%.2f MVA\n', ...
        loadVA.B2/1e6, loadVA.B3/1e6, loadVA.B4/1e6, loadVA.B5/1e6);
    fid = fopen(fullfile(OUT_SUM,'smoke_test_report_v2.txt'),'w');
    pr = @(varargin) fprintf_both(fid, varargin{:});
    pr('SMOKE TEST REPORT (v2)\nGenerated: %s\n\n', datestr(now));

    % Load the trained classifier. When available the smoke test runs CLOSED
    % LOOP: the switching decision is driven by the RF PREDICTION, never by
    % the known injected zone.
    rf=[]; try, S=load(fullfile(fileparts(OUT_SUM),'rf_model_v2.mat')); rf=S.rf; catch, end
    closedLoop = ~isempty(rf);
    if closedLoop
        pr('MODE: CLOSED LOOP — the isolation/tie decision is driven by the RF\n');
        pr('      prediction computed from Stage-1 measurements on the normal\n');
        pr('      network (fault active, breakers closed, tie open). Nothing\n');
        pr('      tells the switching logic where the fault is.\n\n');
    else
        pr('MODE: OPEN LOOP — no trained model found (rf_model_v2.mat missing).\n');
        pr('      Switching is driven by the KNOWN injected zone to verify the\n');
        pr('      breaker/tie logic only; this does NOT test the ML chain.\n');
        pr('      Run MASTER_A + MASTER_B, then re-run smoke for the closed loop.\n\n');
    end

    cases = {'Healthy','B2','B3','B4','B5'};
    for c = 1:numel(cases)
        zone = cases{c};
        set_normal_state(BL); clear_all_faults(BL); set_loads(BL,1.0);

        if ~strcmp(zone,'Healthy')
            set_param(BL.fault.(zone),'FaultA','on','GroundFault','on', ...
                'FaultResistance','0.001','GroundResistance','0.001', ...
                'SwitchTimes','[0.5 2.0]','InitialStates','0');
        end

        % ---------- STAGE 1: DETECTION on the normal network ----------
        % Fault active, all breakers closed, tie open — the same conditions the
        % classifier was trained under. The RF sees ONLY the 24 RMS features.
        set_param(MODEL,'StopTime','2.0');
        s1 = sim(MODEL,'SimulationMode','normal','SaveOutput','on','SaveTime','on', ...
            'SignalLogging','on','SignalLoggingName','logsout','SaveFormat','Dataset');

        % DATA-DRIVEN detection: the feature-sampling instant comes from the
        % measurements themselves, never from the known injection time.
        [tdet, distFound] = detect_onset(s1, VBASE);
        if distFound; tsamp = min(tdet+0.5, 1.9); else; tsamp = 1.5; end

        assigned = zone; predicted = '(no model)';
        if closedLoop
            f = features24(s1, tsamp);
            predicted = zone_of_class(str2double(predict(rf,f)));
        end
        predMatch = strcmp(predicted, zone);

        % ---------- DECISION: the policy input is the PREDICTION ----------
        if closedLoop; decision = predicted; else; decision = zone; end
        [brk, isolated, restored, attemptTie, remainsT1] = zone_policy(decision);

        % ---------- STAGE 2: act on the decision (fault still active) ----------
        capOk = true; restVA = NaN; tieClosed = false;
        if strcmp(decision,'Healthy')
            sOut = s1;        % no switching commanded -> stage-1 network stands
        else
            for i=1:numel(brk); set_switch(BL.ctrl.(brk{i}), false); end
            if attemptTie
                % capacity from MEASURED pre-fault load (Stage-1 window
                % [0.30,0.45] s). CT placement in this model: each measurement
                % is in series with its OWN fault+load branch (verified: healthy
                % currents equal the individual load currents), so per-bus VAs
                % are independent and must be SUMMED. Post-restoration voltage
                % verification remains the final backstop.
                restVA = 0;
                for i=1:numel(restored)
                    restVA = restVA + measured_bus_va(s1, restored{i}, [0.30 0.45]);
                end
                restVA = restVA + measured_bus_va(s1, 'B5', [0.30 0.45]);
                capOk  = restVA <= T2VA;
            end
            tieClosed = attemptTie && capOk;
            set_switch(BL.ctrl.TIE, tieClosed);
            sOut = sim(MODEL,'SimulationMode','normal','SaveOutput','on','SaveTime','on', ...
                'SignalLogging','on','SignalLoggingName','logsout','SaveFormat','Dataset');
        end

        % post-restoration voltages
        Vpu=[];
        for i=1:numel(restored); Vpu(end+1)=pu_voltage(sOut,['RMS_V_' restored{i}],VBASE,1.6); end %#ok<AGROW>
        Vok = isempty(Vpu) || all(Vpu>=VBAND(1)&Vpu<=VBAND(2));
        if tieClosed && ~Vok; set_switch(BL.ctrl.TIE,false); tieClosed=false; end

        % status + tie reason. For B4/B5, keeping the tie OPEN is the designed
        % correct action (closing would backfeed the faulted zone) — it is NOT
        % a blocked restoration attempt, so the status is ISOLATED_NO_TIE.
        if strcmp(decision,'Healthy')
            status='HEALTHY_NO_ACTION';
            tieReason='n/a (no fault detected)';
        elseif ~attemptTie
            status='ISOLATED_NO_TIE';
            tieReason='kept OPEN by design: closing would backfeed the faulted zone; healthy buses remain on T1';
        elseif ~capOk
            status='BLOCKED_BY_CAPACITY';
            tieReason=sprintf('close refused: reconnected load %.2f MVA exceeds T2 rating %.2f MVA', restVA/1e6, T2VA/1e6);
        elseif tieClosed && Vok
            status='RESTORED';
            tieReason='CLOSED: capacity and 0.95-1.05 pu voltage checks passed';
        else
            status='ISOLATED_NO_TIE';
            tieReason='reverted OPEN: post-restoration voltage outside 0.95-1.05 pu band';
        end

        % outcome judged against the ACTUAL injected zone
        vFaultAct = NaN;
        if ~strcmp(zone,'Healthy'); vFaultAct = pu_voltage(sOut,['RMS_V_' zone],VBASE,1.6); end
        if closedLoop && ~predMatch
            status = ['WRONG_PREDICTION_' status];   % actions were applied per a wrong zone
        end

        tieEligible = attemptTie;                          % only B2/B3 are tie-eligible
        tieClosedInto_B4B5 = tieClosed && any(strcmp(zone,{'B4','B5'}));

        pr('---- Case: %s ----\n', zone);
        pr('  1. injected (actual) zone  : %s\n', assigned);
        pr('     RF predicted zone       : %s%s\n', predicted, ...
           ternary(~closedLoop,'', ternary(predMatch,'   [MATCH]','   [*** MISMATCH ***]')));
        pr('     decision driven by      : %s -> policy applied for "%s"\n', ...
           ternary(closedLoop,'RF prediction (CLOSED loop)','known zone (OPEN loop)'), decision);
        if distFound
            pr('     disturbance detected    : yes, at t = %.3f s (measured; features sampled at %.3f s)\n', tdet, tsamp);
        else
            pr('     disturbance detected    : no (steady state; features sampled at 1.50 s)\n');
        end
        pr('  2. breakers opened         : %s\n', ternary(isempty(brk),'(none)',strjoin(brk,', ')));
        pr('  3. tie state               : %s\n', ternary(tieClosed,'CLOSED','OPEN'));
        pr('     tie reason              : %s\n', tieReason);
        if attemptTie
            pr('     capacity check          : MEASURED reconnect %.2f MVA vs T2 %.2f MVA -> %s\n', ...
               restVA/1e6, T2VA/1e6, ternary(capOk,'OK','EXCEEDED'));
        end
        pr('  4. isolated zone (by action): %s\n', isolated);
        if ~strcmp(zone,'Healthy')
            pr('     actual faulted bus %s V  : %.3f pu -> %s\n', zone, vFaultAct, ...
               ternary(vFaultAct<0.8,'de-energised (isolation effective)','STILL ENERGISED *** check ***'));
        end
        pr('  5. restored zones (via tie): %s\n', ternary(isempty(restored),'(none)',strjoin(restored,', ')));
        pr('     remains on T1 (main path): %s\n', ternary(isempty(remainsT1),'(none)',strjoin(remainsT1,', ')));
        pr('  6. tie eligible for close  : %s\n', ternary(tieEligible,'yes (B2/B3 only)','no'));
        pr('  7. tie closed into B4/B5   : %s   (MUST be no)\n', ternary(tieClosedInto_B4B5,'YES *** VIOLATION ***','no'));
        if ~isempty(Vpu)
            pr('  8. post-restoration V (pu) : %s   [band %.2f-%.2f]\n', mat2str(round(Vpu,4)), VBAND(1),VBAND(2));
        else
            pr('  8. post-restoration V (pu) : (no restoration attempted)\n');
        end
        pr('     status                  : %s\n', status);

        % per-case waveform evidence (both stages) for supervisor review
        wdir = fullfile(OUT_SUM,'smoke_waveforms');
        if ~exist(wdir,'dir'); mkdir(wdir); end
        wfile = fullfile(wdir, sprintf('smoke_%02d_%s.png', c, zone));
        try
            smoke_wavefig(s1, sOut, zone, decision, status, VBASE, VBAND, tdet, wfile);
            pr('     waveform figure         : %s\n\n', wfile);
        catch MEw
            pr('     waveform figure         : FAILED (%s)\n\n', MEw.message);
        end

        clear_all_faults(BL); set_normal_state(BL);
    end
    fclose(fid);
end

function smoke_wavefig(s1, s2, zone, decision, status, VBASE, VBAND, tdet, fout)
% Two-stage waveform evidence for one smoke case, rendered from the live
% simulation data of THIS case (nothing synthetic):
%   Stage 1 — all bus voltages (pu) + faulted-bus current with the fault on
%             the normal network (tie open, breakers closed);
%   Stage 2 — all bus voltages (pu) after the prediction-driven switching.
    busn={'B2','B3','B4','B5'}; cols=lines(4);
    fig=figure('Visible','off','Position',[40 40 1020 780],'Color','w');

    subplot(2,1,1); hold on; grid on; box on;
    for b=1:4
        M=get_rms(s1,['RMS_V_' busn{b}]);
        plot(M(:,1), mean(M(:,2:4),2)/VBASE, '-','Color',cols(b,:),'LineWidth',1.3);
    end
    yline(VBAND(1),'r--'); yline(VBAND(2),'r--');
    if ~isnan(tdet); xline(tdet,'k:','detected'); end
    ylim([0 1.2]); ylabel('Bus voltage (pu)');
    if strcmp(zone,'Healthy')
        title('Stage 1 — healthy network (no fault injected)');
    else
        title(sprintf('Stage 1 — fault at %s on the normal network (tie open)', zone));
    end
    legend([busn {'0.95 pu','1.05 pu'}],'Location','eastoutside');

    subplot(2,1,2); hold on; grid on; box on;
    for b=1:4
        M=get_rms(s2,['RMS_V_' busn{b}]);
        plot(M(:,1), mean(M(:,2:4),2)/VBASE, '-','Color',cols(b,:),'LineWidth',1.3);
    end
    yline(VBAND(1),'r--'); yline(VBAND(2),'r--');
    ylim([0 1.2]); xlabel('Time (s)'); ylabel('Bus voltage (pu)');
    title(sprintf('Stage 2 — after action for predicted "%s"  ->  %s', decision, status), 'Interpreter','none');
    legend([busn {'0.95 pu','1.05 pu'}],'Location','eastoutside');

    exportgraphics(fig, fout, 'Resolution', 200); close(fig);
end

function [brk, isolated, restored, attemptTie, remainsT1] = zone_policy(zone)
% DETERMINISTIC protection action table — intentionally NOT learned from data.
% What must be (and is) LEARNED is the input to this function: the fault ZONE,
% which the RF classifier infers from the 24 RMS measurements alone. In the
% closed-loop test this function receives the PREDICTION, never the truth.
% The zone->breaker mapping itself is fixed by the physical topology (which
% breaker feeds which bus is a fact of the network, not a statistical
% discovery) and must remain deterministic and auditable, as in any
% certifiable protection scheme. "ML-assisted self-healing" = learned
% localisation feeding a fixed, verifiable switching policy.
%   restored  = healthy zones re-energised through the T2/tie path
%   remainsT1 = healthy zones that never lose supply (stay on the T1 main path)
    switch zone
        case 'Healthy'; brk={};                        isolated='(none)'; restored={};          attemptTie=false; remainsT1={'B2','B3','B4'};
        case 'B2';      brk={'CB_MAIN','CB_BUS1_B3'};   isolated='B2';     restored={'B3','B4'}; attemptTie=true;  remainsT1={};
        case 'B3';      brk={'CB_BUS1_B3','CB_BUS1_B4'};isolated='B3';     restored={'B4'};      attemptTie=true;  remainsT1={'B2'};
        case 'B4';      brk={'CB_BUS1_B4'};             isolated='B4';     restored={};          attemptTie=false; remainsT1={'B2','B3'};
        case 'B5';      brk={'CB_T2_BUS5'};             isolated='B5';     restored={};          attemptTie=false; remainsT1={'B2','B3','B4'};
        otherwise
            error('zone_policy:unknown','No policy for decision "%s".', zone);
    end
end
function va = read_xfmr_va(MODEL, tok)
% Read NominalPower = [S, f] directly from the ACTUAL transformer block.
% NO fallback: if the value cannot be read from the live model, ABORT loudly.
    b = find_xfmr(MODEL, tok);
    if isempty(b)
        error('read_xfmr:notfound', ...
            'No transformer matching "%s" found (probed mask parameters of all root-level blocks).', tok);
    end
    nums = str2num(get_param(b,'NominalPower')); %#ok<ST2NM>
    if isempty(nums) || nums(1) <= 0
        error('read_xfmr:badvalue','Could not parse NominalPower of block "%s".', regexprep(b,'\s+',' '));
    end
    va = nums(1);
    fprintf('  [model read] %s rating = %.2f MVA   (block: %s)\n', tok, va/1e6, regexprep(b,'\s+',' '));
end
function v = read_xfmr_v2(MODEL, tok)
% Read the secondary line-to-line voltage = first element of Winding2 = [Vll R L].
% NO fallback: aborts if unreadable.
    b = find_xfmr(MODEL, tok);
    if isempty(b)
        error('read_xfmr:notfound', ...
            'No transformer matching "%s" found (probed mask parameters of all root-level blocks).', tok);
    end
    w = str2num(get_param(b,'Winding2')); %#ok<ST2NM>
    if isempty(w) || w(1) <= 0
        error('read_xfmr:badvalue','Could not parse Winding2 of block "%s".', regexprep(b,'\s+',' '));
    end
    v = w(1);
    fprintf('  [model read] %s secondary voltage = %.0f V line-to-line   (block: %s)\n', tok, v, regexprep(b,'\s+',' '));
end
function b = find_xfmr(MODEL, tok)
% Identify the transformer by PROBING ACTUAL MASK PARAMETERS in the LIVE model:
% the root-level block whose normalised name starts with tok AND whose mask
% really contains NominalPower + Winding2. No BlockType/SourceBlock filtering —
% those are .slx file-format attributes that linked library blocks do NOT
% report at runtime, which is why the previous search missed the transformer.
    b = '';
    blks = find_system(MODEL,'SearchDepth',1);
    for i = 1:numel(blks)
        if strcmp(blks{i}, MODEL); continue; end
        nm = strtrim(regexprep(get_param(blks{i},'Name'),'\s+',' '));
        if ~startsWith(nm, tok); continue; end
        try
            mn = get_param(blks{i},'MaskNames');
            if any(strcmp(mn,'NominalPower')) && any(strcmp(mn,'Winding2'))
                b = blks{i}; return;
            end
        catch
        end
    end
end
function z = zone_of_class(c)
    if c==0; z='Healthy';
    elseif c<=3; z='B2'; elseif c<=6; z='B3'; elseif c<=9; z='B4'; else; z='B5'; end
end

function fprintf_both(fid, varargin)
    fprintf(varargin{:}); fprintf(fid, varargin{:});
end

%% ---- shared model helpers (standalone copies) ----
function BL = discover_blocks(MODEL)
    z={'B2','B3','B4','B5'}; BL.fault=struct(); BL.load=struct();
    for k=1:numel(z)
        BL.fault.(z{k})=pick(MODEL,{['Fault_' z{k}], leg(z{k},'Fault_SXEW')},'Reference');
        BL.load.(z{k}) =pick(MODEL,{['DL_' z{k}],    leg(z{k},'DL_SXEW')},   'Reference');
    end
    BL.ctrl.CB_MAIN=pick_ctrl(MODEL,'CB_MAIN');
    BL.ctrl.CB_BUS1_B3=pick_ctrl(MODEL,'CB_BUS1_B3');
    BL.ctrl.CB_BUS1_B4=pick_ctrl(MODEL,'CB_BUS1_B4');
    BL.ctrl.CB_T2_BUS5=pick_ctrl(MODEL,'CB_T2_BUS5');
    BL.ctrl.TIE=pick_ctrl(MODEL,'TIE');
end
function s=leg(zone,name); if strcmp(zone,'B5'); s=name; else; s=''; end; end
function p=pick(MODEL,cands,bt)
    p='';
    for i=1:numel(cands)
        nm=cands{i}; if isempty(nm); continue; end
        h=find_system(MODEL,'SearchDepth',1,'BlockType',bt,'Name',nm);
        if isempty(h)
            h=find_system(MODEL,'SearchDepth',1,'RegExp','on','Name', ...
               ['^' regexprep(regexptranslate('escape',nm),'\s+','\\s+') '$']);
        end
        if ~isempty(h); p=getfullname(h{1}); return; end
    end
    error('pick:notfound','none of: %s',strjoin(cands,', '));
end
function p=pick_ctrl(MODEL,tok)
    cs=find_system(MODEL,'SearchDepth',1,'BlockType','Constant');
    for i=1:numel(cs)
        nm=regexprep(get_param(cs{i},'Name'),'\s+',' ');
        if contains(nm,tok); p=getfullname(cs{i}); return; end
    end
    error('pick_ctrl:notfound','no Constant matching %s',tok);
end
function set_switch(ctrl,closed); set_param(ctrl,'Value',num2str(double(logical(closed)))); end
function set_normal_state(BL)
    set_switch(BL.ctrl.CB_MAIN,true); set_switch(BL.ctrl.CB_BUS1_B3,true);
    set_switch(BL.ctrl.CB_BUS1_B4,true); set_switch(BL.ctrl.CB_T2_BUS5,true);
    set_switch(BL.ctrl.TIE,false);
end
function clear_all_faults(BL)
    z=fieldnames(BL.fault);
    for k=1:numel(z)
        set_param(BL.fault.(z{k}),'FaultA','off','FaultB','off','FaultC','off','GroundFault','off', ...
                  'SwitchTimes','[1000000 1000001]','InitialStates','0');
    end
end
function set_loads(BL,lm)
    z=fieldnames(BL.load);
    for k=1:numel(z)
        b=BL.load.(z{k});
        for pn={'ActivePower','InductiveReactivePower'}
            try
                mn=get_param(b,'MaskNames');
                if any(strcmp(mn,pn{1}))
                    ud=get_param(b,'UserData'); key=matlab.lang.makeValidName(pn{1});
                    if ~isstruct(ud)||~isfield(ud,key)
                        base=str2double(get_param(b,pn{1}));
                        if ~isstruct(ud); ud=struct(); end; ud.(key)=base; set_param(b,'UserData',ud);
                    else; base=ud.(key); end
                    set_param(b,pn{1},num2str(base*lm));
                end
            catch; end
        end
    end
end
function loadVA = read_load_va(BL)
    z=fieldnames(BL.load); loadVA=struct();
    for k=1:numel(z)
        P=sg(BL.load.(z{k}),'ActivePower',1e6); Q=sg(BL.load.(z{k}),'InductiveReactivePower',0);
        loadVA.(z{k})=hypot(P,Q);
    end
end
function v=sg(b,p,d); try v=str2double(get_param(b,p)); if isnan(v); v=d; end; catch; v=d; end; end
function v=pu_voltage(sOut,varname,VBASE,t)
    M=get_rms(sOut,varname); tt=M(:,1); [~,idx]=min(abs(tt-t));
    phaseRMS=mean(M(max(1,idx-3):min(size(M,1),idx+3),2:4),1); v=mean(phaseRMS)/VBASE;  % RMS_V is line-to-line -> pu (11 kV LL base)
end
function f=features24(sOut, tsamp)
% 24 RMS features sampled at tsamp — which the CALLER derives from the
% measured disturbance-detection time, never from the known fault onset.
    V={'RMS_V_B2','RMS_V_B3','RMS_V_B4','RMS_V_B5'}; I={'RMS_I_B2','RMS_I_B3','RMS_I_B4','RMS_I_B5'};
    f=zeros(1,24); c=0;
    for k=1:4
        Vm=get_rms(sOut,V{k}); Im=get_rms(sOut,I{k});
        f(c+1:c+3)=at(Vm,tsamp); f(c+4:c+6)=at(Im,tsamp); c=c+6;
    end
end

function [tdet, found] = detect_onset(sOut, VBASE)
% DATA-DRIVEN disturbance detection — no ground-truth onset time is used.
% Baseline window [0.30,0.45] s; the disturbance instant is the first sample
% after 0.45 s where any bus phase current exceeds 1.5x its own baseline or
% any bus voltage drops below 0.85 pu.
    sigsI={'RMS_I_B2','RMS_I_B3','RMS_I_B4','RMS_I_B5'};
    sigsV={'RMS_V_B2','RMS_V_B3','RMS_V_B4','RMS_V_B5'};
    tdet=NaN; found=false; tCand=[];
    for k=1:4
        M=get_rms(sOut,sigsI{k}); t=M(:,1);
        base=mean(M(t>=0.30 & t<=0.45, 2:4),1);
        dev = M(:,2:4) > 1.5*max(base,1e-3);
        idx=find(any(dev,2) & t>0.45, 1,'first');
        if ~isempty(idx); tCand(end+1)=t(idx); end %#ok<AGROW>
        Mv=get_rms(sOut,sigsV{k}); vpu=mean(Mv(:,2:4),2)/VBASE;
        idx2=find(vpu<0.85 & Mv(:,1)>0.45, 1,'first');
        if ~isempty(idx2); tCand(end+1)=Mv(idx2,1); end %#ok<AGROW>
    end
    if ~isempty(tCand); tdet=min(tCand); found=true; end
end

function va = measured_bus_va(sOut, bus, twin)
% Apparent power estimated from MEASURED pre-fault RMS values in window twin:
% S = sqrt(3) * VLL * I  (RMS_V signals are line-to-line).
    Mv=get_rms(sOut,['RMS_V_' bus]); Mi=get_rms(sOut,['RMS_I_' bus]);
    t=Mv(:,1); w = t>=twin(1) & t<=twin(2);
    VLL = mean(mean(Mv(w,2:4),2));
    ti=Mi(:,1); wi = ti>=twin(1) & ti<=twin(2);
    I   = mean(mean(Mi(wi,2:4),2));
    va  = sqrt(3)*VLL*I;
end
function row=at(M,t); tt=M(:,1);[~,idx]=min(abs(tt-t)); lo=max(1,idx-2);hi=min(size(M,1),idx+2); row=mean(M(lo:hi,2:4),1); end
function M=get_rms(sOut,varname)
    s=[]; try, s=sOut.get(varname); catch, end
    if isempty(s)&&evalin('base',['exist(''' varname ''',''var'')']); s=evalin('base',varname); end
    if isstruct(s)&&isfield(s,'signals'); t=s.time; val=s.signals.values;
    elseif isa(s,'timeseries'); t=s.Time; val=s.Data;
    else; error('get_rms:fmt','cannot read %s',varname); end
    if size(val,2)<3; val=repmat(val(:,1),1,3); end
    M=[t(:),val(:,1:3)];
end
function s=ternary(c,a,b); if c; s=a; else; s=b; end; end
