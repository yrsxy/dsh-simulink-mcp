function sl_new(name, save_path)
%SL_NEW Create a new blank Simulink model.
%   save_path: "" keeps it unsaved, otherwise save the .slx there.
    name = sl_str(name);
    save_path = sl_str(save_path);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if bdIsLoaded(name)
            close_system(name, 0);
        end
        new_system(name);
        try
            % Dataset output needs the Simulink HMI signal observer, which
            % Windows application-control policies can block; Array output
            % always works and every sl_* reader understands it.
            set_param(name, 'SaveFormat', 'Array');
        catch
        end
        payload = struct('ok', true, 'model', name, 'saved', false);
        if ~isempty(save_path)
            save_system(name, save_path);
            payload.saved = true;
            payload.path = save_path;
        end
        sl_reply(payload);
    catch ME
        sl_fail(ME);
    end
end
