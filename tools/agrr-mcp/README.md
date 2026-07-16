# AGRR MCP Server

Official thin MCP wrapper for AGRR Masters crop `setup_proposal` API. No business logic is duplicated in this package — HTTP calls only.

## Prerequisites

- Node.js 20+
- AGRR API key with Masters access
- Running `agrr-server` (local Docker: `http://127.0.0.1:3000`)

## Environment

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AGRR_API_KEY` | yes | — | Bearer token (`Authorization: Bearer …`) |
| `AGRR_API_BASE_URL` | no | `http://127.0.0.1:3000` | API base URL |

Generate an API key via the AGRR UI or `POST /api/v1/api_keys/generate` (session required).

## Install & start

```bash
cd tools/agrr-mcp
npm install
AGRR_API_KEY=your-key npm start
```

## Cursor MCP config

Add to `.cursor/mcp.json` (or Cursor Settings → MCP):

```json
{
  "mcpServers": {
    "agrr": {
      "command": "node",
      "args": ["tools/agrr-mcp/src/index.mjs"],
      "env": {
        "AGRR_API_KEY": "your-key",
        "AGRR_API_BASE_URL": "http://127.0.0.1:3000"
      }
    }
  }
}
```

## Tools

| Tool | HTTP |
|------|------|
| `list_reference_crops` | `GET /api/v1/masters/crops` (client filters `is_reference=true`) |
| `get_crop_detail` | `GET /api/v1/masters/crops/{id}` |
| `propose_crop_setup` | `POST /api/v1/masters/crops/{id}/setup_proposal?mode=dry_run` |
| `apply_crop_setup` | `POST /api/v1/masters/crops/{id}/setup_proposal?mode=apply` |

Request/response schema: [`docs/api/setup_proposal-openapi-snippet.yaml`](../../docs/api/setup_proposal-openapi-snippet.yaml).

## Tests

```bash
npm test
```

Contract test uses fixed tomato (jp) input (`src/fixtures.mjs`) and asserts `dry_run` returns `valid: true` with no validation errors (mocked HTTP).

### Live API smoke (optional)

With local Docker up and a user crop id:

```bash
export AGRR_API_KEY=…
export AGRR_API_BASE_URL=http://127.0.0.1:3000
node -e "
import { AgrrClient } from './src/agrr-client.mjs';
import { tomatoJpSetupProposal } from './src/fixtures.mjs';
const c = new AgrrClient();
const r = await c.proposeCropSetup(CROP_ID, tomatoJpSetupProposal());
console.log(r);
"
```

## Apply idempotency

`apply` is **not** idempotent. Re-applying the same proposal to a crop that already has stages/blueprints may fail validation or create duplicates. Workflow: always `propose_crop_setup` (dry_run) → user confirmation → single `apply_crop_setup`.

## Sample skill

See [`.cursor/skills/agrr-crop-setup/SKILL.md`](../../.cursor/skills/agrr-crop-setup/SKILL.md).
