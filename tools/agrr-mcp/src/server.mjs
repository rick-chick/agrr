import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

import { createAgrrMcpToolHandlers } from './tools.mjs';

/**
 * @param {{ client: import('./agrr-client.mjs').AgrrClient }} deps
 */
export function createAgrrMcpServer({ client }) {
  const server = new McpServer({
    name: 'agrr-mcp',
    version: '0.1.0',
  });

  const tools = createAgrrMcpToolHandlers(client);
  for (const [name, tool] of Object.entries(tools)) {
    server.registerTool(name, {
      description: tool.description,
      inputSchema: tool.inputSchema,
    }, tool.handler);
  }

  return server;
}
