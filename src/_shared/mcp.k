import json

# ── Shared MCP Server Definitions ───────────────────────────────────
# Single source of truth for MCP servers used by OpenCode, Claude Desktop,
# Claude Code, Codex, and Kiro.

_SHELL_PATH = "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin"

# Canonical server name → flag-slug mapping. Profiles declare which servers to
# include via a single `mcp_included = ["Jujutsu", "GitHub", ...]` array; this
# map expands that array into the per-server `mcp_<slug>_included` booleans used
# by the Handlebars conditionals below.
_MCP_SERVER_SLUGS = {
    "Jujutsu" = "jujutsu"
    "GitHub" = "github"
    "Backlog" = "backlog"
    "Playwright" = "playwright"
    "Chrome DevTools" = "chrome_devtools"
    "Obsidian" = "obsidian"
    "Salesforce DX" = "salesforce_dx"
    "Atlassian" = "atlassian"
    "Postman" = "postman"
    "SonarQube" = "sonarqube"
    "Netlify" = "netlify"
    "Neovim" = "neovim"
    "Home Assistant" = "home_assistant"
    "Gitea" = "gitea"
    "GitLab" = "gitlab"
}

# Derived variable names: {"Jujutsu": "mcp_jujutsu_included", ...}
_MCP_FLAG_NAMES = {
    name: "mcp_" + slug + "_included"
    for name, slug in _MCP_SERVER_SLUGS
}

# Expand an `mcp_included` list into a dict of dotter variables.
# Merged into each profile's `variables` block in src/profiles.k.
included_map = lambda included {
    {
        flag: name in included
        for name, flag in _MCP_FLAG_NAMES
    }
}

# Expand a variables dict that contains `mcp_included` into a dict that also
# contains the per-server `mcp_<slug>_included` boolean flags dotter templates
# need. Safe to call when `mcp_included` is absent; in that case no flags are
# added. This lets default/personal/work/local each declare only the array while
# the per-server booleans are derived in exactly one place per profile.
expand_mcp_included = lambda variables {
    variables | included_map(variables.mcp_included) if "mcp_included" in variables else variables
}

# Profile-level default inclusion lists. These are the MCPs a personal or work
# machine expects unless local.k overrides `mcp_included`.
MCP_PERSONAL = ["Jujutsu", "GitHub", "Backlog", "Obsidian", "Home Assistant"]
MCP_WORK = ["Jujutsu", "GitHub", "Backlog", "Atlassian", "Postman", "SonarQube"]

# Compute the effective `mcp_included` list for this machine. The local.k
# override wins, then the active dotter profile (personal/work), then none.
effective_mcp_included = lambda packages, variables {
    variables.mcp_included if "mcp_included" in variables else \
    MCP_PERSONAL if "personal" in packages else \
    MCP_WORK if "work" in packages else []
}

# Build the OpenCode `mcp` dict for a given inclusion list. ALL servers are
# emitted so project-level configs can flip individual servers on without
# needing to duplicate connection details. Included servers get `enabled: true`;
# excluded servers get `enabled: false` so they don't load or contribute tools
# to context.
opencode_mcp_for = lambda included {
    {
        s.name: {
            k: v
            for k, v in s.opencode
            if k != "enabled"
        } | {"enabled": s.name in included}
        for s in _mcp_servers
    }
}


