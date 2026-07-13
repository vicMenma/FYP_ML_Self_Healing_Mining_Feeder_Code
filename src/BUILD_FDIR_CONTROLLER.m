%% ========================================================================
%  BUILD_FDIR_CONTROLLER.m
%  Adds an AUTONOMOUS in-model FDIR controller to a COPY of the feeder model so
%  the whole detect -> classify -> isolate -> restore scheme runs inside ONE
%  Simulink simulation. After building, you inject a fault (enable any Fault_Bx)
%  and press RUN — the controller does the rest. No command window needed.
%
%  What it adds to the copy:
%    * FDIR_Controller  (MATLAB Function block) — detection, 0.5 s settle timer,
%      RF classification (via getRF/classifyRF), zone->breaker policy, latching.
%    * Mux (8x3 -> 24)  feeding the 24 RMS features to the controller.
%    * Clock            feeding simulation time.
%    * Demux (5)        splitting the controller's command vector.
%    * rewires the 5 breaker/tie control inputs from their Constant blocks to
%      the Demux outputs (the Constants are left in place but disconnected).
%
%  NON-DESTRUCTIVE: writes mining_feeder_layer_FDIR.slx; original untouched.
%  Requires getRF.m and classifyRF.m on the path (same folder). Run from scripts/.
%% ========================================================================
clc;
SRC = 'mining_feeder_layer_FINAL_baseline';
DST = 'mining_feeder_layer_FDIR';
fprintf('BUILD_FDIR_CONTROLLER — assembling an autonomous in-model controller\n\n');

% ---- 0. make a fresh copy of the model ----
if bdIsLoaded(DST); close_system(DST,0); end
if exist([DST '.slx'],'file'); delete([DST '.slx']); end
copyfile([SRC '.slx'], [DST '.slx']);
load_system(DST);
fprintf('[1/6] copied %s.slx -> %s.slx\n', SRC, DST);

% ---- 1. locate the control Constants (breaker command sources) ----
ctrlTok = {'CB_MAIN','CB_BUS1_B3','CB_BUS1_B4','CB_T2_BUS5','TIE'};
ctrl = cell(1,5);
for i=1:5; ctrl{i} = pick_ctrl(DST, ctrlTok{i}); end
fprintf('[2/6] found the 5 control Constant blocks\n');

% ---- 2. locate the 8 RMS feature taps (To-Workspace variable names) ----
featNames = {'RMS_V_B2','RMS_I_B2','RMS_V_B3','RMS_I_B3','RMS_V_B4','RMS_I_B4','RMS_V_B5','RMS_I_B5'};
tap = cell(1,8);
for i=1:8
    tap{i} = find_tows(DST, featNames{i});
    assert(~isempty(tap{i}), 'No To-Workspace block writing "%s".', featNames{i});
end
fprintf('[3/6] found the 8 RMS signal taps (V/I at B2-B5)\n');

% ---- 3. add the new blocks ----
add_block('simulink/Signal Routing/Mux', [DST '/FDIR_Mux'], 'Inputs','8', ...
    'Position',[150 1220 160 1420]);
add_block('simulink/Sources/Clock', [DST '/FDIR_Clock'], 'Position',[150 1450 180 1480]);
add_block('simulink/User-Defined Functions/MATLAB Function', [DST '/FDIR_Controller'], ...
    'Position',[300 1280 440 1380]);
add_block('simulink/Signal Routing/Demux', [DST '/FDIR_Demux'], 'Outputs','5', ...
    'Position',[500 1290 510 1370]);

% set the controller code
rt = sfroot;
chart = rt.find('-isa','Stateflow.EMChart','-and','Path',[DST '/FDIR_Controller']);
chart.Script = controller_code();
fprintf('[4/6] added FDIR_Controller, Mux, Clock, Demux and set the controller code\n');

% ---- 4. wire features + clock into the controller ----
muxPH = get_param([DST '/FDIR_Mux'],'PortHandles');
for i=1:8
    sp = src_port_of(tap{i});                 % branch the signal feeding this To-Workspace
    add_line(DST, sp, muxPH.Inport(i), 'autorouting','on');
end
ctlPH = get_param([DST '/FDIR_Controller'],'PortHandles');
add_line(DST, get_param([DST '/FDIR_Mux'],'PortHandles').Outport(1),  ctlPH.Inport(1), 'autorouting','on'); % feat
add_line(DST, get_param([DST '/FDIR_Clock'],'PortHandles').Outport(1), ctlPH.Inport(2), 'autorouting','on'); % t
fprintf('[5/6] wired 24 RMS features + clock into the controller\n');

% ---- 5. controller -> Demux -> breaker control ports (reuse Constant dests) ----
ctlPH = get_param([DST '/FDIR_Controller'],'PortHandles');   % refresh (block now has 2 outputs)
add_line(DST, ctlPH.Outport(1), get_param([DST '/FDIR_Demux'],'PortHandles').Inport(1), 'autorouting','on');
% show the predicted class (2nd controller output) live on a Display block
add_block('simulink/Sinks/Display',[DST '/FDIR_PredictedClass'],'Position',[560 1410 690 1450]);
add_line(DST, ctlPH.Outport(2), get_param([DST '/FDIR_PredictedClass'],'PortHandles').Inport(1), 'autorouting','on');
dmxPH = get_param([DST '/FDIR_Demux'],'PortHandles');
for i=1:5
    dst = const_dest_port(ctrl{i});           % breaker control port the Constant fed
    add_line(DST, dmxPH.Outport(i), dst, 'autorouting','on');
end

