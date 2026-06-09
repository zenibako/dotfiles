import _shared

# ── Completions config ─────────────────────────────────────────────────
completions = _shared.CompletionsConfig {
    tools = {
        acli = { zsh = "acli completion zsh", nu = "open ~/.config/nushell/completions/acli.nu --raw" }
        atuin = { zsh = "", nu = "atuin gen-completions --shell nushell" }
        backlog = { zsh = "", nu = "open ~/.config/nushell/completions/backlog.nu --raw" }
        carapace = { zsh = "", nu = "carapace _carapace nushell" }
        clawdbot = { zsh = "", nu = "" }
        dotter = { zsh = "dotter gen-completions --shell zsh", nu = "open ~/.config/nushell/completions/dotter.nu --raw" }
        pixlet = { zsh = "pixlet completion zsh", nu = "open ~/.config/nushell/completions/pixlet.nu --raw" }
        jj = { zsh = "jj util completion zsh", nu = "jj util completion nushell" }
        netlify = { zsh = "cat ~/.config/tabtab/zsh/netlify.zsh", nu = "" }
        opencode = { zsh = "opencode completion zsh", nu = "open ~/.config/nushell/completions/opencode.nu --raw" }
        openclaw = { zsh = "cat ~/.openclaw/completions/openclaw.zsh", nu = "" }
        pnpm = { zsh = "pnpm completion zsh", nu = "" }
        sf = { zsh = "", nu = "" }
        starship = { zsh = "starship completions zsh", nu = "" }
        workmux = { zsh = "workmux completions zsh", nu = "" }
        zoxide = { zsh = "", nu = "" }
    }
}
