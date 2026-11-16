function sl_selftest(folder)
%SL_SELFTEST Prove the toolchain works end to end in a throwaway model:
%   engine, library paths, block creation, wiring, compile, simulate, read
%   data, metrics, snapshot, save and error reporting. Leaves nothing behind.
    folder = sl_str(folder);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    model = 'dsh_selftest';
    if isempty(folder)
        folder = fullfile(tempdir, 'dsh-simulink-selftest');
    end
    checks = struct('name', {}, 'ok', {}, 'detail', {});
    started = tic;

    function run(name, fn)
        try
            detail = fn();
            checks(end+1) = struct('name', name, 'ok', true, 'detail', detail); %#ok<AGROW>
        catch ME
            checks(end+1) = struct('name', name, 'ok', false, 'detail', ME.message); %#ok<AGROW>
        end
    end

    try
        if ~exist(folder, 'dir')
            mkdir(folder);
        end
        for stale = {model, 'model'}
            try
                close_system(stale{1}, 0);
            catch
            end
        end
        restore = onCleanup(@() sl_selftestCleanup(model, folder)); %#ok<NASGU>

        run('matlab session', @() sprintf('%s, pid %d', version('-release'), feature('getpid')));
        run('simulink licensed', @() sl_assert(license('test', 'Simulink') == 1, 'Simulink license missing'));
        run('library search', @() sl_libraryCheck());
        run('create model', @() sl_model(model));
        run('add blocks', @() sl_addFour(model));
        run('wire blocks', @() sl_wireFour(model));
        run('set parameter', @() sl_setGain(model));
        run('compile', @() sl_compile(model));
        run('simulate', @() sl_simulate(model));
        run('read data', @() sl_readCheck());
        run('metrics', @() sl_metricCheck());
        run('snapshot', @() sl_snapshotCheck(model, folder));
        run('save', @() sl_saveCheck(model, folder));
        run('error reporting', @() sl_errorCheck(folder));
    catch ME
        checks(end+1) = struct('name', 'harness', 'ok', false, 'detail', ME.message);
    end

    passed = sum([checks.ok]);
    failed = numel(checks) - passed;
    payload = struct('ok', failed == 0, 'passed', passed, 'failed', failed, ...
                     'seconds', toc(started), 'folder', folder, 'checks', checks);
    sl_reply(payload);
end

function sl_selftestCleanup(model, folder)
    for stale = {model, 'model'}
        try
            close_system(stale{1}, 0);
        catch
        end
    end
    try
        rmdir(folder, 's');
    catch
    end
end

function detail = sl_assert(condition, message)
    if ~condition
        error('sl:selftest', '%s', message);
    end
    detail = 'ok';
end

function detail = sl_model(model)
    new_system(model);
    if ~bdIsLoaded(model)
        error('sl:selftest', 'model did not load after new_system');
    end
    try
        % Dataset output needs the Simulink HMI observer, which some Windows
        % application-control policies block; Array output never does.
        set_param(model, 'SaveFormat', 'Array');
    catch
    end
    detail = model;
end

function detail = sl_libraryCheck()
%SL_LIBRARYCHECK Prove a library path is usable without loading every plugin.
%   get_param('simulink/...') forces the whole Simulink library in, and on a
%   machine where application control blocks one library DLL that turns a
%   healthy session into a broken one. Adding a block is what the tools
%   actually do, so test exactly that.
    probe = 'dsh_selftest_lib';
    try
        close_system(probe, 0);
    catch
    end
    new_system(probe);
    cleanup = onCleanup(@() sl_dropProbe(probe)); %#ok<NASGU>
    add_block('simulink/Math Operations/Gain', [probe '/g'], 'Position', [30 30 70 60]);
    handle = getSimulinkBlockHandle([probe '/g']);
    if handle <= 0
        error('sl:selftest', 'Gain from the Simulink library could not be added');
    end
    detail = 'ok';
end

function sl_dropProbe(probe)
    try
        close_system(probe, 0);
    catch
    end
