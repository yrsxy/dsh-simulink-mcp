function sl_lib_search(query, limit)
%SL_LIB_SEARCH Find blocks in the built-in Simulink library by path substring.
%   Use this instead of guessing library paths. limit 0 means 50.
    query = sl_str(query);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        persistent libPath
        if isempty(libPath)
            load_system('simulink');
            libPath = find_system('simulink', 'Type', 'Block');
        end
        if isempty(query)
            hits = libPath;
        else
            hits = libPath(~cellfun(@isempty, regexpi(libPath, query, 'once')));
        end
        n = numel(hits);
        if limit <= 0
            limit = 50;
        end
        shown = hits(1:min(limit, n));
        % library paths come back display-formatted with embedded newlines;
        % add_block() wants the real (space separated) path
        shown = cellfun(@(x) strtrim(strrep(strrep(x, char(10), ' '), char(13), ' ')), ...
                        shown, 'UniformOutput', false);
        sl_reply(struct('ok', true, 'query', query, 'total', n, ...
                        'shown', numel(shown), 'paths', {shown}));
    catch ME
        sl_fail(ME);
    end
end
