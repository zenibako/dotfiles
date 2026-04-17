---
name: n8n
description: >
  Manage n8n workflows via the REST API when the n8n MCP server lacks the needed
  operation (e.g. creating, updating, or deleting workflows). Use alongside the n8n
  MCP tools for read/execute operations, and fall back to curl for write operations.
compatibility: Requires n8n instance URL and API key (stored in dotter variables `n8n_mcp_url` and `n8n_mcp_token`).
metadata:
  author: chanderson
  version: "1.0"
---

# n8n REST API

## When to use

- When the n8n MCP tools don't support an operation (create, update, delete workflows)
- When you need to modify workflow nodes, settings, name, or description
- When you need to transfer workflows between instances or back them up

**Prefer n8n MCP tools** for: listing workflows, getting workflow details, executing workflows, publishing/unpublishing.

## Authentication

The n8n API uses **two** authentication mechanisms:

1. **MCP JWT Token** (`n8n_mcp_token`) — for the n8n MCP server (HTTP/Bearer auth)
2. **REST API Key** (`n8n_api_key`) — for the n8n REST API (`X-N8N-API-KEY` header)

Both are stored as dotter variables in `.dotter/local.toml`.

- **Base URL**: `n8n_mcp_url` variable (strip `/mcp-server/http` to get API root)
- **REST API Key**: `n8n_api_key` variable

Read these from `.dotter/local.toml` in the dotfiles repo, or from the deployed
opencode/claude configs.

```
# Example: derive API base URL from MCP URL
MCP_URL="https://n8n.chanderson.tech/mcp-server/http"
API_BASE="${MCP_URL%/mcp-server/http}/api/v1"
```

All REST API requests require the header:
```
X-N8N-API-KEY: <n8n_api_key>
```

## API Endpoints

### Workflows

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/workflows` | List all workflows |
| `GET` | `/api/v1/workflows/:id` | Get a specific workflow |
| `POST` | `/api/v1/workflows` | Create a new workflow |
| `PUT` | `/api/v1/workflows/:id` | Update a workflow |
| `DELETE` | `/api/v1/workflows/:id` | Delete a workflow |
| `POST` | `/api/v1/workflows/:id/activate` | Activate a workflow |
| `POST` | `/api/v1/workflows/:id/deactivate` | Deactivate a workflow |

### Executions

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/executions` | List executions |
| `GET` | `/api/v1/executions/:id` | Get execution details |
| `DELETE` | `/api/v1/executions/:id` | Delete an execution |

### Credentials

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/credentials` | List credentials (names only) |
| `GET` | `/api/v1/credentials/:id` | Get credential by ID |
| `POST` | `/api/v1/credentials` | Create credential |
| `DELETE` | `/api/v1/credentials/:id` | Delete credential |

### Tags

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/tags` | List tags |
| `POST` | `/api/v1/tags` | Create tag |

## Common Examples

### List workflows
```bash
curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$API_BASE/workflows" | jq '.data[] | {id, name, active}'
```

### Get a workflow
```bash
curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$API_BASE/workflows/WORKFLOW_ID" | jq '.data'
```

### Update a workflow (e.g. rename a node)
```bash
# Get current workflow first, save to temp file
TMP=$(mktemp)
curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$API_BASE/workflows/WORKFLOW_ID" > "$TMP"

# Modify with jq, then PUT back (MUST use temp file for large JSON)
jq '(.nodes[] | select(.name == "Old Name")).name = "New Name"' "$TMP" | \
  jq '{name, nodes, connections, settings}' > "${TMP}.updated"

curl -s -X PUT -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"${TMP}.updated" \
  "$API_BASE/workflows/WORKFLOW_ID"

rm "$TMP" "${TMP}.updated"
```

### Create a workflow
```bash
curl -s -X POST -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Workflow",
    "nodes": [],
    "connections": {},
    "settings": {}
  }' \
  "$API_BASE/workflows"
```

### Activate/Deactivate
```bash
curl -s -X POST -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$API_BASE/workflows/WORKFLOW_ID/activate"

curl -s -X POST -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$API_BASE/workflows/WORKFLOW_ID/deactivate"
```

### Delete a workflow
```bash
curl -s -X DELETE -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$API_BASE/workflows/WORKFLOW_ID"
```

## Workflow Object Structure

When updating workflows, include all required fields:

```json
{
  "name": "Workflow Name",
  "nodes": [
    {
      "id": "uuid",
      "name": "Node Name",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [250, 300],
      "parameters": {}
    }
  ],
  "connections": {
    "Node A": {
      "main": [[{"node": "Node B", "type": "main", "index": 0}]]
    }
  },
  "settings": {
    "executionOrder": "v1"
  }
}
```

**Important**: When updating via `PUT`, only these fields are writable:
- `name` — workflow name
- `nodes` — array of node objects (full objects required)
- `connections` — connection map between nodes
- `settings` — workflow settings object (strict schema; known keys: `executionOrder`, `callerPolicy`, `availableInMCP`, `saveManualExecutions`, `saveDataSuccessExecution`, `saveDataErrorExecution`, `saveExecutionProgress`, `timezone`, `errorWorkflow`)

Read-only fields (returned by GET but rejected by PUT): `description`, `tags`, `active`, `id`, `createdAt`, `updatedAt`, `versionId`, `meta`, etc.

**Always GET first, modify only writable fields with jq, then PUT back.** Use temp files
for large workflow JSON (piping via bash variables breaks on control characters).

```bash
# Pattern: GET > jq filter > temp file > PUT
TMP=$(mktemp)
curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$API_BASE/workflows/ID" > "$TMP"
jq '{name, nodes, connections, settings}' "$TMP" > "${TMP}.out"
# ... edit "${TMP}.out" as needed ...
curl -s -X PUT -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" -d @"${TMP}.out" "$API_BASE/workflows/ID"
rm "$TMP" "${TMP}.out"
```

## Reading Credentials from Dotter

The API base URL and key can be read from the deployed configs or local.toml:

```bash
# From dotter local.toml
N8N_API_KEY=$(grep n8n_api_key ~/.dotter/local.toml | cut -d'"' -f2)
N8N_URL=$(grep n8n_mcp_url ~/.dotter/local.toml | cut -d'"' -f2)
API_BASE="${N8N_URL%/mcp-server/http}/api/v1"
```

## Gotchas

- The API base URL is different from the MCP URL: strip `/mcp-server/http` and append `/api/v1`
- PUT requests only accept `name`, `nodes`, `connections`, `settings` — other fields are read-only and rejected
- Use **temp files** for PUT payloads (bash variables break on JSON with control characters)
- When renaming a node, also update the `connections` map keys to match the new name
- Node IDs must be unique strings within a workflow
- The `typeVersion` field is required for each node and must match the node package version
- `description` and `tags` are read-only via API — set them in the n8n UI
- Workflow settings like `availableInMCP` control MCP visibility; update via settings in PUT
- The n8n MCP token and API key are JWTs that may expire — regenerate from n8n UI if you get 401s