#!/usr/bin/env python3
"""
Quick validation for skill SKILL.md frontmatter.
Uses stdlib only — no external dependencies.
"""

import re
import sys
from pathlib import Path


def _parse_frontmatter(text: str) -> dict:
    """
    Parse simple YAML frontmatter using stdlib only.
    Handles 'key: value', quoted values, and multiline (> | >- |-) indicators.
    Only top-level keys are extracted (not indented lines).
    """
    result = {}
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        # Only match top-level keys (not indented)
        m = re.match(r"^([a-zA-Z][a-zA-Z0-9_-]*)\s*:\s*(.*)", line)
        if m:
            key = m.group(1)
            value = m.group(2).strip()
            if value in (">", "|", ">-", "|-", ""):
                # Collect indented continuation lines
                continuation = []
                i += 1
                while i < len(lines) and (
                    lines[i].startswith("  ") or lines[i].startswith("\t")
                ):
                    continuation.append(lines[i].strip())
                    i += 1
                result[key] = " ".join(continuation)
                continue
            else:
                # Strip surrounding quotes
                if len(value) >= 2 and (
                    (value[0] == '"' and value[-1] == '"')
                    or (value[0] == "'" and value[-1] == "'")
                ):
                    value = value[1:-1]
                result[key] = value
        i += 1
    return result


def validate_skill(skill_path) -> tuple[bool, str]:
    """Validate a skill directory's SKILL.md frontmatter."""
    skill_path = Path(skill_path)

    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        return False, "SKILL.md not found"

    content = skill_md.read_text()
    if not content.startswith("---"):
        return False, "No YAML frontmatter found"

    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return False, "Invalid frontmatter format"

    frontmatter_text = match.group(1)
    frontmatter = _parse_frontmatter(frontmatter_text)

    ALLOWED_PROPERTIES = {
        "name", "description", "license", "allowed-tools", "metadata", "compatibility"
    }
    unexpected_keys = set(frontmatter.keys()) - ALLOWED_PROPERTIES
    if unexpected_keys:
        return False, (
            f"Unexpected key(s) in SKILL.md frontmatter: {', '.join(sorted(unexpected_keys))}. "
            f"Allowed properties are: {', '.join(sorted(ALLOWED_PROPERTIES))}"
        )

    if "name" not in frontmatter:
        return False, "Missing 'name' in frontmatter"
    if "description" not in frontmatter:
        return False, "Missing 'description' in frontmatter"

    name = str(frontmatter.get("name", "")).strip()
    if name:
        if not re.match(r"^[a-z0-9-]+$", name):
            return False, f"Name '{name}' should be kebab-case (lowercase letters, digits, and hyphens only)"
        if name.startswith("-") or name.endswith("-") or "--" in name:
            return False, f"Name '{name}' cannot start/end with hyphen or contain consecutive hyphens"
        if len(name) > 64:
            return False, f"Name is too long ({len(name)} characters). Maximum is 64 characters."

    description = str(frontmatter.get("description", "")).strip()
    if description:
        if "<" in description or ">" in description:
            return False, "Description cannot contain angle brackets (< or >)"
        if len(description) > 1024:
            return False, f"Description is too long ({len(description)} characters). Maximum is 1024 characters."

    compatibility = str(frontmatter.get("compatibility", "")).strip()
    if compatibility and len(compatibility) > 500:
        return False, f"Compatibility is too long ({len(compatibility)} characters). Maximum is 500 characters."

    return True, "Skill is valid!"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python quick_validate.py <skill_directory>")
        sys.exit(1)

    valid, message = validate_skill(sys.argv[1])
    print(message)
    sys.exit(0 if valid else 1)
