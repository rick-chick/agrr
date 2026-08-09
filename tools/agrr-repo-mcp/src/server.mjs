import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

import { createRepoFsAccess } from './fs-access.mjs';
import { createAgrrRepoMcpToolHandlers } from './tools.mjs';

/**
 * @param {{ repoRoot: string }} deps
 */
export function createAgrrRepoMcpServer({ repoRoot }) {
  const fsAccess = createRepoFsAccess(repoRoot);
  const server = new McpServer({
    name: 'agrr-repo-mcp',
    version: '0.1.0',
  });

  const tools = createAgrrRepoMcpToolHandlers({ repoRoot, fsAccess });
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
