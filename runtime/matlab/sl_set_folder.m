function sl_set_folder(folder)
%SL_SET_FOLDER Change the MATLAB working folder.
    folder = sl_str(folder);
    mcpWarnState = warning('off', 'all'); %#ok<NASGU>
    mcpCleanup = onCleanup(@() warning(mcpWarnState)); %#ok<NASGU>
    try
        if exist(folder, 'dir') ~= 7
            error('sl:noSuchFolder', 'folder does not exist: %s', folder);
        end
        old = pwd;
        cd(folder);
        sl_reply(struct('ok', true, 'previous', old, 'cwd', pwd));
    catch ME
        sl_fail(ME);
    end
end
