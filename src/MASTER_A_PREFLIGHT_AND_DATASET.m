%% =========================================================================
%  MASTER_A_PREFLIGHT_AND_DATASET.m   (v2 — sectionalised radial topology)
%  ─────────────────────────────────────────────────────────────────────────
%  Thesis: ML-Assisted Self-Healing of a 33/11 kV Mining Distribution Feeder
%  Author: Victoire Chinyanta Chimundu — CU-BEE-100-7229  |  Supervisor: Mr Charles Kasonde
%
%  WHAT THIS SCRIPT DOES (in order)
%    [0] Discovers the EXACT block paths in the current model with find_system
%        (no hard-coded SXEW names; prefers B5 naming; adapts if names differ).
%    [1] Sets the normal switching state before every simulation:
%          CB_MAIN, CB_BUS1_B3, CB_BUS1_B4, CB_T2_BUS5 = CLOSED ; TIE_SWITCH = OPEN
%    [2] Runs a STRICT SLG grounding pre-flight for all four fault zones
%        (B2,B3,B4,B5). Sets GroundResistance low so the ground-return path is
%        electrically valid, then confirms a physically meaningful SLG current
%        rise at each zone. ABORTS the pipeline if any zone fails.
%    [3] Generates the 13-class dataset (1000 samples) with the tie OPEN and
%        exactly one fault block active per scenario.
%    [4] Extracts the 24 RMS features (V/I, phases A/B/C at B2,B3,B4,B5).
%    [5] Writes all outputs under  outputs_v2_topology/  (old outputs untouched).
%
%  Class map (fault-ZONE labels, not restoration labels):
%    0        = Healthy
%    1,2,3    = Fault_B2 zone: SLG, LL, 3PH
%    4,5,6    = Fault_B3 zone: SLG, LL, 3PH
%    7,8,9    = Fault_B4 zone: SLG, LL, 3PH
%    10,11,12 = Fault_B5 zone: SLG, LL, 3PH
% =========================================================================

clc; close all;
fprintf('=================================================================\n');
fprintf('  MASTER A (v2) — DISCOVERY, SLG PRE-FLIGHT, DATASET GENERATION\n');
fprintf('  %s\n', datestr(now));
fprintf('=================================================================\n\n');

%% =========================================================================
%%  SECTION 0 — CONFIGURATION
%% =========================================================================
MODEL         = 'mining_feeder_layer_FINAL_baseline';
SIM_STOP_TIME = 2.0;          % s

% --- output folder (NEW; never overwrites the old final-release outputs) ---
OUT_ROOT = fullfile(pwd, 'outputs_v2_topology');
OUT_SUM  = fullfile(OUT_ROOT, 'summaries');
if ~exist(OUT_ROOT,'dir'); mkdir(OUT_ROOT); end
if ~exist(OUT_SUM ,'dir'); mkdir(OUT_SUM ); end

% --- fault-block parameter names (Three-Phase Fault, confirmed from model) ---
FP_A  = 'FaultA';  FP_B = 'FaultB';  FP_C = 'FaultC';
FP_G  = 'GroundFault';
FP_RF = 'FaultResistance';            % Ron
FP_RG = 'GroundResistance';           % Rg  (500 ohm in the shipped model -> must be lowered)
FP_ST = 'SwitchTimes';
FP_IS = 'InitialStates';
RG_LOW = 0.001;                        % ground resistance for near-bolted SLG (ohm)

% --- sweep design (900 fault + 100 healthy = 1000) ---
FAULT_RF  = [0.001, 0.1, 0.5, 1.0, 5.0];      % fault resistance (ohm)
FAULT_LM  = [0.70, 0.85, 1.00, 1.10, 1.30];   % load multiplier (pu)
FAULT_TON = [0.50, 0.75, 1.00];               % fault onset time (s)
EXTRACT_DT = 0.5;                              % extract 0.5 s after onset
HEALTHY_LM = linspace(0.55,1.35,10);
HEALTHY_REPEATS = 10;                          % 10 x 10 = 100 healthy
HEALTHY_T  = 1.5;

