-- One authenticated script; no application tell, password input, or command input.
-- Arguments are the reviewed helper path and its seven closed identity/path fields.
on run argv
    if (count of argv) is not 8 then error "expected helper and seven fixed arguments" number 64
    set helperPath to item 1 of argv
    set fixedArguments to ""
    repeat with i from 2 to 8
        set fixedArguments to fixedArguments & " " & quoted form of (item i of argv)
    end repeat
    set privateDirectory to item 8 of argv
    -- Authentication cancellation/errors propagate to osascript stderr, before ready.
    do shell script "/usr/bin/true" with administrator privileges altering line endings false
    -- Only this ordinary-user shell opens the selector diagnostic file.
    set selectorCommand to quoted form of helperPath & " --select" & fixedArguments & " 2>" & quoted form of (privateDirectory & "/selector.ndjson")
    set ticket to do shell script selectorCommand altering line endings false
    -- Preserve both helper channels on shell errors. Raw spindump channels are
    -- separately role-framed base64 by the helper; the trailing wrapper status is
    -- transport metadata, never the sample outcome. No privileged file writes.
    set captureCommand to quoted form of helperPath & " --capture" & fixedArguments & " " & quoted form of ticket & " 2>&1; result=$?; /usr/bin/printf '\n{\"event\":\"helper_result\",\"exit\":%s}\n' \"$result\""
    return do shell script captureCommand with administrator privileges altering line endings false
end run
