function sl_layout(model, direction, spacing)
%SL_LAYOUT Re-position every block into a flow layout ordered by signal
%   direction. Feedback loops are detected (DFS back edges) and ignored for
%   layering, so a control loop lays out left-to-right instead of exploding.
%   direction: "right" (default) or "down". spacing: pixels between columns.
    model = sl_str(model);
    direction = sl_str(direction);
    mcpWarnState = warning('off', 'all'); %#ok<NAGSU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        if isempty(direction)
            direction = 'right';
        end
        if spacing <= 0
            spacing = 60;
        end
        blocks = find_system(model, 'Type', 'Block');
        n = numel(blocks);
        if n == 0
            sl_reply(struct('ok', true, 'model', model, 'moved', 0));
            return;
        end
        index = containers.Map(blocks, num2cell(1:n));

        % --- collect edges ------------------------------------------------
        src = zeros(0, 1);
        dst = zeros(0, 1);
        hs = find_system(model, 'FindAll', 'on', 'type', 'line');
        for k = 1:numel(hs)
            sb = get_param(hs(k), 'SrcBlockHandle');
            if sb == -1
                continue;
            end
            sp = [get_param(sb, 'Parent') '/' get_param(sb, 'Name')];
            if ~isKey(index, sp)
                continue;
            end
            db = get_param(hs(k), 'DstBlockHandle');
            for d = db(:)'
                if d == -1
                    continue;
                end
                dp = [get_param(d, 'Parent') '/' get_param(d, 'Name')];
                if ~isKey(index, dp)
                    continue;
                end
                src(end+1, 1) = index(sp); %#ok<AGROW>
                dst(end+1, 1) = index(dp); %#ok<AGROW>
            end
        end

        % --- DFS to find back edges (feedback) ----------------------------
        adj = cell(1, n);
        for e = 1:numel(src)
            adj{src(e)}(end+1) = dst(e);
        end
        color = zeros(1, n);   % 0 unseen, 1 on stack, 2 done
        isBack = false(numel(src), 1);
        % Start from nodes with in-degree zero, otherwise the DFS root (and
        % therefore which edge gets called "feedback") depends on find_system
        % order -- which put the controller output at the left edge of the
        % diagram on a real model.
        indeg = zeros(1, n);
        for e = 1:numel(src)
            indeg(dst(e)) = indeg(dst(e)) + 1;
        end
        [~, roots] = sort(indeg, 'ascend');
        for u = roots
            if color(u) == 0
                dfs(u);
            end
        end

        % --- layer via relaxation over forward edges only -----------------
        layer = zeros(1, n);
        for iter = 1:(n + 1)
            changed = false;
            for e = 1:numel(src)
                if isBack(e)
                    continue;
                end
                u = src(e);
                v = dst(e);
                if layer(v) < layer(u) + 1
                    layer(v) = layer(u) + 1;
                    changed = true;
                end
            end
            if ~changed
                break;
            end
        end
        % defensive: a missed cycle must never explode the number of columns
        if n > 1 && max(layer) > n - 1
            layer = min(layer, n - 1);
        end
        % any block still isolated (pure cycle with no entry) goes last
        if max(layer) == 0 && n > 1
            layer = 0:(n - 1);
        end

        % --- order blocks within each layer (barycentre, reduces crossings) --
        maxL = max(layer);
        preds = cell(1, n);
        succs = cell(1, n);
        for e = 1:numel(src)
            if isBack(e)
                continue;
            end
            preds{dst(e)}(end+1) = src(e);
            succs{src(e)}(end+1) = dst(e);
        end
        order = cell(1, maxL + 1);
        for L = 0:maxL
            order{L + 1} = find(layer == L);
        end
        rowOf = zeros(1, n);
        for L = 0:maxL
            for k = 1:numel(order{L + 1})
                rowOf(order{L + 1}(k)) = k;
            end
        end
        for sweep = 1:4
            for L = 1:maxL
                idxs = order{L + 1};
                key = zeros(1, numel(idxs));
                for k = 1:numel(idxs)
                    pp = preds{idxs(k)};
                    if isempty(pp)
                        key(k) = rowOf(idxs(k));
                    else
                        key(k) = mean(rowOf(pp));
                    end
                end
                [~, ord] = sort(key);
                order{L + 1} = idxs(ord);
                for k = 1:numel(order{L + 1})
                    rowOf(order{L + 1}(k)) = k;
                end
            end
            for L = (maxL - 1):-1:0
                idxs = order{L + 1};
                key = zeros(1, numel(idxs));
                for k = 1:numel(idxs)
                    ss = succs{idxs(k)};
                    if isempty(ss)
                        key(k) = rowOf(idxs(k));
                    else
                        key(k) = mean(rowOf(ss));
                    end
                end
                [~, ord] = sort(key);
                order{L + 1} = idxs(ord);
                for k = 1:numel(order{L + 1})
                    rowOf(order{L + 1}(k)) = k;
                end
            end
        end

        % --- place -------------------------------------------------------
        pos = get_param(blocks, 'Position');
        sz = zeros(n, 2);
        for k = 1:n
            v = pos{k};
            w = v(3) - v(1);
            hgt = v(4) - v(2);
            if w <= 0, w = 100; end
            if hgt <= 0, hgt = 40; end
            sz(k, :) = [w, hgt];
        end
        colW = max(sz(:, 1)) + spacing;
        rowH = max(sz(:, 2)) + 40;
        for L = 0:maxL
            idxs = order{L + 1};
            for k = 1:numel(idxs)
                b = idxs(k);
                idx = k - 1;
                if strcmpi(direction, 'down')
                    l = 30 + idx * colW;
                    t = 30 + L * rowH;
                else
                    l = 30 + L * colW;
                    t = 30 + idx * rowH;
                end
                set_param(blocks{b}, 'Position', [l, t, l + sz(b, 1), t + sz(b, 2)]);
            end
        end
        sl_reply(struct('ok', true, 'model', model, 'moved', n, ...
                        'direction', direction, 'layers', max(layer) + 1, ...
                        'feedbackEdges', sum(isBack)));
    catch ME
        sl_fail(ME);
    end

    function dfs(u)
        color(u) = 1;
        for v = adj{u}
            if color(v) == 1
                % u -> v closes a cycle: mark that specific edge as feedback
                e = find(src == u & dst == v);
                isBack(e) = true;
            elseif color(v) == 0
                dfs(v);
            end
        end
        color(u) = 2;
    end
end
