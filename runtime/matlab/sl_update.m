function sl_update(model)
%SL_UPDATE Compile the model (Update Diagram). This is the cheapest way to
%   surface wiring/port/data-type/solver errors without running a simulation.
%   A failure reports the blocks named in the diagnostic plus a hint.
    model = sl_str(model);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if ~bdIsLoaded(model)
            error('sl:notLoaded', 'model is not loaded: %s', model);
        end
        set_param(model, 'SimulationCommand', 'update');
        sl_reply(struct('ok', true, 'model', model, 'compiled', true));
    catch ME
        message = sl_plainText(ME.message);
        blocks = sl_blocksInMessage(model, message);
        sl_reply(struct('ok', false, 'model', model, 'compiled', false, ...
                        'error', message, 'identifier', ME.identifier, ...
                        'blocks', {blocks}, 'hint', sl_errorHint(message, blocks)));
    end
end

function text = sl_plainText(message)
%SL_PLAINTEXT Remove the hyperlink markup Simulink puts around block names.
%   A diagnostic reads 'parameter 'Gain' of '<a href="...">model/K</a> is
%   invalid', so the path only survives if the anchor tags go first. Keeping
%   the markup also broke every keyword test, because the Chinese and English
%   wording sat inside <a href="matlab:..."> wrappers.
    text = regexprep(message, '<[^>]*>', '');
    text = strrep(text, '&quot;', '"');
end

function blocks = sl_blocksInMessage(model, message)
%SL_BLOCKSINMESSAGE Pull the block paths a Simulink diagnostic refers to.
    blocks = {};
    tokens = regexp(message, '''([^'']+)''', 'tokens');
    for k = 1:numel(tokens)
        path = tokens{k}{1};
        if isempty(strfind(path, '/')) && ~strcmp(path, model)
            continue
        end
        if getSimulinkBlockHandle(path) > 0 && ~any(strcmp(blocks, path))
            blocks{end+1} = path; %#ok<AGROW>
        end
    end
end

function hint = sl_errorHint(message, blocks)
%SL_ERRORHINT Turn the usual Simulink diagnostic wording into a next step.
%   Both wordings are matched: a Chinese MATLAB sends Chinese diagnostics, and
%   the English tests below never fire there.
    hint = '';
    lowered = lower(message);
    if any(strfind(lowered, 'unconnected')) || any(strfind(message, '未连接'))
        hint = 'a port has no line: call sl_ports on the block and sl_lines on the model';
    elseif any(strfind(lowered, 'dimension')) || any(strfind(lowered, 'size mismatch')) ...
            || any(strfind(message, '维度')) || any(strfind(message, '宽度'))
        hint = 'signal widths disagree: check each input port with sl_ports, then sl_block_params';
    elseif any(strfind(lowered, 'algebraic loop')) || any(strfind(message, '代数环'))
        hint = 'the feedback path has no state: insert an Integrator or Unit Delay';
    elseif any(strfind(lowered, 'undefined')) || any(strfind(lowered, 'not defined')) ...
            || any(strfind(message, '未定义'))
        hint = 'a workspace variable is missing: define it with evaluate_matlab_code before the model uses it';
    elseif any(strfind(lowered, 'sample time')) || any(strfind(message, '采样时间'))
        hint = 'sample times are inconsistent: set a common rate on the source blocks';
    elseif any(strfind(lowered, 'invalid setting')) || any(strfind(message, '设置无效')) ...
            || any(strfind(lowered, 'invalid parameter'))
        hint = 'a block parameter is out of range or unreadable: read it back with sl_block_params';
    elseif any(strfind(lowered, 'cannot propagate')) || any(strfind(message, '无法传播'))
        hint = 'a signal type cannot reach the destination port: check the block''s data type with sl_block_params';
    elseif ~isempty(blocks)
        hint = 'read the named block with sl_block_params, then sl_update again';
    end
end
