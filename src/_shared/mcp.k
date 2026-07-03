import json

# ── Shared MCP Server Definitions ───────────────────────────────────
# Single source of truth for MCP servers used by both OpenCode and Claude Desktop.
# Each server defines its OpenCode and Claude Desktop representations.

_SHELL_PATH = "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin"

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
            "enabled" = "{{mcp_home_assistant_included}}"
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "Gitea"
        opencode = {
            "type" = "local"
            "command" = ["/Users/{{username}}/go/bin/forgejo-mcp", "stdio", "--server", "{{gitea_url}}", "--token", "{{gitea_token}}"]
            "environment" = {"PATH" = _SHELL_PATH}
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
            "enabled" = "{{mcp_gitlab_included}}"
        }
        # Native Custom Connector in Claude (Settings → Connectors UI).
        # URL: {{gitlab_url}}/api/v4/mcp — not managed by this config.
        claude = None
    }
]

# Build OpenCode mcp dict from shared definitions (used by Claude Desktop via
# the claude.k pipeline; OpenCode itself uses opencode_mcp_section below).
mcp_opencode = {s.name: s.opencode for s in _mcp_servers}

# OpenCode MCP section rendered with Handlebars conditionals so dotter can
# literally omit disabled servers at deploy time. The first entries are
# always enabled in the default profile; subsequent entries are gated on
# per-profile flags and prefixed with a comma so the JSON stays valid when
# they are omitted.
_opencode_mcp_always = """    "Jujutsu": {
      "type": "local",
      "command": [
        "{{shell_bin_path}}/npx",
        "-y",
        "jj-mcp-server"
      ],
      "environment": {
        "PATH": "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin"
      },
      "enabled": true
    },
    "GitHub": {
      "type": "remote",
      "url": "https://api.githubcopilot.com/mcp/",
      "oauth": false,
      "headers": {},
      "enabled": true
    },
    "Backlog": {
      "type": "local",
      "command": [
        "{{shell_bin_path}}/backlog",
        "mcp",
        "start"
      ],
      "enabled": true
    }"""

_opencode_mcp_conditional = [
    ["mcp_gitea_included", """    ,"Gitea": {
      "type": "local",
      "command": [
        "/Users/{{username}}/go/bin/forgejo-mcp",
        "stdio",
        "--server",
        "{{gitea_url}}",
        "--token",
        "{{gitea_token}}"
      ],
      "environment": {
        "PATH": "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin"
      },
      "enabled": true
    }"""],
    ["mcp_gitlab_included", """    ,"GitLab": {
      "type": "remote",
      "url": "{{gitlab_url}}/api/v4/mcp",
      "oauth": false,
      "headers": {},
      "enabled": true
    }"""],
    ["mcp_obsidian_included", """    ,"Obsidian": {
      "type": "remote",
      "url": "{{mcp_obsidian_url}}",
      "oauth": false,
      "headers": {}
    }"""],
    ["mcp_salesforce_dx_included", """    ,"Salesforce DX": {
      "type": "local",
      "command": [
        "{{shell_bin_path}}/npx",
        "-y",
        "@salesforce/mcp",
        "--orgs",
        "DEFAULT_TARGET_ORG",
        "--toolsets",
        "all",
        "--allow-non-ga-tools"
      ],
      "environment": {
        "PATH": "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    }"""],
    ["mcp_postman_included", """    ,"Postman": {
      "type": "remote",
      "url": "https://mcp.postman.com/mcp"
    }"""],
    ["mcp_sonarqube_included", """    ,"SonarQube": {
      "type": "local",
      "command": [
        "{{shell_bin_path}}/docker",
        "run",
        "--init",
        "--pull=always",
        "-i",
        "--rm",
        "-e",
        "SONARQUBE_URL",
        "-e",
        "SONARQUBE_TOKEN",
        "mcp/sonarqube"
      ],
      "environment": {
        "DOCKER_CONTEXT": "colima",
        "PATH": "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin",
        "SONARQUBE_URL": "{{sonarqube_url}}",
        "SONARQUBE_TOKEN": "{{sonarqube_token}}"
      }
    }"""],
    ["mcp_netlify_included", """    ,"Netlify": {
      "type": "local",
      "command": [
        "{{shell_bin_path}}/npx",
        "-y",
        "@netlify/mcp"
      ],
      "environment": {
        "PATH": "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    }"""],
    ["mcp_neovim_included", """    ,"Neovim": {
      "type": "local",
      "command": [
        "{{shell_bin_path}}/npx",
        "-y",
        "mcp-neovim-server"
      ],
      "environment": {
        "ALLOW_SHELL_COMMANDS": "true",
        "NVIM_SOCKET_PATH": "/tmp/nvim",
        "PATH": "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    }"""],
    ["mcp_home_assistant_included", """    ,"Home Assistant": {
      "type": "remote",
      "url": "{{home_assistant_url}}/api/mcp",
      "oauth": false,
      "headers": {}
    }"""],
    ["mcp_playwright_included", """    ,"Playwright": {
      "type": "local",
      "command": [
        "{{shell_bin_path}}/npx",
        "-y",
        "@playwright/mcp@latest"
      ],
      "environment": {
        "PATH": "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    }"""],
    ["mcp_chrome_devtools_included", """    ,"Chrome DevTools": {
      "type": "local",
      "command": [
        "{{shell_bin_path}}/npx",
        "-y",
        "chrome-devtools-mcp@latest",
        "--launch"
      ],
      "environment": {
        "PATH": "{{shell_bin_path}}:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    }"""],
]

# Build conditional blocks with leading commas so JSON stays valid when entries
# are omitted by dotter's Handlebars rendering.
_conditional_blocks = [
    "{{#if " + pair[0] + "}}" + pair[1] + "{{/if}}"
    for pair in _opencode_mcp_conditional
]

opencode_mcp_section = "{\n" + _opencode_mcp_always + "\n" + "\n".join(_conditional_blocks) + "\n  }"

# Build Claude Desktop mcpServers dict from shared definitions
# Only include servers that have a claude representation
mcp_claude = {s.name: s.claude for s in _mcp_servers if s.claude}

# Build Kiro mcpServers dict from shared definitions
# Only include servers that have a kiro representation
mcp_kiro = {s.name: s.kiro for s in _mcp_servers if s.kiro}
