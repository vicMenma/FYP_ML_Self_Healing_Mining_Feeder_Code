function [cls, name] = classifyRF(feat)
%CLASSIFYRF  Predict the fault class (0-12) and its label from 24 RMS features.
%   Loads and caches the trained forest + class names on first call, and wraps
%   TreeBagger predict() so all cell/char handling happens in the normal MATLAB
%   interpreter; the FDIR_Controller block calls this extrinsically and receives
%   a plain double and a char label. The Simulink block never holds the object.
%     feat order: [V_B2abc I_B2abc V_B3abc I_B3abc V_B4abc I_B4abc V_B5abc I_B5abc]
%     cls: 0 Healthy | 1-3 B2 | 4-6 B3 | 7-9 B4 | 10-12 B5 (SLG,LL,3PH within each)
%     name: e.g. 'SLG-B2', 'Healthy'
    persistent rf names
    if isempty(rf); [rf, names] = getRF(); end
    yc  = predict(rf, double(feat(:)'));
    cls = str2double(yc{1});
    if isnan(cls); cls = 0; end
    name = names{cls+1};
end