ZONES       = {'B2','B3','B4','B5'};
FAULT_TYPES = {'SLG','LL','3PH'};
CLASS_BASE  = [1,4,7,10];
CLASS_NAMES = {'Healthy', ...
    'SLG-B2','LL-B2','3PH-B2', 'SLG-B3','LL-B3','3PH-B3', ...
    'SLG-B4','LL-B4','3PH-B4', 'SLG-B5','LL-B5','3PH-B5'};
% phase configuration per fault type
PH(1) = struct('A','on','B','off','C','off','G','on');   % SLG
PH(2) = struct('A','on','B','on', 'C','off','G','off');  % LL
PH(3) = struct('A','on','B','on', 'C','on', 'G','off');  % 3PH

SLG_PASS_RATIO = 3.0;   % minimum Ia(fault)/Ia(healthy) to accept an SLG zone

%% =========================================================================
%%  SECTION 0b — BLOCK DISCOVERY (find_system)
%% =========================================================================
fprintf('[0] Discovering block paths with find_system ...\n');
load_system(MODEL);
BL = discover_blocks(MODEL);      % struct with exact paths, see local function
report_blocks(BL, fullfile(OUT_SUM,'block_discovery_report_v2.txt'), MODEL);

% To-Workspace variables that carry the 24 features (Structure With Time)
SIG_V = {'RMS_V_B2','RMS_V_B3','RMS_V_B4','RMS_V_B5'};
SIG_I = {'RMS_I_B2','RMS_I_B3','RMS_I_B4','RMS_I_B5'};

%% =========================================================================
%%  SECTION 1 — NORMAL SWITCHING STATE
%% =========================================================================
fprintf('\n[1] Setting normal switching state (all CB closed, TIE open) ...\n');
set_normal_state(BL);

%% =========================================================================
%%  SECTION 2 — STRICT SLG GROUNDING PRE-FLIGHT (all four zones)
%% =========================================================================
fprintf('\n[2] SLG grounding pre-flight for zones B2,B3,B4,B5 ...\n');
fprintf('    (GroundResistance lowered to %.3f ohm; ground return must be valid)\n\n', RG_LOW);

slg = struct('zone',{},'Ihealthy',{},'Islg',{},'ratio',{},'status',{});
abort_zone = '';
for k = 1:numel(ZONES)
    z   = ZONES{k};
    fb_ = BL.fault.(z);

    % healthy baseline current (Phase A) at this zone, tie open, no fault
    set_normal_state(BL);
    clear_all_faults(BL, FP_A,FP_B,FP_C,FP_G,FP_ST,FP_IS);
    sOutH = runsim(MODEL, SIM_STOP_TIME);
    Ih = phaseA_window(sOutH, SIG_I{k}, 0.30, 0.45);

    % SLG at this zone: Phase A + ground, near-bolted, valid ground return
    clear_all_faults(BL, FP_A,FP_B,FP_C,FP_G,FP_ST,FP_IS);
    set_param(fb_, FP_A,'on', FP_B,'off', FP_C,'off', FP_G,'on', ...
              FP_RF, num2str(0.001), FP_RG, num2str(RG_LOW), ...
              FP_ST, '[0.5 2.0]', FP_IS, '0');
    sOutF = runsim(MODEL, SIM_STOP_TIME);
    Is = phaseA_window(sOutF, SIG_I{k}, 1.00, 1.20);   % 0.5 s after onset

    ratio = Is / max(Ih, 1e-6);
    st = 'PASS'; if ~(ratio >= SLG_PASS_RATIO); st = 'FAIL'; end
    slg(k) = struct('zone',z,'Ihealthy',Ih,'Islg',Is,'ratio',ratio,'status',st);
    fprintf('    SLG_%s : healthy Ia=%8.1f A   SLG Ia=%9.1f A   x%6.1f   %s\n', ...
            z, Ih, Is, ratio, st);
    if strcmp(st,'FAIL') && isempty(abort_zone); abort_zone = z; end
end
clear_all_faults(BL, FP_A,FP_B,FP_C,FP_G,FP_ST,FP_IS);
set_normal_state(BL);

