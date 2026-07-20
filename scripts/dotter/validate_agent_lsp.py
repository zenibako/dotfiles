#!/usr/bin/env python3
"""Validate LSP coverage for OpenCode and Claude Code after deploy.

Companion to validate_lsp.lua (which exercises Neovim attachments in a live
headless session). This script covers the two agent CLIs where a live
attachment test isn't practical:

- OpenCode: parses the deployed ~/.config/opencode/opencode.jsonc `lsp`
  section, checks each enabled server's binary resolves, and flags duplicate
  entries (underscore/hyphen key drift, two keys sharing one binary).
- Claude Code: reads enabledPlugins from ~/.claude/settings.json, resolves
  each *-lsp plugin's server command from the plugin catalog cache (static
  fallback when the cache lacks an entry), and checks the binary resolves.

Finishes with a language x tool coverage matrix across Neovim, OpenCode, and
Claude Code so gaps are visible in one place.

Output format matches scripts/dotter/lib.sh conventions (2-space indent,
"==>" step headers, ✓/⚠/⊘ glyphs, ANSI colors only when stdout is a TTY and
NO_COLOR is unset). Always exits 0 — coverage gaps are advisory, not deploy
blockers.
"""

from __future__ import annotations

import glob
import json
import os
import re
import shutil
import sys
from pathlib import Path

# ANSI colors (matched to scripts/dotter/lib.sh: TTY only, NO_COLOR respected)
if sys.stdout.isatty() and not os.environ.get("NO_COLOR"):
    _GREEN, _YELLOW, _GRAY, _BLUE, _BOLD, _RESET = (
        "\033[32m", "\033[33m", "\033[90m", "\033[34m", "\033[1m", "\033[0m",
    )
else:
    _GREEN = _YELLOW = _GRAY = _BLUE = _BOLD = _RESET = ""

_GLYPH_COLOR = {"✓": _GREEN, "⚠": _YELLOW, "⊘": _GRAY, "—": _GRAY}


def _c(glyph: str) -> str:
    return f"{_GLYPH_COLOR.get(glyph, '')}{glyph}{_RESET}"


def _header(title: str) -> None:
    print(f"{_BOLD}{_BLUE}==> {title}{_RESET}")


HOME = Path.home()
OPENCODE_CONFIG = HOME / ".config/opencode/opencode.jsonc"
CLAUDE_SETTINGS = HOME / ".claude/settings.json"
PLUGIN_CATALOG = HOME / ".claude/plugins/plugin-catalog-cache.json"
CLAUDE_SKILLS_DIR = HOME / ".claude/skills"
NVIM_LSP_DIR = HOME / ".config/nvim/lsp"
NVIM_PLUGIN_DIR = HOME / ".config/nvim/lua/plugins"

# Fallback plugin -> LSP binary map for official Claude Code LSP plugins whose
# lspServers entry is missing from the local catalog cache.
CLAUDE_PLUGIN_BINARIES = {
    "gopls-lsp": "gopls",
    "html-lsp": "vscode-html-language-server",
    "json-lsp": "vscode-json-language-server",
    "lua-lsp": "lua-language-server",
    "swift-lsp": "sourcekit-lsp",
    "typescript-lsp": "typescript-language-server",
    "yaml-lsp": "yaml-language-server",
    "clangd-lsp": "clangd",
    "pyright-lsp": "pyright-langserver",
    "csharp-lsp": "csharp-ls",
    "jdtls-lsp": "jdtls",
    "kotlin-lsp": "kotlin-lsp",
    "php-lsp": "intelephense",
    "ruby-lsp": "ruby-lsp",
    "rust-analyzer-lsp": "rust-analyzer",
}

# Server/plugin name -> language, for the cross-tool coverage matrix. Keys are
# normalized (lowercase, '_' -> '-', '@marketplace' suffix stripped).
SERVER_LANGUAGE = {
    "gopls": "go",
    "gopls-lsp": "go",
    "basedpyright": "python",
    "pyright-lsp": "python",
    "lua-ls": "lua",
    "lua-lsp": "lua",
    "html": "html",
    "html-lsp": "html",
    "jsonls": "json",
    "json-lsp": "json",
    "yamlls": "yaml",
    "yaml-lsp": "yaml",
    "taplo": "toml",
    "cue": "cue",
    "kcl-lsp": "kcl",
    "pkl-lsp": "pkl",
    "starlark-rust": "starlark",
    "typescript-tools": "typescript",
    "typescript-language-server": "typescript",
    "typescript-lsp": "typescript",
    "apex-language-server": "apex",
    "apex-ls": "apex",
    "lwc-language-server": "lwc",
    "visualforce-language-server": "visualforce",
    "gitlab-ci-ls": "gitlab-ci",
    "terraform-ls": "terraform",
    "sourcekit-lsp": "swift",
    "swift-lsp": "swift",
    "jinja-lsp": "jinja",
    "clangd-lsp": "c/c++",
}


