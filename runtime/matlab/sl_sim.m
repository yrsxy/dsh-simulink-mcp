function sl_sim(model, stop_time, solver)
%SL_SIM Run a simulation and summarise the result.
%   stop_time: "" keeps the model value, else e.g. "10".
%   solver:    "" keeps the model value, else e.g. "ode45".
%   The SimulationOutput is kept in the base workspace as `simOut` so
%   sl_sim_data / sl_plot can read it afterwards.
    model = sl_str(model);
    stop_time = sl_str(stop_time);
    solver = sl_str(solver);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        if ~isempty(stop_time)
            set_param(model, 'StopTime', stop_time);
        end
        if ~isempty(solver)
            set_param(model, 'Solver', solver);
        end
        set_param(model, 'SaveOutput', 'on');
        % Dataset output needs the Simulink HMI signal observer, which some
        % Windows application-control policies block. Array output never
        % needs it, and sl_series / sl_plot / sl_metrics read both. Switch
        % before simulating: after one observer failure the whole MATLAB
        % session keeps failing.
        switched = false;
        try
            if any(strcmpi(char(get_param(model, 'SaveFormat')), {'Dataset', 'Timeseries'}))
                set_param(model, 'SaveFormat', 'Array');
                switched = true;
            end
        catch
        end
        try
            simOut = sim(model);
        catch ME
            if ~isempty(strfind(ME.identifier, 'SignalObserverCreateFailure')) || ...
                    ~isempty(strfind(ME.message, 'signal observer'))
                set_param(model, 'SaveFormat', 'Array');
                switched = true;
                simOut = sim(model);
            else
                rethrow(ME);
            end
        end
        assignin('base', 'simOut', simOut);

        info = struct('ok', true, 'model', model, 'simulated', true);
        if switched
            info.saveFormat = 'Array';
            info.saveFormatSwitched = true;
            info.hint = ['The model asked for Dataset output, which needs the Simulink ' ...
                         'signal observer. Array output was used instead, so no data ' ...
                         'was lost. If this was not your choice, a Windows ' ...
                         'application-control policy is probably blocking the observer DLLs.'];
        end
        try
            t = simOut.tout;
            info.samples = numel(t);
            info.tStart = t(1);
            info.tEnd = t(end);
        catch
        end
        try
            y = simOut.yout;
            if isa(y, 'Simulink.SimulationData.Dataset')
                info.outputs = y.numElements;
                names = cell(1, y.numElements);
                for k = 1:y.numElements
                    names{k} = y.getElement(k).Name;
                end
                info.outputNames = names;
            else
                info.outputs = numel(y);
            end
        catch
        end
        try
            ls = simOut.logsout;
            info.loggedSignals = ls.numElements;
            names = cell(1, ls.numElements);
            for k = 1:ls.numElements
                names{k} = ls.getElement(k).Name;
            end
            info.loggedNames = names;
        catch
        end
        try
            info.stopEvent = char(simOut.SimulationMetadata.ExecutionInfo.StopEvent);
        catch
        end
        sl_reply(info);
    catch ME
        sl_reply(struct('ok', false, 'model', model, 'simulated', false, ...
                        'error', ME.message));
    end
end
