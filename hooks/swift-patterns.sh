#!/bin/bash
# swift-patterns.sh — PreToolUse hook (matcher: Edit|Write)
# Blocks deprecated/unwanted patterns in Swift files.
# Consolidated: absorbs block-print-nslog and warn-logger-nonisolated checks.

INPUT=$(cat) || exit 0

# Skip in subagents
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty') || exit 0
[[ -n "$AGENT_ID" ]] && exit 0

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty') || exit 0

[[ "$FILE" != *.swift ]] && exit 0

NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty') || exit 0
[[ -z "$NEW_CONTENT" ]] && exit 0

# Each rule: pattern|message
RULES=(
  '"sparkles"|Do not use "sparkles" SF Symbol — AI cliche.'
  'NSLock|os_unfair_lock|pthread_mutex|Do not use locks in audio code — use Atomic only. Locks cause priority inversion.'
  'DispatchQueue\.|DispatchGroup|Use async/await instead of GCD. DispatchQueue.main.async is unnecessary (MainActor default). Use Task.detached for background work.'
  'ObservableObject|@Published|Use @Observable macro instead of ObservableObject/@Published.'
  '\.cornerRadius\(|Use .clipShape(.rect(cornerRadius:)) instead of deprecated .cornerRadius().'
  'NavigationView|Use NavigationStack instead of deprecated NavigationView.'
  'URL\(string:.*\)!|Force-unwrapped URL — use guard let or add "// safe: literal URL" comment.'
  '\.foregroundColor\(|Use .foregroundStyle() instead of deprecated .foregroundColor().'
  '\bprint\(|NSLog\(|Do not use print() or NSLog() — use os.Logger categories.'
  'private let log = Logger\.|Logger nonisolated check — use "private nonisolated let log = Logger.*" for MainActor-safe access.'
)

VIOLATIONS=()
for rule in "${RULES[@]}"; do
  PATTERN="${rule%|*}"
  MESSAGE="${rule##*|}"
  if echo "$NEW_CONTENT" | grep -qE "$PATTERN"; then
    # Special case: Logger nonisolated — only block if nonisolated is missing
    if [[ "$MESSAGE" == *"nonisolated check"* ]]; then
      if echo "$NEW_CONTENT" | grep -qE 'nonisolated.*let log = Logger\.'; then
        continue
      fi
    fi
    VIOLATIONS+=("- $MESSAGE")
  fi
done

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  COMBINED=$(printf '%s\n' "${VIOLATIONS[@]}")
  COMBINED=$(echo "$COMBINED" | sed 's/"/\\"/g' | tr '\n' ' ')
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$COMBINED"
  }
}
EOF
fi
