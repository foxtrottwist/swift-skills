#!/usr/bin/env python3
"""
Skill Packager — creates a distributable .skill file from a skill directory.

Usage:
    python -m scripts.package_skill <path/to/skill-folder> [output-directory]

Example:
    python -m scripts.package_skill skills/iter
    python -m scripts.package_skill skills/iter dist/
"""

import fnmatch
import sys
import zipfile
from pathlib import Path
from .quick_validate import validate_skill

# Patterns to exclude when packaging.
EXCLUDE_DIRS = {"__pycache__", "node_modules"}
EXCLUDE_GLOBS = {"*.pyc"}
EXCLUDE_FILES = {".DS_Store"}
# Directories excluded only at the skill root (not when nested deeper).
ROOT_EXCLUDE_DIRS = {"evals"}


def should_exclude(rel_path: Path) -> bool:
    """Check if a path should be excluded from packaging."""
    parts = rel_path.parts
    if any(part in EXCLUDE_DIRS for part in parts):
        return True
    # rel_path is relative to skill_path.parent, so parts[0] is the skill
    # folder name and parts[1] (if present) is the first subdir.
    if len(parts) > 1 and parts[1] in ROOT_EXCLUDE_DIRS:
        return True
    name = rel_path.name
    if name in EXCLUDE_FILES:
        return True
    return any(fnmatch.fnmatch(name, pat) for pat in EXCLUDE_GLOBS)


def package_skill(skill_path, output_dir=None):
    """
    Package a skill directory into a .skill file (ZIP format).

    Args:
        skill_path: Path to the skill directory (must contain SKILL.md)
        output_dir: Output directory for the .skill file (defaults to cwd)

    Returns:
        Path to the created .skill file, or None on error.
    """
    skill_path = Path(skill_path).resolve()

    if not skill_path.exists():
        print(f"Error: skill directory not found: {skill_path}")
        return None

    if not skill_path.is_dir():
        print(f"Error: path is not a directory: {skill_path}")
        return None

    if not (skill_path / "SKILL.md").exists():
        print(f"Error: SKILL.md not found in {skill_path}")
        return None

    print(f"Validating {skill_path.name}...")
    valid, message = validate_skill(skill_path)
    if not valid:
        print(f"Validation failed: {message}")
        return None
    print(f"  {message}")

    skill_name = skill_path.name
    if output_dir:
        output_path = Path(output_dir).resolve()
        output_path.mkdir(parents=True, exist_ok=True)
    else:
        output_path = Path.cwd()

    skill_filename = output_path / f"{skill_name}.skill"

    try:
        with zipfile.ZipFile(skill_filename, "w", zipfile.ZIP_DEFLATED) as zipf:
            for file_path in sorted(skill_path.rglob("*")):
                if not file_path.is_file():
                    continue
                arcname = file_path.relative_to(skill_path.parent)
                if should_exclude(arcname):
                    continue
                zipf.write(file_path, arcname)

        print(f"  Packaged -> {skill_filename}")
        return skill_filename

    except Exception as e:
        print(f"Error creating .skill file: {e}")
        return None


def main():
    if len(sys.argv) < 2:
        print("Usage: python -m scripts.package_skill <path/to/skill-folder> [output-directory]")
        sys.exit(1)

    skill_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None

    result = package_skill(skill_path, output_dir)
    sys.exit(0 if result else 1)


if __name__ == "__main__":
    main()
