#!/usr/bin/env python3
"""Validate Claude Code settings.json and report configured MCP servers.

settings.json no longer carries MCP definitions: Claude Code ignores
`mcpServers` there. User-global MCP servers live in ~/.claude.json, so pass
that path as the optional second argument to report the live server list.

Usage: validate_cc_settings.py <settings.json> [mcp-source.json]
"""
import json
import sys

settings_path = sys.argv[1]
mcp_path = sys.argv[2] if len(sys.argv) > 2 else settings_path

try:
    with open(settings_path) as f:
        json.load(f)
except json.JSONDecodeError as e:
    print(f'ERROR: Invalid JSON in {settings_path}: {e}', file=sys.stderr)
    sys.exit(1)

servers = {}
try:
    with open(mcp_path) as f:
        servers = json.load(f).get('mcpServers', {})
except FileNotFoundError:
    pass
except json.JSONDecodeError as e:
    print(f'ERROR: Invalid JSON in {mcp_path}: {e}', file=sys.stderr)
    sys.exit(1)

names = ', '.join(servers.keys())
print(f'  Claude Code settings OK ({len(servers)} MCP servers: {names})')
