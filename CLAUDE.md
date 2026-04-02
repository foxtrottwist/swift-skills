# CLAUDE.md

## Build / Test

- `bash build.sh` — validates plugin structure (skills, hooks)
- `bash package.sh` — packages skills into distributable .skill files
- `claude --plugin-dir .` — load plugin locally without installing

## Versioning

Bump version in **both** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

## Constraints

- Skills array in `build.sh` is hardcoded — add new skills there
- All hooks use fail-open design (`|| exit 0`)
