---
inclusion: auto
---

# Dotfiles Workspace Conventions

- **Deploy**: `dotter deploy -f` (templates from .dotter/global.toml)
- **KCL configs**: Shared MCP definitions in `src/_shared/mcp.k`, opencode config in `src/opencode_config.k`
- **Profiles**: personal (opencode-go/glm-5.2), work (openai/gpt-5.4)
- **Shell**: zshenv is POSIX; zshrc is zsh-only interactive
- **VCS**: Jujutsu with GPG signing. Never bypass signing.
- **Secrets**: Never commit `local.toml`
- **Nvim profiles**: Edit in `nvim/{default,work,personal}`, not `~/.config/nvim`
