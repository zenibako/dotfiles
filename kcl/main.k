import json
import schemas
import file

# ── Package lists ───────────────────────────────────────────────────────
packages = schemas.PackageList {
    fedora = ["fzf", "fd-find", "ripgrep", "zsh", "tmux", "git", "gh", "jq", "curl", "wget", "snapd", "golang", "cargo"]
    brew_taps = ["atlassian/acli", "borkdude/brew", "hashicorp/tap", "browsh-org/browsh", "clojure/tools", "gcenx/wine", "jichu4n/palm-os", "jonathanruiz/tap", "koekeishiya/formulae", "rsteube/tap", "sst/tap", "valkyrie00/bbrew", "zerotier/tap", "vladkens/tap"]
    brew_formulae = ["xz","autoconf","automake","openssl@3","readline","node","aws-cdk","acli","glib","bison","carapace","cmake","coreutils","cryptography","curl","docker","docker-buildx","docker-credential-helper","dotter","enchant","fastfetch","fd","gnutls","harfbuzz","pango","ffmpeg","fswatch","fzf","isl","gcc","gh","git","git-extras","glab","go","gopls","netpbm","graphviz","mermaid-cli","grep","homeassistant-cli","htop","hunspell","icu4c@76","imagemagick","openjdk","jdtls","jj","openjdk@21","jmeter","jq","libffi","libolm","libyaml","lua","lua-language-server","vscode-langservers-extracted","yaml-language-server","typescript-language-server","cue","starlark-rust","luarocks","make","maven","mosh","neovim","nghttp2","nushell","ollama","pandoc","pipx","pkl","pkl-lsp","pmd","pnpm","postgresql@14","prettier","protobuf","pyenv","python-yq","python@3.13","ripgrep","ruby","ruby-install","rust","sesh","sf","sonar-scanner","starship","stylua","termscp","terraform","hashicorp/tap/terraform-ls","tmux","tree-sitter","weechat","wget","xq","yarn","yt-dlp","zlib","zoxide","zsh","zsh-autosuggestions","zsh-completions","borkdude/brew/babashka","browsh-org/browsh/browsh","clojure/tools/clojure","jichu4n/palm-os/pilot-link","vladkens/tap/macmon","jonathanruiz/tap/wakey","rsteube/tap/carapace-spec","sst/tap/opencode","valkyrie00/bbrew/bbrew"]
    brew_casks = ["android-commandlinetools","android-platform-tools","font-hack-nerd-font","geekbench","ghostty","gpg-suite","mitmproxy","quakenotch","salesforce-cli","temurin","visual-studio-code","zap","zerotier-one"]
    vscode_extensions = [
        "alefragnani.project-manager",
        "amiralizadeh9480.cpp-helper",
        "astro-build.astro-vscode",
        "augustocdias.tasks-shell-input",
        "christian-kohler.npm-intellisense",
        "chrmarti.network-proxy-test",
        "chuckjonas.apex-pmd",
        "codezombiech.gitignore",
        "compulim.vscode-mocha",
        "cpylua.language-postcss",
        "cspotcode.vscode-mocha-latte",
        "dbaeumer.vscode-eslint",
        "docker.docker",
        "donjayamanne.githistory",
        "esbenp.prettier-vscode",
        "financialforce.lana",
        "github.copilot",
        "github.copilot-chat",
        "juanblanco.solidity",
        "kendoui.kendotemplatewizard",
        "linhmtran168.mac-ca-vscode",
        "marus25.cortex-debug",
        "mcu-debug.debug-tracker-vscode",
        "mcu-debug.memory-view",
        "mcu-debug.peripheral-viewer",
        "mcu-debug.rtos-views",
        "midouest.playdate-debug",
        "ms-azuretools.vscode-containers",
        "ms-azuretools.vscode-docker",
        "ms-dotnettools.vscode-dotnet-runtime",
        "ms-python.black-formatter",
        "ms-python.debugpy",
        "ms-python.isort",
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-toolsai.jupyter",
        "ms-toolsai.jupyter-keymap",
        "ms-toolsai.jupyter-renderers",
        "ms-toolsai.vscode-jupyter-cell-tags",
        "ms-toolsai.vscode-jupyter-slideshow",
        "ms-vscode-remote.remote-containers",
        "ms-vscode.cmake-tools",
        "ms-vscode.cpptools",
        "ms-vscode.cpptools-extension-pack",
        "ms-vscode.cpptools-themes",
        "ms-vscode.makefile-tools",
        "ms-vscode.remote-explorer",
        "ms-vscode.remote-server",
        "nomicfoundation.hardhat-solidity",
        "orta.vscode-jest",
        "piersdeseilligny.betterfountain",
        "redhat.vscode-xml",
        "salesforce.salesforce-vscode-slds",
        "salesforce.salesforcedx-einstein-gpt",
        "salesforce.salesforcedx-vscode",
        "salesforce.salesforcedx-vscode-apex",
        "salesforce.salesforcedx-vscode-apex-debugger",
        "salesforce.salesforcedx-vscode-apex-replay-debugger",
        "salesforce.salesforcedx-vscode-core",
        "salesforce.salesforcedx-vscode-expanded",
        "salesforce.salesforcedx-vscode-lightning",
        "salesforce.salesforcedx-vscode-lwc",
        "salesforce.salesforcedx-vscode-soql",
        "salesforce.salesforcedx-vscode-visualforce",
        "salesforce.sfdx-code-analyzer-vscode",
        "sumneko.lua",
        "twxs.cmake",
        "vscodevim.vscode-vim",
        "vue.volar",
        "ziyasal.vscode-open-in-github",
        "zxh404.vscode-proto3",
    ]
}

