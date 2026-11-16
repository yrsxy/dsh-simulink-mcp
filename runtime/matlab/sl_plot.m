function sl_plot(signal, out_path)
%SL_PLOT Plot a simulated signal to a PNG (scope-style figure).
%   signal: field of simOut ("yout", "tout", or a logged signal name).
%   out_path "" writes to the temp folder.
    signal = sl_str(signal);
    out_path = sl_str(out_path);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if evalin('base', 'exist(''simOut'',''var'')') == 0
            error('sl:noSimOut', 'no simOut in the base workspace; run sl_sim first');
        end
        if isempty(regexp(signal, '^[A-Za-z][A-Za-z0-9_]*(\{\d+\}|\(\d+\))?$', 'once'))
            error('sl:badSignal', ...
                  'signal must be an identifier with an optional index, e.g. "yout{2}": %s', signal);
        end
        data = evalin('base', ['simOut.' signal]);
        if isa(data, 'Simulink.SimulationData.Signal')
            data = data.Values;
        end
        if isempty(out_path)
            out_path = fullfile(tempdir, ['sim_' signal '.png']);
        end
        f = figure('Visible', 'off');
        try
            hold on;
            grid on;
            if isa(data, 'timeseries')
                plot(data.Time, data.Data, 'LineWidth', 1.5);
            elseif isa(data, 'Simulink.SimulationData.Dataset')
                for k = 1:data.numElements
                    el = data.getElement(k);
                    v = el.Values;
                    if isa(v, 'timeseries')
                        plot(v.Time, v.Data, 'LineWidth', 1.5, 'DisplayName', el.Name);
                    end
                end
            elseif isnumeric(data)
                % Numeric data has no time vector of its own; using the
                % sample index as the x axis would label points as seconds.
                tt = sl_plotTime(numel(data(:, 1)));
                if isempty(tt)
                    plot(data, 'LineWidth', 1.5);
                    xlabel('sample');
                else
                    plot(tt, double(data), 'LineWidth', 1.5);
                    xlabel('time (s)');
                end
            else
                error('sl:badSignal', 'signal is not numeric/timeseries/Dataset');
            end
            ylabel(signal);
            title(signal);
            print(f, '-dpng', '-r150', out_path);
        catch ME2
            close(f);
            rethrow(ME2);
        end
        close(f);
        d = dir(out_path);
        sl_reply(struct('ok', true, 'signal', signal, 'path', out_path, 'bytes', d.bytes));
    catch ME
        sl_fail(ME);
    end
end

function t = sl_plotTime(n)
%SL_PLOTTIME Time vector of the last simulation, when it matches n samples.
    t = [];
    try
        if evalin('base', 'exist(''simOut'',''var'')') ~= 1
            return
        end
        candidate = double(evalin('base', 'simOut.tout'));
        candidate = candidate(:);
        if numel(candidate) == n
            t = candidate;
        end
    catch
        t = [];
    end
end
