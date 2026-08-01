%% ========================================================================
%  PATCH_FDIR_IDLE.m
%  Changes the FDIR controller's idle value from -1 to 0 (Healthy) in the
%  EXISTING mining_feeder_layer_FDIR model, editing ONLY the controller code.
%  It does NOT rebuild the model and does NOT move any blocks — your current
%  layout is preserved. Run once from the scripts/ folder.
%% ========================================================================
DST = 'mining_feeder_layer_FDIR';
load_system(DST);

rt = sfroot;
chart = rt.find('-isa','Stateflow.EMChart','-and','Path',[DST '/FDIR_Controller']);
assert(~isempty(chart), 'FDIR_Controller not found in %s — build it first.', DST);

code = chart.Script;
new  = strrep(code, 'clsL = -1', 'clsL = 0');          % idle value -> Healthy(0)
new  = strrep(new,  '-1 = monitoring', 'idle = Healthy(0)');

if strcmp(code, new)
    fprintf('No change needed — the idle value is already 0 (no "clsL = -1" found).\n');
else
    chart.Script = new;
    save_system(DST);
    fprintf('Idle value changed to 0 (Healthy) in %s.\n', DST);
    fprintf('Block layout untouched. Re-run the simulation: a healthy run now shows 0,\n');
    fprintf('and a faulted run shows 0 before the fault, then the fault class after.\n');
end
