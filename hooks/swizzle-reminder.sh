#!/bin/bash
# Post-build/test reminder to use swizzle for log monitoring.

cat /dev/stdin > /dev/null

echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"After builds/tests in Swift/iOS projects, consider using `swizzle stream-logs` to monitor os_log output for errors, warnings, or unexpected behavior. Use `swizzle stream-logs --subsystem <bundle-id>` to filter by app. Check the swizzle skill for more options."}}'
