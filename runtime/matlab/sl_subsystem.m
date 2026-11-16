function sl_subsystem(model, blocks, name, mode)
%SL_SUBSYSTEM Group blocks into a subsystem, or expand a subsystem back.
%   model:  loaded model name.
%   blocks: comma-separated block paths, model-relative ("Gain1") or full.
%           For mode "expand" pass exactly one subsystem path.
%   name:   name for the new subsystem; "" keeps the generated one.
%   mode:   "group" (default) or "expand".
%
%   Grouping is the way to keep a diagram readable: the ports Simulink needs
%   are created automatically, and the inner wiring is untouched.
    model = sl_str(model);
    blocks = sl_str(blocks);
    name = sl_str(name);
    mode = sl_str(mode);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        if isempty(mode)
            mode = 'group';
        end
        if isempty(blocks)
            error('sl:noBlocks', 'blocks must name at least one block');
        end
        parts = strtrim(strsplit(blocks, ','));
        parts = parts(~cellfun(@isempty, parts));
        hs = [];
        failed = {};
        for k = 1:numel(parts)
            full = parts{k};
            if isempty(strfind(full, '/'))
                full = [model '/' full];
            end
            try
                hs(end+1) = get_param(full, 'Handle'); %#ok<AGROW>
            catch ME
                failed{end+1} = struct('block', full, 'error', ME.message); %#ok<AGROW>
            end
        end
        if isempty(hs)
            error('sl:noSuchBlock', 'none of the given blocks exist: %s', blocks);
        end

        before = find_system(model, 'SearchDepth', 1, 'Type', 'Block');
        if strcmpi(mode, 'expand')
            if numel(hs) > 1
                error('sl:tooMany', 'expand takes one subsystem, got %d blocks', numel(hs));
            end
            if ~strcmp(get_param(hs(1), 'BlockType'), 'SubSystem')
                error('sl:notSubsystem', 'not a subsystem: %s', getfullname(hs(1)));
            end
            target = getfullname(hs(1));
            inner = find_system(target, 'SearchDepth', 1, 'Type', 'Block');
            Simulink.BlockDiagram.expandSubsystem(hs(1));
            after = find_system(model, 'SearchDepth', 1, 'Type', 'Block');
            produced = setdiff(after, before);
            % expanding leaves an area annotation outlining where the block
            % was; it carries no meaning once the contents are back
            annAfter = find_system(model, 'FindAll', 'on', 'Type', 'annotation');
            parts = strsplit(target, '/');
            shortName = parts{end};
            removed = 0;
            for k = 1:numel(annAfter)
                try
                    if ~strcmp(get_param(annAfter(k), 'AnnotationType'), 'area_annotation')
                        continue;
                    end
                    % match by name so a frame left by an earlier expand goes too
                    if strcmp(strtrim(get_param(annAfter(k), 'Text')), shortName)
                        delete(annAfter(k));
                        removed = removed + 1;
                    end
                catch
                end
            end
            sl_reply(struct('ok', true, 'model', model, 'mode', 'expand', ...
                            'expanded', target, 'produced', numel(produced), ...
                            'blocks', {produced}, 'innerBlocks', numel(inner), ...
                            'annotationsRemoved', removed, 'failed', {failed}));
            return;
        end

        Simulink.BlockDiagram.createSubsystem(hs);
        after = find_system(model, 'SearchDepth', 1, 'Type', 'Block');
        created = setdiff(after, before);
        if isempty(created)
            error('sl:createFailed', 'Simulink did not create a subsystem');
        end
        subsys = created{1};
        if ~isempty(name)
            % rename through the handle: the path string goes stale as soon
            % as the name changes, so it cannot be used for a second lookup
            h = get_param(subsys, 'Handle');
            set_param(h, 'Name', name);
            subsys = getfullname(h);
        end
        ins = find_system(subsys, 'SearchDepth', 1, 'BlockType', 'Inport');
        outs = find_system(subsys, 'SearchDepth', 1, 'BlockType', 'Outport');
        inner = find_system(subsys, 'SearchDepth', 1, 'Type', 'Block');
        sl_reply(struct('ok', true, 'model', model, 'mode', 'group', ...
                        'subsystem', subsys, 'inports', numel(ins), ...
                        'outports', numel(outs), 'innerBlocks', numel(inner), ...
                        'moved', numel(hs), 'position', ...
                        mat2str(get_param(subsys, 'Position')), ...
                        'failed', {failed}));
    catch ME
        sl_fail(ME);
    end
end