write_slg_report(slg, OUT_SUM);   % slg_preflight_check_v2.csv / .txt

if ~isempty(abort_zone)
    error('MASTER_A:SLGPreflight', ...
        'SLG grounding/measurement failure in %s. Dataset generation aborted.', abort_zone);
end
fprintf('\n    SLG pre-flight PASSED for all four zones.\n');

%% =========================================================================
%%  SECTION 3 — DATASET GENERATION (1000 samples, tie OPEN throughout)
%% =========================================================================
fprintf('\n[3] Generating 13-class dataset (tie OPEN, one fault active per run) ...\n');
X = [];  y = [];  meta = {};   ck_file = fullfile(OUT_ROOT,'dataset_checkpoint_v2.mat');
if exist(ck_file,'file')
    S = load(ck_file); X = S.X; y = S.y; meta = S.meta;
    fprintf('    Resuming from checkpoint: %d samples already present.\n', numel(y));
end

% ---- healthy samples ----
hi = 0;
for lv = 1:numel(HEALTHY_LM)
    for r = 1:HEALTHY_REPEATS
        hi = hi + 1; sid = hi;
        if sid <= numel(y); continue; end   % resume support
        set_normal_state(BL);
        clear_all_faults(BL, FP_A,FP_B,FP_C,FP_G,FP_ST,FP_IS);
        set_loads(BL, HEALTHY_LM(lv));
        sOut = runsim(MODEL, SIM_STOP_TIME);
        f = features24(sOut, SIG_V, SIG_I, HEALTHY_T);
        X(end+1,:) = f; y(end+1,1) = 0; %#ok<SAGROW>
        meta{end+1,1} = sprintf('Healthy LM=%.2f rep=%d', HEALTHY_LM(lv), r); %#ok<SAGROW>
        if mod(numel(y),20)==0
            save(ck_file,'X','y','meta'); fprintf('      healthy %3d/100\n', numel(y));
        end
    end
end

% ---- fault samples: 4 zones x 3 types x 5 Rf x 5 LM x 3 ton = 900 ----
for zk = 1:numel(ZONES)
    z = ZONES{zk};  fb_ = BL.fault.(z);
    for tt = 1:numel(FAULT_TYPES)
        cls = CLASS_BASE(zk) + (tt-1);
        for iRf = 1:numel(FAULT_RF)
            for iLM = 1:numel(FAULT_LM)
                for iT = 1:numel(FAULT_TON)
                    tag = sprintf('%s-%s Rf=%.3f LM=%.2f ton=%.2f', ...
                        FAULT_TYPES{tt}, z, FAULT_RF(iRf), FAULT_LM(iLM), FAULT_TON(iT));
                    % resume: skip if already stored
                    if any(strcmp(meta, tag)); continue; end

                    set_normal_state(BL);                 % tie OPEN during data gen
                    clear_all_faults(BL, FP_A,FP_B,FP_C,FP_G,FP_ST,FP_IS);
                    set_loads(BL, FAULT_LM(iLM));

                    p = PH(tt);
                    tend = FAULT_TON(iT) + 0.9;
                    set_param(fb_, FP_A,p.A, FP_B,p.B, FP_C,p.C, FP_G,p.G, ...
                        FP_RF, num2str(FAULT_RF(iRf)), FP_RG, num2str(RG_LOW), ...
                        FP_ST, sprintf('[%.4f %.4f]', FAULT_TON(iT), tend), FP_IS,'0');

                    sOut = runsim(MODEL, SIM_STOP_TIME);
                    f = features24(sOut, SIG_V, SIG_I, FAULT_TON(iT)+EXTRACT_DT);
                    X(end+1,:) = f; y(end+1,1) = cls; %#ok<SAGROW>
                    meta{end+1,1} = tag; %#ok<SAGROW>
                    if mod(numel(y),25)==0
                        save(ck_file,'X','y','meta');
                        fprintf('      total %4d/1000  (%s)\n', numel(y), tag);
                    end
                end
            end
        end
    end
