import _shared.templates as tpl

# ── Constants ───────────────────────────────────────────────────────────
_gpg_backend = "gpg"
_builtin_editor = ":builtin"
_sign_all = True

# ── jj config (TOML template) ──────────────────────────────────────────
jj = {
    user = {
        name = tpl.hb("name")
        email = tpl.hb("email")
    }
    ui = {
        default_command = ["log", "--limit", "5"]
        diff_editor = _builtin_editor
        show_cryptographic_signatures = True
    }
    signing = {
        sign_all = _sign_all
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
