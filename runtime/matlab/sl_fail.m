function sl_fail(ME)
%SL_FAIL Report an expected failure as structured JSON (not an MCP error),
%   so the agent can read it and correct itself. The failure is also kept in
%   root appdata, because MException.last only works at the command prompt.
    record = struct('message', ME.message, 'identifier', ME.identifier, ...
                    'stack', {{}}, 'when', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    try
        if ~isempty(ME.stack)
            record.stack = {ME.stack.name};
        end
        setappdata(0, 'dshLastError', record);
    catch
        % Recording must never mask the original failure.
    end
    payload = struct('ok', false, 'error', ME.message);
    if ~isempty(ME.identifier)
        payload.identifier = ME.identifier;
    end
    sl_reply(payload);
end
