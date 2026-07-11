%% ========================================================================
%  INTERPOLATION_TEST.m
%  Reviewer robustness test #5: does the classifier generalise to fault
%  conditions BETWEEN the training-grid points? The training dataset used a
%  fixed grid (Rf, LM, ton). Here a small set of strictly OFF-GRID cases is
%  simulated, features are extracted with the IDENTICAL pipeline used for the
%  dataset, and the EXISTING trained model (rf_model_v2.mat) is used to
%  predict — the model is NOT retrained and the 1000-sample dataset is reused.
%
%  Only a small batch of new simulations is required (default 72 fault cases,
%  ~1-1.5 h). Reduce the OFF-grid vectors below to shorten the run.
%
%  Output: outputs_v2_topology/summaries/interpolation_test_v2.{txt,csv}
%  Run from the scripts/ folder (same folder as MASTER_A).
%% ========================================================================
clc; close all;
fprintf('INTERPOLATION (off-grid) GENERALISATION TEST\n%s\n\n', datestr(now));

%% ---- configuration (mirrors MASTER_A) ----
MODEL         = 'mining_feeder_layer_FINAL_baseline';
SIM_STOP_TIME = 2.0;
EXTRACT_DT    = 0.5;
FP_A='FaultA'; FP_B='FaultB'; FP_C='FaultC'; FP_G='GroundFault';
FP_RF='FaultResistance'; FP_RG='GroundResistance'; FP_ST='SwitchTimes'; FP_IS='InitialStates';
RG_LOW = 0.001;
SIG_V = {'RMS_V_B2','RMS_V_B3','RMS_V_B4','RMS_V_B5'};
SIG_I = {'RMS_I_B2','RMS_I_B3','RMS_I_B4','RMS_I_B5'};
ZONES = {'B2','B3','B4','B5'}; FAULT_TYPES = {'SLG','LL','3PH'}; CLASS_BASE = [1,4,7,10];
PH(1)=struct('A','on','B','off','C','off','G','on');    % SLG
PH(2)=struct('A','on','B','on', 'C','off','G','off');   % LL
PH(3)=struct('A','on','B','on', 'C','on', 'G','off');   % 3PH

% ---- OFF-GRID test points (strictly between the training-grid values) ------
%   training Rf : 0.001 0.1 0.5 1.0 5.0   ->  off-grid below
%   training LM : 0.70 0.85 1.00 1.10 1.30
%   training ton: 0.50 0.75 1.00
RF_OFF  = [0.05, 0.30, 2.50];    % between grid points
LM_OFF  = [0.78, 1.20];          % between grid points
TON_OFF = 0.625;                 % between 0.50 and 0.75

%% ---- discover blocks + load model + trained RF ----
load_system(MODEL);
BL = discover_blocks(MODEL);
Mm = load(local_find('rf_model_v2.mat')); rf = Mm.rf;
CLASS_NAMES = Mm.CLASS_NAMES;
nCases = numel(ZONES)*numel(FAULT_TYPES)*numel(RF_OFF)*numel(LM_OFF);
fprintf('Off-grid fault cases to simulate: %d  (Rf=%s, LM=%s, ton=%.3f)\n\n', ...
    nCases, mat2str(RF_OFF), mat2str(LM_OFF), TON_OFF);

%% ---- run the off-grid cases ----
rows = {}; nExact=0; nZone=0; nMiss=0; n=0; t0=tic;
for zk = 1:numel(ZONES)
    z = ZONES{zk}; fb = BL.fault.(z);
    for tt = 1:numel(FAULT_TYPES)
        cls = CLASS_BASE(zk) + (tt-1);
        for iR = 1:numel(RF_OFF)
            for iL = 1:numel(LM_OFF)
                n = n + 1;
                set_normal_state(BL);
                clear_all_faults(BL, FP_A,FP_B,FP_C,FP_G,FP_ST,FP_IS);
                set_loads(BL, LM_OFF(iL));
                p = PH(tt); tend = TON_OFF + 0.9;
                set_param(fb, FP_A,p.A,FP_B,p.B,FP_C,p.C,FP_G,p.G, ...
                    FP_RF,num2str(RF_OFF(iR)), FP_RG,num2str(RG_LOW), ...
                    FP_ST,sprintf('[%.4f %.4f]',TON_OFF,tend), FP_IS,'0');
                sOut = runsim(MODEL, SIM_STOP_TIME);
                f    = features24(sOut, SIG_V, SIG_I, TON_OFF+EXTRACT_DT);
                yh   = str2double(predict(rf, f));
                ex   = (yh == cls); zc = (zone_of(yh) == zone_of(cls)); ms = (cls~=0 && yh==0);
                nExact=nExact+ex; nZone=nZone+zc; nMiss=nMiss+ms;
                rows(end+1,:) = {z, FAULT_TYPES{tt}, RF_OFF(iR), LM_OFF(iL), cls, ...
                    CLASS_NAMES{cls+1}, yh, CLASS_NAMES{yh+1}, ex, zc}; %#ok<SAGROW>
                fprintf('  %-4s %-3s Rf=%.2f LM=%.2f -> pred %-7s %s  (%d/%d)\n', ...
                    z, FAULT_TYPES{tt}, RF_OFF(iR), LM_OFF(iL), CLASS_NAMES{yh+1}, ...
                    tern(ex,'[exact]',tern(zc,'[zone ok]','[WRONG]')), n, nCases);
            end
        end
    end
