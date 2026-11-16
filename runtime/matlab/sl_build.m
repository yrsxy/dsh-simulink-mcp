function sl_build(model, spec, layout)
%SL_BUILD Build or extend a model from a JSON spec.
%   model:  model name; created if it is not loaded and not on disk.
%   spec:   path to a .json file, or the JSON text itself. Shape:
%           {"params":{"StopTime":"120"},
%            "blocks":[{"name":"ref","lib":"simulink/Sources/Step",
%                       "params":{"Time":"0"},"pos":[30,40,70,80]}],
%            "lines":[{"from":"ref/1","to":"err/1"}]}
%           "lib" may be replaced by "type" (Step, Gain, Sum, Integrator,
%           TransferFcn, PID, Saturate, Scope, Outport, ...).
%   layout: "true" re-lays out the diagram afterwards; "" or "false" keeps
%           the positions from the spec (or a simple row for missing ones).
    model = sl_str(model);
    spec = sl_str(spec);
    layout = sl_str(layout);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if isempty(model)
            error('sl:noModel', 'model must be given');
        end
        if isempty(spec)
            error('sl:noSpec', 'spec must be a JSON path or JSON text');
        end
        if isfile(spec)
            text = fileread(spec);
        else
            text = spec;
        end
        try
            s = jsondecode(text);
        catch ME
            error('sl:badSpec', 'spec is not valid JSON: %s', ME.message);
        end

        created = false;
        if ~bdIsLoaded(model)
            if isfile([model '.slx'])
                load_system(model);
            else
                new_system(model);
                created = true;
            end
        end

        if isfield(s, 'params') && isstruct(s.params)
            f = fieldnames(s.params);
            for k = 1:numel(f)
                set_param(model, f{k}, val2str(s.params.(f{k})));
            end
        end

        added = {};
        existing = {};
        failed = {};
        if isfield(s, 'blocks') && ~isempty(s.blocks)
            bs = s.blocks;
            for k = 1:numel(bs)
                % jsondecode returns a struct array only when every element
                % has the same fields; a mixed list comes back as a cell.
                if iscell(bs)
                    b = bs{k};
                else
                    b = bs(k);
                end
                try
                    if ~isfield(b, 'name') || isempty(b.name)
                        error('sl:badBlock', 'block %d has no name', k);
                    end
                    dest = [model '/' b.name];
                    if ~isfield(b, 'pos') || isempty(b.pos)
                        pos = [40 + 150 * (k - 1), 60, 100 + 150 * (k - 1), 100];
                    else
                        pos = b.pos;
                    end
                    if exist_block(dest)
                        set_block_params(dest, b);
                        existing{end+1} = dest; %#ok<AGROW>
                        continue;
                    end
                    lib = '';
                    if isfield(b, 'lib')
                        lib = sl_str(b.lib);
                    end
                    if isempty(lib) && isfield(b, 'type')
                        lib = libFor(sl_str(b.type));
                    end
                    if isempty(lib)
                        error('sl:badBlock', 'block %s needs "lib" or a known "type"', b.name);
                    end
                    add_block(lib, dest);
                    set_param(dest, 'Position', pos);
                    set_block_params(dest, b);
                    added{end+1} = dest; %#ok<AGROW>
                catch ME
                    failed{end+1} = struct('block', char(string(getfield_safe(b, 'name'))), ...
                                           'error', ME.message); %#ok<AGROW>
                end
            end
        end

        linesAdded = {};
        linesExisting = {};
        linesFailed = {};
        if isfield(s, 'lines') && ~isempty(s.lines)
            ls = s.lines;
            for k = 1:numel(ls)
                if iscell(ls)
                    one = ls{k};
                else
                    one = ls(k);
                end
                try
                    add_line(model, sl_str(one.from), sl_str(one.to), 'autorouting', 'on');
                    linesAdded{end+1} = [sl_str(one.from) ' -> ' sl_str(one.to)]; %#ok<AGROW>
                catch ME
                    if lineExists(model, sl_str(one.to))
                        linesExisting{end+1} = [sl_str(one.from) ' -> ' sl_str(one.to)]; %#ok<AGROW>
                        continue;
                    end
                    linesFailed{end+1} = struct( ...
                        'line', [sl_str(one.from) ' -> ' sl_str(one.to)], ...
                        'error', ME.message); %#ok<AGROW>
                end
            end
        end

        if any(strcmpi(layout, {'1', 'true', 'yes', 'on'}))
            try
                evalc('sl_layout(model, ''right'', 60);');
            catch
                % Layout is cosmetic: never fail a build over it.
            end
        end

        blk = find_system(model, 'SearchDepth', 1, 'Type', 'Block');
        sl_reply(struct('ok', true, 'model', model, 'created', created, ...
                        'added', {added}, 'existing', {existing}, ...
                        'failed', {failed}, 'linesAdded', {linesAdded}, ...
                        'linesExisting', {linesExisting}, ...
                        'linesFailed', {linesFailed}, 'blockCount', numel(blk)));
    catch ME
        sl_fail(ME);
    end
