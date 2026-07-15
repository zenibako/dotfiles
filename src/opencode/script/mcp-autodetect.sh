#!/bin/sh
# Detects git remotes and writes a project-level opencode.json to enable
# relevant MCP servers. Designed to run from a zsh chpwd hook or manually.
#
# Usage: mcp-autodetect.sh [project-dir]
# Defaults to current directory.
#
# Detection rules:
#   - Gitea remote (git.chanderson.tech) → enable Gitea MCP
#   - GitLab remote (gitlab.com or self-hosted) → enable GitLab MCP
#   - Salesforce project (sfdx-project.json) → enable Salesforce DX MCP
#   - Atlassian markers (.jira config) → enable Atlassian MCP
#
# Conservatively scoped — only enables MCPs that have clear project signals.
# Chrome DevTools, Playwright, Obsidian, and Home Assistant are NOT auto-detected
# because they produce too many false positives. Users can enable those manually
# per-project via .opencode/opencode.json.
#
# The script writes .opencode/opencode.json with {"mcp": {...}} overrides.
# OpenCode merges project config on top of global, so disabled servers in
# global can be flipped on here without duplicating connection details.
# Re-runs are idempotent: the file is rewritten each time.

set -eu

DIR="${1:-$(pwd)}"
OPCODE_FILE="$DIR/.opencode/opencode.json"

MCP_ENABLE=""

# --- Git remote based detection ---

if git -C "$DIR" remote -v 2>/dev/null | grep -q "git\.chanderson\.tech"; then
    MCP_ENABLE="${MCP_ENABLE},\"Gitea\": {\"enabled\": true}"
fi

if git -C "$DIR" remote -v 2>/dev/null | grep -q "gitlab\.com"; then
    MCP_ENABLE="${MCP_ENABLE},\"GitLab\": {\"enabled\": true}"
fi

# Also check jj remotes if jj is available
if command -v jj >/dev/null 2>&1; then
    if jj git remote list 2>/dev/null | grep -q "git\.chanderson\.tech"; then
        MCP_ENABLE="${MCP_ENABLE},\"Gitea\": {\"enabled\": true}"
    fi
    if jj git remote list 2>/dev/null | grep -q "gitlab\.com"; then
        MCP_ENABLE="${MCP_ENABLE},\"GitLab\": {\"enabled\": true}"
    fi
fi

# --- File-based detection ---

if [ -f "$DIR/sfdx-project.json" ] || [ -d "$DIR/.sfdx" ]; then
    MCP_ENABLE="${MCP_ENABLE},\"Salesforce DX\": {\"enabled\": true}"
fi

if [ -f "$DIR/.jira" ] || [ -f "$DIR/.acli" ]; then
    MCP_ENABLE="${MCP_ENABLE},\"Atlassian\": {\"enabled\": true}"
fi

# If nothing to enable, remove stale config and exit
if [ -z "$MCP_ENABLE" ]; then
    rm -f "$OPCODE_FILE" 2>/dev/null
    exit 0
fi

# Strip leading comma
MCP_ENABLE="${MCP_ENABLE#,}"

# Write the project config
mkdir -p "$DIR/.opencode"
cat > "$OPCODE_FILE" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "mcp": {
    $MCP_ENABLE
  }
}
EOF

# Add to project .gitignore if not already present
if [ -f "$DIR/.gitignore" ]; then
    if ! grep -qx ".opencode/opencode.json" "$DIR/.gitignore" 2>/dev/null; then
        printf '\n# OpenCode MCP auto-detection\n.opencode/opencode.json\n' >> "$DIR/.gitignore"
    fi
fi

echo "mcp-autodetect: wrote $OPCODE_FILE"