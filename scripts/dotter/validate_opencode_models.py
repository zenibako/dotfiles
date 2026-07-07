#!/usr/bin/env python3
"""Validate opencode_*_agent_model values against `opencode models` output.

Resolves the active profile from .dotter/local.toml `packages`, reads the
four agent model variables (local.toml [variables] overrides take precedence
over .dotter/global.toml [personal.variables]/[work.variables]), and verifies
each non-empty value appears in `opencode models` output.

Exits non-zero on any mismatch so dotter deploy is blocked.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

# ANSI colors (matched to scripts/dotter/lib.sh)
if sys.stdout.isatty() and not os.environ.get("NO_COLOR"):
    _c = ("\033[32m", "\033[31m", "\033[33m", "\033[0m")
else:
    _c = ("", "", "", "")
_G, _R, _Y, _X = _c

try:
    import tomllib as _toml
except ImportError:  # Python < 3.11
    import tomli as _toml  # type: ignore[no-redef]  # guaranteed via requirements.txt

AGENT_MODEL_VARS = (
    "opencode_build_agent_model",
    "opencode_plan_agent_model",
    "opencode_test_agent_model",
    "opencode_review_agent_model",
)


def _err(msg: str) -> None:
    print(f"{_R}ERROR:{_X} {msg}", file=sys.stderr)


def _resolve_repo_root() -> Path:
    env = os.environ.get("REPO_ROOT")
    if env:
        return Path(env)
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"], stderr=subprocess.DEVNULL
        )
        return Path(out.decode().strip())
    except Exception:
        return Path.cwd()


def _load_toml(path: Path) -> dict[str, object]:
    if not path.is_file():
        return {}
    with open(path, "rb") as f:
        return _toml.load(f)


def _active_profile(local_cfg: dict[str, object]) -> str | None:
    packages = local_cfg.get("packages", [])
    if isinstance(packages, str):
        packages = [p.strip().strip('"') for p in packages.strip("[]").split(",") if p.strip()]
    for pkg in packages:
        if pkg in ("personal", "work"):
            return pkg
    return None


def _resolve_agent_models(
    local_cfg: dict[str, object], global_cfg: dict[str, object], profile: str | None
) -> dict[str, str]:
    """local.toml [variables] overrides > global.toml [<profile>.variables] defaults."""
    resolved: dict[str, str] = {}
    profile_vars: dict[str, str] = {}
    if profile and profile in global_cfg:
        section = global_cfg[profile]
        if isinstance(section, dict):
            section_vars = section.get("variables", {})
            if isinstance(section_vars, dict):
                profile_vars = {k: str(v) for k, v in section_vars.items()}

    local_vars: dict[str, str] = {}
    local_section_vars = local_cfg.get("variables", {})
    if isinstance(local_section_vars, dict):
        local_vars = {k: str(v) for k, v in local_section_vars.items()}

    for var in AGENT_MODEL_VARS:
        val = local_vars.get(var) or profile_vars.get(var) or ""
        # Strip surrounding quotes if tomllib parsed as str already; empty stays empty.
        resolved[var] = val.strip().strip('"')
    return resolved


def _available_models() -> set[str] | None:
    """Return set of available model IDs, or None if opencode isn't callable."""
    opencode = os.environ.get("OPENCODE_BIN", "opencode")
    try:
        out = subprocess.check_output(
            [opencode, "models"], stderr=subprocess.DEVNULL, timeout=30
        )
    except FileNotFoundError:
        _err("opencode binary not found on PATH; cannot validate agent models.")
        return None
    except subprocess.SubprocessError as exc:
        _err(f"`opencode models` failed: {exc}")
        return None
    return {line.strip() for line in out.decode().splitlines() if line.strip()}


def _suggest(val: str, available: set[str]) -> str:
    """Suggest closest available model IDs by provider prefix then name token overlap."""
    provider, _, name = val.partition("/")
    # Prefer same-provider candidates; fall back to all if provider yields nothing.
    pool = [m for m in available if m.startswith(provider + "/")] if provider else list(available)
    if not pool:
        pool = list(available)

    # Score by shared name tokens (split on non-alphanumeric). Higher = closer.
    def score(candidate: str) -> int:
        cand_name = candidate.partition("/")[2] if "/" in candidate else candidate
        cand_tokens = {t for t in re.split(r"[^a-zA-Z0-9]+", cand_name.lower()) if t}
        val_tokens = {t for t in re.split(r"[^a-zA-Z0-9]+", name.lower()) if t}
        return len(cand_tokens & val_tokens)

    ranked = sorted(pool, key=lambda m: (-score(m), m))[:5]
    if not ranked:
        return "    no close matches found in `opencode models` output."
    return f"    closest available: {', '.join(ranked)}"


def main() -> int:
    repo = _resolve_repo_root()
    local_path = Path(os.environ.get("DOTTER_LOCAL_CONFIG", repo / ".dotter" / "local.toml"))
    global_path = repo / ".dotter" / "global.toml"

    local_cfg = _load_toml(local_path)
    global_cfg = _load_toml(global_path)

    profile = _active_profile(local_cfg)
    if profile is None:
        print(f"  {_Y}⊘{_X} opencode agent model validation (no personal/work profile in packages)")
        return 0

    resolved = _resolve_agent_models(local_cfg, global_cfg, profile)

    # If every agent model is empty, nothing to validate (user hasn't configured them).
    if all(not v for v in resolved.values()):
        print(f"  {_Y}⊘{_X} opencode agent model validation (no agent models configured)")
        return 0

    available = _available_models()
    if available is None:
        return 1

    failures: list[str] = []
    for var in AGENT_MODEL_VARS:
        val = resolved[var]
        if not val:
            continue
        if val not in available:
            failures.append(f"  {var} = \"{val}\"  (profile: {profile})")
            failures.append(_suggest(val, available))

    if failures:
        _err(
            f"opencode agent model validation failed for profile '{profile}'.\n"
            + "\n".join(failures)
            + f"\n  Available models: see `opencode models` ({len(available)} total)."
        )
        return 1

    print(f"  {_G}✓{_X} opencode agent models (profile: {profile}): "
          + ", ".join(f"{v.split('/', 1)[-1]}" for v in resolved.values() if v))
    return 0


if __name__ == "__main__":
    sys.exit(main())
