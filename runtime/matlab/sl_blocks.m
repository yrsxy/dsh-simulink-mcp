function sl_blocks(model, depth, type_filter)
%SL_BLOCKS List blocks in a model or subsystem.
%   depth: -1 for every level, otherwise SearchDepth (1 = top level).
%   type_filter: "" for all, else a Simulink BlockType such as "Gain".
    model = sl_str(model);
    type_filter = sl_str(type_filter);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        if depth < 0
            blocks = find_system(model, 'Type', 'Block');
        else
            blocks = find_system(model, 'SearchDepth', depth, 'Type', 'Block');
        end
        if ~isempty(type_filter)
            types = get_param(blocks, 'BlockType');
            keep = strcmp(types, type_filter);
            blocks = blocks(keep);
        end
        if isempty(blocks)
            sl_reply(struct('ok', true, 'model', model, 'count', 0, 'blocks', {{}}));
            return;
        end
        types = get_param(blocks, 'BlockType');
        rows = cell(1, numel(blocks));
        for k = 1:numel(blocks)
            rows{k} = struct('path', blocks{k}, 'type', types{k});
        end
        sl_reply(struct('ok', true, 'model', model, 'count', numel(blocks), 'blocks', {rows}));
    catch ME
        sl_fail(ME);
    end
end