end
clear_all_faults(BL, FP_A,FP_B,FP_C,FP_G,FP_ST,FP_IS); set_normal_state(BL);

%% ---- report ----
T = cell2table(rows,'VariableNames', ...
    {'Zone','Type','Rf_ohm','LM','TrueClass','TrueLabel','PredClass','PredLabel','Exact','ZoneCorrect'});
outdir = fullfile('outputs_v2_topology','summaries'); if ~exist(outdir,'dir'); outdir=pwd; end
writetable(T, fullfile(outdir,'interpolation_test_v2.csv'));

exactAcc = nExact/nCases; zoneAcc = nZone/nCases;
L = {'INTERPOLATION (OFF-GRID) GENERALISATION TEST', sprintf('Generated: %s',datestr(now)), '', ...
 sprintf('Off-grid cases : %d  (Rf=%s ohm, LM=%s pu, ton=%.3f s)', nCases, mat2str(RF_OFF), mat2str(LM_OFF), TON_OFF), ...
 'These fault resistances, load multipliers and onset time lie strictly BETWEEN the', ...
 'training-grid points; the model has not seen them. Predictions use rf_model_v2.mat.', '', ...
 sprintf('Exact-class accuracy (type + location) : %6.2f %%  (%d/%d)', exactAcc*100, nExact, nCases), ...
 sprintf('Zone-localisation accuracy            : %6.2f %%  (%d/%d)', zoneAcc*100,  nZone,  nCases), ...
 sprintf('Missed faults (fault predicted Healthy): %d', nMiss), '', 'Per-fault-type exact accuracy:'};
for tt=1:numel(FAULT_TYPES)
    idx = strcmp(T.Type, FAULT_TYPES{tt});
    L{end+1}=sprintf('   %-3s : %6.2f %%  (%d/%d)', FAULT_TYPES{tt}, 100*mean(T.Exact(idx)), sum(T.Exact(idx)), sum(idx)); %#ok<SAGROW>
end
L{end+1}=''; L{end+1}=sprintf('Total simulation wall time: %.1f min.', toc(t0)/60);
txt = strjoin(L,char(10)); disp(' '); disp(txt);
fid=fopen(fullfile(outdir,'interpolation_test_v2.txt'),'w'); fprintf(fid,'%s\n',txt); fclose(fid);
fprintf('\nSaved: %s\n      %s\n', fullfile(outdir,'interpolation_test_v2.txt'), fullfile(outdir,'interpolation_test_v2.csv'));

%% ======================================================================
%%  LOCAL FUNCTIONS  (copied verbatim from MASTER_A so the pipeline is identical)
%% ======================================================================
function z = zone_of(cls)
    if cls==0; z=0; else; z = floor((cls-1)/3)+1; end   % 1->B2 2->B3 3->B4 4->B5
end
function s = tern(c,a,b); if c; s=a; else; s=b; end; end
function p = local_find(name)
    c = {fullfile('outputs_v2_topology',name), name, fullfile('outputs','model',name)};
    p=''; for i=1:numel(c); if exist(c{i},'file'); p=c{i}; return; end; end
    error('%s not found — run from the scripts/ folder.', name);
end
function BL = discover_blocks(MODEL)
    z = {'B2','B3','B4','B5'}; BL.fault=struct(); BL.load=struct();
    for k=1:numel(z)
        BL.fault.(z{k}) = pick(MODEL, {['Fault_' z{k}], leg(z{k},'Fault_SXEW')});
        BL.load.(z{k})  = pick(MODEL, {['DL_' z{k}],    leg(z{k},'DL_SXEW')});
    end
    BL.ctrl.CB_MAIN=pick_ctrl(MODEL,'CB_MAIN'); BL.ctrl.CB_BUS1_B3=pick_ctrl(MODEL,'CB_BUS1_B3');
    BL.ctrl.CB_BUS1_B4=pick_ctrl(MODEL,'CB_BUS1_B4'); BL.ctrl.CB_T2_BUS5=pick_ctrl(MODEL,'CB_T2_BUS5');
    BL.ctrl.TIE=pick_ctrl(MODEL,'TIE');
