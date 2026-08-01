%% ========================================================================
%  LIVE_FDIR_DEMO.m
%  One-command demonstration of the trained scheme: inject a fault, let the
%  Random Forest DECIDE what kind of fault it is and where (from the 24 RMS
%  measurements only), then take the protective action — isolate the faulted
%  zone and, where the topology allows, CLOSE the tie to restore healthy buses.
%
%  It prints a plain-English timeline and saves a two-stage figure so the
%  restoration mechanism (the tie CLOSING) is explicit.
%
%  How the "restoration" works (this is the point that confuses people):
%    Stage 1  = fault on the intact feeder (all breakers CLOSED, tie OPEN).
%               Used ONLY to get measurements for the classifier. Here B2, B3
%               and B4 all sag together because they share the T1 feeder.
%    Stage 2  = the ACTION: open the faulted-zone breakers AND close the tie.
%               The healthy buses now draw from T2 through the CLOSED tie.
%    The tie is OPEN in Stage 1 and CLOSED in Stage 2 — the buses are restored
%    by CLOSING it, never with it open.
%
%  Change FAULT_ZONE / FAULT_TYPE below to try any case. Run from scripts/.
%% ========================================================================
clc; close all;

MODEL = 'mining_feeder_layer_FINAL_baseline';
load_system(MODEL);
BL = discover_blocks(MODEL);
S  = load(local_find('rf_model_v2.mat')); rf = S.rf; CLASS_NAMES = S.CLASS_NAMES;
VBASE = read_xfmr_v2(MODEL,'T1');    % 11 kV line-to-line base
T2VA  = read_xfmr_va(MODEL,'T2');    % T2 rating for the capacity check
VBAND = [0.95 1.05];
PH.SLG = struct('A','on','B','off','C','off','G','on');
PH.LL  = struct('A','on','B','on', 'C','off','G','off');
PH.PH3 = struct('A','on','B','on', 'C','on', 'G','off');

% Save the current state of every block this demo will touch, so the model can
% be returned EXACTLY to its pre-demo state at the end (even if an error occurs).
S0 = capture_state(BL, MODEL);

% ================= PRE-STAGE — choose the fault to inject =================
fprintf('\n%s\n  PRE-STAGE — choose the fault to inject\n%s\n', repmat('-',1,60), repmat('-',1,60));
FAULT_ZONE = choose('  Fault LOCATION', {'B2','B3','B4','B5'}, 'B2');
FAULT_TYPE = choose('  Fault TYPE',     {'SLG','LL','3PH'},   'SLG');
phcfg = PH.(strrep(FAULT_TYPE,'3PH','PH3'));

line = @() fprintf('%s\n', repmat('=',1,60));
line(); fprintf('  LIVE FDIR DEMO — detect, classify, isolate, restore\n'); line();
fprintf('Injected fault (ground truth, HIDDEN from the classifier): %s at %s\n\n', FAULT_TYPE, FAULT_ZONE);

try   % ---- protected region: restore the model state no matter what ----

% ---------- STAGE 1: fault on the intact feeder ----------
set_normal_state(BL); clear_all_faults(BL); set_loads(BL,1.0);
set_param(BL.fault.(FAULT_ZONE),'FaultA',phcfg.A,'FaultB',phcfg.B,'FaultC',phcfg.C, ...
    'GroundFault',phcfg.G,'FaultResistance','0.001','GroundResistance','0.001', ...
    'SwitchTimes','[0.5 2.0]','InitialStates','0');
set_param(MODEL,'StopTime','2.0');
s1 = sim(MODEL,'SimulationMode','normal','SaveOutput','on','SaveTime','on', ...
    'SignalLogging','on','SignalLoggingName','logsout','SaveFormat','Dataset');

[tdet, found] = detect_onset(s1, VBASE);
if found; tsamp = min(tdet+0.5,1.9); else; tsamp = 1.5; end
fprintf('[STAGE 1] fault on the intact feeder (all breakers CLOSED, tie OPEN)\n');
if found; fprintf('  disturbance DETECTED at t = %.3f s\n', tdet); else; fprintf('  no disturbance detected\n'); end
fprintf('  bus voltages during fault:');
for b={'B2','B3','B4','B5'}; fprintf('  %s=%.2f', b{1}, pu_voltage(s1,['RMS_V_' b{1}],VBASE,tsamp)); end
fprintf(' pu\n\n');

