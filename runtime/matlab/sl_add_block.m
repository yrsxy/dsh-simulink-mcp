function sl_add_block(source, destination, position)
%SL_ADD_BLOCK Add a library block to a model.
%   source:      library path, e.g. "simulink/Math Operations/Gain"
%                (find one with sl_lib_search instead of guessing)
%   destination: full path in the model, e.g. "mymodel/Gain1"
%   position:    "l t r b" in pixels, or "" to auto-place at the right edge.
    source = sl_str(source);
    destination = sl_str(destination);
    position = sl_str(position);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        model = strtok(destination, '/');
        if isempty(model)
            error('sl:badDestination', 'destination must be "<model>/<block>"');
        end
        if isempty(position)
            blocks = find_system(model, 'SearchDepth', 1, 'Type', 'Block');
            if isempty(blocks)
                pos = [30 100 130 140];
            else
                ps = get_param(blocks, 'Position');
                rights = cellfun(@(v) v(3), ps);
                tops = cellfun(@(v) v(2), ps);
                pos = [max(rights) + 60, tops(end), max(rights) + 160, tops(end) + 40];
            end
        else
            % accept both "10 20 110 60" and the MATLAB-ish "[10 20 110 60]"
            position = strrep(strrep(strrep(position, '[', ''), ']', ''), ',', ' ');
            pos = sscanf(position, '%d %d %d %d')';
            if numel(pos) ~= 4
                error('sl:badPosition', 'position must be "l t r b", got: %s', position);
            end
        end
        add_block(source, destination);
        set_param(destination, 'Position', pos);
        sl_reply(struct('ok', true, 'block', destination, 'source', source, ...
                        'position', pos));
    catch ME
        sl_fail(ME);
    end
end
