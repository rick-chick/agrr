#!/usr/bin/env node
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

import { createAgrrClientFromEnv } from './agrr-client.mjs';
import { createAgrrMcpServer } from './server.mjs';

async function main() {
  const client = createAgrrClientFromEnv();
  const server = createAgrrMcpServer({ client });
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('agrr-mcp server running on stdio');
}

main().catch((err) => {
  console.error('agrr-mcp failed to start:', err);
  process.exit(1);
});
