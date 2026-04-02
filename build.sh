#!/usr/bin/env bash
# Validates plugin structure. Run package.sh to build distributable .skill files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS=(foundation-models axiom-swiftdata axiom-swiftui-26-ref axiom-accessibility-diag swizzle swift-structured-logging)
AGENTS=()

echo "==> Validating swift-skills plugin"

errors=0

# plugin.json
if [ ! -f "$SCRIPT_DIR/.claude-plugin/plugin.json" ]; then
  echo "  FAIL: .claude-plugin/plugin.json missing"
  errors=$((errors + 1))
else
  echo "  OK: .claude-plugin/plugin.json"
fi

# .mcp.json
if [ ! -f "$SCRIPT_DIR/.mcp.json" ]; then
  echo "  FAIL: .mcp.json missing"
  errors=$((errors + 1))
else
  echo "  OK: .mcp.json"
fi

# Skills
for skill in "${SKILLS[@]}"; do
  if [ -f "$SCRIPT_DIR/skills/$skill/SKILL.md" ]; then
    echo "  OK: skills/$skill"
  else
    echo "  FAIL: skills/$skill/SKILL.md missing"
    errors=$((errors + 1))
  fi
done

# Hooks
if [ ! -f "$SCRIPT_DIR/hooks/hooks.json" ]; then
  echo "  FAIL: hooks/hooks.json missing"
  errors=$((errors + 1))
else
  echo "  OK: hooks/hooks.json"
fi

HOOK_SCRIPTS=(swift-patterns.sh swift-skill-nudge.sh swizzle-reminder.sh)
for hook in "${HOOK_SCRIPTS[@]}"; do
  if [ -f "$SCRIPT_DIR/hooks/$hook" ] && [ -x "$SCRIPT_DIR/hooks/$hook" ]; then
    echo "  OK: hooks/$hook"
  else
    echo "  FAIL: hooks/$hook missing or not executable"
    errors=$((errors + 1))
  fi
done

echo ""
if [ "$errors" -gt 0 ]; then
  echo "==> Validation failed with $errors error(s)"
  exit 1
fi

echo "==> Validation passed"
