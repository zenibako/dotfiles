import _shared.templates as tpl

# ── Constants ───────────────────────────────────────────────────────────
_gpg_backend = "gpg"
_builtin_editor = ":builtin"
# jj >= 0.30 replaced the boolean `signing.sign_all` with the `signing.behavior`
# enum; the old key is silently ignored (behavior defaults to "keep" = never
# auto-sign). "own" signs commits authored by the configured user.
_signing_behavior = "own"

# ── jj config (TOML template) ──────────────────────────────────────────
jj = {
    user = {
        name = tpl.hb("name")
        email = tpl.hb("email")
    }
    ui = {
        "default-command" = ["log", "--limit", "5"]
        diff_editor = _builtin_editor
        show_cryptographic_signatures = True
    }
    signing = {
        behavior = _signing_behavior
        backend = _gpg_backend
        key = tpl.hb("gpg_key")
    }
    merge_tools = {
        diffconflicts = {
            program = "nvim"
            merge_args = [
                "-c", "let g:jj_diffconflicts_marker_length=$marker_length",
                "-c", "JJDiffConflicts!",
                "$output", "$base", "$left", "$right"
            ]
            merge_tool_edits_conflict_markers = True
        }
    }
}
