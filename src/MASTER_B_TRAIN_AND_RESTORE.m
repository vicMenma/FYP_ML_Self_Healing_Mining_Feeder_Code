%% =========================================================================
%  MASTER_B_TRAIN_AND_RESTORE.m   (v2 — sectionalised radial topology)
%  ─────────────────────────────────────────────────────────────────────────
%  Thesis: ML-Assisted Self-Healing of a 33/11 kV Mining Distribution Feeder
%  Author: Victoire Chinyanta Chimundu — CU-BEE-100-7229  |  Supervisor: Mr Charles Kasonde
%
%  [1] Trains a 500-tree cost-sensitive Random Forest on the v2 dataset.
%  [2] Reports SIMPLE, defendable metrics only:
%        confusion matrix, accuracy, precision, recall, F1,
%        five-fold cross-validation, OOB error, feature importance.
%      (No Wilson interval, no McNemar, no bootstrap CIs, no p-values.)
%  [3] Runs the zone-based isolation + topology-limited restoration logic and
%      assigns an explicit status to every scenario:
%        RESTORED | ISOLATED_NO_TIE | BLOCKED_BY_CAPACITY | ERROR
%      For B4/B5 the tie is kept OPEN by design (closing would backfeed the
%      faulted zone) -> status ISOLATED_NO_TIE with the reason in Note, and
%      the healthy upstream buses are reported under RemainsOnT1.
%
%  Restoration policy (exact):
%    Fault_B2 : open CB_MAIN + CB_BUS1_B3 ; tie-close if V & T2 capacity OK ;
%               restored = {B3,B4} ; isolated = B2
%    Fault_B3 : open CB_BUS1_B3 + CB_BUS1_B4 ; tie-close if V & capacity OK ;
%               B2 stays on T1 ; restored = {B4} ; isolated = B3
%    Fault_B4 : open CB_BUS1_B4 ; TIE stays OPEN (would backfeed B4) ;
%               B2,B3 stay on T1 ; isolated = B4
%    Fault_B5 : open CB_T2_BUS5 ; TIE stays OPEN (would backfeed B5) ;
%               main feeder stays on T1 ; isolated = B5
%  Restoration is CONDITIONAL and TOPOLOGY-LIMITED — never "full restoration
%  for all fault locations", and the tie NEVER backfeeds the faulted zone.
% =========================================================================

clc; close all; rng(42);
MODEL   = 'mining_feeder_layer_FINAL_baseline';
OUT_ROOT = fullfile(pwd,'outputs_v2_topology');
OUT_SUM  = fullfile(OUT_ROOT,'summaries');
if ~exist(OUT_SUM,'dir'); mkdir(OUT_SUM); end
LOG = fullfile(OUT_SUM,'pipeline_log_v2.txt');
logf(LOG, sprintf('MASTER_B (v2) started %s', datestr(now)), true);

VBAND = [0.95 1.05];      % pu acceptance band — DESIGN criterion, not a model value
% VBASE and T2_RATING_VA are NOT hardcoded: both are read live from the model
% in section [2] (read_xfmr_v2 / read_xfmr_va) and the script ABORTS if the
% reads fail. No electrical fallback values exist in this script.
LOAD_LEVELS  = [0.70 1.00 1.30];
CLASS_NAMES  = {'Healthy','SLG-B2','LL-B2','3PH-B2','SLG-B3','LL-B3','3PH-B3', ...
                'SLG-B4','LL-B4','3PH-B4','SLG-B5','LL-B5','3PH-B5'};

%% =========================================================================
%%  [1] LOAD DATASET + TRAIN RANDOM FOREST
%% =========================================================================
% ---- ENTRY GATE: refuse to run on a missing or malformed dataset -----------
dsfile = fullfile(OUT_ROOT,'fault_dataset_v2.mat');
if ~exist(dsfile,'file')
    error('MASTER_B:NoDataset', ...
        ['fault_dataset_v2.mat not found in %s.\n' ...
         'MASTER_A has not completed dataset generation. Run MASTER_A first\n' ...
         '(expect several HOURS for the 1000-sample sweep). MASTER_B itself\n' ...
         'then needs ~30-60 minutes for the restoration simulations.'], OUT_ROOT);
end
S = load(dsfile);   % X, y, featNames, CLASS_NAMES
X = S.X; y = S.y; featNames = S.featNames;
assert(size(X,2)==24, 'MASTER_B:BadDataset', 'Expected 24 features, found %d.', size(X,2));
assert(numel(unique(y))==13, 'MASTER_B:BadDataset', 'Expected 13 classes, found %d.', numel(unique(y)));
assert(size(X,1)>=500, 'MASTER_B:BadDataset', ...
    'Only %d samples found — dataset generation appears incomplete.', size(X,1));
logf(LOG, sprintf('Dataset gate PASSED: %d samples, %d features, %d classes.', ...
    size(X,1), size(X,2), numel(unique(y))));

