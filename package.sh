#!/usr/bin/env bash
# Packages all skills into distributable .skill files under dist/.
# Run build.sh first to validate structure before packaging.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$SCRIPT_DIR/dist"

echo "==> Packaging swift-skills"
mkdir -p "$DIST"

errors=0

for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  skill=$(basename "$skill_dir")
  if [ ! -f "$skill_dir/SKILL.md" ]; then
    echo "  SKIP: $skill (no SKILL.md)"
    continue
  fi
  if python3 -m scripts.package_skill "skills/$skill" "$DIST" 2>&1 | sed 's/^/  /'; then
    : # success message printed by package_skill.py
  else
    echo "  FAIL: $skill"
    errors=$((errors + 1))
  fi
done

echo ""
if [ "$errors" -gt 0 ]; then
  echo "==> Packaging failed with $errors error(s)"
  exit 1
fi

echo "==> Packaged $(ls "$DIST"/*.skill 2>/dev/null | wc -l | tr -d ' ') skills to dist/"
