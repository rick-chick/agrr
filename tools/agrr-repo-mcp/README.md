# AGRR Repo MCP Server

Filesystem-derived MCP server for AGRR repository structure. Queries bounded contexts, crates, test commands, and frontend layers without reading Markdown documentation.

## Prerequisites

- Node.js 20+
- AGRR monorepo checkout (this package lives in `tools/agrr-repo-mcp`)

## Environment

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AGRR_REPO_ROOT` | no | workspace root (three levels above `src/`) | Repo root for filesystem queries |

## Install & start

```bash
cd tools/agrr-repo-mcp
npm install
npm start
```

## Cursor MCP config

Add to `.cursor/mcp.json` (or Cursor Settings → MCP):

```json
{
  "mcpServers": {
    "agrr-repo": {
      "command": "node",
      "args": ["tools/agrr-repo-mcp/src/index.mjs"]
    }
  }
}
```

Optional: set `AGRR_REPO_ROOT` if the server runs outside the default workspace layout.

## Tools

| Tool | Source |
|------|--------|
| `list_bounded_contexts` | `crates/agrr-domain/src/` directory names |
| `list_crates` | `crates/*/Cargo.toml` name and description |
| `list_test_commands` | Canonical test runner script paths and existence |
| `get_frontend_layers` | `frontend/src/app/{domain,usecase,adapters,components}/` |

Each tool response includes `generated_at` (ISO 8601). Reads use `crates/`, `frontend/`, and `scripts/` only (no Markdown).

## Tests

```bash
cd tools/agrr-repo-mcp
npm test
```

## Related

- [`tools/agrr-mcp/`](../../tools/agrr-mcp/) — crop setup API MCP (HTTP wrapper)
