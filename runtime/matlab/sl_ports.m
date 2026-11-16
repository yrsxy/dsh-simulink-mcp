function sl_ports(block_path)
%SL_PORTS Report a block's port counts and which ports already have a line.
    block_path = sl_str(block_path);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if getSimulinkBlockHandle(block_path) == -1
            error('sl:noSuchBlock', 'block not found: %s', block_path);
        end
        p = get_param(block_path, 'Ports');
        ph = get_param(block_path, 'PortHandles');
        kinds = {'in', 'out', 'enable', 'trigger', 'state', 'lconn', 'rconn'};
        handles = {ph.Inport, ph.Outport, ph.Enable, ph.Trigger, ph.State, ph.LConn, ph.RConn};
        counts = struct();
        conn = struct();
        for k = 1:numel(kinds)
            if k <= numel(p)
                counts.(kinds{k}) = p(k);
            end
            hs = handles{k};
            if isempty(hs)
                flags = [];
            else
                flags = arrayfun(@(h) get_param(h, 'Line') ~= -1, hs);
            end
            conn.([kinds{k} 'Connected']) = flags;
        end
        sl_reply(struct('ok', true, 'block', block_path, 'counts', counts, 'connected', conn));
    catch ME
        sl_fail(ME);
    end
end