def _norm(name: str) -> str:
    return name.split("@", 1)[0].lower().replace("_", "-")


def _strip_jsonc(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"^\s*//.*$", "", text, flags=re.M)


def _binary_ok(cmd: str) -> bool:
    expanded = os.path.expandvars(os.path.expanduser(cmd))
    if "/" in expanded:
        return os.path.isfile(expanded) and os.access(expanded, os.X_OK)
    return shutil.which(expanded) is not None


def _row(glyph: str, name: str, detail: str) -> None:
    print(f"  {_c(glyph)} {name:<27} {detail}")


def _summary(ok: int, warn: int, skip: int) -> None:
    glyph = "⚠" if warn else "✓"
    print(f"\n  {_c(glyph)} {ok} OK, {warn} warnings, {skip} disabled")


def validate_opencode() -> dict[str, str]:
    """Returns {normalized server name: language or ''} for covered servers."""
    _header("OpenCode LSP Validation")
    if not OPENCODE_CONFIG.is_file():
        _row("⊘", "opencode.jsonc", "not deployed")
        return {}

    try:
        cfg = json.loads(_strip_jsonc(OPENCODE_CONFIG.read_text()))
    except (json.JSONDecodeError, OSError) as e:
        _row("⚠", "opencode.jsonc", f"unparseable: {e}")
        return {}

    lsp = cfg.get("lsp", {})
    if not lsp:
        _row("⊘", "lsp", "no lsp section")
        return {}

    covered: dict[str, str] = {}
    by_norm: dict[str, list[str]] = {}
    by_binary: dict[str, list[str]] = {}
    for name, srv in lsp.items():
        by_norm.setdefault(_norm(name), []).append(name)
        cmd = (srv.get("command") or [""])[0]
        if cmd and not srv.get("disabled"):
            by_binary.setdefault(cmd, []).append(name)

    ok = warn = skip = 0
    for name in sorted(lsp):
        srv = lsp[name]
        cmd = (srv.get("command") or [""])[0]
        norm = _norm(name)

        # Stale duplicate: same normalized name under a different key, and this
        # is the non-canonical (underscore) spelling.
        siblings = [n for n in by_norm[norm] if n != name]
        if siblings and "_" in name:
            _row("⚠", name, f"stale duplicate of {siblings[0]} — remove from live config")
            warn += 1
            continue

        if srv.get("disabled"):
            _row("⊘", name, "disabled")
            skip += 1
            continue

        dup_binary = [n for n in by_binary.get(cmd, []) if n != name]
        if dup_binary:
            _row("⚠", name, f"same binary as {', '.join(dup_binary)}: {cmd}")
            warn += 1
            covered[norm] = SERVER_LANGUAGE.get(norm, "")
            continue

        if not cmd:
            _row("⚠", name, "no command")
            warn += 1
        elif _binary_ok(cmd):
            _row("✓", name, cmd)
            ok += 1
            covered[norm] = SERVER_LANGUAGE.get(norm, "")
        else:
            _row("⚠", name, f"not installed: {cmd}")
            warn += 1

    _summary(ok, warn, skip)
    return covered


