%% ========================================================================
%  CAPTURE_FDIR_RUN.m
%  Runs the autonomous FDIR model (mining_feeder_layer_FDIR) with an SLG fault
%  at B2 and captures the bus voltages over ONE continuous simulation, showing
%  the whole detect -> classify -> isolate -> restore sequence in a single run
%  (not the two-stage script evaluation). Saves the result figure for Chapter 5.
%% ========================================================================
clc;
mdl = 'mining_feeder_layer_FDIR';
load_system(mdl);

% clear all faults, then inject a single line-to-ground fault at B2 (t = 0.5 s)
for z = {'Fault_B2','Fault_B3','Fault_B4','Fault_B5'}
    set_param([mdl '/' z{1}],'FaultA','off','FaultB','off','FaultC','off','GroundFault','off', ...
        'SwitchTimes','[1000000 1000001]','InitialStates','0');
end
set_param([mdl '/Fault_B2'],'FaultA','on','GroundFault','on', ...
    'FaultResistance','0.001','GroundResistance','0.001','SwitchTimes','[0.5 2.0]','InitialStates','0');
set_param(mdl,'StopTime','2.0');

out = sim(mdl,'SimulationMode','normal','SaveOutput','on','SaveTime','on', ...
    'SignalLogging','on','SignalLoggingName','logsout','SaveFormat','Dataset');

VBASE = 11000; busn = {'B2','B3','B4','B5'}; cols = lines(4);
f = figure('Color','w','Position',[80 80 960 520],'Visible','off'); hold on; grid on; box on;
for b = 1:4
    M = get_rms(out, ['RMS_V_' busn{b}]);
    plot(M(:,1), mean(M(:,2:4),2)/VBASE, 'LineWidth',1.6, 'Color',cols(b,:));
end
yline(0.95,'r--'); yline(1.05,'r--'); xline(0.5,'k:','fault');
ylim([0 1.2]); xlabel('Time (s)'); ylabel('Bus voltage (pu)');
title('Autonomous FDIR — one continuous run: SLG fault at B2 (detect \rightarrow isolate \rightarrow restore)');
legend([busn, {'0.95 pu','1.05 pu'}], 'Location','southeast');
outp = fullfile('outputs_v2_topology','figures','thesis_rewrite','chapter_5','FDIR_autonomous_run.png');
print(f,'-dpng','-r180',outp); close(f);
fprintf('SAVED %s\n', outp);

function M = get_rms(sOut, varname)
    s = [];
    try, s = sOut.get(varname); catch, end
    if isempty(s) && evalin('base',['exist(''' varname ''',''var'')']); s = evalin('base', varname); end
    if isstruct(s) && isfield(s,'signals'); t = s.time; val = s.signals.values;
    elseif isa(s,'timeseries'); t = s.Time; val = s.Data;
    else; error('get_rms:fmt','cannot read %s', varname); end
    if size(val,2) < 3; val = repmat(val(:,1),1,3); end
    M = [t(:), val(:,1:3)];
end
