---
inclusion: auto
---

# Dotfiles Repository Conventions

- **Deploy**: `dotter deploy -f`
- **Profiles**: Select ONE of personal/work, ONE of mac/linux, ONE of monokai/nightowl/tokyonight
- **Profile inheritance**: `work` and `personal` depend on `default` via `depends = ["default"]`
- **Nvim**: Edit profiles in `nvim/{default,work,personal}`, never `~/.config/nvim` directly
- **Secrets**: Never commit `local.toml`
- **Shell conventions**: `~/.zshenv` is POSIX-compatible; `~/.zshrc` is zsh-only interactive
- **Version control**: Use Jujutsu (jj) — commits must be GPG signed
- **Commit style**: Conventional commits (fix:, feat:, chore:, docs:)
- **Co-authored-by**: Include AI attribution trailer on agent commits

## Commit Attribution

Set `AI_CO_AUTHOR` before committing. For Kiro sessions use:
```
jj commit -m "feat: description

Co-authored-by: Kiro <kiro@ai>"
```