end
function s = leg(zone,name); if strcmp(zone,'B5'); s=name; else; s=''; end; end
function p = pick(MODEL,cands)
    p='';
    for i=1:numel(cands)
        nm=cands{i}; if isempty(nm); continue; end
        h=find_system(MODEL,'SearchDepth',1,'BlockType','Reference','Name',nm);
        if isempty(h)
            h=find_system(MODEL,'SearchDepth',1,'RegExp','on','Name',['^' regexprep(regexptranslate('escape',nm),'\s+','\\s+') '$']);
        end
        if ~isempty(h); p=getfullname(h{1}); return; end
    end
    error('discover:notfound','Missing block: %s', strjoin(cands,', '));
end
function p = pick_ctrl(MODEL,token)
    cs=find_system(MODEL,'SearchDepth',1,'BlockType','Constant');
    for i=1:numel(cs)
        if contains(regexprep(get_param(cs{i},'Name'),'\s+',' '), token); p=getfullname(cs{i}); return; end
    end
    error('discover:ctrl','No control Constant matching "%s".', token);
end
function set_switch(b,closed); set_param(b,'Value',num2str(double(logical(closed)))); end
function set_normal_state(BL)
    set_switch(BL.ctrl.CB_MAIN,true); set_switch(BL.ctrl.CB_BUS1_B3,true);
    set_switch(BL.ctrl.CB_BUS1_B4,true); set_switch(BL.ctrl.CB_T2_BUS5,true);
    set_switch(BL.ctrl.TIE,false);
end
function clear_all_faults(BL,A,B,C,G,ST,IS)
    z=fieldnames(BL.fault);
    for k=1:numel(z)
        set_param(BL.fault.(z{k}),A,'off',B,'off',C,'off',G,'off',ST,'[1000000 1000001]',IS,'0');
    end
end
function set_loads(BL,lm)
    z=fieldnames(BL.load);
    for k=1:numel(z)
        blk=BL.load.(z{k});
        for pn={'ActivePower','InductiveReactivePower'}
            try
                mn=get_param(blk,'MaskNames');
                if any(strcmp(mn,pn{1}))
                    ud=get_param(blk,'UserData'); key=matlab.lang.makeValidName(pn{1});
                    if ~isstruct(ud)||~isfield(ud,key)
                        base=str2double(get_param(blk,pn{1}));
                        if ~isstruct(ud); ud=struct(); end; ud.(key)=base; set_param(blk,'UserData',ud);
                    else; base=ud.(key); end
                    set_param(blk,pn{1},num2str(base*lm));
                end
            catch; end
        end
    end
end
function sOut = runsim(MODEL,stop)
    set_param(MODEL,'StopTime',num2str(stop));
    sOut = sim(MODEL,'SimulationMode','normal','FastRestart','off', ...
        'SaveOutput','on','SaveTime','on','SignalLogging','on', ...
        'SignalLoggingName','logsout','SaveFormat','Dataset');
end
function M = get_rms(sOut,varname)
    s=[]; try, s=sOut.get(varname); catch, end
    if isempty(s) && evalin('base',['exist(''' varname ''',''var'')']); s=evalin('base',varname); end
    if isstruct(s)&&isfield(s,'signals'); t=s.time; val=s.signals.values;
    elseif isa(s,'timeseries'); t=s.Time; val=s.Data;
    else; error('get_rms:fmt','Cannot read %s',varname); end
    if size(val,2)<3; val=repmat(val(:,1),1,3); end
    M=[t(:), val(:,1:3)];
end
function f = features24(sOut,SIG_V,SIG_I,textract)
    f=zeros(1,24); c=0;
    for k=1:4
        Vm=get_rms(sOut,SIG_V{k}); Im=get_rms(sOut,SIG_I{k});
        f(c+1:c+3)=at(Vm,textract); f(c+4:c+6)=at(Im,textract); c=c+6;
    end
end
function row = at(M,t)
    tt=M(:,1); [~,idx]=min(abs(tt-t)); lo=max(1,idx-2); hi=min(size(M,1),idx+2);
    row=mean(M(lo:hi,2:4),1);
end
