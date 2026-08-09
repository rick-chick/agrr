import fs from 'node:fs/promises';
import path from 'node:path';

import { createSafeFs } from './safe-fs.mjs';

const FRONTEND_LAYERS = ['domain', 'usecase', 'adapters', 'components'];

const TEST_COMMAND_PATHS = [
  'scripts/run-rust-contract-tests.sh',
  '.cursor/skills/test-common/scripts/run-test-rust-domain.sh',
  '.cursor/skills/test-common/scripts/run-test-frontend.sh',
];

/**
 * @param {{ repoRoot: string }} opts
 */
export function createRepoScanner({ repoRoot }) {
  const safeFs = createSafeFs(repoRoot);

  function generatedAt() {
    return new Date().toISOString();
  }

  async function listBoundedContexts() {
    const entries = await safeFs.readdir('crates/agrr-domain/src', { withFileTypes: true });
    const contexts = entries
      .filter((e) => e.isDirectory())
      .map((e) => e.name)
      .sort();
    return { generated_at: generatedAt(), contexts };
  }

  async function listCrates() {
    const crateDirs = await safeFs.readdir('crates', { withFileTypes: true });
    const crates = [];
    for (const entry of crateDirs) {
      if (!entry.isDirectory()) continue;
      const cargoPath = `crates/${entry.name}/Cargo.toml`;
      try {
        const text = await safeFs.readFile(cargoPath, 'utf8');
        const nameMatch = text.match(/^name\s*=\s*"([^"]+)"/m);
        const descMatch = text.match(/^description\s*=\s*"([^"]*)"/m);
        crates.push({
          name: nameMatch?.[1] ?? entry.name,
          description: descMatch?.[1] ?? '',
          path: cargoPath,
        });
      } catch {
        // skip crates without readable Cargo.toml
      }
    }
    crates.sort((a, b) => a.name.localeCompare(b.name));
    return { generated_at: generatedAt(), crates };
  }

  async function listTestCommands() {
    const commands = [];
    for (const relPath of TEST_COMMAND_PATHS) {
      let exists = false;
      try {
        if (relPath.startsWith('scripts/')) {
          const stat = await safeFs.stat(relPath);
          exists = stat.isFile();
        } else {
          const abs = path.resolve(repoRoot, relPath);
          const stat = await fs.stat(abs);
          exists = stat.isFile();
        }
      } catch {
        exists = false;
      }
      commands.push({ path: relPath, exists });
    }
    return { generated_at: generatedAt(), commands };
  }

  async function countFilesRecursive(relativeDir) {
    let count = 0;
    const entries = await safeFs.readdir(relativeDir, { withFileTypes: true });
    for (const entry of entries) {
      const child = `${relativeDir}/${entry.name}`;
      if (entry.isDirectory()) {
        count += await countFilesRecursive(child);
      } else if (entry.isFile()) {
        count += 1;
      }
    }
    return count;
  }

  async function getFrontendLayers() {
    const layers = [];
    for (const name of FRONTEND_LAYERS) {
      const relPath = `frontend/src/app/${name}`;
      let exists = false;
      let fileCount = 0;
      try {
        const stat = await safeFs.stat(relPath);
        exists = stat.isDirectory();
        if (exists) {
          fileCount = await countFilesRecursive(relPath);
        }
      } catch {
        exists = false;
      }
      layers.push({ name, path: relPath, exists, file_count: fileCount });
    }
    return { generated_at: generatedAt(), layers };
  }

  return {
    listBoundedContexts,
    listCrates,
    listTestCommands,
    getFrontendLayers,
  };
}