_mcp_servers = [
    {
        name = "Jujutsu"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/npx", "-y", "jj-mcp-server"]
            "environment" = {"PATH" = _SHELL_PATH}
            "enabled" = "{{mcp_jujutsu_included}}"
        }
        claude = {
            "command" = "{{shell_bin_path}}/npx"
            "args" = ["-y", "jj-mcp-server"]
            "env" = {"PATH" = _SHELL_PATH}
        }
    }
    {
        name = "GitHub"
        # Remote GitHub MCP server. GitHub doesn't support Dynamic Client
        # Registration so OAuth won't work. Auth token injected at deploy
        # time from `gh auth token` via post_deploy.sh.
        opencode = {
            "type" = "remote"
            "url" = "https://api.githubcopilot.com/mcp/"
            "oauth" = False
            "headers" = {}
            "enabled" = "{{mcp_github_included}}"
        }
        # Claude Desktop's config schema only supports stdio servers, so this
        # remote server is added natively as a Custom Connector via the Claude
        # Settings → Connectors UI (URL: https://api.githubcopilot.com/mcp/),
        # which lives in Claude's internal storage and can't be managed here.
        claude = None
    }
    {
        name = "Backlog"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/backlog", "mcp", "start"]
            "enabled" = "{{mcp_backlog_included}}"
        }
        claude = {
            "command" = "{{shell_bin_path}}/backlog"
            "args" = ["mcp", "start"]
        }
    }
    {
        name = "Playwright"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/npx", "-y", "@playwright/mcp@latest"]
            "environment" = {"PATH" = _SHELL_PATH}
            "enabled" = "{{mcp_playwright_included}}"
        }
        claude = {
            "command" = "{{shell_bin_path}}/npx"
            "args" = ["-y", "@playwright/mcp@latest"]
            "env" = {"PATH" = _SHELL_PATH}
        }
    }
    {
        name = "Chrome DevTools"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/npx", "-y", "chrome-devtools-mcp@latest", "--launch"]
            "environment" = {"PATH" = _SHELL_PATH}
            "enabled" = "{{mcp_chrome_devtools_included}}"
        }
        claude = {
            "command" = "{{shell_bin_path}}/npx"
            "args" = ["-y", "chrome-devtools-mcp@latest", "--launch"]
            "env" = {"PATH" = _SHELL_PATH}
        }
    }
    {
        name = "Obsidian"
        # Local REST API plugin's built-in MCP endpoint (streamable HTTP).
        # Personal-profile only: gated on mcp_obsidian_included (True in the
        # personal profile, False in default/work). url + token injected by
        # patch_opencode_secrets.py at post-deploy.
        opencode = {
            "type" = "remote"
            "url" = "{{mcp_obsidian_url}}"
            "oauth" = False
            "headers" = {}
            # Rendered as a bare boolean via the .replace() in opencode_config.k.
            "enabled" = "{{mcp_obsidian_included}}"
        }
        # Claude Desktop's mcpServers has no per-server "enabled" flag, so the
        # whole entry must be wrapped in a Handlebars {{#if}} guard. KCL can't
        # emit that through json.encode, so it is spliced in as raw text by
        # claude.k (see the _obsidian_entry block there); None excludes it here.
        claude = None
    }
    {
        name = "Salesforce DX"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/npx", "-y", "@salesforce/mcp", "--orgs", "DEFAULT_TARGET_ORG", "--toolsets", "all", "--allow-non-ga-tools"]
            "environment" = {"PATH" = _SHELL_PATH}
            "enabled" = "{{mcp_salesforce_dx_included}}"
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "Atlassian"
        opencode = {
            "type" = "remote"
            "url" = "https://mcp.atlassian.com/v1/mcp"
            "oauth" = False
            "headers" = {}
            "enabled" = "{{mcp_atlassian_included}}"
        }
        # Native Custom Connector in Claude (Settings → Connectors UI).
        # URL: https://mcp.atlassian.com/v1/mcp — not managed by this config.
        claude = None
    }
    {
        name = "Postman"
        opencode = {
            "type" = "remote"
            "url" = "https://mcp.postman.com/mcp"
            "oauth" = False
            "headers" = {}
            "enabled" = "{{mcp_postman_included}}"
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "SonarQube"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/docker", "run", "--init", "--pull=always", "-i", "--rm", "-e", "SONARQUBE_URL", "-e", "SONARQUBE_TOKEN", "mcp/sonarqube"]
            "environment" = {
                "DOCKER_CONTEXT" = "colima"
                "PATH" = _SHELL_PATH
                "SONARQUBE_URL" = "{{sonarqube_url}}"
                "SONARQUBE_TOKEN" = "{{sonarqube_token}}"
            }
            "enabled" = "{{mcp_sonarqube_included}}"
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "Netlify"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/npx", "-y", "@netlify/mcp"]
            "environment" = {"PATH" = _SHELL_PATH}
            "enabled" = "{{mcp_netlify_included}}"
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "Neovim"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/npx", "-y", "mcp-neovim-server"]
            "environment" = {
                "ALLOW_SHELL_COMMANDS" = "true"
                "NVIM_SOCKET_PATH" = "/tmp/nvim"
                "PATH" = _SHELL_PATH
            }
            "enabled" = "{{mcp_neovim_included}}"
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "Home Assistant"
        # Token injected by patch_opencode_secrets.py at post-deploy.
        opencode = {
            "type" = "remote"
            "url" = "{{home_assistant_url}}/api/mcp"
            "oauth" = False
            "headers" = {}
            "enabled" = "{{mcp_home_assistant_included}}"
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "Gitea"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/npx", "-y", "gitea-mcp"]
            "environment" = {
                "PATH" = _SHELL_PATH
                "GITEA_HOST" = "{{gitea_url}}"
                "GITEA_ACCESS_TOKEN" = "{{gitea_token}}"
            }
            "enabled" = "{{mcp_gitea_included}}"
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "GitLab"
        opencode = {
            "type" = "remote"
            "url" = "{{gitlab_url}}/api/v4/mcp"
            # Gated on mcp_gitlab_included (off by default). The self-hosted MCP
            # endpoint only exists when the instance has GitLab Duo +
            # beta/experimental features enabled; otherwise it 404s. Rendered as
            # a bare boolean via the .replace() in opencode_config.k.
            "oauth" = False
            "headers" = {}
            "enabled" = "{{mcp_gitlab_included}}"
        }
        # Native Custom Connector in Claude (Settings → Connectors UI).
        # URL: {{gitlab_url}}/api/v4/mcp — not managed by this config.
        claude = None
    }
]

# Build Claude Desktop mcpServers dict from shared definitions
# Only include servers that have a claude representation
mcp_claude = {s.name: s.claude for s in _mcp_servers if s.claude}

# Build Kiro mcpServers dict from shared definitions
# Only include servers that have a kiro representation
mcp_kiro = {s.name: s.kiro for s in _mcp_servers if s.kiro}
