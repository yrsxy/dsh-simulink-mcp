function sl_trace(model, block, direction, depth)
%SL_TRACE Follow the signal chain into or out of one block, so a large model
%   can be read one path at a time instead of as a full line dump.
%   direction: "upstream" (where the input comes from) or "downstream".
    model = sl_str(model);
    block = sl_str(block);
    direction = lower(sl_str(direction));
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        if isempty(direction) || ~any(strcmp(direction, {'upstream', 'downstream'}))
            direction = 'upstream';
        end
        if depth <= 0
            depth = 3;
        end
        start = block;
        if isempty(strfind(start, '/'))
            start = [model '/' start];
        end
        if getSimulinkBlockHandle(start) <= 0
            error('sl:noSuchBlock', 'block not found: %s', start);
        end

        lines = find_system(model, 'FindAll', 'on', 'type', 'line');
        eSrc = []; eDst = []; eSrcP = []; eDstP = [];
        for k = 1:numel(lines)
            sh = get_param(lines(k), 'SrcBlockHandle');
            dh = get_param(lines(k), 'DstBlockHandle');
            if isempty(sh) || sh < 0
                continue;
            end
            sp = get_param(get_param(lines(k), 'SrcPortHandle'), 'PortNumber');
            try
                dports = get_param(get_param(lines(k), 'DstPortHandle'), 'PortNumber');
                % a branch to several blocks returns a cell of port numbers
                if iscell(dports)
                    dports = cell2mat(dports);
                end
            catch
                dports = numel(dh);
            end
            for j = 1:numel(dh)
                if dh(j) < 0
                    continue;
                end
                eSrc(end+1) = sh;               %#ok<AGROW>
                eDst(end+1) = dh(j);            %#ok<AGROW>
                eSrcP(end+1) = sp;              %#ok<AGROW>
                if numel(dports) >= j
                    eDstP(end+1) = dports(j);   %#ok<AGROW>
                else
                    eDstP(end+1) = 1;           %#ok<AGROW>
                end
            end
        end

        % one connection can be reported by several branch segments: keep it once
        if ~isempty(eSrc)
            rows = unique([eSrc(:) eDst(:) eSrcP(:) eDstP(:)], 'rows');
            eSrc = rows(:, 1)';
            eDst = rows(:, 2)';
            eSrcP = rows(:, 3)';
            eDstP = rows(:, 4)';
        end

        visited = {start};
        frontier = {start};
        edges = struct('from', {}, 'fromPort', {}, 'to', {}, 'toPort', {}, 'depth', {});
        chain = {start};
        for level = 1:depth
            next = {};
            for i = 1:numel(frontier)
                cur = frontier{i};
                curH = getSimulinkBlockHandle(cur);
                if strcmp(direction, 'upstream')
                    idx = find(eDst == curH);
                    partners = eSrc(idx);
                else
                    idx = find(eSrc == curH);
                    partners = eDst(idx);
                end
                for j = 1:numel(idx)
                    partner = getfullname(partners(j));
                    edge = struct('from', getfullname(eSrc(idx(j))), ...
                                  'fromPort', eSrcP(idx(j)), ...
                                  'to', getfullname(eDst(idx(j))), ...
                                  'toPort', eDstP(idx(j)), ...
                                  'depth', level);
                    edges(end+1) = edge; %#ok<AGROW>
                    if ~any(strcmp(visited, partner))
                        visited{end+1} = partner; %#ok<AGROW>
                        next{end+1} = partner;    %#ok<AGROW>
                    end
                end
            end
            if isempty(next)
                break;
            end
            chain{end+1} = strjoin(next, ' | '); %#ok<AGROW>
            frontier = next;
        end

        names = cell(1, numel(visited));
        for k = 1:numel(visited)
            names{k} = get_param(visited{k}, 'BlockType');
        end
        payload = struct('ok', true, 'model', model, 'start', start, ...
                         'direction', direction, 'depth', depth, ...
                         'nodes', {visited}, 'types', {names}, ...
                         'edges', edges, 'chain', {chain});
        sl_reply(payload);
    catch ME
        sl_fail(ME);
    end
end
