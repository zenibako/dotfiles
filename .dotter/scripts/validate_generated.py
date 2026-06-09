#!/usr/bin/env python3
"""Validate that all KCL-generated configs are well-formed.

Runs after KCL + Python converter to catch broken configs before dotter deploy.
Checks:
  - All expected files exist
  - TOML files parse correctly
  - Template files have valid structure (no orphaned {{}} blocks)
  - Generated JSON is valid

Exit codes:
  0 = all valid
  1 = validation failure
"""

import json
import sys
from pathlib import Path


def check_file_exists(path, desc):
    if not Path(path).exists():
        print(f"  FAIL: Missing {desc}: {path}")
        return False
    print(f"  OK: {desc}")
    return True


def check_toml_parses(path, desc):
    try:
        import tomllib
        with open(path, "rb") as f:
            tomllib.load(f)
    except ImportError:
        try:
            import tomli
            with open(path, "rb") as f:
                tomli.load(f)
        except ImportError:
            print(f"  SKIP: No TOML parser available for {desc}")
            return True
    except Exception as e:
        print(f"  FAIL: {desc} is invalid TOML: {e}")
        return False
    print(f"  OK: {desc} parses as TOML")
    return True


def check_json_parses(path, desc):
    try:
        with open(path) as f:
            json.load(f)
    except Exception as e:
        print(f"  FAIL: {desc} is invalid JSON: {e}")
        return False
    print(f"  OK: {desc} parses as JSON")
    return True


def check_template_file(path, desc):
    """Check template file for balanced Handlebars blocks."""
    try:
        with open(path) as f:
            content = f.read()
    except Exception as e:
        print(f"  FAIL: {desc} unreadable: {e}")
        return False

    # Check for balanced {{#if}} / {{/if}}
    import re
    open_if = len(re.findall(r'\{\{#if\b', content))
    close_if = len(re.findall(r'\{\{/if\}\}', content))
    if open_if != close_if:
        print(f"  FAIL: {desc} has unbalanced {{#if}} blocks ({open_if} open, {close_if} close)")
        return False

    # Check for other common block tags
    for tag in ['each', 'with', 'unless']:
        open_tags = len(re.findall(rf'\{{{{#{tag}\b', content))
        close_tags = len(re.findall(rf'\{{{{/{tag}\}}\}}', content))
        if open_tags != close_tags:
            print(f"  FAIL: {desc} has unbalanced {{#{tag}}} blocks")
            return False

    print(f"  OK: {desc} template structure valid")
    return True


def main():
    print("== Validating KCL-generated configs ==")
    all_ok = True

    # Expected files
    expected = [
        ("generated/config.json", "KCL JSON output", "json"),
        (".dotter/global.toml", "dotter config", "toml"),
        ("shared/env.toml", "env config", "template"),
        ("shared/completions.toml", "completions config", "toml"),
        ("packages-fedora.txt", "Fedora packages", "txt"),
        ("Brewfile", "Homebrew bundle", "txt"),
        ("atuin/config.toml", "atuin config", "toml"),
        ("starship.toml", "starship config", "toml"),
        ("aerospace.toml", "aerospace config", "toml"),
        ("jj/config.toml", "jj config", "template"),
        ("tmux.conf", "tmux config", "template"),
        ("ghostty/config", "ghostty config", "template"),
    ]

    for path, desc, kind in expected:
        if not check_file_exists(path, desc):
            all_ok = False
            continue

        if kind == "toml":
            if not check_toml_parses(path, desc):
                all_ok = False
        elif kind == "json":
            if not check_json_parses(path, desc):
                all_ok = False
        elif kind == "template":
            if not check_template_file(path, desc):
                all_ok = False

    if all_ok:
        print("\nAll generated configs valid.")
        return 0
    else:
        print("\nValidation FAILED — fix issues before deploying.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