% ---------- CLASSIFY ----------
f = features24(s1, tsamp);
cls = str2double(predict(rf, f));
predZone = zone_of_class(cls); predName = CLASS_NAMES{cls+1};
parts = split(predName,'-'); predType = parts{1};
fprintf('[CLASSIFY] RF reads the 24 RMS features (nothing tells it where the fault is)\n');
fprintf('  predicted class : %d  (%s)\n', cls, predName);
fprintf('  => fault TYPE   = %s\n', predType);
fprintf('  => fault ZONE   = %s      [match with injected: %s]\n\n', predZone, tern(strcmp(predZone,FAULT_ZONE),'YES','NO'));

% ---------- DECIDE ----------
[brk, isolated, restored, attemptTie, remainsT1] = zone_policy(predZone);
fprintf('[DECIDE] deterministic policy for predicted zone %s:\n', predZone);
fprintf('  open breakers : %s   (isolate %s)\n', strjoin(brk,', '), isolated);
fprintf('  restore zones : %s%s\n', tern(isempty(restored),'(none)',strjoin(restored,', ')), ...
    tern(isempty(remainsT1),'',[ '   |  stay on T1: ' strjoin(remainsT1,', ')]));
fprintf('  tie eligible  : %s\n\n', tern(attemptTie,'yes (upstream fault)','no (terminal zone — closing would backfeed)'));

% ---------- STAGE 2: act ----------
capOk=true; restVA=NaN; tieClosed=false;
if ~strcmp(predZone,'Healthy')
    for i=1:numel(brk); set_switch(BL.ctrl.(brk{i}), false); end
    if attemptTie
        restVA=0; for i=1:numel(restored); restVA=restVA+measured_bus_va(s1,restored{i},[0.30 0.45]); end
        restVA=restVA+measured_bus_va(s1,'B5',[0.30 0.45]); capOk = restVA<=T2VA;
    end
    tieClosed = attemptTie && capOk;
    set_switch(BL.ctrl.TIE, tieClosed);
    s2 = sim(MODEL,'SimulationMode','normal','SaveOutput','on','SaveTime','on', ...
        'SignalLogging','on','SignalLoggingName','logsout','SaveFormat','Dataset');
else
    s2 = s1;
end
fprintf('[STAGE 2] apply the switching (fault still active)\n');
if attemptTie; fprintf('  capacity check: reconnect %.2f MVA <= T2 %.2f MVA -> %s\n', restVA/1e6, T2VA/1e6, tern(capOk,'OK','EXCEEDS')); end
fprintf('  TIE_SWITCH    : %s\n', tern(tieClosed,'CLOSED  <-- this is what re-energises the healthy buses','OPEN (kept open by design)'));
fprintf('  bus voltages after action:');
Vpu=struct();
for b={'B2','B3','B4','B5'}; Vpu.(b{1})=pu_voltage(s2,['RMS_V_' b{1}],VBASE,1.6); fprintf('  %s=%.2f',b{1},Vpu.(b{1})); end
fprintf(' pu\n\n');

% ---------- RESULT ----------
restV = cellfun(@(b) Vpu.(b), restored);
Vok = isempty(restV) || all(restV>=VBAND(1) & restV<=VBAND(2));
if strcmp(predZone,'Healthy'); status='HEALTHY_NO_ACTION';
elseif ~attemptTie;           status='ISOLATED_NO_TIE';
elseif ~capOk;                status='BLOCKED_BY_CAPACITY';
elseif tieClosed && Vok;      status='RESTORED';
else;                         status='ISOLATED_TIE_BLOCKED'; end
line(); fprintf('  RESULT: %s\n', status); line();
fprintf('  %s isolated (de-energised).', isolated);
if strcmp(status,'RESTORED')
    fprintf(' %s restored from T2 through the CLOSED tie (%.2f-%.2f pu).\n', ...
        strjoin(restored,', '), min(restV), max(restV));
    fprintf('  Note: the tie is OPEN during detection (Stage 1) and CLOSED after the\n');
    fprintf('        action (Stage 2). The healthy buses come back ONLY because it closes.\n');
else
    fprintf(' Tie kept OPEN; healthy buses %s stay on the T1 main path.\n', strjoin(remainsT1,', '));
end

