import _shared

# ── Default profile ────────────────────────────────────────────────────
default = _shared.Profile {
    files = {
        gitconfig = { target = "~/.config/git/dotter-gitconfig", type = "template" }
        "git/commit-template" = "~/.git-commit-template"
        "git/hooks/prepare-commit-msg" = { target = "~/.config/git/hooks/prepare-commit-msg", type = "template" }
        "out/shared/env.toml" = { target = "~/.config/shared/env.toml", type = "template" }
        "out/shared/completions.toml" = "~/.config/shared/completions.toml"
        "atuin/bin" = "~/.atuin/bin"
        "out/atuin/config.toml" = "~/.config/atuin/config.toml"
        "pnpm/rc" = "~/.config/pnpm/rc"
        "out/tmux.conf" = { target = "~/.tmux.conf", type = "template" }
        zshenv = { target = "~/.zshenv", type = "template" }
        zshrc = { target = "~/.zshrc", type = "template" }
        carapace = "~/.config/carapace"
        "out/ghostty/config" = { target = "~/.config/ghostty/config", type = "template" }
        iamb = "~/.config/iamb"
        nushell = { target = "~/.config/nushell", type = "template" }
        "out/starship.toml" = "~/.config/starship.toml"
        jj = { target = "~/.config/jj", type = "template" }
        "nvim/default" = { target = "~/.config/nvim", type = "template" }
        "opencode/.gitignore" = { target = "~/.config/opencode/.gitignore", type = "symbolic" }
        "opencode/AGENTS.md" = { target = "~/.config/opencode/AGENTS.md", type = "symbolic" }
        "opencode/command/review.md" = { target = "~/.config/opencode/command/review.md", type = "symbolic" }
        "opencode/prompt" = { target = "~/.config/opencode/prompt", type = "symbolic" }
        "opencode/opencode.jsonc" = { target = "~/.config/opencode/opencode.jsonc", type = "template" }
        "opencode/script" = { target = "~/.config/opencode/script", type = "symbolic" }
        "claude-desktop" = { target = "~/Library/Application Support/Claude", type = "template" }
        "claude-code/CLAUDE.md" = { target = "~/.claude/CLAUDE.md", type = "template" }
        "claude-code/settings.json" = { target = "~/.claude/settings.json", type = "template" }
        "shared/commands/go.md" = { target = "~/.claude/commands/go.md", type = "symbolic" }
        "shared/commands/fix-pipeline.md" = { target = "~/.claude/commands/fix-pipeline.md", type = "symbolic" }
        "shared/commands/coderabbit-review.md" = { target = "~/.claude/commands/coderabbit-review.md", type = "symbolic" }
        "claude-code/commands/review.md" = { target = "~/.claude/commands/review.md", type = "symbolic" }
        "claude-code/commands/jj-fix-conflicts.md" = { target = "~/.claude/commands/jj-fix-conflicts.md", type = "symbolic" }
        gitlogue = "~/.config/gitlogue"
        "agents/skills" = { target = "~/.agents/skills", type = "symbolic" }
    }
    variables = {
        name = ""
        email = ""
        username = "chanderson"
        vim_set_num_relnum = "set number relativenumber"
        gpg_key = ""
        github_personal_access_token = ""
        gitea_url = ""
        gitea_token = ""
        home_assistant_url = ""
        home_assistant_token = ""
        home_assistant_webhook_id = ""
        playdate_sdk_enabled = False
        bartender_hooks_enabled = False
        claude_remote_tools_device_name = "mac-mini"
        claude_model = "opus"
        claude_effort_level = "high"
        claude_plugin_pyright_lsp = False
        claude_plugin_extra_lsps = True
        claude_model_at_top = True
        claude_plugin_clangd_lsp = False
        mcp_obsidian_enabled = False
        mcp_obsidian_url = ""
        mcp_obsidian_token = ""
        bluesky_handle = ""
        bluesky_app_password = ""
        plex_user_token = ""
        plex_server_token = ""
        plex_url = ""
        tmdb_key = ""
        youtube_api_key = ""
        google_places_api_key = ""
        slack_d_cookie = ""
        slack_token = ""
        reddit_session = ""
        reddit_token_v2 = ""
        brave_search_api_key = ""
        proton_user = ""
        proton_password = ""
        telegram_bot_token = ""
    }
}

# ── Personal profile ───────────────────────────────────────────────────
personal = _shared.Profile {
    depends = ["default"]
    files = {
        "nvim/personal" = { target = "~/.config/nvim", type = "template" }
    }
    variables = {
        opencode_profile_personal = True
        mcp_coderabbit = False
        mcp_home_assistant_enabled = False
        mcp_netlify = True
        opencode_build_agent_model = "ollama-cloud/kimi-k2.6:cloud"
        opencode_plan_agent_model = "ollama-cloud/gemma4:31b"
        opencode_test_agent_model = "ollama-cloud/glm-5.1"
        opencode_review_agent_model = "ollama-cloud/glm-5.1"
        claude_agent_push_notif_enabled = True
        claude_bypass_permissions_account_id = "c5055d6d-b6e9-46de-a26f-0dad4c6255fc"
        claude_bypass_permissions_value = True
        claude_bypass_permissions_extras_enabled = True
        claude_cowork_scheduled_tasks_enabled = True
        claude_epitaxy_personal_prefs_enabled = True
        claude_effort_level_enabled = True
    }
}

# ── Work profile ────────────────────────────────────────────────────────
work = _shared.Profile {
    depends = ["default"]
    files = {
        "nvim/work" = { target = "~/.config/nvim", type = "template" }
        "opencode/plugin/slack-workflow.ts" = { target = "~/.config/opencode/plugin/slack-workflow.ts", type = "template" }
        "opencode/script/lwc-lsp-wrapper.sh" = { target = "~/.config/opencode/script/lwc-lsp-wrapper.sh", type = "symbolic" }
    }
    variables = {
        opencode_profile_work = True
        mcp_salesforce_dx_enabled = False
        mcp_atlassian_enabled = False
        mcp_odaseva_enabled = False
        mcp_postman_enabled = True
        mcp_sonarqube_enabled = True
        postman_api_key = ""
        sonarqube_url = ""
        sonarqube_token = ""
        gitlab_personal_access_token = ""
        gitlab_api_url = "https://gitlab.com/api/v4"
        gitlab_url = ""
        opencode_slack_webhook_url = ""
        opencode_build_agent_model = "openai/gpt-5.4"
        opencode_plan_agent_model = "openai/gpt-5.4"
        opencode_test_agent_model = "openai/gpt-5.4"
        opencode_review_agent_model = "openai/gpt-5.4"
        node_extra_ca_certs = ""
        p10k_root_dir = ""
        claude_agent_push_notif_enabled = False
        claude_bypass_permissions_account_id = "cc63eabd-b672-4570-871a-fd0d4607e75d"
        claude_bypass_permissions_value = False
        claude_bypass_permissions_extras_enabled = False
        claude_cowork_scheduled_tasks_enabled = False
        claude_epitaxy_personal_prefs_enabled = False
        claude_effort_level_enabled = False
    }
}

# ── Platform profiles ─────────────────────────────────────────────────
linux = _shared.Profile {
    files = {
        hypr = "~/.config/hypr"
    }
    variables = {
        shell_bin_path = "/usr/bin"
    }
}

mac = _shared.Profile {
    files = {
        "out/aerospace.toml" = "~/.aerospace.toml"
    }
    variables = {
        shell_bin_path = "/opt/homebrew/bin"
    }
}

oda_mcp = _shared.Profile {}
