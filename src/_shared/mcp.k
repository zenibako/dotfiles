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
            "enabled" = True
        }
        claude = {
            "command" = "{{shell_bin_path}}/npx"
            "args" = ["-y", "jj-mcp-server"]
            "env" = {"PATH" = _SHELL_PATH}
        }
    }
    {
        name = "GitHub"
        # Remote GitHub MCP server. Claude Code/Desktop are first-party OAuth
        # clients, so they authenticate automatically with no token in config.
        # opencode can't OAuth here (GitHub doesn't support Dynamic Client
        # Registration), so it uses a PAT bearer header sourced from local.toml
        # (Proton Pass), like the Home Assistant server.
        opencode = {
            "type" = "remote"
            "url" = "https://api.githubcopilot.com/mcp/"
            "headers" = {
                "Authorization" = "Bearer {{github_personal_access_token}}"
            }
            "enabled" = True
        }
        claude = {
            "type" = "http"
            "url" = "https://api.githubcopilot.com/mcp/"
        }
    }
    {
        name = "Backlog"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/backlog", "mcp", "start"]
            "enabled" = True
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
            "enabled" = True
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
            "enabled" = True
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
        # url + token come from local.toml (mac-mini's vault host + API key).
        opencode = {
            "type" = "remote"
            "url" = "{{mcp_obsidian_url}}"
            "headers" = {
                "Authorization" = "Bearer {{mcp_obsidian_token}}"
            }
            "enabled" = True
        }
        claude = {
            "command" = "{{shell_bin_path}}/npx"
                "args" = ["-y", "mcp-remote", "{{mcp_obsidian_url}}", "--allow-http", "--header", "Authorization:\${MCP_OBSIDIAN_AUTH}"]
            "env" = {
                "MCP_OBSIDIAN_AUTH" = "Bearer {{mcp_obsidian_token}}"
                "PATH" = _SHELL_PATH
            }
        }
    }
    {
        name = "Salesforce DX"
        opencode = {
            "type" = "local"
            "command" = ["{{shell_bin_path}}/npx", "-y", "@salesforce/mcp", "--orgs", "DEFAULT_TARGET_ORG", "--toolsets", "all", "--allow-non-ga-tools"]
            "environment" = {"PATH" = _SHELL_PATH}
            "enabled" = False
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "Atlassian"
        opencode = {
            "type" = "remote"
            "url" = "https://mcp.atlassian.com/v1/mcp"
            "enabled" = False
        }
        claude = {
            "type" = "http"
            "url" = "https://mcp.atlassian.com/v1/mcp"
        }
    }
    {
        name = "Postman"
        opencode = {
            "type" = "remote"
            "url" = "https://mcp.postman.com/mcp"
            "enabled" = False
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
            "enabled" = False
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
            "enabled" = False
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
            "enabled" = False
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "Home Assistant"
        opencode = {
            "type" = "remote"
            "url" = "{{home_assistant_url}}/api/mcp"
            "headers" = {
                "Authorization" = "Bearer {{home_assistant_token}}"
            }
            "enabled" = False
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
            "enabled" = False
        }
        # Not available in Claude Desktop
        claude = None
    }
    {
        name = "GitLab"
        opencode = {
            "type" = "remote"
            "url" = "{{gitlab_url}}/api/v4/mcp"
            "enabled" = False
        }
        claude = {
            "type" = "http"
            "url" = "{{gitlab_url}}/api/v4/mcp"
        }
    }
]

# Build OpenCode mcp dict from shared definitions
mcp_opencode = {s.name: s.opencode for s in _mcp_servers}

# Build Claude Desktop mcpServers dict from shared definitions
# Only include servers that have a claude representation
mcp_claude = {s.name: s.claude for s in _mcp_servers if s.claude}