% ---- 6. save ----
set_param(DST,'StopTime','2.0');
save_system(DST);
fprintf('[6/6] saved %s.slx\n\n', DST);
fprintf('DONE. Next steps:\n');
fprintf('  1. open %s\n', DST);
fprintf('  2. enable a fault, e.g. in Fault_B2 set a single line-to-ground fault\n');
fprintf('     (FaultA on, GroundFault on, R = 0.001) with Transition times [0.5 2.0].\n');
fprintf('  3. press RUN. The controller detects the fault ~0.5 s later, classifies\n');
fprintf('     it, opens the faulted-zone breakers and (for B2/B3) closes the tie.\n');
fprintf('     Watch the DL_Bx voltage scopes: the faulted bus collapses, the healthy\n');
fprintf('     buses recover — all in one continuous run.\n');
fprintf('  4. the RF prediction is shown in TWO places:\n');
fprintf('       - the FDIR_PredictedClass Display block on the canvas (shows 0 = Healthy\n');
fprintf('         while monitoring, then the fault class 1-12 once a fault is classified), and\n');
fprintf('       - the Command Window, e.g.  [FDIR] fault classified as SLG-B2 (class 1).\n');
fprintf('     Class map: 0 Healthy; 1-3 SLG/LL/3PH-B2; 4-6 B3; 7-9 B4; 10-12 B5.\n');

%% ===================== local functions =====================
function s = controller_code()
c = {
'function [cmd, cls] = FDIR_Controller(feat, t) %#codegen'
'% Autonomous FDIR: detect a disturbance, wait 0.5 s, classify with the trained'
'% Random Forest, then latch the breaker/tie commands.'
'%   feat: 24 RMS features [V_B2abc I_B2abc V_B3abc I_B3abc V_B4abc I_B4abc V_B5abc I_B5abc]'
'%   cmd : [CB_MAIN CB_BUS1_B3 CB_BUS1_B4 CB_T2_BUS5 TIE]  (1=closed, 0=open; TIE 1=closed)'
'coder.extrinsic(''classifyRF'',''reportFDIR'');'
'persistent baseI det tdet decided cmdL clsL'
'if isempty(det)'
'    baseI = ones(1,12); det = false; tdet = 0; decided = false;'
'    cmdL = [1 1 1 1 0]; clsL = 0;   % normal: CB closed, tie open; idle = Healthy(0)'
'end'
'f = feat(:).'';'
'Iidx = [4 5 6 10 11 12 16 17 18 22 23 24];'
'Vidx = [1 2 3 7 8 9 13 14 15 19 20 21];'
'VBASE = 11000;'
'if t < 0.45'
'    baseI = f(Iidx);           % track the healthy pre-fault current baseline'
'end'
'if ~det && t > 0.45'
'    if any(f(Iidx) > 1.5*max(baseI,1)) || any(f(Vidx) < 0.85*VBASE)'
'        det = true; tdet = t;  % disturbance detected'
'    end'
'end'
'if det && ~decided && t >= tdet + 0.5'
'    c = 0;'
'    c = classifyRF(f);   % RF: 0 Healthy | 1-3 B2 | 4-6 B3 | 7-9 B4 | 10-12 B5'
'    clsL = c; cmdL = policy(c); decided = true;'
'    reportFDIR(t, c);    % prints the readable label in the Command Window'
'end'
'cmd = cmdL;'
'cls = clsL;'
'end'
''
'function cmd = policy(cls)'
'cmd = [1 1 1 1 0];'
'if cls>=1 && cls<=3        % B2: isolate (open CB_MAIN+CB_BUS1_B3), restore via tie'
'    cmd = [0 0 1 1 1];'
'elseif cls>=4 && cls<=6    % B3: isolate (open CB_BUS1_B3+CB_BUS1_B4), restore via tie'
'    cmd = [1 0 0 1 1];'
'elseif cls>=7 && cls<=9    % B4: isolate (open CB_BUS1_B4), tie stays open'
'    cmd = [1 1 0 1 0];'
'elseif cls>=10 && cls<=12  % B5: isolate (open CB_T2_BUS5), tie stays open'
'    cmd = [1 1 1 0 0];'
'end'
'end'
};
s = strjoin(c, char(10));
end

function h = find_tows(sys, varname)
    all = find_system(sys,'BlockType','ToWorkspace'); h='';
    for i=1:numel(all)
        if strcmp(get_param(all{i},'VariableName'), varname); h=all{i}; return; end
    end
end
function sp = src_port_of(towsBlk)
    ph = get_param(towsBlk,'PortHandles'); ln = get_param(ph.Inport(1),'Line');
    assert(ln~=-1, 'To-Workspace "%s" has no incoming signal.', get_param(towsBlk,'Name'));
    sp = get_param(ln,'SrcPortHandle');
end
function dst = const_dest_port(constBlk)
    ph = get_param(constBlk,'PortHandles'); ln = get_param(ph.Outport(1),'Line');
    assert(ln~=-1, 'Control Constant "%s" is not connected.', get_param(constBlk,'Name'));
    d = get_param(ln,'DstPortHandle'); dst = d(1);
    delete_line(ln);   % remove Constant->breaker link; the Demux takes over
end
function p=pick_ctrl(MODEL,tok)
    cs=find_system(MODEL,'SearchDepth',1,'BlockType','Constant'); p='';
    for i=1:numel(cs)
        if contains(regexprep(get_param(cs{i},'Name'),'\s+',' '),tok); p=getfullname(cs{i}); return; end
    end
    error('pick_ctrl:notfound','no Constant matching %s',tok);
end
