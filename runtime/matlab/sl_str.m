function s = sl_str(v)
%SL_STR Normalise an argument to a plain char row.
%   The MCP server delivers JSON strings as MATLAB `string`; isempty("") is
%   FALSE for those, which silently broke every "omitted argument" check.
    if ischar(v)
        s = v;
    elseif isstring(v)
        if isscalar(v)
            s = char(v);
        else
            s = strjoin(cellstr(v), ' ');
        end
    else
        try
            s = char(string(v));
        catch
            s = '';
        end
    end
    s = s(:)';
end
