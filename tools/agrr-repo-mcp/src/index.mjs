#!/usr/bin/env node
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

import { createRepoScanner } from './repo-scanner.mjs';
import { createAgrrRepoMcpServer } from './server.mjs';

function resolveRepoRoot() {
  if (process.env.AGRR_REPO_ROOT) {
    return path.resolve(process.env.AGRR_REPO_ROOT);
  }
  return path.resolve(fileURLToPath(new URL('.', import.meta.url)), '../../..');
}

async function main() {
  const repoRoot = resolveRepoRoot();
  const scanner = createRepoScanner({ repoRoot });
  const server = createAgrrRepoMcpServer({ scanner });
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('agrr-repo-mcp server running on stdio (repo:', repoRoot, ')');
}

main().catch((err) => {
  console.error('agrr-repo-mcp failed to start:', err);
  process.exit(1);
});
