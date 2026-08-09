import { access } from 'node:fs/promises';
import { join } from 'node:path';

const TEST_COMMAND_PATHS = [
  {
    name: 'run-rust-contract-tests',
    path: 'scripts/run-rust-contract-tests.sh',
  },
  {
    name: 'run-test-rust-domain',
    path: '.cursor/skills/test-common/scripts/run-test-rust-domain.sh',
  },
  {
    name: 'run-test-frontend',
    path: '.cursor/skills/test-common/scripts/run-test-frontend.sh',
  },
];

const FRONTEND_LAYERS = ['domain', 'usecase', 'adapters', 'components'];

/**
 * @returns {string}
 */
export function isoTimestamp() {
  return new Date().toISOString();
}

/**
 * @param {string} cargoToml
 */
function parseCargoPackageMeta(cargoToml) {
  const nameMatch = cargoToml.match(/^name\s*=\s*"([^"]+)"/m);
  const descriptionMatch = cargoToml.match(/^description\s*=\s*"([^"]+)"/m);
  return {
    name: nameMatch?.[1] ?? null,
    description: descriptionMatch?.[1] ?? null,
  };
}

/**
 * @param {import('./fs-access.mjs').createRepoFsAccess extends (...args: any[]) => infer R ? R : never} fsAccess
 * @param {string} dirPath
 */
async function countFilesRecursive(fsAccess, dirPath) {
  let count = 0;
  const entries = await fsAccess.readdir(dirPath, { withFileTypes: true });
  for (const entry of entries) {
    const child = fsAccess.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      count += await countFilesRecursive(fsAccess, child);
    } else if (entry.isFile()) {
      count += 1;
    }
  }
  return count;
}

/**
 * @param {string} repoRoot
 * @param {ReturnType<typeof import('./fs-access.mjs').createRepoFsAccess>} fsAccess
 */
export async function listBoundedContexts(repoRoot, fsAccess) {
  const domainSrc = join(repoRoot, 'crates/agrr-domain/src');
  const entries = await fsAccess.readdir(domainSrc, { withFileTypes: true });
  const contexts = entries
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();

  return {
    generated_at: isoTimestamp(),
    bounded_contexts: contexts,
  };
}

/**
 * @param {string} repoRoot
 * @param {ReturnType<typeof import('./fs-access.mjs').createRepoFsAccess>} fsAccess
 */
export async function listCrates(repoRoot, fsAccess) {
  const cratesDir = join(repoRoot, 'crates');
  const entries = await fsAccess.readdir(cratesDir, { withFileTypes: true });
  const crates = [];

  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }
    const cargoPath = join(cratesDir, entry.name, 'Cargo.toml');
    try {
      const text = await fsAccess.readFile(cargoPath, 'utf8');
      const meta = parseCargoPackageMeta(text);
      crates.push({
        directory: entry.name,
        name: meta.name,
        description: meta.description,
      });
    } catch {
      // skip crates without readable Cargo.toml
    }
  }

  crates.sort((a, b) => (a.name ?? '').localeCompare(b.name ?? ''));

  return {
    generated_at: isoTimestamp(),
    crates,
  };
}

/**
 * @param {string} repoRoot
 */
export async function listTestCommands(repoRoot) {
  const commands = [];
  for (const cmd of TEST_COMMAND_PATHS) {
    const absolute = join(repoRoot, cmd.path);
    let exists = false;
    try {
      await access(absolute);
      exists = true;
    } catch {
      exists = false;
    }
    commands.push({
      name: cmd.name,
      path: cmd.path,
      exists,
    });
  }

  return {
    generated_at: isoTimestamp(),
    commands,
  };
}

/**
 * @param {string} repoRoot
 * @param {ReturnType<typeof import('./fs-access.mjs').createRepoFsAccess>} fsAccess
 */
export async function getFrontendLayers(repoRoot, fsAccess) {
  const appRoot = join(repoRoot, 'frontend/src/app');
  const layers = [];

  for (const layer of FRONTEND_LAYERS) {
    const layerPath = join(appRoot, layer);
    let exists = false;
    let file_count = 0;
    try {
      const entries = await fsAccess.readdir(layerPath, { withFileTypes: true });
      exists = true;
      file_count = await countFilesRecursive(fsAccess, layerPath);
      void entries;
    } catch {
      exists = false;
      file_count = 0;
    }
    layers.push({
      layer,
      path: `frontend/src/app/${layer}`,
      exists,
      file_count,
    });
  }

  return {
    generated_at: isoTimestamp(),
    layers,
  };
}

export const AGRR_REPO_MCP_TOOL_NAMES = [
  'list_bounded_contexts',
  'list_crates',
  'list_test_commands',
  'get_frontend_layers',
];

/**
 * @param {{ repoRoot: string; fsAccess: ReturnType<typeof import('./fs-access.mjs').createRepoFsAccess> }} deps
 */
export function createAgrrRepoMcpToolHandlers({ repoRoot, fsAccess }) {
  return {
    list_bounded_contexts: {
      description:
        'List bounded-context directories under crates/agrr-domain/src/ (filesystem only).',
      inputSchema: {},
      handler: async () => {
        const result = await listBoundedContexts(repoRoot, fsAccess);
        return {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
        };
      },
    },
    list_crates: {
      description:
        'List workspace crates from crates/*/Cargo.toml (name and description).',
      inputSchema: {},
      handler: async () => {
        const result = await listCrates(repoRoot, fsAccess);
        return {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
        };
      },
    },
    list_test_commands: {
      description:
        'Return canonical test runner script paths and existence (no Markdown reads).',
      inputSchema: {},
      handler: async () => {
        const result = await listTestCommands(repoRoot);
        return {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
        };
      },
    },
    get_frontend_layers: {
      description:
        'Report frontend/src/app layer directories (domain, usecase, adapters, components).',
      inputSchema: {},
      handler: async () => {
        const result = await getFrontendLayers(repoRoot, fsAccess);
        return {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
        };
      },
    },
  };
}