end

function tf = lineExists(model, to)
%LINEEXISTS True when the destination port already carries a connection,
%   so a rerun of the same spec is not reported as a failure.
    tf = false;
    try
        parts = strsplit(to, '/');
        pn = str2double(parts{end});
        blk = strjoin(parts(1:end-1), '/');
        ph = get_param([model '/' blk], 'PortHandles');
        if pn >= 1 && pn <= numel(ph.Inport)
            tf = get_param(ph.Inport(pn), 'Line') ~= -1;
        end
    catch
    end
end

function tf = exist_block(dest)
    tf = false;
    try
        get_param(dest, 'Handle');
        tf = true;
    catch
    end
end

function set_block_params(dest, b)
    if isfield(b, 'params') && isstruct(b.params)
        f = fieldnames(b.params);
        for j = 1:numel(f)
            set_param(dest, f{j}, val2str(b.params.(f{j})));
        end
    end
end

function v = getfield_safe(s, f)
    if isstruct(s) && isfield(s, f)
        v = s.(f);
    else
        v = '';
    end
end

function s = val2str(v)
    if ischar(v)
        s = v;
    elseif isstring(v)
        s = char(v);
    elseif islogical(v)
        if v
            s = 'on';
        else
            s = 'off';
        end
    elseif isnumeric(v)
        if isscalar(v)
            s = num2str(v, 16);
        else
            s = mat2str(v);
        end
    else
        s = char(string(v));
    end
end

function lib = libFor(type)
%LIBFOR Map a plain block type to its library path, so a spec can stay short.
    % keep digits: Out1 / In1 are real block names, and stripping them
    % made every Out1 spec fail with 'needs a known type'.
    key = lower(regexprep(type, '[^A-Za-z0-9]', ''));
    names = {'step', 'simulink/Sources/Step'; ...
             'constant', 'simulink/Sources/Constant'; ...
             'sine', 'simulink/Sources/Sine Wave'; ...
             'clock', 'simulink/Sources/Clock'; ...
             'ramp', 'simulink/Sources/Ramp'; ...
             'inport', 'simulink/Sources/In1'; ...
             'gain', 'simulink/Math Operations/Gain'; ...
             'sum', 'simulink/Math Operations/Sum'; ...
             'product', 'simulink/Math Operations/Product'; ...
             'integrator', 'simulink/Continuous/Integrator'; ...
             'derivative', 'simulink/Continuous/Derivative'; ...
             'transferfcn', 'simulink/Continuous/Transfer Fcn'; ...
             'pid', 'simulink/Continuous/PID Controller'; ...
             'pidcontroller', 'simulink/Continuous/PID Controller'; ...
             'transferfunction', 'simulink/Continuous/Transfer Fcn'; ...
             'transferf', 'simulink/Continuous/Transfer Fcn'; ...
             'saturate', 'simulink/Discontinuities/Saturation'; ...
             'saturation', 'simulink/Discontinuities/Saturation'; ...
             'scope', 'simulink/Sinks/Scope'; ...
             'display', 'simulink/Sinks/Display'; ...
             'terminator', 'simulink/Sinks/Terminator'; ...
             'outport', 'simulink/Sinks/Out1'; ...
             'out1', 'simulink/Sinks/Out1'; ...
             'in1', 'simulink/Sources/In1'; ...
             'tf', 'simulink/Continuous/Transfer Fcn'; ...
             'sat', 'simulink/Discontinuities/Saturation'; ...
             'sinewave', 'simulink/Sources/Sine Wave'; ...
             'ground', 'simulink/Sinks/Ground'; ...
             'toworkspace', 'simulink/Sinks/To Workspace'; ...
             'stop', 'simulink/Sinks/Stop Simulation'; ...
             'unitdelay', 'simulink/Discrete/Unit Delay'; ...
             'memory', 'simulink/Discrete/Memory'; ...
             'relational', 'simulink/Logic and Bit Operations/Relational Operator'; ...
             'switch', 'simulink/Signal Routing/Switch'; ...
             'lookuptable', 'simulink/Lookup Tables/1-D Lookup Table'; ...
             'mux', 'simulink/Signal Routing/Mux'; ...
             'demux', 'simulink/Signal Routing/Demux'; ...
             'subsystem', 'simulink/Ports & Subsystems/Subsystem'};
    lib = '';
    for k = 1:size(names, 1)
        if strcmp(names{k, 1}, key)
            lib = names{k, 2};
            return;
        end
    end
    % Last resort: ask the Simulink library for a block with that exact name,
    % so a spec may spell a type the way the block browser shows it.
    hits = find_system('simulink', 'SearchDepth', 3, 'LookUnderMasks', 'all', ...
                       'FollowLinks', 'on', 'Name', type);
    if ~isempty(hits)
        lib = hits{1};
    end
end
