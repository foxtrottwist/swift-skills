#!/bin/bash
# swift-skill-nudge.sh — UserPromptSubmit hook
# When a prompt references Swift/iOS work, remind Claude to check relevant skills.

INPUT=$(cat) || exit 0

# Skip in subagents
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty') || exit 0
[[ -n "$AGENT_ID" ]] && exit 0

PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty') || exit 0

[[ -z "$PROMPT" ]] && exit 0

# Match Swift/iOS signals in the prompt
if echo "$PROMPT" | grep -qiE '\.swift|swiftui|swiftdata|@model|@observable|foundation model|xcode|ios|ipados|@mainactor|concurrency|async.await'; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Swift/iOS work detected. Check available skills before starting: swiftui-pro (SwiftUI review), swift-concurrency-pro (concurrency), swift-testing-pro (tests), swiftdata-pro (SwiftData), swiftui-performance-audit (performance), foundation-models-ref (on-device AI). Invoke the relevant skill — don't rely on general knowledge for domain-specific patterns."
  }
}
EOF
fi