% stratified 80/20 split
cv = cvpartition(y,'HoldOut',0.20);
Xtr = X(training(cv),:); ytr = y(training(cv));
Xte = X(test(cv),:);     yte = y(test(cv));

% cost-sensitive: penalise fault-to-Healthy (false negative) by 12.5x
K = 13; C = ones(K) - eye(K);
C(2:13, 1) = 12.5;                 % true fault (rows 2..13) predicted Healthy (col 1)
classes = 0:12;

fprintf('Training 500-tree cost-sensitive Random Forest on %d samples ...\n', numel(ytr));
tTrain = tic;
rf = TreeBagger(500, Xtr, ytr, 'Method','classification', ...
    'OOBPrediction','on','OOBPredictorImportance','on', ...
    'Cost', C);   % numeric labels: class order = sorted unique(ytr) = 0..12, matches C
logf(LOG, sprintf('RF training done in %.1f s. (Training on 800x24 samples IS genuinely fast;', toc(tTrain)));
logf(LOG,        '   the slow, provable part of MASTER_B is the restoration simulations below.)');

% ---- test-set evaluation ----
yhat = str2double(predict(rf, Xte));
acc  = mean(yhat == yte);
Cm   = confusionmat(yte, yhat, 'Order', classes);
[prec, rec, f1] = prf_from_confusion(Cm);

% ---- OOB error curve + feature importance (naturally available) ----
oobErr = oobError(rf);
imp    = rf.OOBPermutedPredictorDeltaError(:).';

% ---- five-fold stratified cross-validation (simple) ----
tCV = tic;
cvACC = zeros(5,1); c5 = cvpartition(y,'KFold',5);
for i = 1:5
    m = TreeBagger(500, X(training(c5,i),:), y(training(c5,i)), ...
        'Method','classification','Cost',C);
    p = str2double(predict(m, X(test(c5,i),:)));
    cvACC(i) = mean(p == y(test(c5,i)));
    fprintf('  CV fold %d/5: accuracy = %.4f\n', i, cvACC(i));
end
logf(LOG, sprintf('Five-fold CV done in %.1f s.', toc(tCV)));

save(fullfile(OUT_ROOT,'oob_error_curve_v2.mat'),'oobErr');
save(fullfile(OUT_ROOT,'feature_importance_v2.mat'),'imp','featNames');
save(fullfile(OUT_ROOT,'confusion_v2.mat'),'Cm','classes','CLASS_NAMES');
save(fullfile(OUT_ROOT,'cv_accuracy_v2.mat'),'cvACC');
write_metrics_report(fullfile(OUT_SUM,'rf_metrics_report_v2.txt'), ...
    acc, prec, rec, f1, Cm, cvACC, oobErr, imp, featNames, CLASS_NAMES, numel(ytr), numel(yte));
save(fullfile(OUT_ROOT,'rf_model_v2.mat'),'rf','featNames','CLASS_NAMES','acc');
logf(LOG, sprintf('RF trained. Test accuracy = %.4f. 5-fold CV mean = %.4f.', acc, mean(cvACC)));

%% =========================================================================
%%  [2] ZONE ISOLATION + TOPOLOGY-LIMITED RESTORATION
%% =========================================================================
logf(LOG,'Running zone isolation + restoration scenarios ...');
load_system(MODEL);
BL = discover_blocks(MODEL);
T2_RATING_VA = read_xfmr_va(MODEL,'T2');   % read live from the model; ABORTS if unreadable
VBASE        = read_xfmr_v2(MODEL,'T1');   % read live from the model; ABORTS if unreadable
logf(LOG, sprintf('T2 rating read from model : %.2f MVA (capacity check).', T2_RATING_VA/1e6));
logf(LOG, sprintf('Voltage base read from T1 : %.0f V line-to-line (pu conversion).', VBASE));
% NOTE: nameplate load values are NOT used by any decision. Capacity checks
% use pre-fault power MEASURED from Stage-1 signals (measured_bus_va).

simstat('reset');                          % start the provable-work counters
rows = {}; nErr = 0;
zoneList  = {'B2','B3','B4','B5'};
logf(LOG, sprintf('Restoration suite: %d scenarios x up to 2 sims each (expect ~%d Simulink runs).', ...
    numel(zoneList)*numel(LOAD_LEVELS), 2*numel(zoneList)*numel(LOAD_LEVELS)));
