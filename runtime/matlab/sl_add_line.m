function sl_add_line(model, src_block, src_port, dst_block, dst_port)
%SL_ADD_LINE Wire one output port to one input port.
%   Use sl_ports() first when a block has several ports.
    model = sl_str(model);
    src_block = sl_str(src_block);
    dst_block = sl_str(dst_block);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        % add_line() takes block paths RELATIVE to the model: "Gain/1",
        % not "mymodel/Gain/1". Strip a model prefix if the caller used one.
        prefix = [model '/'];
        if strncmp(src_block, prefix, numel(prefix))
            src_block = src_block(numel(prefix) + 1:end);
        end
        if strncmp(dst_block, prefix, numel(prefix))
            dst_block = dst_block(numel(prefix) + 1:end);
        end
        src_port = round(src_port);
        dst_port = round(dst_port);
        if src_port < 1 || dst_port < 1
            error('sl:badPort', 'port numbers are 1-based');
        end
        h = add_line(model, sprintf('%s/%d', src_block, src_port), ...
                            sprintf('%s/%d', dst_block, dst_port), ...
                            'autorouting', 'on');
        sl_reply(struct('ok', true, 'from', sprintf('%s/%d', src_block, src_port), ...
                        'to', sprintf('%s/%d', dst_block, dst_port), 'handle', h));
    catch ME
        sl_fail(ME);
    end
end