# ── Themes ─────────────────────────────────────────────────────────────
themes = {
    monokai = schemas.ThemeVariables {
        ghostty_theme = "Monokai Pro"
        ghostty_unfocused_split_fill = "#221f22"
        ghostty_split_divider_color = "#727072"
        nvim_colorscheme_plugin = "sainnhe/sonokai"
        nvim_colorscheme_config = """      vim.g.sonokai_enable_italic = true
      vim.g.sonokai_transparent_background = 1
      vim.cmd.colorscheme('sonokai')"""
        nvim_lualine_theme = "sonokai"
        tmux_theme_plugin = "zenibako/tmux-monokai-pro"
        tmux_theme_config = """
# Monokai theme configuration
set -g @monokai-plugins 'time battery cpu-usage ram-usage'
set -g @monokai-show-powerline true
set -g @monokai-show-left-sep ''
set -g @monokai-show-right-sep ''
"""
        nu_prompt_insert_color = "green_bold"
        nu_prompt_normal_color = "yellow_bold"
    }
    nightowl = schemas.ThemeVariables {
        ghostty_theme = "Night Owl"
        ghostty_unfocused_split_fill = "#011627"
        ghostty_split_divider_color = "#5f7e97"
        nvim_colorscheme_plugin = "oxfist/night-owl.nvim"
        nvim_colorscheme_config = """      require('night-owl').setup()
      vim.cmd.colorscheme('night-owl')"""
        nvim_lualine_theme = "night-owl"
        tmux_theme_plugin = "kylepeeler/tmux-nightowl"
        tmux_theme_config = """
# Nightowl theme configuration
set -g @nightowl-show-powerline true
set -g @nightowl-show-left-icon session
set -g @nightowl-show-left-sep ''
set -g @nightowl-show-right-sep ''
set -g @nightowl-military-time false
set -g @nightowl-cpu-usage true
set -g @nightowl-ram-usage true
set -g @nightowl-show-timezone true
set -g @nightowl-border-contrast true
"""
        nu_prompt_insert_color = "light_blue_bold"
        nu_prompt_normal_color = "light_purple_bold"
    }
    tokyonight = schemas.ThemeVariables {
        ghostty_theme = "TokyoNight Night"
        ghostty_unfocused_split_fill = "#1a1b26"
        ghostty_split_divider_color = "#283457"
        nvim_colorscheme_plugin = "folke/tokyonight.nvim"
        nvim_colorscheme_config = """      require('tokyonight').setup({
        style = 'night',
        transparent = true,
        terminal_colors = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          sidebars = 'transparent',
          floats = 'transparent',
        },
      })
      vim.cmd.colorscheme('tokyonight')"""
        nvim_lualine_theme = "tokyonight"
        tmux_theme_plugin = "janoamaral/tokyo-night-tmux"
        tmux_theme_config = """
# Tokyo Night theme configuration
set -g @tokyo-night-tmux_theme night
set -g @tokyo-night-tmux_transparent 0
set -g @tokyo-night-tmux_window_id_style fsquare
set -g @tokyo-night-tmux_pane_id_style hsquare
set -g @tokyo-night-tmux_zoom_id_style dsquare
set -g @tokyo-night-tmux_show_datetime 1
set -g @tokyo-night-tmux_date_format MYD
set -g @tokyo-night-tmux_time_format 12H
set -g @tokyo-night-tmux_show_path 1
set -g @tokyo-night-tmux_path_format relative
set -g @tokyo-night-tmux_show_battery_widget 0
set -g @tokyo-night-tmux_show_netspeed 0
set -g @tokyo-night-tmux_show_music 0
set -g @tokyo-night-tmux_show_hostname 0
"""
        nu_prompt_insert_color = "cyan_bold"
        nu_prompt_normal_color = "blue_bold"
    }
}

