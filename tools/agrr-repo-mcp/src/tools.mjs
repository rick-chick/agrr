import { z } from 'zod';

/**
 * @param {ReturnType<import('./repo-scanner.mjs').createRepoScanner>} scanner
 */
export function createAgrrRepoMcpToolHandlers(scanner) {
  const emptySchema = z.object({});

  return {
    list_bounded_contexts: {
      description:
        'List bounded context directories under crates/agrr-domain/src/ (filesystem-derived).',
      inputSchema: {},
      handler: async () => {
        const data = await scanner.listBoundedContexts();
        return {
          content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
        };
      },
    },
    list_crates: {
      description:
        'List workspace crates from crates/*/Cargo.toml with name and description.',
      inputSchema: {},
      handler: async () => {
        const data = await scanner.listCrates();
        return {
          content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
        };
      },
    },
    list_test_commands: {
      description:
        'Return paths and existence for contract, domain, and frontend test runner scripts.',
      inputSchema: {},
      handler: async () => {
        const data = await scanner.listTestCommands();
        return {
          content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
        };
      },
    },
    get_frontend_layers: {
      description:
        'Return existence and file counts for frontend/src/app/{domain,usecase,adapters,components}/.',
      inputSchema: {},
      handler: async () => {
        const data = await scanner.getFrontendLayers();
        return {
          content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
        };
      },
    },
  };
}

export const AGRR_REPO_MCP_TOOL_NAMES = [
  'list_bounded_contexts',
  'list_crates',
  'list_test_commands',
  'get_frontend_layers',
];
