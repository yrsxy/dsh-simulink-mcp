function sl_metrics(variable, reference, band_percent)
%SL_METRICS Characterise the last simulated signal: steady state, overshoot,
%   rise time, settling time and steady-state error. Picks the first output
%   when variable is "".
    variable = sl_str(variable);
    reference = sl_str(reference);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if band_percent <= 0
            band_percent = 2;
        end
        [t, y, name] = sl_series(variable);
        n = numel(t);
        if n < 3
            error('sl:noData', 'not enough samples to characterise the signal (%d)', n);
        end

        payload = struct('ok', true, 'variable', variable, 'signal', name, ...
                         'samples', n, 'tStart', t(1), 'tEnd', t(end));
        dt = diff(t);
        payload.dtMedian = median(dt);
        payload.dtMin = min(dt);
        payload.dtMax = max(dt);

        head = max(1, round(0.01 * n));
        tail = max(1, n - round(0.05 * n) + 1);
        y0 = mean(y(1:head));
        yf = mean(y(tail:end));
        payload.yInitial = y0;
        payload.yFinal = yf;
        payload.yMin = min(y);
        payload.yMax = max(y);

        span = abs(yf - y0);
        if span > 0
            up = yf > y0;
            if up
                [peak, idx] = max(y);
                lo = y0 + 0.10 * span;
                hi = y0 + 0.90 * span;
            else
                [peak, idx] = min(y);
                lo = y0 - 0.10 * span;
                hi = y0 - 0.90 * span;
            end
            payload.peak = peak;
            payload.peakTime = t(idx);
            if up
                payload.overshootPercent = max(0, (peak - yf) / span * 100);
            else
                payload.overshootPercent = max(0, (yf - peak) / span * 100);
            end

            if up
                i10 = find(y >= lo, 1, 'first');
                i90 = find(y >= hi, 1, 'first');
            else
                i10 = find(y <= lo, 1, 'first');
                i90 = find(y <= hi, 1, 'first');
            end
            if ~isempty(i10) && ~isempty(i90) && i90 > i10
                payload.riseTime = t(i90) - t(i10);
            end

            band = band_percent / 100 * span;
            outside = find(abs(y - yf) > band, 1, 'last');
            if isempty(outside)
                payload.settlingTime = 0;
            elseif outside < n
                payload.settlingTime = t(outside + 1);
            else
                payload.settlingTime = NaN;
                payload.settled = false;
            end
            payload.bandPercent = band_percent;
        end

        if ~isempty(reference)
            ref = str2double(reference);
            if ~isnan(ref)
                payload.reference = ref;
                payload.steadyStateError = ref - yf;
                if abs(ref) > 0
                    payload.steadyStateErrorPercent = (ref - yf) / abs(ref) * 100;
                end
            end
        end
        sl_reply(payload);
    catch ME
        sl_fail(ME);
    end
end
