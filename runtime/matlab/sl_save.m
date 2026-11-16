function sl_save(model, save_path)
%SL_SAVE Save a loaded model. save_path "" reuses the model's own file.
    model = sl_str(model);
    save_path = sl_str(save_path);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        actual = save_path;
        note = '';
        if isempty(save_path)
            save_system(model);
        else
            try
                save_system(model, save_path);
            catch ME
                [~, ~, ext] = fileparts(save_path);
                if ~strcmpi(ext, '.slx')
                    rethrow(ME);
                end
                % The .slx writer loads extra MathWorks DLLs that some
                % application-control policies block; the .mdl writer does
                % not. Say so instead of failing silently or pretending all
                % is well.
                actual = [save_path(1:end - numel(ext)) '.mdl'];
                save_system(model, actual);
                note = sprintf(['.slx write failed (%s); saved as .mdl. ' ...
                                'This is usually a Windows application-control ' ...
                                'or code-signing policy blocking a MathWorks DLL.'], ME.message);
            end
        end
        payload = struct('ok', true, 'model', model, 'path', actual);
        if ~isempty(note)
            payload.warning = note;
        end
        sl_reply(payload);
    catch ME
        sl_fail(ME);
    end
end
