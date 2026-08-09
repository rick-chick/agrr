#!/usr/bin/env node
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

import { DEFAULT_REPO_ROOT } from './repo-root.mjs';
import { createAgrrRepoMcpServer } from './server.mjs';

async function main() {
  const repoRoot = process.env.AGRR_REPO_ROOT ?? DEFAULT_REPO_ROOT;
  const server = createAgrrRepoMcpServer({ repoRoot });
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('agrr-repo-mcp server running on stdio');
}

main().catch((err) => {
  console.error('agrr-repo-mcp failed to start:', err);
  process.exit(1);
});