end

function detail = sl_addFour(model)
    add_block('simulink/Sources/Step', [model '/ref'], 'Position', [30 100 70 140]);
    add_block('simulink/Math Operations/Gain', [model '/gain'], 'Position', [130 95 170 145]);
    add_block('simulink/Continuous/Transfer Fcn', [model '/plant'], 'Position', [230 90 290 150]);
    add_block('simulink/Sinks/Out1', [model '/out'], 'Position', [350 105 390 135]);
    names = {[model '/ref'], [model '/gain'], [model '/plant'], [model '/out']};
    for k = 1:numel(names)
        if getSimulinkBlockHandle(names{k}) <= 0
            error('sl:selftest', 'block missing: %s', names{k});
        end
    end
    detail = '4 blocks';
end

function detail = sl_wireFour(model)
    add_line(model, 'ref/1', 'gain/1', 'autorouting', 'on');
    add_line(model, 'gain/1', 'plant/1', 'autorouting', 'on');
    add_line(model, 'plant/1', 'out/1', 'autorouting', 'on');
    detail = '3 lines';
end

function detail = sl_setGain(model)
    set_param([model '/gain'], 'Gain', '2.5');
    value = get_param([model '/gain'], 'Gain');
    if ~strcmp(value, '2.5')
        error('sl:selftest', 'gain reads back as %s', value);
    end
    set_param(model, 'StopTime', '3');
    detail = 'Gain=2.5';
end

function detail = sl_compile(model)
    set_param(model, 'SimulationCommand', 'update');
    detail = 'diagram updated';
end

function detail = sl_simulate(model)
    simOut = sim(model);
    assignin('base', 'simOut', simOut);
    detail = sprintf('%d samples', numel(simOut.tout));
end

function detail = sl_readCheck()
    [t, y] = sl_series('');
    if numel(t) ~= numel(y) || numel(t) < 5
        error('sl:selftest', 'series is inconsistent');
    end
    detail = sprintf('%d points', numel(t));
end

function detail = sl_metricCheck()
    out = evalc('sl_metrics('''', ''0'', 2)');
    payload = jsondecode(strtrim(out));
    if ~payload.ok || ~isfield(payload, 'yFinal')
        error('sl:selftest', 'metrics payload is incomplete');
    end
    detail = sprintf('settles at %.4g', payload.yFinal);
end

function detail = sl_snapshotCheck(model, folder)
    png = fullfile(folder, 'diagram.png');
    print(['-s' model], '-dpng', '-r100', png);
    d = dir(png);
    if isempty(d) || d.bytes < 2000
        error('sl:selftest', 'snapshot is missing or too small');
    end
    detail = sprintf('%d bytes', d.bytes);
end

function detail = sl_saveCheck(model, folder)
    % keep the file name equal to the model name, otherwise save_system
    % renames the loaded model and the next run collides with it
    slx = fullfile(folder, [model '.slx']);
    try
        save_system(model, slx);
        d = dir(slx);
        if isempty(d) || d.bytes < 1000
            error('sl:selftest', 'saved model is missing or too small');
        end
        detail = sprintf('%d bytes (.slx)', d.bytes);
    catch ME
        % Keep the reason visible: on a machine where .slx writing is blocked
        % this is the one check that tells the user why.
        mdl = fullfile(folder, [model '.mdl']);
        save_system(model, mdl);
        d = dir(mdl);
        if isempty(d) || d.bytes < 1000
            rethrow(ME);
        end
        detail = sprintf('%d bytes (.mdl fallback: %s)', d.bytes, ME.message);
    end
end

function detail = sl_errorCheck(folder)
    missing = fullfile(folder, 'does-not-exist.slx');
    out = evalc('sl_open(missing)');
    payload = jsondecode(strtrim(out));
    if payload.ok || ~strcmp(payload.identifier, 'sl:noSuchFile')
        error('sl:selftest', 'a missing file should report sl:noSuchFile');
    end
    detail = 'reports sl:noSuchFile';
end