end
clear_all_faults(BL, FP_A,FP_B,FP_C,FP_G,FP_ST,FP_IS);
set_normal_state(BL);

%% =========================================================================
%%  SECTION 4 — SAVE DATASET
%% =========================================================================
featNames = feature_names(ZONES);
save(fullfile(OUT_ROOT,'fault_dataset_v2.mat'),'X','y','meta','featNames','CLASS_NAMES');
T = array2table(X,'VariableNames',featNames);
T.class = y; T.label = CLASS_NAMES(y+1)'; T.scenario = meta;   % full traceability per row
writetable(T, fullfile(OUT_ROOT,'fault_dataset_v2.csv'));
% Excel workbook: full dataset + per-class summary sheet
xfile = fullfile(OUT_ROOT,'fault_dataset_v2.xlsx');
writetable(T, xfile, 'Sheet','dataset');
cnt  = histcounts(y, -0.5:1:12.5)';
Tsum = table((0:12)', CLASS_NAMES(:), cnt, 'VariableNames', {'class','label','samples'});
writetable(Tsum, xfile, 'Sheet','class_summary');

fprintf('\n[4] Dataset saved: %d samples, %d features.\n', size(X,1), size(X,2));
fprintf('    -> %s\n', fullfile(OUT_ROOT,'fault_dataset_v2.mat'));
fprintf('    Class counts:\n');
for c = 0:12
    fprintf('      %2d %-8s : %d\n', c, CLASS_NAMES{c+1}, sum(y==c));
end
fprintf('\nMASTER_A (v2) complete.\n');

%% =========================================================================
%%  LOCAL FUNCTIONS
%% =========================================================================
function BL = discover_blocks(MODEL)
% Discover exact block paths. Prefers B5 naming; falls back to legacy SXEW
% only if a B5 block is genuinely absent. Handles names that contain spaces
% or embedded newlines (control Constants).
    z = {'B2','B3','B4','B5'};
    BL.fault = struct(); BL.load = struct(); BL.meas = struct();
    for k = 1:numel(z)
        BL.fault.(z{k}) = pick(MODEL, {['Fault_' z{k}], legacy(z{k},'Fault_SXEW')}, 'Reference');
        BL.load.(z{k})  = pick(MODEL, {['DL_' z{k}],    legacy(z{k},'DL_SXEW')},    'Reference');
        BL.meas.(z{k})  = pick(MODEL, {['Measurement DL_' z{k}], ['Measurement_DL_' z{k}]}, 'Reference');
    end
    % breakers (Three-Phase Breaker = Reference blocks)
    BL.cb.CB_MAIN     = pick(MODEL, {'CB_MAIN'},     'Reference');
    BL.cb.CB_BUS1_B3  = pick(MODEL, {'CB_BUS1_B3'},  'Reference');
    BL.cb.CB_BUS1_B4  = pick(MODEL, {'CB_BUS1_B4'},  'Reference');
    BL.cb.CB_T2_BUS5  = pick(MODEL, {'CB_T2_BUS5'},  'Reference');
    BL.cb.TIE_SWITCH  = pick(MODEL, {'TIE_SWITCH'},  'Reference');
    % control Constants (names contain a newline, e.g. "Constant\nCB_MAIN")
    BL.ctrl.CB_MAIN    = pick_ctrl(MODEL, 'CB_MAIN');
    BL.ctrl.CB_BUS1_B3 = pick_ctrl(MODEL, 'CB_BUS1_B3');
    BL.ctrl.CB_BUS1_B4 = pick_ctrl(MODEL, 'CB_BUS1_B4');
    BL.ctrl.CB_T2_BUS5 = pick_ctrl(MODEL, 'CB_T2_BUS5');
    BL.ctrl.TIE        = pick_ctrl(MODEL, 'TIE');   % "Constant\nTIE_B4_B5"
end

function s = legacy(zone, name)
    if strcmp(zone,'B5'); s = name; else; s = ''; end
end

function p = pick(MODEL, candidates, btype)
% Return the exact path of the first candidate block that exists.
    p = '';
    for i = 1:numel(candidates)
        nm = candidates{i};
        if isempty(nm); continue; end
        h = find_system(MODEL,'SearchDepth',1,'BlockType',btype,'Name',nm);
        if isempty(h)   % also try masked/regexp match (whitespace-insensitive)
            h = find_system(MODEL,'SearchDepth',1,'RegExp','on','Name', ...
                ['^' regexprep(regexptranslate('escape',nm),'\s+','\\s+') '$']);
        end
        if ~isempty(h); p = getfullname(h{1}); return; end
    end
    error('discover_blocks:notfound','Could not find any of: %s', strjoin(candidates,', '));
end

function p = pick_ctrl(MODEL, token)
% Find the Constant control block whose (whitespace-normalised) name contains token.
    cs = find_system(MODEL,'SearchDepth',1,'BlockType','Constant');
    for i = 1:numel(cs)
        nm = regexprep(get_param(cs{i},'Name'), '\s+', ' ');
        if contains(nm, token); p = getfullname(cs{i}); return; end
    end
    error('discover_blocks:ctrl','No control Constant matching "%s".', token);
end

function report_blocks(BL, file, MODEL)
    fid = fopen(file,'w');
    fprintf(fid,'BLOCK DISCOVERY REPORT (v2)\nModel: %s\nGenerated: %s\n\n', MODEL, datestr(now));
    dump = @(hdr,s) print_struct(fid,hdr,s);
    dump('FAULT BLOCKS', BL.fault);
    dump('LOAD BLOCKS',  BL.load);
    dump('MEASUREMENTS', BL.meas);
    dump('BREAKERS',     BL.cb);
    dump('CONTROL CONSTANTS', BL.ctrl);
    fclose(fid);
    fprintf('    Block discovery report -> %s\n', file);
end

function print_struct(fid, hdr, s)
    fprintf(fid,'== %s ==\n', hdr); f = fieldnames(s);
    for i=1:numel(f); fprintf(fid,'  %-12s : %s\n', f{i}, s.(f{i})); end
    fprintf(fid,'\n');
end

function set_switch(ctrlBlk, closed)
% closed=true -> Value 1 (closed) ; closed=false -> Value 0 (open)
    set_param(ctrlBlk, 'Value', num2str(double(logical(closed))));
end

function set_normal_state(BL)
    set_switch(BL.ctrl.CB_MAIN,    true);
    set_switch(BL.ctrl.CB_BUS1_B3, true);
    set_switch(BL.ctrl.CB_BUS1_B4, true);
    set_switch(BL.ctrl.CB_T2_BUS5, true);
    set_switch(BL.ctrl.TIE,        false);   % normally OPEN
end

function clear_all_faults(BL, A,B,C,G,ST,IS)
    z = fieldnames(BL.fault);
    for k=1:numel(z)
        set_param(BL.fault.(z{k}), A,'off', B,'off', C,'off', G,'off', ...
                  ST,'[1000000 1000001]', IS,'0');
    end
end

function set_loads(BL, lm)
% Scale each load's ActivePower/ReactivePower by the load multiplier lm.
    z = fieldnames(BL.load);
    for k=1:numel(z)
        blk = BL.load.(z{k});
        scale_load_param(blk, 'ActivePower', lm);
        scale_load_param(blk, 'InductiveReactivePower', lm);
    end
end

function scale_load_param(blk, pname, lm)
    try
        mn = get_param(blk,'MaskNames');
        if any(strcmp(mn,pname))
            base = getbase(blk, pname);
            set_param(blk, pname, num2str(base*lm));
        end
    catch
    end
end

function b = getbase(blk, pname)
% Cache the 1.0-pu base value in the block's UserData so repeated scaling is stable.
    ud = get_param(blk,'UserData');
    if ~isstruct(ud) || ~isfield(ud, matlab.lang.makeValidName(pname))
        b = str2double(get_param(blk,pname));
        if isempty(ud) || ~isstruct(ud); ud = struct(); end
        ud.(matlab.lang.makeValidName(pname)) = b;
        set_param(blk,'UserData',ud);
    else
        b = ud.(matlab.lang.makeValidName(pname));
    end
end

function sOut = runsim(MODEL, stop)
    set_param(MODEL,'StopTime',num2str(stop));
    sOut = sim(MODEL,'SimulationMode','normal','FastRestart','off', ...
        'SaveOutput','on','SaveTime','on', ...
        'SignalLogging','on','SignalLoggingName','logsout','SaveFormat','Dataset');
end

function v = phaseA_window(sOut, varname, t0, t1)
    M = get_rms(sOut, varname);
    t = M(:,1);
    v = mean(M(t>=t0 & t<=t1, 2));   % column 2 = Phase A
end

function M = get_rms(sOut, varname)
% Return [t, A, B, C] for a "Structure With Time" To-Workspace variable,
% robust to variable being returned in the SimulationOutput or base ws.
    s = [];
    try, s = sOut.get(varname); catch, end
    if isempty(s) && evalin('base',['exist(''' varname ''',''var'')'])
        s = evalin('base', varname);
    end
    if isstruct(s) && isfield(s,'signals')
        t = s.time; val = s.signals.values;
    elseif isa(s,'timeseries')
        t = s.Time; val = s.Data;
    else
        error('get_rms:fmt','Cannot read variable %s', varname);
    end
    if size(val,2) < 3; val = repmat(val(:,1),1,3); end
    M = [t(:), val(:,1:3)];
end

function f = features24(sOut, SIG_V, SIG_I, textract)
% 24 features = [V(A,B,C) I(A,B,C)] at B2,B3,B4,B5, sampled at textract.
    f = zeros(1,24); c = 0;
    for k = 1:4
        Vm = get_rms(sOut, SIG_V{k}); Im = get_rms(sOut, SIG_I{k});
        vA = at(Vm,textract); iA = at(Im,textract);
        f(c+1:c+3) = vA; f(c+4:c+6) = iA; c = c + 6;
    end
end

function row = at(M, t)
    tt = M(:,1);
    [~,idx] = min(abs(tt - t));
    lo = max(1,idx-2); hi = min(size(M,1),idx+2);
    row = mean(M(lo:hi, 2:4), 1);
end

function names = feature_names(ZONES)
    names = {}; ph = {'A','B','C'};
    for k=1:numel(ZONES)
        for p=1:3; names{end+1} = sprintf('V_%s_%s', ZONES{k}, ph{p}); end %#ok<AGROW>
        for p=1:3; names{end+1} = sprintf('I_%s_%s', ZONES{k}, ph{p}); end %#ok<AGROW>
    end
end

function write_slg_report(slg, OUT_SUM)
    % CSV
    fid = fopen(fullfile(OUT_SUM,'slg_preflight_check_v2.csv'),'w');
    fprintf(fid,'Zone,Healthy_Ia_A,SLG_Ia_A,Multiplication_Factor,Status\n');
    for k=1:numel(slg)
        fprintf(fid,'%s,%.3f,%.3f,%.3f,%s\n', slg(k).zone, slg(k).Ihealthy, ...
                slg(k).Islg, slg(k).ratio, slg(k).status);
    end
    fclose(fid);
    % TXT
    fid = fopen(fullfile(OUT_SUM,'slg_preflight_check_v2.txt'),'w');
    fprintf(fid,'SLG GROUNDING PRE-FLIGHT (v2)\nGenerated: %s\n\n', datestr(now));
    fprintf(fid,'%-6s %14s %14s %10s  %s\n','Zone','Healthy Ia (A)','SLG Ia (A)','Factor','Status');
    for k=1:numel(slg)
        fprintf(fid,'%-6s %14.1f %14.1f %9.1fx  %s\n', slg(k).zone, ...
                slg(k).Ihealthy, slg(k).Islg, slg(k).ratio, slg(k).status);
    end
    allpass = all(strcmp({slg.status},'PASS'));
    fprintf(fid,'\nOverall: %s\n', ternary(allpass,'ALL ZONES PASS','FAIL — see above'));
    fclose(fid);
end

function s = ternary(c,a,b); if c; s=a; else; s=b; end; end