def validate_claude_code() -> dict[str, str]:
    print()
    _header("Claude Code LSP Validation")
    if not CLAUDE_SETTINGS.is_file():
        _row("⊘", "settings.json", "not deployed")
        return {}

    try:
        settings = json.loads(CLAUDE_SETTINGS.read_text())
    except (json.JSONDecodeError, OSError) as e:
        _row("⚠", "settings.json", f"unparseable: {e}")
        return {}

    plugins = settings.get("enabledPlugins", {})
    lsp_plugins = {k: v for k, v in plugins.items() if _norm(k).endswith("-lsp")}

    # Local skill-dir LSP definitions (~/.claude/skills/*/.lsp.json), e.g. the
    # apex-ls prototype — not plugins, but they add LSP coverage all the same.
    local_lsps: dict[str, str] = {}
    if CLAUDE_SKILLS_DIR.is_dir():
        for lsp_json in sorted(CLAUDE_SKILLS_DIR.glob("*/.lsp.json")):
            try:
                servers = json.loads(lsp_json.read_text())
            except (json.JSONDecodeError, OSError):
                continue
            for srv in servers.values():
                if isinstance(srv, dict) and srv.get("command"):
                    local_lsps[_norm(lsp_json.parent.name)] = srv["command"]
                    break

    if not lsp_plugins and not local_lsps:
        _row("⊘", "enabledPlugins", "no LSP plugins configured")
        return {}

    # Prefer the actual command from the plugin catalog cache; fall back to the
    # static map for plugins the cache doesn't carry lspServers for.
    catalog_cmds: dict[str, str] = {}
    if PLUGIN_CATALOG.is_file():
        try:
            catalog = json.loads(PLUGIN_CATALOG.read_text())
            for key, entry in catalog.get("catalog", {}).get("plugins", {}).items():
                servers = (entry.get("marketplace_entry") or {}).get("lspServers") or {}
                if isinstance(servers, dict):
                    for srv in servers.values():
                        if isinstance(srv, dict) and srv.get("command"):
                            catalog_cmds[_norm(key)] = srv["command"]
                            break
        except (json.JSONDecodeError, OSError):
            pass

    covered: dict[str, str] = {}
    ok = warn = skip = 0
    for plugin in sorted(lsp_plugins):
        short = _norm(plugin)
        if not lsp_plugins[plugin]:
            _row("⊘", short, "disabled")
            skip += 1
            continue
        cmd = catalog_cmds.get(short) or CLAUDE_PLUGIN_BINARIES.get(short)
        if not cmd:
            _row("⚠", short, "unknown plugin — no binary mapping")
            warn += 1
        elif _binary_ok(cmd):
            _row("✓", short, cmd)
            ok += 1
            covered[short] = SERVER_LANGUAGE.get(short, "")
        else:
            _row("⚠", short, f"not installed: {cmd}")
            warn += 1

    for name, cmd in sorted(local_lsps.items()):
        if _binary_ok(cmd):
            _row("✓", name, f"{cmd} (local .lsp.json)")
            ok += 1
            covered[name] = SERVER_LANGUAGE.get(name, "")
        else:
            _row("⚠", name, f"not installed: {cmd} (local .lsp.json)")
            warn += 1

    _summary(ok, warn, skip)
    return covered


def detect_nvim_servers() -> dict[str, str]:
    covered: dict[str, str] = {}
    for f in sorted(NVIM_LSP_DIR.glob("*.lua")) if NVIM_LSP_DIR.is_dir() else []:
        covered[_norm(f.stem)] = SERVER_LANGUAGE.get(_norm(f.stem), "")

    # Servers enabled outside lsp/*.lua (mirrors config/lsp.lua + the local
    # apex_ls prototype plugin's own existence checks).
    if glob.glob(
        str(HOME / ".vscode/extensions/salesforce.salesforcedx-vscode-visualforce-*/dist/visualforceServer.js")
    ):
        covered["visualforce-language-server"] = "visualforce"
    if os.access(HOME / ".local/share/apex-language-server/apex-ls-stdio.sh", os.X_OK):
        covered["apex-ls"] = "apex"
    if NVIM_PLUGIN_DIR.is_dir() and any(
        "typescript-tools" in p.read_text() for p in NVIM_PLUGIN_DIR.glob("*.lua")
    ):
        covered["typescript-tools"] = "typescript"
    return covered


def coverage_matrix(nvim: dict[str, str], opencode: dict[str, str], claude: dict[str, str]) -> None:
    print()
    _header("LSP Coverage Matrix (language × tool)")
    by_lang: dict[str, dict[str, list[str]]] = {}
    for tool, servers in (("nvim", nvim), ("opencode", opencode), ("claude-code", claude)):
        for server, lang in servers.items():
            lang = lang or server
            by_lang.setdefault(lang, {}).setdefault(tool, []).append(server)

    print(f"  {_GRAY}{'language':<12} {'nvim':<8} {'opencode':<10} {'claude-code':<12}{_RESET}")
    full = 0
    for lang in sorted(by_lang):
        tools = by_lang[lang]
        cells = ["✓" if t in tools else "—" for t in ("nvim", "opencode", "claude-code")]
        if all(c == "✓" for c in cells):
            full += 1
        # Pad the plain cell first, then colorize the glyph — embedding ANSI
        # codes before padding would count them toward the column width.
        padded = [
            f"{cells[0]:<8}".replace(cells[0], _c(cells[0]), 1),
            f"{cells[1]:<10}".replace(cells[1], _c(cells[1]), 1),
            f"{cells[2]:<12}".replace(cells[2], _c(cells[2]), 1),
        ]
        print(f"  {lang:<12} {padded[0]} {padded[1]} {padded[2]}")
    print(f"\n  {_c('✓')} {len(by_lang)} languages, {full} covered by all three tools")


def main() -> int:
    opencode = validate_opencode()
    claude = validate_claude_code()
    coverage_matrix(detect_nvim_servers(), opencode, claude)
    return 0


if __name__ == "__main__":
    sys.exit(main())
