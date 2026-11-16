function sl_delete_line(model, src_block, src_port, dst_block, dst_port)
%SL_DELETE_LINE Remove the connection between two ports.
    model = sl_str(model);
    src_block = sl_str(src_block);
    dst_block = sl_str(dst_block);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        delete_line(model, sprintf('%s/%d', src_block, round(src_port)), ...
                           sprintf('%s/%d', dst_block, round(dst_port)));
        sl_reply(struct('ok', true, 'deleted', sprintf('%s/%d -> %s/%d', ...
            src_block, round(src_port), dst_block, round(dst_port))));
    catch ME
        sl_fail(ME);
    end
end
