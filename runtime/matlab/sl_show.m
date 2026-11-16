function sl_show(model)
%SL_SHOW Open the model in the Simulink editor so the user can watch.
%   Use it right after sl_new / sl_open when the human wants to see the
%   diagram while it is being built.
    model = sl_str(model);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        open_system(model);
        try
            set_param(model, 'ZoomFactor', 'FitSystem');
        catch
        end
        sl_reply(struct('ok', true, 'model', model, 'open', true));
    catch ME
        sl_fail(ME);
    end
end
