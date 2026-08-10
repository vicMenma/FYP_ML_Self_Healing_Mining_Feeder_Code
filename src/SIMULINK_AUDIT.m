function SIMULINK_AUDIT()
%% Non-destructive audit of the FINAL Simulink model for thesis traceability.
%  Writes SIMULINK_BLOCK_INVENTORY.csv + MODEL_PARAMETER_AUDIT.csv to the
%  evidence folder and prints a summary (breakers, tie, transformers, source,
%  loads, faults). Read-only: loads the model, never saves it.
clc;
EV  = 'C:\Users\victo\Desktop\Thesis - ML-Assisted Self-Healing of a Mining Distribution Feeder with Selective Fault Isolation\Project matlab\Thesis_Revision_Evidence';
MDL = 'mining_feeder_layer_FINAL_baseline';

info = Simulink.MDLInfo([MDL '.slx']);
fprintf('=== MODEL: %s.slx ===\n', MDL);
fprintf('SAVED_RELEASE|%s\n', info.ReleaseName);
try, fprintf('MODEL_VERSION|%s\n', info.ModelVersion); catch, end

load_system(MDL);
blks = find_system(MDL,'LookUnderMasks','all','FollowLinks','on','Type','block');
fprintf('TOTAL_BLOCKS|%d\n\n', numel(blks));

% ---- full inventory ----
fid = fopen(fullfile(EV,'SIMULINK_BLOCK_INVENTORY.csv'),'w');
fprintf(fid,'Name,Path,BlockType,MaskType,Category\n');
imp = {};                      % important blocks for parameter audit
for i=1:numel(blks)
    nm = clean(get_param(blks{i},'Name'));
    bt = get_param(blks{i},'BlockType');
    mt = ''; try, mt=get_param(blks{i},'MaskType'); catch, end
    cat = categ(mt, nm, bt);
    fprintf(fid,'"%s","%s","%s","%s","%s"\n', nm, blks{i}, bt, clean(mt), cat);
    if ~isempty(cat), imp{end+1} = struct('path',blks{i},'name',nm,'mt',mt,'cat',cat); end %#ok<AGROW>
end
fclose(fid);

% ---- parameter audit: dump every dialog parameter of important blocks ----
fid2 = fopen(fullfile(EV,'MODEL_PARAMETER_AUDIT.csv'),'w');
fprintf(fid2,'Category,Block,Parameter,Value\n');
for k=1:numel(imp)
    b = imp{k};
    dp = struct(); try, dp = get_param(b.path,'DialogParameters'); catch, end
    if isempty(dp), continue; end
    fns = fieldnames(dp);
    for j=1:numel(fns)
        v=''; try, v = get_param(b.path, fns{j}); catch, end
        if ~ischar(v), try, v = mat2str(v); catch, v='<nonchar>'; end; end
        fprintf(fid2,'"%s","%s","%s","%s"\n', b.cat, b.name, fns{j}, clean(v));
    end
end
fclose(fid2);

% ---- console summary by category ----
cats = {'Source','Transformer','Breaker','TieSwitch','Load','Fault','Line','Measurement'};
for c=1:numel(cats)
    sel = imp(cellfun(@(x)strcmp(x.cat,cats{c}), imp));
    fprintf('--- %s (%d) ---\n', cats{c}, numel(sel));
    for k=1:numel(sel)
        fprintf('  %-22s  [%s]\n', sel{k}.name, sel{k}.mt);
    end
end

% ---- breaker / tie detail (names + initial state + control) ----
fprintf('\n=== BREAKER / TIE DETAIL ===\n');
sw = imp(cellfun(@(x)any(strcmp(x.cat,{'Breaker','TieSwitch'})), imp));
for k=1:numel(sw)
    b=sw{k};
    fprintf('  %s [%s]\n', b.name, b.cat);
    for p = {'sw','InitialState','SwitchTimes','ExternalControl','Ron','BreakerResistanceRon'}
        val=''; try, val=get_param(b.path,p{1}); catch, continue; end
        if ~ischar(val), val=mat2str(val); end
        fprintf('      %-16s = %s\n', p{1}, clean(val));
    end
end
fprintf('\nAUDIT_DONE\n');
end

function s = clean(s)
if ~ischar(s), try, s=char(string(s)); catch, s=''; end; end
s = regexprep(s, '[\r\n]+', ' ');
s = strrep(s, '"', '''');
end

function c = categ(mt, nm, bt)
mtl=lower(mt); nml=lower(nm);
c='';
if contains(mtl,'breaker')
    if contains(nml,'tie'), c='TieSwitch'; else, c='Breaker'; end
elseif contains(nml,'tie') && (contains(mtl,'switch')||contains(bt,'Subsystem'))
    c='TieSwitch';
elseif contains(mtl,'transformer'), c='Transformer';
elseif contains(mtl,'source') && ~contains(mtl,'controlled'), c='Source';
elseif contains(mtl,'load'), c='Load';
elseif contains(mtl,'fault'), c='Fault';
elseif contains(mtl,'pi section')||contains(mtl,'distributed')||contains(mtl,'transmission line'), c='Line';
elseif contains(mtl,'measurement')||contains(nml,'rms'), c='Measurement';
end
end
