#!/usr/bin/env python3
"""Merge the dotfiles-managed Claude Desktop config into the live file.

Claude Desktop rewrites claude_desktop_config.json at runtime (it persists its
own ``preferences`` there), so dotter cannot own the file directly without
clobbering that runtime state -- it bails out with "target contents were
changed. Skipping" and the config never updates.

Instead, dotter renders the templated config to a private staging path that it
owns exclusively (so it never conflicts), and this script merges the
dotfiles-managed keys into the live file at post-deploy time:

  * ``mcpServers``                      -> full replace (dotfiles is the single
                                            source of truth, so servers removed
                                            from the dotfiles actually disappear)
  * ``preferences`` / ``coworkUserFilesPath`` / anything else the dotfiles set
                                        -> overlay (dotfiles keys win; any extra
                                            keys Claude wrote are preserved)

The merge is idempotent: re-running with no upstream changes leaves the live
file untouched.

Usage: merge_claude_desktop_config.py <rendered-staging> <live-target>
"""
import json
import sys


def deep_merge(base, overlay):
    """Recursively overlay ``overlay`` onto ``base`` in place; overlay wins."""
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], value)
        else:
            base[key] = value
    return base


def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return default
    except (json.JSONDecodeError, OSError) as exc:
        print(f"  WARNING: could not read {path}: {exc}", file=sys.stderr)
        return default


def main():
    if len(sys.argv) != 3:
        print(
            "usage: merge_claude_desktop_config.py <rendered> <live>",
            file=sys.stderr,
        )
        return 2
    rendered_path, live_path = sys.argv[1], sys.argv[2]

    rendered = load_json(rendered_path, None)
    if not isinstance(rendered, dict):
        # Nothing to merge (dotter did not render the staging file); leave the
        # live config alone rather than failing the whole deploy.
        print(f"  SKIP: rendered config missing or invalid: {rendered_path}")
        return 0

    live = load_json(live_path, {})
    if not isinstance(live, dict):
        live = {}

    merged = deep_merge(dict(live), rendered)
    # mcpServers is wholly owned by the dotfiles: replace rather than merge so
    # that servers removed upstream are dropped instead of lingering.
    if "mcpServers" in rendered:
        merged["mcpServers"] = rendered["mcpServers"]

    if merged == live:
        print("  Claude Desktop config already up to date")
        return 0

    with open(live_path, "w") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")
    print(
        f"  Merged Claude Desktop config "
        f"({len(merged.get('mcpServers', {}))} MCP servers)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
