function sl_env(detail)
%SL_ENV Report the MATLAB/Simulink environment this session is attached to.
%   detail: "" for a summary, "full" to also list every toolbox.
    detail = sl_str(detail);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        v = ver;
        names = {v.Name};
        info = struct();
        info.ok = true;
        info.pid = feature('getpid');
        info.matlabVersion = version;
        info.cwd = pwd;
        info.desktop = usejava('desktop');
        info.toolboxCount = numel(v);
        info.simulink = any(strcmp(names, 'Simulink'));
        info.stateflow = any(strcmp(names, 'Stateflow'));
        info.simulinkTest = any(strcmp(names, 'Simulink Test'));
        info.simulinkCoder = any(strcmp(names, 'Simulink Coder'));
        info.matlabRoot = matlabroot;
        try
            diagrams = find_system('SearchDepth', 0, 'type', 'block_diagram');
            if ~isempty(diagrams)
                info.saveFormat = char(get_param(diagrams{1}, 'SaveFormat'));
            end
        catch
        end
        try
            trace = fullfile(fileparts(which('sl_env')), '.matlab-search.json');
            if isfile(trace)
                found = jsondecode(fileread(trace));
                info.launcher = struct('found', char(string(found.found)), ...
                                       'searched', numel(found.searched));
            end
        catch
        end
        if strcmpi(detail, 'full')
            info.toolboxes = names;
        end
        sl_reply(info);
    catch ME
        sl_fail(ME);
    end
end
