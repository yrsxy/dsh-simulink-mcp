function sl_list_models(pattern)
%SL_LIST_MODELS List loaded block diagrams, separating user models from libraries.
%   pattern: "" for all, otherwise a regexp on the name.
    pattern = sl_str(pattern);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        all = find_system('type', 'block_diagram');
        isLib = false(1, numel(all));
        for k = 1:numel(all)
            isLib(k) = strcmp(get_param(all{k}, 'BlockDiagramType'), 'library');
        end
        if ~isempty(pattern)
            keep = ~cellfun(@isempty, regexp(all, pattern, 'once'));
            all = all(keep);
            isLib = isLib(keep);
        end
        models = all(~isLib);
        libs = all(isLib);
        % NOTE: cell values must be wrapped in {} or struct() spreads them
        % into a struct array instead of storing the list in one field.
        sl_reply(struct('ok', true, 'count', numel(models), ...
                        'models', {models}, 'libraries', {libs}));
    catch ME
        sl_fail(ME);
    end
end