for zi = 1:numel(zoneList)
    z = zoneList{zi};
    for li = 1:numel(LOAD_LEVELS)
        lm = LOAD_LEVELS(li);
        tSc = tic;
        try
            r = run_restoration(MODEL, BL, z, lm, T2_RATING_VA, VBAND, VBASE, rf);
        catch ME
            nErr = nErr + 1;
            logf(LOG, sprintf('  *** SCENARIO ERROR %s LM=%.2f: %s', z, lm, ME.message));
            fprintf(2, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            r = struct('zone',z,'lm',lm,'predicted','','predOK','','status','ERROR','isolated',z, ...
                'restored','','remainsT1','','tie','OPEN','breakers','','Vrest','','faultBusV',NaN,'note',ME.message);
        end
        rows(end+1,:) = { r.zone, r.lm, r.predicted, r.predOK, r.status, r.isolated, ...
            r.restored, r.remainsT1, r.tie, r.breakers, r.Vrest, r.faultBusV, r.note }; %#ok<SAGROW>
        logf(LOG, sprintf('  %s LM=%.2f -> pred=%s(%s) %-20s tie=%s isolated=%s tieRestored=[%s] onT1=[%s]  (%.1f s)', ...
            r.zone, r.lm, r.predicted, r.predOK, r.status, r.tie, r.isolated, r.restored, r.remainsT1, toc(tSc)));
    end
end
Tr = cell2table(rows,'VariableNames', ...
    {'Zone','LoadMult','PredictedZone','PredictionCorrect','Status','IsolatedZone', ...
     'RestoredZones','RemainsOnT1','TieState', ...
     'BreakersOpened','RestoredVoltages_pu','FaultBusVoltage_pu','Note'});
writetable(Tr, fullfile(OUT_ROOT,'restoration_results_v2.csv'));
writetable(Tr, fullfile(OUT_ROOT,'restoration_results_v2.xlsx'));   % Excel copy for the thesis
write_restoration_summary(fullfile(OUT_SUM,'restoration_summary_v2.txt'), Tr);
if nErr > 0
    error('MASTER_B:RestorationErrors', ...
        ['%d of %d restoration scenarios ERRORED — the results table is NOT valid.\n' ...
         'Fix the cause (full reports above and in pipeline_log_v2.txt) and re-run.'], ...
        nErr, height(Tr));
end

%% =========================================================================
%%  [2b] SEVERE-CASE FAULT + RESTORATION WAVEFORMS  (proof of operation)
%%  ONLY the worst (near-bolted, LM=1.0) SLG, LL and 3PH case per zone =
%%  12 waveform cases total, NOT all 36 scenarios. Each case is captured in
%%  two stages of the same fault (the model drives breakers by static
%%  Constants, so a single run holds one switch state):
%%    Stage 1 : fault on the NORMAL network (tie open)  -> shows the fault
%%    Stage 2 : after zone isolation + tie decision      -> shows restoration
%% =========================================================================
logf(LOG,'Capturing severe-case fault + restoration waveform DATA (12 cases; figures rendered by MASTER_C) ...');
WAVE_DIR = fullfile(OUT_ROOT,'waveforms_v2');
if ~exist(WAVE_DIR,'dir'); mkdir(WAVE_DIR); end
severeTypes = {'SLG','LL','3PH'};
wman = {}; wcount = 0;
for zi = 1:numel(zoneList)
    z = zoneList{zi};
    for ti = 1:numel(severeTypes)
        ft = severeTypes{ti};
        nfig = (zi-1)*numel(severeTypes) + ti;   % 1..12 (figure order used by MASTER_C)
        try
            [datFile, status] = capture_case(MODEL, BL, z, ft, ...
                T2_RATING_VA, VBAND, VBASE, WAVE_DIR, nfig, rf);
            wcount = wcount + 1;
            wman(end+1,:) = {sprintf('%s-%s',ft,z), z, ft, status, relpath(datFile)}; %#ok<SAGROW>
            logf(LOG, sprintf('  waveform %-3s-%s -> %-22s (live-sim data saved)', ft, z, status));
        catch ME
            logf(LOG, sprintf('  waveform %-3s-%s ERROR: %s', ft, z, ME.message));
        end
    end
end
if ~isempty(wman)
    writetable(cell2table(wman,'VariableNames', ...
        {'Case','Zone','FaultType','RestorationStatus','DataFile'}), ...
        fullfile(WAVE_DIR,'waveform_manifest_v2.csv'));
end
logf(LOG, sprintf('Severe-case waveform data captured: %d/12 (MASTER_C renders the figures).', wcount));
if wcount < 12
    logf(LOG, sprintf('*** WARNING: only %d of 12 waveform cases captured — see errors above.', wcount));
end

logf(LOG, sprintf('PROOF OF WORK: %d Simulink runs, %.1f min total simulation wall time.', ...
    simstat('count'), simstat('time')/60));
if simstat('count') < 30
    logf(LOG, '*** WARNING: fewer than 30 simulations ran — the restoration/waveform suites are incomplete.');
end
logf(LOG, sprintf('MASTER_B (v2) complete %s', datestr(now)));
fprintf('\nMASTER_B (v2) complete. Test accuracy = %.4f.\n', acc);
fprintf('Proof of work: %d simulations, %.1f min simulation wall time (details in pipeline_log_v2.txt).\n', ...
    simstat('count'), simstat('time')/60);

%% =========================================================================
%%  LOCAL FUNCTIONS
%% =========================================================================
function r = run_restoration(MODEL, BL, zone, lm, T2VA, VBAND, VBASE, rf)
% CLOSED-LOOP scenario: the switching decision is driven by the RF PREDICTION
% computed from Stage-1 measurements — never by the known injected zone.
% Stage 1: fault on the normal network (training conditions) -> classify.
% Stage 2: apply the isolation/tie policy FOR THE PREDICTED ZONE -> verify.
    FP.A='FaultA'; FP.B='FaultB'; FP.C='FaultC'; FP.G='GroundFault';
    FP.RF='FaultResistance'; FP.RG='GroundResistance'; FP.ST='SwitchTimes'; FP.IS='InitialStates';

    set_normal_state(BL);
    clear_all_faults(BL,FP);
    set_loads(BL, lm);

    % representative near-bolted SLG at the zone (t on = 0.5 s)
    set_param(BL.fault.(zone), FP.A,'on',FP.B,'off',FP.C,'off',FP.G,'on', ...
        FP.RF,'0.001', FP.RG,'0.001', FP.ST,'[0.5 2.0]', FP.IS,'0');

    % ---- STAGE 1: detection on the NORMAL network ----
    s1 = simrun(MODEL);
    % sampling instant from MEASURED disturbance detection, not the known onset
    [tdet, distFound] = detect_onset(s1, VBASE);
    if distFound; tsamp = min(tdet+0.5, 1.9); else; tsamp = 1.5; end
    predZone  = zone_of_class(str2double(predict(rf, features24(s1, tsamp))));
    predMatch = strcmp(predZone, zone);
    decision  = predZone;                      % the policy input IS the prediction

    switch decision
        case 'Healthy'
            brk=''; isolated='(none)'; restored={}; attemptTie=false; remainsT1={'B2','B3','B4'};
        case 'B2'
            open_cb(BL,{'CB_MAIN','CB_BUS1_B3'}); brk='CB_MAIN,CB_BUS1_B3';
            isolated='B2'; restored={'B3','B4'}; attemptTie=true;  remainsT1={};
        case 'B3'
            open_cb(BL,{'CB_BUS1_B3','CB_BUS1_B4'}); brk='CB_BUS1_B3,CB_BUS1_B4';
            isolated='B3'; restored={'B4'}; attemptTie=true;       remainsT1={'B2'};
        case 'B4'
            open_cb(BL,{'CB_BUS1_B4'}); brk='CB_BUS1_B4';
            isolated='B4'; restored={}; attemptTie=false;          remainsT1={'B2','B3'};
        case 'B5'
            open_cb(BL,{'CB_T2_BUS5'}); brk='CB_T2_BUS5';
            isolated='B5'; restored={}; attemptTie=false;          remainsT1={'B2','B3','B4'};
        otherwise
            error('run_restoration:badDecision','No policy for predicted zone "%s".', decision);
    end

    capOk = true; restVA = NaN;
    if attemptTie
        % capacity from MEASURED pre-fault load (Stage-1 window [0.30,0.45] s):
        % neither the nameplate values nor the known load multiplier are given
        % to the decision logic. CT placement in this model: each measurement
        % is in series with its OWN fault+load branch (verified: healthy CT
        % currents equal the individual load currents), so per-bus VAs are
        % independent and must be SUMMED. Voltage verification is the backstop.
        restVA = 0;
        for i=1:numel(restored)
            restVA = restVA + measured_bus_va(s1, restored{i}, [0.30 0.45]);
        end
        restVA = restVA + measured_bus_va(s1, 'B5', [0.30 0.45]);   % B5 already on T2
        capOk  = restVA <= T2VA;
    end

    % For B4/B5 the tie stays OPEN by design (closing would backfeed the
    % faulted zone). That is the correct action, not a blocked restoration
    % attempt, so the status is ISOLATED_NO_TIE with the reason recorded.
    tieClosed = false; status = 'ISOLATED_NO_TIE';
    if ~attemptTie
        tieReason = 'tie kept OPEN by design (would backfeed faulted zone); healthy buses remain on T1';
    elseif ~capOk
        status = 'BLOCKED_BY_CAPACITY';
        tieReason = sprintf('tie close refused: reconnect %.2f MVA exceeds T2 %.2f MVA', restVA/1e6, T2VA/1e6);
    else
        tieClosed = true;
        tieReason = sprintf('tie closed: reconnect %.2f MVA within T2 %.2f MVA', restVA/1e6, T2VA/1e6);
    end
    set_switch(BL.ctrl.TIE, tieClosed);

    % ---- STAGE 2: network after the (prediction-driven) switching action ----
    if strcmp(decision,'Healthy')
        sOut = s1;                       % no switching commanded -> stage-1 network stands
    else
        sOut = simrun(MODEL);
    end

    Vpu = [];
    for i=1:numel(restored)
        Vpu(end+1) = pu_voltage(sOut, ['RMS_V_' restored{i}], VBASE, 1.6); %#ok<AGROW>
    end
    Vok = isempty(Vpu) || all(Vpu>=VBAND(1) & Vpu<=VBAND(2));
    if tieClosed && ~Vok
        set_switch(BL.ctrl.TIE, false);
        status = 'ISOLATED_NO_TIE';
        tieReason = 'tie reverted OPEN: post-restoration voltage outside 0.95-1.05 pu band';
        sOut = simrun(MODEL);
        Vpu = []; for i=1:numel(restored)
            Vpu(end+1) = pu_voltage(sOut,['RMS_V_' restored{i}],VBASE,1.6); end %#ok<AGROW>
    elseif tieClosed && Vok
        status = 'RESTORED';
    end

    % success criterion is judged against the ACTUAL faulted zone
    faultBusV = pu_voltage(sOut, ['RMS_V_' zone], VBASE, 1.6);

    if ~predMatch
        % Wrong prediction -> actions were applied to the wrong zone. This is a
        % reportable OUTCOME of the closed loop, not a script error.
        status = 'MISPREDICTED_WRONG_ACTION';
        tieReason = sprintf('RF predicted %s but actual fault is %s -> policy acted on the wrong zone', predZone, zone);
    elseif faultBusV > 0.8
        % Correct prediction but the faulted zone is still energised: the
        % breaker command did not take effect -> genuine failure, abort loudly.
        error('run_restoration:IsolationIneffective', ...
            'Faulted zone %s still reads %.3f pu after isolation — breaker action did not take effect.', ...
            zone, faultBusV);
    end

    clear_all_faults(BL,FP); set_normal_state(BL);

    r.zone=zone; r.lm=lm; r.predicted=predZone; r.predOK=ternary(predMatch,'YES','NO');
    r.status=status; r.isolated=isolated;
    r.restored=strjoin(restored,'+'); r.remainsT1=strjoin(remainsT1,'+');
    r.tie=ternary(tieClosed,'CLOSED','OPEN');
    r.breakers=brk; r.Vrest=num2str(round(Vpu,4)); r.faultBusV=faultBusV;
    r.note=tieReason;
end

function open_cb(BL, names)
    for i=1:numel(names); set_switch(BL.ctrl.(names{i}), false); end
end

function v = pu_voltage(sOut, varname, VBASE, t)
    M = get_rms(sOut, varname); tt=M(:,1);
    [~,idx]=min(abs(tt-t));
    phaseRMS = mean(M(max(1,idx-3):min(size(M,1),idx+3), 2:4),1);   % mean of 3 phase RMS V
    v  = mean(phaseRMS) / VBASE;                                    % RMS_V is line-to-line -> pu on 11 kV LL base
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


function [prec, rec, f1] = prf_from_confusion(Cm)
    n = size(Cm,1); prec=zeros(n,1); rec=zeros(n,1); f1=zeros(n,1);
    for i=1:n
        tp = Cm(i,i); fp = sum(Cm(:,i))-tp; fn = sum(Cm(i,:))-tp;
        prec(i) = tp/max(tp+fp,eps); rec(i)=tp/max(tp+fn,eps);
        f1(i)   = 2*prec(i)*rec(i)/max(prec(i)+rec(i),eps);
    end
end

function write_metrics_report(f, acc, prec, rec, f1, Cm, cvACC, oobErr, imp, featNames, names, ntr, nte)
    fid=fopen(f,'w');
    fprintf(fid,'RANDOM FOREST METRICS REPORT (v2)\nGenerated: %s\n\n',datestr(now));
    fprintf(fid,'Train/Test: %d / %d   Trees: 500   Cost(fault->Healthy)=12.5x\n\n',ntr,nte);
    fprintf(fid,'OVERALL TEST ACCURACY : %.4f (%.2f%%)\n\n',acc,acc*100);
    fprintf(fid,'PER-CLASS PRECISION / RECALL / F1\n');
    for i=1:numel(names)
        fprintf(fid,'  %2d %-9s  P=%.3f  R=%.3f  F1=%.3f\n',i-1,names{i},prec(i),rec(i),f1(i));
    end
    fprintf(fid,'\nMACRO  P=%.3f  R=%.3f  F1=%.3f\n',mean(prec),mean(rec),mean(f1));
    fprintf(fid,'\nFIVE-FOLD CROSS-VALIDATION ACCURACY\n');
    for i=1:numel(cvACC); fprintf(fid,'  Fold %d: %.4f\n',i,cvACC(i)); end
    fprintf(fid,'  Mean: %.4f\n',mean(cvACC));
    fprintf(fid,'\nOUT-OF-BAG ERROR (final): %.4f\n',oobErr(end));
    fprintf(fid,'\nTOP-8 FEATURE IMPORTANCE (OOB permutation delta error)\n');
    [~,ord]=sort(imp,'descend');
    for i=1:min(8,numel(ord)); fprintf(fid,'  %-8s : %.4f\n',featNames{ord(i)},imp(ord(i))); end
    fprintf(fid,'\nCONFUSION MATRIX (rows=true 0..12, cols=pred 0..12)\n');
    for i=1:size(Cm,1); fprintf(fid,'  %s\n',num2str(Cm(i,:),'%5d')); end
    fprintf(fid,'\nNOTE: Only simple, defendable metrics are reported. No Wilson interval,\n');
    fprintf(fid,'McNemar test, bootstrap confidence interval, or p-value is used.\n');
    fclose(fid);
end

function write_restoration_summary(f, T)
    fid=fopen(f,'w');
    fprintf(fid,'RESTORATION SUMMARY (v2) — conditional, topology-limited\nGenerated: %s\n\n',datestr(now));
    fprintf(fid,'Tie policy: closed only for upstream faults (B2, B3) when the T2 capacity and\n');
    fprintf(fid,'0.95-1.05 pu voltage checks pass. For B4 and B5 faults the tie is kept OPEN by\n');
    fprintf(fid,'design, because closing it would backfeed the faulted zone; the healthy buses\n');
    fprintf(fid,'listed under RemainsOnT1 never lose supply (they stay on the T1 main path).\n');
    fprintf(fid,'Full restoration of all healthy buses is NOT claimed for every fault location.\n\n');
    fprintf(fid,'CLOSED LOOP: every switching decision below was driven by the RF\n');
    fprintf(fid,'prediction computed from Stage-1 measurements on the normal network,\n');
    fprintf(fid,'never by the known injected zone.\n\n');
    fprintf(fid,'%-5s %-8s %-9s %-5s %-24s %-9s %-9s %-12s %-12s\n', ...
        'Zone','LoadMlt','Pred','OK','Status','Isolated','Tie','TieRestored','RemainsOnT1');
    for i=1:height(T)
        fprintf(fid,'%-5s %-8.2f %-9s %-5s %-24s %-9s %-9s %-12s %-12s\n', T.Zone{i}, T.LoadMult(i), ...
            T.PredictedZone{i}, T.PredictionCorrect{i}, T.Status{i}, T.IsolatedZone{i}, ...
            T.TieState{i}, T.RestoredZones{i}, T.RemainsOnT1{i});
    end
    okPred = all(strcmp(T.PredictionCorrect,'YES'));
    okIso = all(cellfun(@(z,iz) strcmp(z,iz), T.Zone, T.IsolatedZone));
    b45 = ismember(T.Zone,{'B4','B5'});
    okBackfeed = all(strcmp(T.TieState(b45),'OPEN'));
    fprintf(fid,'\nCHECK: RF predicted the correct zone in every case : %s\n',tern(okPred));
    fprintf(fid,'CHECK: faulted zone isolated in every case         : %s\n',tern(okIso));
    fprintf(fid,'CHECK: tie never CLOSED for B4/B5 faults           : %s\n',tern(okBackfeed));
    fclose(fid);
end
function s=tern(b); if b; s='PASS'; else; s='FAIL'; end; end
function s=ternary(c,a,b); if c; s=a; else; s=b; end; end

% ---- shared model helpers (standalone copies) ----
function BL = discover_blocks(MODEL)
    z={'B2','B3','B4','B5'}; BL.fault=struct(); BL.load=struct(); BL.meas=struct();
    for k=1:numel(z)
        BL.fault.(z{k})=pick(MODEL,{['Fault_' z{k}], leg(z{k},'Fault_SXEW')},'Reference');
        BL.load.(z{k}) =pick(MODEL,{['DL_' z{k}],    leg(z{k},'DL_SXEW')},   'Reference');
        BL.meas.(z{k}) =pick(MODEL,{['Measurement DL_' z{k}],['Measurement_DL_' z{k}]},'Reference');
    end
    BL.cb.CB_MAIN=pick(MODEL,{'CB_MAIN'},'Reference');
    BL.cb.CB_BUS1_B3=pick(MODEL,{'CB_BUS1_B3'},'Reference');
    BL.cb.CB_BUS1_B4=pick(MODEL,{'CB_BUS1_B4'},'Reference');
    BL.cb.CB_T2_BUS5=pick(MODEL,{'CB_T2_BUS5'},'Reference');
    BL.cb.TIE_SWITCH=pick(MODEL,{'TIE_SWITCH'},'Reference');
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
function clear_all_faults(BL,FP)
    z=fieldnames(BL.fault);
    for k=1:numel(z)
        set_param(BL.fault.(z{k}),FP.A,'off',FP.B,'off',FP.C,'off',FP.G,'off', ...
                  FP.ST,'[1000000 1000001]',FP.IS,'0');
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
function M=get_rms(sOut,varname)
    s=[]; try, s=sOut.get(varname); catch, end
    if isempty(s)&&evalin('base',['exist(''' varname ''',''var'')']); s=evalin('base',varname); end
    if isstruct(s)&&isfield(s,'signals'); t=s.time; val=s.signals.values;
    elseif isa(s,'timeseries'); t=s.Time; val=s.Data;
    else; error('get_rms:fmt','cannot read %s',varname); end
    if size(val,2)<3; val=repmat(val(:,1),1,3); end
    M=[t(:),val(:,1:3)];
end
function logf(file,msg,reset)
    if nargin<3; reset=false; end
    if reset; fid=fopen(file,'w'); else; fid=fopen(file,'a'); end
    fprintf(fid,'[%s] %s\n',datestr(now,'yyyy-mm-dd HH:MM:SS'),msg); fclose(fid);
    fprintf('%s\n',msg);
end

% ---- severe-case fault + restoration waveform capture ----
function [datFile, status] = capture_case(MODEL, BL, zone, ftype, T2VA, VBAND, VBASE, WAVE_DIR, nfig, rf)
    FP.A='FaultA'; FP.B='FaultB'; FP.C='FaultC'; FP.G='GroundFault';
    FP.RF='FaultResistance'; FP.RG='GroundResistance'; FP.ST='SwitchTimes'; FP.IS='InitialStates';
    switch ftype                              % severe, near-bolted phase config
        case 'SLG'; pa='on'; pb='off'; pc='off'; pg='on';
        case 'LL';  pa='on'; pb='on';  pc='off'; pg='off';
        case '3PH'; pa='on'; pb='on';  pc='on';  pg='off';
    end
    lm = 1.0;

    % ---------- Stage 1: fault on the NORMAL network (tie open) ----------
    set_normal_state(BL); clear_all_faults(BL,FP); set_loads(BL,lm);
    set_param(BL.fault.(zone), FP.A,pa,FP.B,pb,FP.C,pc,FP.G,pg, ...
        FP.RF,'0.001', FP.RG,'0.001', FP.ST,'[0.5 2.0]', FP.IS,'0');
    s1 = simrun(MODEL);
    Vf = get_rms(s1, ['RMS_V_' zone]);        % faulted-bus RMS voltage (3 phase)
    If = get_rms(s1, ['RMS_I_' zone]);        % faulted-bus RMS current (3 phase)

    % PHYSICS CHECK: the fault must actually be present in Stage 1 — Phase A
    % current during the fault window must rise clearly above the pre-fault level.
    preI = winmean(If, 0.30, 0.45, 2);
    fltI = winmean(If, 1.00, 1.20, 2);
    if fltI < 2*max(preI, 1e-6)
        error('capture_case:FaultNotApplied', ...
            '%s fault at %s produced no current rise (pre %.1f A -> fault %.1f A) — fault block not active.', ...
            ftype, zone, preI, fltI);
    end

    % ---------- CLOSED LOOP: predict the zone from Stage-1 features ----------
    % The switching below is driven by the PREDICTION, not the injected zone;
    % the sampling instant comes from measured disturbance detection.
    [tdet, distFound] = detect_onset(s1, VBASE);
    if distFound; tsamp = min(tdet+0.5, 1.9); else; tsamp = 1.5; end
    predZone  = zone_of_class(str2double(predict(rf, features24(s1, tsamp))));
    predMatch = strcmp(predZone, zone);
    [brk, restored, attemptTie] = policy(predZone);
    capOk = true;
    if attemptTie
        % capacity from MEASURED pre-fault load — no nameplate/lm ground truth.
        % Each CT reads its OWN load branch in this model, so SUM per bus.
        rv = 0;
        for i=1:numel(restored); rv = rv + measured_bus_va(s1, restored{i}, [0.30 0.45]); end
        rv = rv + measured_bus_va(s1, 'B5', [0.30 0.45]);
        capOk = rv <= T2VA;
    end
    tieClosed = attemptTie && capOk;

    % ---------- Stage 2: apply decision, same fault still active ----------
    set_normal_state(BL);
    for i=1:numel(brk); set_switch(BL.ctrl.(brk{i}), false); end
    set_switch(BL.ctrl.TIE, tieClosed);
    s2 = simrun(MODEL);
    Vpu = struct();
    for zz = {'B2','B3','B4','B5'}
        Vpu.(zz{1}) = vpu_series(get_rms(s2, ['RMS_V_' zz{1}]), VBASE);
    end
    Vok = true;
    for i=1:numel(restored)
        vend = mean(Vpu.(restored{i})(end-20:end,2));
        Vok = Vok && vend>=VBAND(1) && vend<=VBAND(2);
    end
    if tieClosed && ~Vok                       % voltage limit not met -> revert tie
        set_switch(BL.ctrl.TIE,false); tieClosed=false;
        s2 = simrun(MODEL);
        for zz = {'B2','B3','B4','B5'}; Vpu.(zz{1}) = vpu_series(get_rms(s2,['RMS_V_' zz{1}]),VBASE); end
    end
    status = decide_status(attemptTie, capOk, tieClosed, Vok);
    if ~predMatch
        status = 'MISPREDICTED_WRONG_ACTION';   % closed-loop outcome, reported honestly
    end

    % ---------- save the LIVE-SIMULATION waveform data ----------
    % Contains everything MASTER_C needs to render the two-stage figure without
    % re-simulating: faulted-bus V/I (Stage 1) and all bus pu voltages (Stage 2).
    datFile = fullfile(WAVE_DIR, sprintf('wave_%s_%s.mat', ftype, zone));
    save(datFile, 'Vf','If','Vpu','status','zone','ftype','brk','restored', ...
         'tieClosed','nfig','VBAND','predZone','predMatch');

    clear_all_faults(BL,FP); set_normal_state(BL);
end

function [brk, restored, attemptTie] = policy(zone)
% DETERMINISTIC protection action table — intentionally NOT learned. The zone
% itself is what the classifier must infer from measurements; the zone->breaker
% mapping is fixed by the physical topology and must stay deterministic and
% auditable, as in any certifiable protection scheme.
    switch zone
        case 'Healthy'; brk={};                    restored={};          attemptTie=false;
        case 'B2'; brk={'CB_MAIN','CB_BUS1_B3'};   restored={'B3','B4'}; attemptTie=true;
        case 'B3'; brk={'CB_BUS1_B3','CB_BUS1_B4'};restored={'B4'};      attemptTie=true;
        case 'B4'; brk={'CB_BUS1_B4'};             restored={};          attemptTie=false;
        case 'B5'; brk={'CB_T2_BUS5'};             restored={};          attemptTie=false;
        otherwise
            error('policy:unknown','No policy for predicted zone "%s".', zone);
    end
end
function st = decide_status(attemptTie, capOk, tieClosed, Vok)
% B4/B5 (~attemptTie): tie kept OPEN by design — correct action, so ISOLATED_NO_TIE.
    if ~attemptTie;             st='ISOLATED_NO_TIE';
    elseif ~capOk;              st='BLOCKED_BY_CAPACITY';
    elseif tieClosed && Vok;    st='RESTORED';
    else;                       st='ISOLATED_NO_TIE'; end
end
function P = vpu_series(M, VBASE)
    pu = mean(M(:,2:4),2) / VBASE;              % RMS_V is line-to-line -> pu (11 kV LL base), per timestep
    P = [M(:,1), pu];
end
function s = simrun(MODEL)
% Single instrumented Simulink run: wall-clock timed and counted, so the amount
% of real simulation work MASTER_B performed is provable from the console/log.
    set_param(MODEL,'StopTime','2.0');
    t0 = tic;
    s = sim(MODEL,'SimulationMode','normal','FastRestart','off', ...
        'SaveOutput','on','SaveTime','on', ...
        'SignalLogging','on','SignalLoggingName','logsout','SaveFormat','Dataset');
    dt = toc(t0);
    n = simstat('add', dt);
    fprintf('      [sim #%d] %.1f s wall time\n', n, dt);
end

function out = simstat(cmd, dt)
% Persistent counters of Simulink runs: how many, and total wall time.
    persistent n total
    if isempty(n); n = 0; total = 0; end
    switch cmd
        case 'reset'; n = 0; total = 0; out = 0;
        case 'add';   n = n + 1; total = total + dt; out = n;
        case 'count'; out = n;
        case 'time';  out = total;
    end
end

function v = winmean(M, t0, t1, col)
% Mean of column <col> of [t A B C] within the time window [t0,t1].
    t = M(:,1); v = mean(M(t>=t0 & t<=t1, col));
end

function f = features24(sOut, tsamp)
% The same 24 RMS features the classifier was trained on (V,I x A,B,C at
% B2..B5). tsamp is derived by the CALLER from the measured disturbance-
% detection time (detect_onset) — the known injection time is never used.
    V={'RMS_V_B2','RMS_V_B3','RMS_V_B4','RMS_V_B5'};
    I={'RMS_I_B2','RMS_I_B3','RMS_I_B4','RMS_I_B5'};
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

function row = at(M, t)
    tt=M(:,1); [~,idx]=min(abs(tt-t)); lo=max(1,idx-2); hi=min(size(M,1),idx+2);
    row=mean(M(lo:hi,2:4),1);
end

function z = zone_of_class(c)
% Class label (0..12) -> fault zone. 0=Healthy; 1-3=B2; 4-6=B3; 7-9=B4; 10-12=B5.
    if c==0; z='Healthy';
    elseif c<=3; z='B2'; elseif c<=6; z='B3'; elseif c<=9; z='B4'; else; z='B5'; end
end
function p = relpath(f); p = strrep(f,[pwd filesep],''); end
