import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

import { createAgrrRepoMcpToolHandlers } from './tools.mjs';

/**
 * @param {{ scanner: ReturnType<import('./repo-scanner.mjs').createRepoScanner> }} deps
 */
export function createAgrrRepoMcpServer({ scanner }) {
  const server = new McpServer({
    name: 'agrr-repo-mcp',
    version: '0.1.0',
  });

  const tools = createAgrrRepoMcpToolHandlers(scanner);
  for (const [name, tool] of Object.entries(tools)) {
    server.registerTool(
      name,
      {
        description: tool.description,
        inputSchema: tool.inputSchema,
      },
      tool.handler,
    );
  }

  return server;
}
