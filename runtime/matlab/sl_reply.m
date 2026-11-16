function sl_reply(payload)
%SL_REPLY Print one JSON line, which is what the MCP server returns as the
%   tool result text. Never abbreviates with disp() so long payloads stay
%   on a single line and remain parseable.
    if ~isfield(payload, 'ok')
        payload.ok = true;
    end
    try
        txt = jsonencode(payload);
    catch
        txt = '{"ok":false,"error":"jsonencode failed"}';
    end
    fprintf('%s\n', txt);
end