# ── Default profile ────────────────────────────────────────────────────
default = schemas.Profile {
    files = {
        gitconfig = { target = "~/.config/git/dotter-gitconfig", type = "template" }
        "git/commit-template" = "~/.git-commit-template"
        "git/hooks/prepare-commit-msg" = { target = "~/.config/git/hooks/prepare-commit-msg", type = "template" }
        "shared/env.toml" = { target = "~/.config/shared/env.toml", type = "template" }
        "shared/completions.toml" = "~/.config/shared/completions.toml"
        "atuin/bin" = "~/.atuin/bin"
        "atuin/config.toml" = "~/.config/atuin/config.toml"
        "pnpm/rc" = "~/.config/pnpm/rc"
        "tmux.conf" = { target = "~/.tmux.conf", type = "template" }
        zshenv = { target = "~/.zshenv", type = "template" }
        zshrc = { target = "~/.zshrc", type = "template" }
        carapace = "~/.config/carapace"
        "ghostty/config" = { target = "~/.config/ghostty/config", type = "template" }
        iamb = "~/.config/iamb"
        nushell = { target = "~/.config/nushell", type = "template" }
        "starship.toml" = "~/.config/starship.toml"
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
personal = schemas.Profile {
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
        claude_model_at_top = True
        claude_plugin_clangd_lsp = False
    }
}

# ── Work profile ────────────────────────────────────────────────────────
work = schemas.Profile {
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
        claude_model_at_top = True
        claude_plugin_clangd_lsp = False
    }
}

# ── Platform profiles ─────────────────────────────────────────────────
linux = schemas.Profile {
    files = {
        hypr = "~/.config/hypr"
    }
    variables = {
        shell_bin_path = "/usr/bin"
    }
}

mac = schemas.Profile {
    files = {
        "aerospace.toml" = "~/.aerospace.toml"
    }
    variables = {
        shell_bin_path = "/opt/homebrew/bin"
    }
}

oda_mcp = schemas.Profile {}

# ── Env config ─────────────────────────────────────────────────────────
env = schemas.EnvConfig {
    editor = "nvim"
    xdg_config_home = "$HOME/.config"
    venv_home = "$HOME/.virtualenvs"
    nvm_dir = "$HOME/.nvm"
    pnpm_home = "$HOME/Library/pnpm"
    sf_use_generic_unix_keychain = "true"
    sf_beta_track_file_moves = "true"
    lua_path = "/opt/homebrew/Cellar/luarocks/3.13.0_1/share/lua/5.5/?.lua;/opt/homebrew/Cellar/luarocks/3.12.2/share/lua/5.5/?.lua;/opt/homebrew/share/lua/5.5/?.lua;/opt/homebrew/share/lua/5.5/?/init.lua;/opt/homebrew/lib/lua/5.5/?.lua;/opt/homebrew/lib/lua/5.5/?/init.lua;./?.lua;./?/init.lua;$HOME/.luarocks/share/lua/5.5/?.lua;$HOME/.luarocks/share/lua/5.5/?/init.lua"
    lua_cpath = "/opt/homebrew/lib/lua/5.5/?.so;/opt/homebrew/lib/lua/5.5/loadall.so;./?.so;$HOME/.luarocks/lib/lua/5.5/?.so"
    path_prepend = [
        "{{shell_bin_path}}",
        "$HOME/.luarocks/bin",
        "$HOME/.cargo/bin",
        "$HOME/Library/pnpm/bin",
        "/opt/python27/bin",
        "$HOME/.local/bin",
    ]
    path_append = [
        "$HOME/go/bin",
        "$HOME/bin",
        "$HOME/.atuin/bin",
        "/usr/local/bin",
        "/Applications/Obsidian.app/Contents/MacOS",
    ]
}

# ── Completions config ─────────────────────────────────────────────────
completions = schemas.CompletionsConfig {
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

# ── Assemble and export ───────────────────────────────────────────────
config = schemas.ConfigMap {
    dotter = schemas.DotterConfig {
        default = default
        personal = personal
        work = work
        linux = linux
        mac = mac
        oda_mcp = oda_mcp
        themes = themes
        packages = packages
        settings = { default_target_type = "automatic" }
    }
    env = env
    completions = completions
}

# Write JSON for the Python converter
file.write("generated/config.json", json.encode(config, indent=2))
