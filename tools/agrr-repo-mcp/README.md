# AGRR Repo MCP Server

MCP server that exposes **filesystem-derived** facts about the AGRR monorepo structure. Agents query crate boundaries, bounded contexts, frontend layers, and test runner paths without relying on Markdown prose.

## Prerequisites

- Node.js 20+
- Repository root (auto-detected from `tools/agrr-repo-mcp/` or set `AGRR_REPO_ROOT`)

## Install & start

```bash
cd tools/agrr-repo-mcp
npm install
npm start
```

Optional: `AGRR_REPO_ROOT=/path/to/agrr npm start`

## Cursor MCP config

Add to `.cursor/mcp.json` (or Cursor Settings → MCP):

```json
{
  "mcpServers": {
    "agrr-repo": {
      "command": "node",
      "args": ["tools/agrr-repo-mcp/src/index.mjs"],
      "env": {
        "AGRR_REPO_ROOT": "/path/to/agrr"
      }
    }
  }
}
```

When the MCP server runs from the repo workspace, `AGRR_REPO_ROOT` is optional.

## Tools

| Tool | Source |
|------|--------|
| `list_bounded_contexts` | Directories under `crates/agrr-domain/src/` |
| `list_crates` | `name` and `description` from `crates/*/Cargo.toml` |
| `list_test_commands` | Paths and existence for contract, domain, and frontend test scripts |
| `get_frontend_layers` | `frontend/src/app/{domain,usecase,adapters,components}/` existence and file counts |

Each tool response includes `generated_at` (ISO 8601).

Filesystem reads via MCP tools use only `crates/`, `frontend/`, and `scripts/` (no Markdown or docs).

## Tests

```bash
npm test
```
