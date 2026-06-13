#!/usr/bin/env python3
"""Validate that all KCL-generated configs are well-formed.

Runs after KCL + Python converter to catch broken configs before dotter deploy.
Checks:
  - All expected files exist in out/
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

OUT = Path("out")
ROOT = Path(".")


def check_file_exists(path, desc):
    # Some files stay at root (dotter entry point, KCL intermediate output)
    if path in ("out/config.json", ".dotter/global.toml"):
        full = ROOT / path
    else:
        full = OUT / path
    if not full.exists():
        print(f"  FAIL: Missing {desc}: {full}")
        return False
    return True


def check_toml_parses(path, desc):
    if not check_file_exists(path, desc):
        return False
    if path in ("out/config.json", ".dotter/global.toml"):
        full = ROOT / path
    else:
        full = OUT / path
    try:
        import tomllib
        with open(full, "rb") as f:
            tomllib.load(f)
    except ImportError:
        try:
            import tomli
            with open(full, "rb") as f:
                tomli.load(f)
        except ImportError:
            print(f"  SKIP: No TOML parser available for {desc}")
            return True
    except Exception as e:
        print(f"  FAIL: {desc} is invalid TOML: {e}")
        return False
    print(f"  OK: {desc}")
    return True


def check_json_parses(path, desc):
    if not check_file_exists(path, desc):
        return False
    if path in ("out/config.json", ".dotter/global.toml"):
        full = ROOT / path
    else:
        full = OUT / path
    try:
        with open(full) as f:
            json.load(f)
    except Exception as e:
        print(f"  FAIL: {desc} is invalid JSON: {e}")
        return False
    print(f"  OK: {desc}")
    return True


def check_template_file(path, desc):
    """Check template file for balanced Handlebars blocks and expected markers."""
    if not check_file_exists(path, desc):
        return False
    if path in ("out/config.json", ".dotter/global.toml"):
        full = ROOT / path
    else:
        full = OUT / path
    try:
        with open(full) as f:
            content = f.read()
    except Exception as e:
        print(f"  FAIL: {desc} unreadable: {e}")
        return False

    # Check for balanced {{#if}} / {{/if}}
    import re
    open_if = len(re.findall(r'\{\{#if\b', content))
    close_if = len(re.findall(r'\{\{/if\}\}', content))
    if open_if != close_if:
        print(f"  FAIL: {desc} has unbalanced {{{{#if}}}} blocks ({open_if} open, {close_if} close)")
        return False

    # Check for other common block tags
    for tag in ['each', 'with', 'unless']:
        open_tags = len(re.findall(r'\{\{#' + tag + r'\b', content))
        close_tags = len(re.findall(r'\{\{/' + tag + r'\}\}', content))
        if open_tags != close_tags:
            print(f"  FAIL: {desc} has unbalanced {{{{#{tag}}}}} blocks")
            return False

    # Check that jj config still has template markers for identity fields
    if path == "jj/config.toml" and ('{{name}}' not in content or '{{email}}' not in content):
        print(f"  FAIL: {desc} missing required Handlebars placeholders ({{name}}, {{email}})")
        return False

    # Check that gitconfig has template markers for identity fields
    if path == "gitconfig" and ('{{name}}' not in content or '{{email}}' not in content):
        print(f"  FAIL: {desc} missing required Handlebars placeholders ({{name}}, {{email}})")
        return False

    print(f"  OK: {desc}")
    return True


def main():
    print("== Validating KCL-generated configs ==")
    all_ok = True

    checks = [
        ("out/config.json", "KCL JSON output", check_json_parses),
        (".dotter/global.toml", "dotter config", check_toml_parses),
        ("shared/env.toml", "env config", check_template_file),
        ("shared/completions.toml", "completions config", check_toml_parses),
        ("packages-fedora.txt", "Fedora packages", check_file_exists),
        ("Brewfile", "Homebrew bundle", check_file_exists),
        ("atuin/config.toml", "atuin config", check_toml_parses),
        ("starship.toml", "starship config", check_toml_parses),
        ("aerospace.toml", "aerospace config", check_toml_parses),
        ("jj/config.toml", "jj config", check_template_file),
        ("tmux.conf", "tmux config", check_template_file),
        ("ghostty/config", "ghostty config", check_template_file),
        ("iamb/config.toml", "iamb config", check_toml_parses),
        ("gitlogue/config.toml", "gitlogue config", check_toml_parses),
        ("pnpm/rc", "pnpm config", check_file_exists),
        ("gitconfig", "gitconfig", check_template_file),
        ("opencode.jsonc", "opencode config", check_template_file),
        ("claude_desktop_config.json", "Claude Desktop config", check_template_file),
        ("claude-code/settings.json", "Claude Code settings", check_template_file),
        ("zshenv", "zshenv", check_template_file),
    ]

    for path, desc, checker in checks:
        if not checker(path, desc):
            all_ok = False

    if all_ok:
        print("\nAll generated configs valid.")
        return 0
    else:
        print("\nValidation FAILED — fix issues before deploying.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
