#!/usr/bin/env bash
# swift-pattern-lint.sh — Scan Swift files for pattern violations
# Usage: swift-pattern-lint.sh <target-dir> <patterns-file> [--output <path>]
# Exit codes: 0 = no errors, 1 = errors found, 2 = invalid args

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <target-dir> <patterns-file> [--output <path>]" >&2
    exit 2
}

# Parse args
TARGET_DIR=""
PATTERNS_FILE=""
OUTPUT_PATH=""

while [ $# -gt 0 ]; do
    case "$1" in
        --output)
            [ $# -lt 2 ] && usage
            OUTPUT_PATH="$2"
            shift 2
            ;;
        -*)
            usage
            ;;
        *)
            if [ -z "$TARGET_DIR" ]; then
                TARGET_DIR="$1"
            elif [ -z "$PATTERNS_FILE" ]; then
                PATTERNS_FILE="$1"
            else
                usage
            fi
            shift
            ;;
    esac
done

[ -z "$TARGET_DIR" ] || [ -z "$PATTERNS_FILE" ] && usage

# Validate inputs
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: target-dir '$TARGET_DIR' does not exist or is not a directory" >&2
    exit 2
fi

if [ ! -f "$PATTERNS_FILE" ]; then
    echo "Error: patterns-file '$PATTERNS_FILE' does not exist" >&2
    exit 2
fi

# Resolve default output path
if [ -z "$OUTPUT_PATH" ]; then
    LINT_DIR="${TARGET_DIR}/.swift-lint.local"
    mkdir -p "$LINT_DIR"
    OUTPUT_PATH="${LINT_DIR}/report.local.json"
else
    OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"
    mkdir -p "$OUTPUT_DIR"
fi

TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Collect all .swift files
SWIFT_FILES=""
FILES_SCANNED=0
while IFS= read -r -d '' f; do
    SWIFT_FILES="${SWIFT_FILES}${f}"$'\n'
    FILES_SCANNED=$((FILES_SCANNED + 1))
done < <(find "$TARGET_DIR" -name "*.swift" -type f -print0 2>/dev/null)

# --- JSON parsing helpers (no jq) ---
# Parse pattern array from JSON file using awk.
# Extracts objects by splitting on "pattern" field occurrences.

