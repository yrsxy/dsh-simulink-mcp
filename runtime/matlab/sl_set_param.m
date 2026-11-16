function sl_set_param(target, param, value)
%SL_SET_PARAM Set a parameter on a block or on a model (solver, StopTime...).
%   The previous value is returned so a change can be reverted.
    target = sl_str(target);
    param = sl_str(param);
    value = sl_str(value);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        isModel = false;
        if isempty(strfind(target, '/'))
            isModel = bdIsLoaded(target);
        end
        if isModel
            prev = get_param(target, param);
            set_param(target, param, value);
        elseif getSimulinkBlockHandle(target) ~= -1
            prev = get_param(target, param);
            set_param(target, param, value);
        else
            error('sl:noSuchTarget', 'not a loaded model or block: %s', target);
        end
        now = get_param(target, param);
        sl_reply(struct('ok', true, 'target', target, 'param', param, ...
                        'previous', prev, 'current', now));
    catch ME
        sl_fail(ME);
    end
end
