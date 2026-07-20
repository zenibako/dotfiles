---
feature: "Dotfiles Knowledge Base"
mode: override
created: "2026-07-03"
---

> This is the knowledge base for the dotfiles repository. It primes AI with project-specific context -- tech stack, architecture, trusted sources, and project structure -- so generated code fits this codebase rather than defaulting to generic patterns.

## 1. Architecture Overview

Personal dotfiles repo managed by KCL + dotter. Single source of truth is `src/*.k` (KCL modules); a Python converter emits `.dotter/global.toml` + `out/` text configs; dotter deploys to `~/.config/`, `~/.zshrc`, etc.
- **KCL layer** (`src/`): profiles (default/work/personal), platforms (mac/linux), themes (monokai/nightowl/tokyonight), tool configs (zsh, nvim, ghostty, jj, tmux, atuin, starship, opencode, claude-code, kiro, codex)
- **Build layer** (`scripts/dotter/`): `generate_from_kcl.py` JSON→TOML, validators, `lib.sh` helpers
- **Deploy layer** (`.dotter/`): generated `global.toml` + user `local.toml`; `pre_deploy.sh` runs KCL, `post_deploy.sh` injects secrets from Keychain
- **Profile inheritance**: `work`/`personal` depend on `default`; platform profiles attach OS-specific files/vars; themes attach color scheme variables

## 2. Tech Stack and Versions

- **KCL**: 0.12.x (config language; not TOML/YAML — those are *outputs*, KCL is the source)
- **Dotter**: 0.13.x (deploy engine; not GNU Stow, not chezmoi)
- **Python**: 3.14.x (build glue only — `generate_from_kcl.py`, validators; not application code)
- **Neovim**: 0.12.x (Lua config; not Vimscript, not init.vim)
- **Zsh**: 5.9.x (POSIX-safe `zshenv` for non-interactive; zsh-only `zshrc`; not bash, not fish as primary)
- **Nushell**: 0.113.x (secondary shell; config templated via dotter; not the primary login shell)
- **Jujutsu (jj)**: 0.42.x (primary VCS; not git CLI — git is the underlying backend)
- **Tmux**: 3.6.x
- **Ghostty**: 1.3.x (terminal; not Alacritty, not Kitty)
- **Shell tools**: Starship, Atuin, Carapace, Zoxide (guarded with `command -v` / `(( ${+commands[...]} ))`)
- **AI assistants configured**: OpenCode, Claude Code, Kiro, Codex (MCP server configs rendered to staging files, merged by `post_deploy.sh`)
- **Secrets**: macOS Keychain via `security` CLI and Proton Pass CLI (`pass-cli`) (not dotenv, not Vault)
- **Themes**: monokai (sonokai), nightowl, tokyonight (not Catppuccin, not Gruvbox)

## 3. Curated Knowledge Sources

### Official Documentation
| Topic | Source | Why We Trust It |
|-------|--------|-----------------|
| KCL language | https://kcl-lang.io/docs/ | Schema, imports, `file.write`, config idioms |
| Dotter | https://github.com/SuperCuber/dotter/wiki | `depends`, file targets, template vs symbolic, `global.toml` format |
| Neovim Lua API | https://neovim.io/doc/user/api.html | `vim.api`, `vim.fn`, autocmds, LSP config (not Vimscript) |
| Jujutsu | https://jj-vcs.github.io/jj/latest/ | Bookmarks, rebase, conflict resolution, `jj config` |
| Ghostty config | https://ghostty.org/docs/config | Keybindings, themes, shaders |

### Internal References
| Topic | Path | What It Captures |
|-------|------|------------------|
| Project README | `README.md` | Pipeline overview, profile selection, secrets workflow |
| Agent guidelines | `AGENTS.md` | Deploy commands, VCS rules, GPG signing, co-author attribution |
| Dotfiles KCL skill | `.agents/skills/dotfiles-kcl/SKILL.md` | KCL module patterns, schema design, template generation |
| Dotter skill | `.agents/skills/dotter/SKILL.md` | Profile inheritance, templating, deployment troubleshooting |

## 4. Project Structure

