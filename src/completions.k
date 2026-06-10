import _shared

# ── Completions config ─────────────────────────────────────────────────
_nu_raw = "open ~/.config/nushell/completions/"

completions = _shared.CompletionsConfig {
    tools = {
        acli = { zsh = "acli completion zsh", nu = _nu_raw + "acli.nu --raw" }
        atuin = { zsh = "", nu = "atuin gen-completions --shell nushell" }
        backlog = { zsh = "", nu = _nu_raw + "backlog.nu --raw" }
        carapace = { zsh = "", nu = "carapace _carapace nushell" }
        clawdbot = { zsh = "", nu = "" }
        dotter = { zsh = "dotter gen-completions --shell zsh", nu = _nu_raw + "dotter.nu --raw" }
        pixlet = { zsh = "pixlet completion zsh", nu = _nu_raw + "pixlet.nu --raw" }
        jj = { zsh = "jj util completion zsh", nu = "jj util completion nushell" }
        netlify = { zsh = "cat ~/.config/tabtab/zsh/netlify.zsh", nu = "" }
        opencode = { zsh = "opencode completion zsh", nu = _nu_raw + "opencode.nu --raw" }
        openclaw = { zsh = "cat ~/.openclaw/completions/openclaw.zsh", nu = "" }
        pnpm = { zsh = "pnpm completion zsh", nu = "" }
        sf = { zsh = "", nu = "" }
        starship = { zsh = "starship completions zsh", nu = "" }
        workmux = { zsh = "workmux completions zsh", nu = "" }
        zoxide = { zsh = "", nu = "" }
    }
}