# Extract all string values for a given key from the JSON using awk
# Usage: extract_field <key> <file>
extract_field() {
    local key="$1"
    local file="$2"
    awk -v key="\"${key}\"" '
    {
        line = $0
        while (match(line, key "[ \t]*:[ \t]*\"")) {
            line = substr(line, RSTART + RLENGTH)
            if (match(line, /^([^"\\]|\\.)*"/)) {
                val = substr(line, 1, RLENGTH - 1)
                # Unescape basic sequences
                gsub(/\\n/, "\n", val)
                gsub(/\\t/, "\t", val)
                gsub(/\\"/, "\"", val)
                gsub(/\\\\/, "\\", val)
                print val
                line = substr(line, RLENGTH + 1)
            } else {
                break
            }
        }
    }
    ' "$file"
}

# Build parallel arrays for patterns, severities, messages
# We'll parse by finding each object block
parse_patterns() {
    local file="$1"
    awk '
    BEGIN { idx = 0; in_obj = 0 }
    /\{/ { in_obj = 1; pattern = ""; severity = ""; msg = "" }
    /\}/ {
        if (in_obj && pattern != "") {
            print "PATTERN:" pattern
            print "SEVERITY:" severity
            print "MESSAGE:" msg
            print "---"
        }
        in_obj = 0
    }
    in_obj {
        if (match($0, /"pattern"[ \t]*:[ \t]*"([^"\\]|\\.)*"/)) {
            val = substr($0, RSTART, RLENGTH)
            gsub(/^"pattern"[ \t]*:[ \t]*"/, "", val)
            gsub(/"$/, "", val)
            # Unescape JSON: \\ -> \ so grep sees the correct regex
            gsub(/\\\\/, "\\", val)
            pattern = val
        }
        if (match($0, /"severity"[ \t]*:[ \t]*"([^"\\]|\\.)*"/)) {
            val = substr($0, RSTART, RLENGTH)
            gsub(/^"severity"[ \t]*:[ \t]*"/, "", val)
            gsub(/"$/, "", val)
            severity = val
        }
        if (match($0, /"message"[ \t]*:[ \t]*"([^"\\]|\\.)*"/)) {
            val = substr($0, RSTART, RLENGTH)
            gsub(/^"message"[ \t]*:[ \t]*"/, "", val)
            gsub(/"$/, "", val)
            msg = val
        }
    }
    ' "$file"
}

# --- Escape a string for JSON output ---
json_escape() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/	/\\t/g' \
        -e $'s/\r/\\r/g'
}

# --- Main scan ---
FINDINGS=""
TOTAL=0
ERROR_COUNT=0
WARNING_COUNT=0
INFO_COUNT=0
FIRST_FINDING=1

# Read parsed pattern blocks
CUR_PATTERN=""
CUR_SEVERITY=""
CUR_MESSAGE=""

while IFS= read -r line; do
    case "$line" in
        PATTERN:*)
            CUR_PATTERN="${line#PATTERN:}"
            ;;
        SEVERITY:*)
            CUR_SEVERITY="${line#SEVERITY:}"
            ;;
        MESSAGE:*)
            CUR_MESSAGE="${line#MESSAGE:}"
            ;;
        ---)
            if [ -z "$CUR_PATTERN" ]; then
                CUR_PATTERN=""
                CUR_SEVERITY=""
                CUR_MESSAGE=""
                continue
            fi

            # Scan all swift files for this pattern
            while IFS= read -r swift_file; do
                [ -z "$swift_file" ] && continue

                # Get relative path
                rel_file="${swift_file#${TARGET_DIR}/}"

                # grep for pattern with line numbers; suppress errors for binary/missing
                while IFS=: read -r lineno matched_line; do
                    [ -z "$lineno" ] && continue

                    TOTAL=$((TOTAL + 1))

                    case "$CUR_SEVERITY" in
                        error)   ERROR_COUNT=$((ERROR_COUNT + 1)) ;;
                        warning) WARNING_COUNT=$((WARNING_COUNT + 1)) ;;
                        *)       INFO_COUNT=$((INFO_COUNT + 1)) ;;
                    esac

                    esc_pattern="$(json_escape "$CUR_PATTERN")"
                    esc_file="$(json_escape "$rel_file")"
                    esc_match="$(json_escape "$matched_line")"
                    esc_severity="$(json_escape "$CUR_SEVERITY")"
                    esc_message="$(json_escape "$CUR_MESSAGE")"

                    if [ "$FIRST_FINDING" -eq 1 ]; then
                        FIRST_FINDING=0
                    else
                        FINDINGS="${FINDINGS},"
                    fi

                    FINDINGS="${FINDINGS}
    {
      \"pattern\": \"${esc_pattern}\",
      \"file\": \"${esc_file}\",
      \"line\": ${lineno},
      \"match\": \"${esc_match}\",
      \"severity\": \"${esc_severity}\",
      \"message\": \"${esc_message}\"
    }"
                done < <(grep -n -E "$CUR_PATTERN" "$swift_file" 2>/dev/null || true)
            done <<< "$SWIFT_FILES"

            CUR_PATTERN=""
            CUR_SEVERITY=""
            CUR_MESSAGE=""
            ;;
    esac
done < <(parse_patterns "$PATTERNS_FILE")

# Build by_severity block
BY_SEVERITY=""
FIRST_SEV=1

if [ "$WARNING_COUNT" -gt 0 ]; then
    BY_SEVERITY="\"warning\": ${WARNING_COUNT}"
    FIRST_SEV=0
fi

if [ "$ERROR_COUNT" -gt 0 ]; then
    [ "$FIRST_SEV" -eq 0 ] && BY_SEVERITY="${BY_SEVERITY}, "
    BY_SEVERITY="${BY_SEVERITY}\"error\": ${ERROR_COUNT}"
    FIRST_SEV=0
fi

if [ "$INFO_COUNT" -gt 0 ]; then
    [ "$FIRST_SEV" -eq 0 ] && BY_SEVERITY="${BY_SEVERITY}, "
    BY_SEVERITY="${BY_SEVERITY}\"info\": ${INFO_COUNT}"
fi

esc_target="$(json_escape "$TARGET_DIR")"
esc_patterns_file="$(json_escape "$PATTERNS_FILE")"

# Write report
printf '{
  "script": "swift-pattern-lint",
  "timestamp": "%s",
  "target": "%s",
  "patterns_file": "%s",
  "findings": [%s
  ],
  "summary": {
    "total": %d,
    "by_severity": {%s},
    "files_scanned": %d
  }
}\n' \
    "$TIMESTAMP" \
    "$esc_target" \
    "$esc_patterns_file" \
    "$FINDINGS" \
    "$TOTAL" \
    "$BY_SEVERITY" \
    "$FILES_SCANNED" \
    > "$OUTPUT_PATH"

echo "Report written to: $OUTPUT_PATH"
echo "Scanned: ${FILES_SCANNED} files, found: ${TOTAL} findings (errors: ${ERROR_COUNT}, warnings: ${WARNING_COUNT})"

# Exit 1 if any errors found
if [ "$ERROR_COUNT" -gt 0 ]; then
    exit 1
fi

exit 0
