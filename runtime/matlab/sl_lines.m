function sl_lines(model, depth)
%SL_LINES List every connection as src block/port -> dst block/port.
    model = sl_str(model);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        if depth < 0
            hs = find_system(model, 'FindAll', 'on', 'type', 'line');
        else
            hs = find_system(model, 'SearchDepth', depth, 'FindAll', 'on', 'type', 'line');
        end
        rows = {};
        for k = 1:numel(hs)
            h = hs(k);
            sb = get_param(h, 'SrcBlockHandle');
            db = get_param(h, 'DstBlockHandle');
            sp = get_param(h, 'SrcPortHandle');
            dph = get_param(h, 'DstPortHandle');
            src = '';
            dst = '';
            spnum = 0;
            dpnum = 0;
            if sb ~= -1
                src = sl_block_fullname(sb);
                spnum = sl_port_index(sb, sp, 'out');
            end
            if ~isempty(db) && db(1) ~= -1
                db = db(1);
                dph = dph(1);
                dst = sl_block_fullname(db);
                dpnum = sl_port_index(db, dph, 'in');
            end
            rows{end+1} = struct('src', src, 'srcPort', spnum, ...
                                 'dst', dst, 'dstPort', dpnum); %#ok<AGROW>
        end
        % a branched net is reported as several line segments; collapse them
        % into one logical edge per src/port -> dst/port pair
        if ~isempty(rows)
            keys = cellfun(@(r) sprintf('%s#%d->%s#%d', r.src, r.srcPort, r.dst, r.dstPort), ...
                           rows, 'UniformOutput', false);
            [~, uniq] = unique(keys, 'first');
            rows = rows(sort(uniq));
        end
        sl_reply(struct('ok', true, 'model', model, 'count', numel(rows), 'lines', {rows}));
    catch ME
        sl_fail(ME);
    end
end

function full = sl_block_fullname(handle)
    parent = get_param(handle, 'Parent');
    name = get_param(handle, 'Name');
    full = [parent '/' name];
end

function n = sl_port_index(block_handle, port_handle, kind)
    n = 0;
    if port_handle == -1
        return;
    end
    ph = get_param(block_handle, 'PortHandles');
    if strcmp(kind, 'out')
        hs = ph.Outport;
    else
        hs = ph.Inport;
    end
    n = find(hs == port_handle, 1);
    if isempty(n)
        n = 0;
    end
end