% ---------- figure ----------
figure('Color','w','Position',[60 60 1000 720]); busn={'B2','B3','B4','B5'}; cols=lines(4); sPair={s1,s2};
for st=1:2
    subplot(2,1,st); hold on; grid on; box on; sOut = sPair{st};
    for b=1:4; M=get_rms(sOut,['RMS_V_' busn{b}]); plot(M(:,1),mean(M(:,2:4),2)/VBASE,'LineWidth',1.4,'Color',cols(b,:)); end
    yline(0.95,'r--'); yline(1.05,'r--'); ylim([0 1.2]); ylabel('Bus voltage (pu)');
    if st==1; if found; xline(tdet,'k:','detected'); end
        title(sprintf('Stage 1 — %s fault at %s on the intact feeder (tie OPEN)',FAULT_TYPE,FAULT_ZONE));
    else
        title(sprintf('Stage 2 — after action: predicted %s -> %s (tie %s)', predName, status, tern(tieClosed,'CLOSED','OPEN')),'Interpreter','none');
        xlabel('Time (s)');
    end
    legend([busn {'0.95','1.05'}],'Location','eastoutside');
end
catch ME
    restore_state(BL, MODEL, S0);      % restore the model even if the demo errors
    rethrow(ME);
end
restore_state(BL, MODEL, S0);          % return every touched block to its pre-demo state

%% ===================== local functions (copied from the pipeline) =========
function p=local_find(n); c={fullfile('outputs_v2_topology',n),n,fullfile('outputs','model',n)}; p=''; for i=1:numel(c); if exist(c{i},'file'); p=c{i}; return; end; end; error('%s not found (run from scripts/).',n); end
function s=tern(c,a,b); if c; s=a; else; s=b; end; end

function v = choose(prompt, opts, defv)
% Prompt until the user enters a valid option (Enter keeps the default).
    while true
        r = strtrim(input(sprintf('%s (%s) [Enter=%s]: ', prompt, strjoin(opts,'/'), defv), 's'));
        if isempty(r); v = defv; break; end
        i = find(strcmpi(r, opts), 1);
        if ~isempty(i); v = opts{i}; break; end
        fprintf('    invalid; choose one of: %s\n', strjoin(opts,', '));
    end
    fprintf('    -> %s\n', v);
end

function S0 = capture_state(BL, MODEL)
% Snapshot every parameter this demo modifies, so it can be fully restored.
    S0.stop = get_param(MODEL,'StopTime');
    cn = fieldnames(BL.ctrl);
    for i=1:numel(cn); S0.ctrl.(cn{i}) = get_param(BL.ctrl.(cn{i}),'Value'); end
    fp = {'FaultA','FaultB','FaultC','GroundFault','FaultResistance','GroundResistance','SwitchTimes','InitialStates'};
    fn = fieldnames(BL.fault);
    for i=1:numel(fn); for j=1:numel(fp); S0.fault.(fn{i}).(fp{j}) = get_param(BL.fault.(fn{i}),fp{j}); end; end
    lp = {'ActivePower','InductiveReactivePower','UserData'};
    ln = fieldnames(BL.load);
    for i=1:numel(ln); for j=1:numel(lp); try, S0.load.(ln{i}).(lp{j}) = get_param(BL.load.(ln{i}),lp{j}); catch, end; end; end
end

function restore_state(BL, MODEL, S0)
% Return every touched block to the exact value captured before the demo.
    try, set_param(MODEL,'StopTime',S0.stop); catch, end
    cn = fieldnames(S0.ctrl);
    for i=1:numel(cn); try, set_param(BL.ctrl.(cn{i}),'Value',S0.ctrl.(cn{i})); catch, end; end
    fn = fieldnames(S0.fault);
    for i=1:numel(fn); fpn=fieldnames(S0.fault.(fn{i})); for j=1:numel(fpn); try, set_param(BL.fault.(fn{i}),fpn{j},S0.fault.(fn{i}).(fpn{j})); catch, end; end; end
    ln = fieldnames(S0.load);
    for i=1:numel(ln); lpn=fieldnames(S0.load.(ln{i})); for j=1:numel(lpn); try, set_param(BL.load.(ln{i}),lpn{j},S0.load.(ln{i}).(lpn{j})); catch, end; end; end
    fprintf('\n[cleanup] all touched blocks restored to their pre-demo state.\n');
