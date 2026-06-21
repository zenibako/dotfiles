#!/usr/bin/env python3
"""Validate Claude Code settings.json and report configured MCP servers."""
import json, sys

path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    print(f'ERROR: Invalid JSON in {path}: {e}', file=sys.stderr)
    sys.exit(1)
servers = data.get('mcpServers', {})
names = ', '.join(servers.keys())
print(f'  Claude Code settings OK ({len(servers)} MCP servers: {names})')
