function sl_snapshot(model, out_path, dpi)
%SL_SNAPSHOT Export the MODEL DIAGRAM itself to a PNG, so you can actually
%   look at what was built (wiring, layout, labels) instead of guessing.
%   out_path "" writes to the temp folder. dpi <= 0 means 150.
    model = sl_str(model);
    out_path = sl_str(out_path);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        if dpi <= 0
            dpi = 150;
        end
        if isempty(out_path)
            out_path = fullfile(tempdir, [model '_diagram.png']);
        end
        print(['-s' model], '-dpng', sprintf('-r%d', round(dpi)), out_path);
        d = dir(out_path);
        if isempty(d)
            error('sl:snapshotFailed', 'no PNG was produced at %s', out_path);
        end
        sl_reply(struct('ok', true, 'model', model, 'path', out_path, 'bytes', d.bytes));
    catch ME
        sl_fail(ME);
    end
end
