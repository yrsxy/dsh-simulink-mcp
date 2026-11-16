function sl_highlight(model, block)
%SL_HIGHLIGHT Mark a block in red in the Simulink editor, and keep the mark
%   in the next sl_snapshot. An empty block clears every mark in the model.
    model = sl_str(model);
    block = sl_str(block);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        if isempty(block)
            blocks = find_system(model, 'SearchDepth', 1, 'Type', 'Block');
            for k = 1:numel(blocks)
                try
                    hilite_system(blocks{k}, 'default');
                catch
                end
            end
            sl_reply(struct('ok', true, 'model', model, 'cleared', true, ...
                            'count', numel(blocks)));
            return
        end
        path = block;
        if isempty(strfind(path, '/'))
            path = [model '/' path];
        end
        if getSimulinkBlockHandle(path) <= 0
            error('sl:noSuchBlock', 'block not found: %s', path);
        end
        hilite_system(path);
        sl_reply(struct('ok', true, 'model', model, 'block', path, ...
                        'highlighted', true));
    catch ME
        sl_fail(ME);
    end
end
