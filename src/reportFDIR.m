function reportFDIR(t, cls)
%REPORTFDIR  Print the FDIR classification result in human-readable form (once).
%   Called extrinsically by the FDIR_Controller block with numbers only, so no
%   variable-size string ever enters the block's generated code.
    names = {'Healthy','SLG-B2','LL-B2','3PH-B2','SLG-B3','LL-B3','3PH-B3', ...
             'SLG-B4','LL-B4','3PH-B4','SLG-B5','LL-B5','3PH-B5'};
    if cls >= 0 && cls <= 12
        fprintf('  [FDIR] t = %.3f s : fault classified as %s (class %d) -> action applied\n', ...
            t, names{cls+1}, cls);
    else
        fprintf('  [FDIR] t = %.3f s : class = %d\n', t, cls);
    end
end