end
function [brk,isolated,restored,attemptTie,remainsT1]=zone_policy(zone)
    switch zone
        case 'Healthy'; brk={}; isolated='(none)'; restored={}; attemptTie=false; remainsT1={'B2','B3','B4'};
        case 'B2'; brk={'CB_MAIN','CB_BUS1_B3'}; isolated='B2'; restored={'B3','B4'}; attemptTie=true; remainsT1={};
        case 'B3'; brk={'CB_BUS1_B3','CB_BUS1_B4'}; isolated='B3'; restored={'B4'}; attemptTie=true; remainsT1={'B2'};
        case 'B4'; brk={'CB_BUS1_B4'}; isolated='B4'; restored={}; attemptTie=false; remainsT1={'B2','B3'};
        case 'B5'; brk={'CB_T2_BUS5'}; isolated='B5'; restored={}; attemptTie=false; remainsT1={'B2','B3','B4'};
        otherwise; error('zone_policy:unknown','no policy for %s',zone);
    end
end
function z=zone_of_class(c); if c==0; z='Healthy'; elseif c<=3; z='B2'; elseif c<=6; z='B3'; elseif c<=9; z='B4'; else; z='B5'; end; end
function BL=discover_blocks(MODEL)
    z={'B2','B3','B4','B5'}; BL.fault=struct(); BL.load=struct();
    for k=1:numel(z); BL.fault.(z{k})=pick(MODEL,{['Fault_' z{k}],leg(z{k},'Fault_SXEW')}); BL.load.(z{k})=pick(MODEL,{['DL_' z{k}],leg(z{k},'DL_SXEW')}); end
    BL.ctrl.CB_MAIN=pick_ctrl(MODEL,'CB_MAIN'); BL.ctrl.CB_BUS1_B3=pick_ctrl(MODEL,'CB_BUS1_B3');
    BL.ctrl.CB_BUS1_B4=pick_ctrl(MODEL,'CB_BUS1_B4'); BL.ctrl.CB_T2_BUS5=pick_ctrl(MODEL,'CB_T2_BUS5'); BL.ctrl.TIE=pick_ctrl(MODEL,'TIE');
end
function s=leg(z,n); if strcmp(z,'B5'); s=n; else; s=''; end; end
function p=pick(MODEL,cands)
    p=''; for i=1:numel(cands); nm=cands{i}; if isempty(nm); continue; end
        h=find_system(MODEL,'SearchDepth',1,'BlockType','Reference','Name',nm);
        if isempty(h); h=find_system(MODEL,'SearchDepth',1,'RegExp','on','Name',['^' regexprep(regexptranslate('escape',nm),'\s+','\\s+') '$']); end
        if ~isempty(h); p=getfullname(h{1}); return; end
    end; error('pick:notfound','none of: %s',strjoin(cands,', '));
end
function p=pick_ctrl(MODEL,tok)
    cs=find_system(MODEL,'SearchDepth',1,'BlockType','Constant');
    for i=1:numel(cs); if contains(regexprep(get_param(cs{i},'Name'),'\s+',' '),tok); p=getfullname(cs{i}); return; end; end
    error('pick_ctrl:notfound','no Constant matching %s',tok);
end
function set_switch(c,cl); set_param(c,'Value',num2str(double(logical(cl)))); end
function set_normal_state(BL); set_switch(BL.ctrl.CB_MAIN,true); set_switch(BL.ctrl.CB_BUS1_B3,true); set_switch(BL.ctrl.CB_BUS1_B4,true); set_switch(BL.ctrl.CB_T2_BUS5,true); set_switch(BL.ctrl.TIE,false); end
function clear_all_faults(BL); z=fieldnames(BL.fault); for k=1:numel(z); set_param(BL.fault.(z{k}),'FaultA','off','FaultB','off','FaultC','off','GroundFault','off','SwitchTimes','[1000000 1000001]','InitialStates','0'); end; end
function set_loads(BL,lm)
    z=fieldnames(BL.load); for k=1:numel(z); b=BL.load.(z{k});
        for pn={'ActivePower','InductiveReactivePower'}; try; mn=get_param(b,'MaskNames');
            if any(strcmp(mn,pn{1})); ud=get_param(b,'UserData'); key=matlab.lang.makeValidName(pn{1});
                if ~isstruct(ud)||~isfield(ud,key); base=str2double(get_param(b,pn{1})); if ~isstruct(ud); ud=struct(); end; ud.(key)=base; set_param(b,'UserData',ud); else; base=ud.(key); end
                set_param(b,pn{1},num2str(base*lm)); end
        catch; end; end
    end
