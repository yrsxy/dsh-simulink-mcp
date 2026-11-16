function sl_last_error(clear_flag)
%SL_LAST_ERROR Return (and optionally clear) the last failure recorded by a
%   simulink tool. MException.last cannot be used here: MATLAB only allows it
%   at the command prompt, so the tools record into root appdata instead.
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        payload = struct('ok', true, 'hasError', false);
        if isappdata(0, 'dshLastError')
            record = getappdata(0, 'dshLastError');
            payload.hasError = true;
            payload.message = record.message;
            payload.identifier = record.identifier;
            payload.stack = record.stack;
            payload.when = record.when;
            if logical(clear_flag)
                rmappdata(0, 'dshLastError');
                payload.cleared = true;
            end
        end
        sl_reply(payload);
    catch ME2
        sl_fail(ME2);
    end
end
