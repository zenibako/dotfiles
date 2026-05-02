# Agent Guidelines for Dotfiles Repository

## Build/Deploy Commands
- **Deploy configs**: `dotter deploy -f` (templates from .dotter/global.toml, uses `depends` for profile inheritance)
- **Go scripts**: `cd waybar/scripts/{docker-stats,weather-stats} && go run main.go`
- **Init setup**: `sh init.sh` (cross-distro package install, oh-my-zsh, tpm, carapace, zoxide, atuin, starship, dotter deploy)
- **OpenCode plugins**: `cd ~/.config/opencode && npm install`

## CI/CD
- **GitHub Actions** stored in `.github/workflows/`; **Gitea Actions** stored in `.gitea/workflows/`
- `validate-dotter.yml` runs on both platforms (mirrored)
- `opencode.yml` is GitHub-only and currently NOT portable to Gitea Actions due to GitHub-specific triggers, custom actions, and event payloads (`issue_comment`, `pull_request_review_comment`, `anomalyco/opencode/github@latest`)

## Version Control
- Config in `jj/config.toml`
- **Merge tool**: `jj-diffconflicts` via nvim (`merge-tools.diffconflicts`)
- **GPG Signing**: ALL commits must be GPG signed. Never bypass signing.
- **Agent Commits**: Agents may commit directly when signing works non-interactively. If signing would block on a GPG/pinentry prompt, stop and prompt the user to make the commit manually with `jj commit -m "message"` so the GPG agent cache is warmed first.

## Repository Structure
- Profiles: `nvim/{default,work,personal}` deployed via dotter (don't edit `~/.config/nvim` directly!)
- Packages: Select ONE profile (personal/work), ONE platform (mac/linux), ONE theme (monokai/nightowl/tokyonight)
- Profile inheritance: `work` and `personal` depend on `default` via `depends = ["default"]`
- Secrets: Never commit `local.toml` (use `local.toml.example` as template)

## Platform-Specific Init

- **`./init.sh`** bootstraps a new machine: cross-distro package install (from `packages-<distro>.txt`), oh-my-zsh, tpm, zsh-completions, carapace (via Gemfury on RPM distros or direct binary), zoxide, atuin, starship, then `dotter deploy -f`
- Distro detection: reads `/etc/os-release` and selects the appropriate `packages-<ID>.txt`
- macOS uses Homebrew (`Brewfile`) instead of package lists
- zshrc guards tool-specific `eval "$(...)"` with `(( ${+commands[tool]} ))` to prevent errors when tools are not yet installed
- zshenv is POSIX-compatible for non-interactive shells (MCP servers); zshrc is zsh-only

## Shell Design Conventions
- `~/.zshenv`: POSIX-compatible env loading for ALL shells (non-interactive safe)
- `~/.zshrc`: interactive-only, zsh-specific syntax (arithmetic expansion, `autoload`, `zstyle`)
- `~/.bashrc` (if any): NEVER source `~/.zshrc` from bash — they are incompatible
- Tools with init scripts (`zoxide init`, `atuin init`, `starship init`) must be guarded with `command -v` or `(( ${+commands[...]} ))` checks to avoid errors on missing binaries

## Commit Attribution (Co-authored-by)

When agents commit changes in this dotfiles repository or any other repo, they **must** include AI co-author attribution in the `Co-authored-by` trailer for transparency.

The system supports **per-command model attribution** via the `AI_CO_AUTHOR` shell environment variable. Agents should set this variable before committing. If not set, a generic placeholder is used.

### Git Commits

The Git `prepare-commit-msg` hook in `~/.config/git/hooks/prepare-commit-msg` automatically appends `Co-authored-by`. It respects `$AI_CO_AUTHOR` if set, otherwise falls back to `Co-authored-by: AI Model <ai@example.com>`.

```bash
# Example: Commit with proper attribution
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" git commit -m "feat: add new feature"

# Or use the convenience wrapper (passes through to git commit)
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" gitc -m "feat: add new feature"
```

### Jujutsu (jj) Commits

JJ configs do not support environment variable interpolation, but the shell helpers `jjc` and `jjd` handle attribution automatically:

```bash
# Commit with proper attribution (uses AI_CO_AUTHOR env var)
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" jjc "feat: add new feature"

# Describe current working copy without creating new commit
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" jjd "fix: correct typo"
```

If not using the wrappers, manually append the line:
```bash
jj commit -m "feat: add new feature

Co-authored-by: Kimi <kimi-k2.6:cloud@ai>"
```

### Required Action Before Committing

1. **Identify the active model**: Check the `opencode_*_agent_model` variables in `.dotter/global.toml`
2. **Set the env var**: Export `AI_CO_AUTHOR` with the correct identity (see mapping below)
3. **Commit**: Use `git commit`, `gitc`, `jjc`, or `jjd` as appropriate

### Model Identity Mapping

| Profile | Model (as of current config) | Co-authored-by |
|---|---|---|
| Personal | `ollama-cloud/kimi-k2.6:cloud` | `Kimi <kimi-k2.6:cloud@ai>` |
| Work | `openai/gpt-5.4` | `GPT-5.4 <gpt-5.4@ai>` |
| Plan/Test | Check `opencode_*_agent_model` | Use the model name from config |

**Format**: Extract the model name from the config value. For `ollama-cloud/kimi-k2.6:cloud`, use `Kimi <kimi-k2.6:cloud@ai>`. For `openai/gpt-5.4`, use `GPT-5.4 <gpt-5.4@ai>`.

**Note**: The `gitc`, `jjc`, and `jjd` shell functions are defined in `zshrc` and are deployed via dotter. After deployment, reload your shell or source `~/.zshrc` to use them.
