function [t, y, name] = sl_series(variable)
%SL_SERIES Extract one time series from `simOut` in the base workspace.
%   variable "" picks the first element of `yout` (or of the first logged
%   signal). Returns time, data and the signal name actually used.
    variable = sl_str(variable);
    if evalin('base', 'exist(''simOut'',''var'')') == 0
        error('sl:noSimOut', 'no simOut in the base workspace; run sl_sim first');
    end
    if isempty(variable)
        variable = 'yout';
    end
    if isempty(regexp(variable, '^[A-Za-z][A-Za-z0-9_]*(\{\d+\}|\(\d+\))?$', 'once'))
        error('sl:badVariable', ...
              'variable must be an identifier with an optional index, e.g. "yout{2}": %s', variable);
    end
    data = evalin('base', ['simOut.' variable]);
    name = variable;

    if isa(data, 'Simulink.SimulationData.Signal')
        name = data.Name;
        data = data.Values;
    end
    if isa(data, 'Simulink.SimulationData.Dataset')
        if data.numElements == 0
            error('sl:noData', ['simOut.%s has no elements; add an Outport block or ', ...
                                'turn on signal logging'], variable);
        end
        element = data.getElement(1);
        name = element.Name;
        data = element.Values;
    end
    if isnumeric(data)
        % SaveFormat="Array" hands back samples only; the time vector is
        % simOut.tout. Without this every metrics/plot call failed on models
        % that use the older (and very common) Array format.
        t = sl_baseTout(variable);
        y = double(data);
        if ~isvector(y)
            y = y(:, 1);
        end
        y = y(:);
        if numel(t) ~= numel(y)
            error('sl:noData', 'time and data lengths differ for %s (%d vs %d)', ...
                  variable, numel(t), numel(y));
        end
        return
    end
    if ~isa(data, 'timeseries')
        error('sl:noData', 'simOut.%s does not hold a time series (class %s)', variable, class(data));
    end

    t = double(data.Time(:));
    y = double(data.Data);
    if ~isvector(y)
        y = y(:, 1);
    end
    y = y(:);
    if numel(t) ~= numel(y)
        error('sl:noData', 'time and data lengths differ for %s', variable);
    end
end

function t = sl_baseTout(variable)
%SL_BASETOUT Time vector of the last simulation, for Array-format output.
    try
        t = double(evalin('base', 'simOut.tout'));
    catch
        error('sl:noData', ['simOut.%s holds raw samples (SaveFormat="Array") and ' ...
                            'simOut.tout is unavailable; rerun sl_sim'], variable);
    end
    t = t(:);
    if isempty(t)
        error('sl:noData', 'simOut.tout is empty; rerun sl_sim');
    end
end
