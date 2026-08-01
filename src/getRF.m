function [rf, names] = getRF()
%GETRF  Load the trained Random Forest and its class names for the FDIR block.
%   Runs as an extrinsic call, so the TreeBagger object is loaded in the normal
%   MATLAB interpreter (no code generation of the model object required).
    cand = {fullfile('outputs_v2_topology','rf_model_v2.mat'), ...
            'rf_model_v2.mat', ...
            fullfile('outputs','model','rf_model_v2.mat')};
    p = '';
    for i = 1:numel(cand)
        if exist(cand{i},'file'); p = cand{i}; break; end
    end
    assert(~isempty(p), 'getRF:notfound', ...
        'rf_model_v2.mat not found — run the model from the scripts/ folder.');
    S = load(p,'rf','CLASS_NAMES');
    rf = S.rf; names = S.CLASS_NAMES;
end
