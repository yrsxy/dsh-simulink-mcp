function sl_delete(target)
%SL_DELETE Delete a block (its connected lines go with it).
%   Also accepts a model name, which deletes the whole model from memory.
    target = sl_str(target);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        isModel = false;
        if isempty(strfind(target, '/'))
            isModel = bdIsLoaded(target);
        end
        if isModel
            close_system(target, 0);
            sl_reply(struct('ok', true, 'closed', target));
            return;
        end
        if getSimulinkBlockHandle(target) == -1
            error('sl:noSuchBlock', 'block not found: %s', target);
        end
        delete_block(target);
        sl_reply(struct('ok', true, 'deleted', target));
    catch ME
        sl_fail(ME);
    end
end
