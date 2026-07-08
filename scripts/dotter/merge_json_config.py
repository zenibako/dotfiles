#!/usr/bin/env python3
"""Merge a dotfiles-managed (rendered) config into a live JSON/JSONC file.

Several apps own their config file at runtime -- Claude Desktop and Claude Code
rewrite theirs to persist UI state, and post_deploy.sh injects secrets into
others -- so the live file always diverges from what dotter last wrote and
dotter refuses to update it ("target contents were changed. Skipping").

To work around that, dotter renders each templated config to a private staging
file it owns exclusively (so it never conflicts), and this script merges the
dotfiles-managed content into the live file at post-deploy time.

Merge semantics:

  * Deep-merge: the rendered config is overlaid onto the live file. Dotfiles
    values win for the keys they define; any keys present only in the live file
    are preserved. That covers BOTH runtime state the app wrote AND secret
    subkeys injected post-deploy (e.g. ``mcp.GitHub.headers.Authorization``),
    because those subkeys are absent from the rendered template and so are left
    untouched.

  * ``--replace KEY`` replaces a whole top-level key from the rendered config
    instead of deep-merging it, so entries removed upstream actually disappear.
    Only use this for keys the dotfiles render completely, including any
    secrets (e.g. Claude Desktop ``mcpServers``, whose sole token arrives via a
    Handlebars variable). Do NOT use it for configs whose secrets are injected
    post-deploy, or a deploy without secret access would blank them.

The merge is idempotent: with no upstream changes the live file is left as-is.

Usage: merge_json_config.py <rendered> <live> [--replace KEY]...
"""
import argparse
import copy
import json
import os
import sys

# ANSI colors (matched to scripts/dotter/lib.sh)
if sys.stdout.isatty() and not os.environ.get("NO_COLOR"):
    _c = ("\033[32m", "\033[33m", "\033[90m", "\033[0m")
else:
    _c = ("", "", "", "")
_G, _Y, _GY, _X = _c


def strip_jsonc_comments(text):
    """Remove // and /* */ comments, ignoring those inside JSON strings."""
    out = []
    i = 0
    n = len(text)
    in_string = False
    escaped = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def deep_merge(base, overlay):
    """Recursively overlay ``overlay`` onto ``base`` in place; overlay wins."""
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], value)
        else:
            base[key] = value
    return base


def load_jsonc(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.loads(strip_jsonc_comments(f.read()))
    except FileNotFoundError:
        return default
    except (json.JSONDecodeError, OSError) as exc:
        print(f"  {_Y}WARNING:{_X} could not read {path}: {exc}", file=sys.stderr)
        return default


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("rendered")
    parser.add_argument("live")
    parser.add_argument(
        "--replace",
        action="append",
        default=[],
        metavar="KEY",
        help="top-level key to replace wholesale instead of deep-merging",
    )
    args = parser.parse_args()

    rendered = load_jsonc(args.rendered, None)
    if not isinstance(rendered, dict):
        print(f"  {_Y}⊘{_X} rendered config missing or invalid: {args.rendered}")
        return 0

    live = load_jsonc(args.live, {})
    if not isinstance(live, dict):
        live = {}

    # Deep-copy: deep_merge mutates nested dicts in place, so a shallow copy
    # would also mutate `live` and make the idempotency check below a false
    # positive for nested changes (they would never get written).
    merged = deep_merge(copy.deepcopy(live), rendered)
    for key in args.replace:
        if key in rendered:
            merged[key] = rendered[key]

    if merged == live:
        print(f"  {_G}✓{_X} {args.live.split('/')[-1]} already up to date")
        return 0

    with open(args.live, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")
    print(f"  {_G}✓{_X} Merged {args.live.split('/')[-1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
