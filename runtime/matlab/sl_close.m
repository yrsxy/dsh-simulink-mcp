function sl_close(model, do_save)
%SL_CLOSE Close a loaded model. do_save=true saves before closing.
    model = sl_str(model);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        close_system(model, do_save);
        sl_reply(struct('ok', true, 'model', model, 'saved', logical(do_save)));
    catch ME
        sl_fail(ME);
    end
end