```
dotfiles/
+-- src/                   # KCL source of truth + static config dirs
|   +-- main.k             # KCL entrypoint — assembles config, writes out/
|   +-- profiles.k         # Profile definitions (default, work, personal, mac, linux)
|   +-- themes.k           # Theme variable sets (monokai, nightowl, tokyonight)
|   +-- *.k                # Tool modules (env, jj, tmux, ghostty, atuin, starship, opencode, claude, kiro, codex...)
|   +-- _shared/           # Shared KCL schemas (Profile, DotterConfig, ConfigMap)
|   +-- zshrc              # Zsh interactive config (template, deployed as-is)
|   +-- zprofile           # Zsh login config
|   +-- zshenv.k           # POSIX-safe env loading (non-interactive)
|   +-- nvim/              # Neovim configs (default/work/personal profiles)
|   +-- opencode/          # OpenCode commands, prompts, scripts, AGENTS.md
|   +-- claude-code/       # Claude Code CLAUDE.md, commands, settings template
|   +-- kiro/              # Kiro steering + MCP config
|   +-- codex/             # Codex AGENTS.md + config template
|   +-- git/               # Commit template, hooks (prepare-commit-msg)
|   +-- gnupg/             # GPG agent config template
|   +-- ghostty/           # Ghostty shaders (static)
|   +-- nushell/           # Nushell config (templated)
|   +-- hypr/              # Hyprland config (Linux)
|   +-- waybar/            # Waybar config + Go scripts (Linux)
|   +-- agents/            # Shared agent commands + skills (symlinked to ~/.agents/)
+-- scripts/
|   +-- pre_deploy.sh      # KCL generation + validation (dotter hook)
|   +-- post_deploy.sh     # Secret injection + post-deploy checks
|   +-- dotter/
|       +-- lib.sh         # Common helpers (resolve_python, run_with_timeout)
|       +-- generate_from_kcl.py  # JSON → TOML converter
|       +-- validate_*.py  # Config validators
+-- .dotter/               # Generated + user config (gitignored)
|   +-- global.toml        # Generated by KCL pipeline
|   +-- local.toml         # Per-machine (user creates from local.k.example)
+-- out/                   # Generated artifacts (gitignored, written by KCL)
+-- .agents/skills/        # Project-local skills (dotfiles-kcl, dotter, validate-*)
+-- .gitea/workflows/      # CI (validate-dotter.yml)
+-- backlog/               # Backlog.md tasks
+-- deploy.sh              # Deploy wrapper (pre_deploy + dotter deploy)
+-- init.sh                # First-time machine bootstrap
+-- local.k.example        # Template for local.k (secrets + per-machine vars)
```

### Key Anchors

Jump straight to these instead of exploring the tree:

| To change… | Go to |
|------------|-------|
| What gets generated / composition root | `src/main.k` (imports every module + `file.write` calls) |
| Shared schemas / types | `src/_shared/schemas.k` |
| MCP servers (defs, inclusion, host emission) | `src/_shared/mcp.k` — `_mcp_servers`, `opencode_mcp_for`, `MCP_PERSONAL`/`MCP_WORK`, `_MCP_HOST_EXCLUDED`, `mcp_server_names` |
| OpenCode agents / config | `src/opencode/config.k` — `_agent`, `_mcp_only`, `_agent_prompt`, `build` |
| OpenCode agent prompts | `src/opencode/prompt/agents/*.md` |
| dotter file mappings (what deploys where) | `src/profiles.k` — each profile's `files = { … }` |
| A tool's config (starship, jj, atuin, …) | `src/<tool>.k` (one module per tool) |
| Neovim config | `src/nvim/{default,work,personal}/` (Lua; deployed as a dotter template) |
| JSON→TOML conversion | `scripts/dotter/generate_from_kcl.py` |
| Deploy hooks (build / secrets) | `scripts/pre_deploy.sh`, `scripts/post_deploy.sh` |
| Secret injection | `scripts/dotter/patch_opencode_secrets.py`, `scripts/secrets/*.sh` |
| Shared shell helpers | `scripts/dotter/lib.sh` |

## 5. Project Conventions

- **KCL is the single source of truth** — never edit `.dotter/global.toml` or `out/` files directly; they are generated. Edit `src/*.k` and run `./deploy.sh`.
- **Use `./deploy.sh` on fresh clones** — it calls `ensure_dotter_dir` (creates `.dotter/` + symlinks hooks) before dotter runs. Once `.dotter/` is set up, bare `dotter deploy` runs the same `pre_deploy`/`post_deploy` hooks (KCL regen, secret injection, validation). The wrapper's value is fresh-clone safety + explicit ordering.
- **Profile inheritance via `depends`** — `work` and `personal` inherit from `default`; do not redeclare inherited variables in child profiles (dotter errors on duplicates). Override values or add new ones only.
- **One profile, one platform, one theme** — selected in `local.k` (generates `.dotter/local.toml`); never hardcode profile/theme selection in `src/*.k`.
- **Secrets never committed** — `local.k` and `.dotter/local.toml` are gitignored. Secrets come from macOS Keychain (`security` CLI) or Proton Pass CLI (`pass-cli`), injected by `post_deploy.sh`.
- **Staging files for runtime-rewritten configs** — OpenCode, Claude Code, Claude Desktop, and Kiro configs render to `~/.cache/dotfiles/*.rendered.*` (not their live paths) because those apps rewrite their config at runtime; `post_deploy.sh` merges them.
- **Shell split**: `zshenv` is POSIX-compatible (non-interactive safe, sourced by MCP servers); `zshrc` is zsh-only (interactive). Never source `zshrc` from bash.
- **Tool init guards** — `zoxide init`, `atuin init`, `starship init` etc. guarded with `command -v` or `(( ${+commands[...]} ))` to avoid errors on missing binaries.
- **GPG-signed commits only** — never bypass signing. Warm cache with `gpg-preset-from-keychain` before agent commits.
- **Agent commits include `Co-authored-by`** — set `AI_CO_AUTHOR` env var before committing; use `jjc`/`jjd` helpers or manual `jj commit -m` with trailer appended.

---
*Generated for dotfiles on 2026-07-03. Mode: override.*
*Produced by the knowledge-priming-refiner skill.