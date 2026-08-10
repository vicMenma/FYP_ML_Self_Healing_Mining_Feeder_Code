%% ========================================================================
%  CAPTURE_FDIR_RUN_BW.m   (BLACK & WHITE version of CAPTURE_FDIR_RUN)
%  Regenerates Figure 5.15 (autonomous FDIR one-continuous-run) in print-safe
%  black & white: the four buses use distinct LINE STYLES so they stay
%  distinguishable when the thesis is printed in monochrome.
%  Run this in your interactive MATLAB (it runs a Simulink simulation), then
%  the PNG below can be dropped into the thesis in place of Figure 5.15.
%% ========================================================================
clc;
mdl = 'mining_feeder_layer_FDIR';
load_system(mdl);
for z = {'Fault_B2','Fault_B3','Fault_B4','Fault_B5'}
    set_param([mdl '/' z{1}],'FaultA','off','FaultB','off','FaultC','off','GroundFault','off', ...
        'SwitchTimes','[1000000 1000001]','InitialStates','0');
end
set_param([mdl '/Fault_B2'],'FaultA','on','GroundFault','on', ...
    'FaultResistance','0.001','GroundResistance','0.001','SwitchTimes','[0.5 2.0]','InitialStates','0');
set_param(mdl,'StopTime','2.0');
out = sim(mdl,'SimulationMode','normal','SaveOutput','on','SaveTime','on', ...
    'SignalLogging','on','SignalLoggingName','logsout','SaveFormat','Dataset');

VBASE = 11000; busn = {'B2','B3','B4','B5'};
sty = {'-','--',':','-.'}; gc = [0 0 0; 0.25 0.25 0.25; 0 0 0; 0.45 0.45 0.45]; lw = [1.6 1.7 2.1 1.8];
f = figure('Color','w','Position',[80 80 960 520],'Visible','on'); hold on; grid on; box on;
h = zeros(1,4);
for b = 1:4
    M = get_rms(out, ['RMS_V_' busn{b}]);
    h(b) = plot(M(:,1), mean(M(:,2:4),2)/VBASE, sty{b}, 'Color', gc(b,:), 'LineWidth', lw(b));
end
yline(0.95,':','Color',[0.55 0.55 0.55]); yline(1.05,':','Color',[0.55 0.55 0.55]);
xline(0.5,':','fault','Color',[0.4 0.4 0.4]);
ylim([0 1.2]); xlabel('Time (s)'); ylabel('Bus voltage (pu)');
title('Autonomous FDIR - one continuous run: SLG fault at B2 (detect \rightarrow isolate \rightarrow restore)');
legend(h, busn, 'Location','southeast');
outp = fullfile('outputs_v2_topology','figures','thesis_rewrite','chapter_5','FDIR_autonomous_run_BW.png');
print(f,'-dpng','-r180',outp); fprintf('SAVED %s\n', outp);

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
