function sl_cleanup(model)
%SL_CLEANUP Remove dangling line segments left behind by block deletion.
%   Those segments keep a port "occupied", so the next add_line fails with
%   "destination port already has a line".
%   NOTE: deleting a line invalidates every line handle, so this re-queries
%   the model after each removal instead of batching.
    model = sl_str(model);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        removed = 0;
        for iter = 1:500
            hs = find_system(model, 'FindAll', 'on', 'type', 'line');
            target = [];
            for k = 1:numel(hs)
                h = hs(k);
                sb = -1;
                db = -1;
                try, sb = get_param(h, 'SrcBlockHandle'); catch, end
                try, db = get_param(h, 'DstBlockHandle'); catch, end
                if sb == -1 || isempty(db) || all(db == -1)
                    target = h;
                    break;
                end
            end
            if isempty(target)
                break;
            end
            delete_line(target);
            removed = removed + 1;
        end
        sl_reply(struct('ok', true, 'model', model, 'removed', removed));
    catch ME
        sl_fail(ME);
    end
end
