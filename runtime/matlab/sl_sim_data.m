function sl_sim_data(variable, max_points)
%SL_SIM_DATA Return simulation data as JSON arrays.
%   variable: field of simOut, e.g. "yout" or "tout" or a logged signal name.
%   max_points <= 0 means 500.
    variable = sl_str(variable);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if evalin('base', 'exist(''simOut'',''var'')') == 0
            error('sl:noSimOut', 'no simOut in the base workspace; run sl_sim first');
        end
        % allow an index suffix so a multi-output Dataset can be read
        % element-wise: "yout", "yout{2}" or "yout(2)"
        if isempty(regexp(variable, '^[A-Za-z][A-Za-z0-9_]*(\{\d+\}|\(\d+\))?$', 'once'))
            error('sl:badVariable', ...
                  'variable must be an identifier with an optional index, e.g. "yout{2}": %s', variable);
        end
        if max_points <= 0
            max_points = 500;
        end
        data = evalin('base', ['simOut.' variable]);
        payload = struct('ok', true, 'variable', variable);
        payload.class = class(data);

        % a Dataset element is a Signal wrapper; its time series is .Values
        if isa(data, 'Simulink.SimulationData.Signal')
            payload.signalName = data.Name;
            data = data.Values;
        end

        % yout is normally a Dataset with one element; unwrap it so the
        % caller gets plain arrays instead of a list of names
        elementName = '';
        if isa(data, 'Simulink.SimulationData.Dataset') && data.numElements == 1
            elementName = data.getElement(1).Name;
            data = data.getElement(1).Values;
            payload.element = elementName;
        end

        if isa(data, 'timeseries')
            [t, y] = sl_downsample(data.Time, data.Data, max_points);
            payload.isTimeSeries = true;
            payload.points = numel(t);
            payload.time = t(:)';
            payload.data = y;
        elseif isa(data, 'Simulink.SimulationData.Dataset')
            names = cell(1, data.numElements);
            for k = 1:data.numElements
                names{k} = data.getElement(k).Name;
            end
            payload.elements = names;
            payload.hint = 'pass an element name to read its values';
        elseif isnumeric(data)
            if isvector(data) && numel(data) > max_points
                idx = round(linspace(1, numel(data), max_points));
                data = data(idx);
            end
            payload.size = size(data);
            payload.data = data;
        else
            payload.preview = char(data);
        end
        sl_reply(payload);
    catch ME
        sl_fail(ME);
    end
end

function [t, y] = sl_downsample(t, y, max_points)
    if numel(t) > max_points
        idx = round(linspace(1, numel(t), max_points));
        t = t(idx);
        y = y(idx, :);
    end
end
