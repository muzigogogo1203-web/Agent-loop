-- One authenticated script; no application tell, password input, or command input.
-- Arguments are only the seven closed identity/path fields, never executable code.
on run argv
    if (count of argv) is not 7 then error "expected seven fixed arguments" number 64
    set helperPath to "/private/tmp/agentloop-admin-final-compile-20260907-20814-ic98bc/admin-capture"
    set helperSHA to "ce85c0c1d709898ef2ff36ce12a9f73d13a440f5d49678dac1ebac64316542f5"
    set fixedArguments to ""
    repeat with i from 1 to 7
        set fixedArguments to fixedArguments & " " & quoted form of (item i of argv)
    end repeat
    set privateDirectory to item 7 of argv
    -- Authentication cancellation/errors propagate to osascript stderr, before ready.
    do shell script "/usr/bin/true" with administrator privileges altering line endings false
    -- Only this ordinary-user shell opens the selector diagnostic file.
    set selectorCommand to quoted form of helperPath & " --select" & fixedArguments & " 2>" & quoted form of (privateDirectory & "/selector.ndjson")
    set ticket to do shell script selectorCommand altering line endings false
    -- Preserve both helper channels on shell errors. Raw spindump channels are
    -- separately role-framed base64 by the helper; the trailing wrapper status is
    -- transport metadata, never the sample outcome. No privileged file writes.
    -- Fixed hash and executable in the same privileged shell. The subshell exec
    -- leaves the outer shell alive to preserve actual helper refusal/exit status.
    set expectedHashLine to helperSHA & "  " & helperPath
    set captureCommand to "( actual=$(/usr/bin/shasum -a 256 " & quoted form of helperPath & ") || exit 65; if [ \"$actual\" != " & quoted form of expectedHashLine & " ]; then /usr/bin/printf '{\"event\":\"refused\",\"reason\":\"helper_pin\"}\\n'; exit 65; fi; exec " & quoted form of helperPath & " --capture" & fixedArguments & " " & quoted form of ticket & " ) 2>&1; result=$?; /usr/bin/printf '\n{\"event\":\"helper_result\",\"exit\":%s}\n' \"$result\""
    return do shell script captureCommand with administrator privileges altering line endings false
end run
