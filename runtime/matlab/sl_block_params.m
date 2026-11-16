function sl_block_params(block_path, filter)
%SL_BLOCK_PARAMS Read a block's dialog parameters with current values.
%   filter: "" for all, otherwise a regexp on parameter names. Prefer a
%   filter: some blocks expose hundreds of parameters.
    block_path = sl_str(block_path);
    filter = sl_str(filter);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if getSimulinkBlockHandle(block_path) == -1
            error('sl:noSuchBlock', 'block not found: %s', block_path);
        end
        dp = get_param(block_path, 'DialogParameters');
        names = fieldnames(dp);
        if ~isempty(filter)
            keep = ~cellfun(@isempty, regexpi(names, filter, 'once'));
            names = names(keep);
        end
        params = struct();
        failed = {};
        for k = 1:numel(names)
            try
                v = get_param(block_path, names{k});
                if iscell(v) && numel(v) == 1
                    v = v{1};
                end
                if isempty(v) && ~ischar(v)
                    v = '';
                end
                params.(names{k}) = v;
            catch
                failed{end+1} = names{k}; %#ok<AGROW>
            end
        end
        payload = struct('ok', true, 'block', block_path, ...
                         'count', numel(names), 'params', params);
        if ~isempty(failed)
            payload.unreadable = failed;
        end
        sl_reply(payload);
    catch ME
        sl_fail(ME);
    end
end