end
function v=read_xfmr_v2(MODEL,tok); b=find_xfmr(MODEL,tok); w=str2num(get_param(b,'Winding2')); v=w(1); end %#ok<ST2NM>
function va=read_xfmr_va(MODEL,tok); b=find_xfmr(MODEL,tok); n=str2num(get_param(b,'NominalPower')); va=n(1); end %#ok<ST2NM>
function b=find_xfmr(MODEL,tok)
    b=''; blks=find_system(MODEL,'SearchDepth',1);
    for i=1:numel(blks); if strcmp(blks{i},MODEL); continue; end
        nm=strtrim(regexprep(get_param(blks{i},'Name'),'\s+',' ')); if ~startsWith(nm,tok); continue; end
        try; mn=get_param(blks{i},'MaskNames'); if any(strcmp(mn,'NominalPower'))&&any(strcmp(mn,'Winding2')); b=blks{i}; return; end; catch; end
    end; error('find_xfmr:notfound','no transformer "%s"',tok);
end
function v=pu_voltage(sOut,varname,VBASE,t); M=get_rms(sOut,varname); tt=M(:,1); [~,idx]=min(abs(tt-t)); v=mean(mean(M(max(1,idx-3):min(size(M,1),idx+3),2:4),1))/VBASE; end
function f=features24(sOut,tsamp)
    V={'RMS_V_B2','RMS_V_B3','RMS_V_B4','RMS_V_B5'}; I={'RMS_I_B2','RMS_I_B3','RMS_I_B4','RMS_I_B5'}; f=zeros(1,24); c=0;
    for k=1:4; Vm=get_rms(sOut,V{k}); Im=get_rms(sOut,I{k}); f(c+1:c+3)=at(Vm,tsamp); f(c+4:c+6)=at(Im,tsamp); c=c+6; end
end
function [tdet,found]=detect_onset(sOut,VBASE)
    sI={'RMS_I_B2','RMS_I_B3','RMS_I_B4','RMS_I_B5'}; sV={'RMS_V_B2','RMS_V_B3','RMS_V_B4','RMS_V_B5'}; tdet=NaN; found=false; tC=[];
    for k=1:4; M=get_rms(sOut,sI{k}); t=M(:,1); base=mean(M(t>=0.30&t<=0.45,2:4),1);
        idx=find(any(M(:,2:4)>1.5*max(base,1e-3),2)&t>0.45,1,'first'); if ~isempty(idx); tC(end+1)=t(idx); end %#ok<AGROW>
        Mv=get_rms(sOut,sV{k}); vpu=mean(Mv(:,2:4),2)/VBASE; idx2=find(vpu<0.85&Mv(:,1)>0.45,1,'first'); if ~isempty(idx2); tC(end+1)=Mv(idx2,1); end %#ok<AGROW>
    end
    if ~isempty(tC); tdet=min(tC); found=true; end
end
function va=measured_bus_va(sOut,bus,twin)
    Mv=get_rms(sOut,['RMS_V_' bus]); Mi=get_rms(sOut,['RMS_I_' bus]); t=Mv(:,1); w=t>=twin(1)&t<=twin(2);
    VLL=mean(mean(Mv(w,2:4),2)); ti=Mi(:,1); wi=ti>=twin(1)&ti<=twin(2); I=mean(mean(Mi(wi,2:4),2)); va=sqrt(3)*VLL*I;
end
function row=at(M,t); tt=M(:,1); [~,idx]=min(abs(tt-t)); row=mean(M(max(1,idx-2):min(size(M,1),idx+2),2:4),1); end
function M=get_rms(sOut,varname)
    s=[]; try, s=sOut.get(varname); catch, end
    if isempty(s)&&evalin('base',['exist(''' varname ''',''var'')']); s=evalin('base',varname); end
    if isstruct(s)&&isfield(s,'signals'); t=s.time; val=s.signals.values; elseif isa(s,'timeseries'); t=s.Time; val=s.Data; else; error('get_rms:fmt','cannot read %s',varname); end
    if size(val,2)<3; val=repmat(val(:,1),1,3); end; M=[t(:),val(:,1:3)];
end
