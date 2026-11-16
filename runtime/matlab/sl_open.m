function sl_open(path)
%SL_OPEN Load an existing .slx model from disk.
    path = sl_str(path);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        % exist() reports 4 for a .slx model, so test for a plain file instead.
        if ~isfile(path)
            error('sl:noSuchFile', 'model file not found: %s', path);
        end
        [p, n] = fileparts(path);
        if ~isempty(p)
            addpath(p);
        end
        load_system(path);
        blocks = find_system(n, 'SearchDepth', 1, 'Type', 'Block');
        sl_reply(struct('ok', true, 'model', n, 'path', path, ...
                        'topLevelBlocks', numel(blocks)));
    catch ME
        sl_fail(ME);
    end
end
