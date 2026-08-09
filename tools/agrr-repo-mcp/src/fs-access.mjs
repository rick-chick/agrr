import { readFile, readdir } from 'node:fs/promises';
import { join, relative } from 'node:path';

/** Relative repo-root prefixes allowed for readdir / readFile. */
export const ALLOWED_READ_PREFIXES = ['crates/', 'frontend/', 'scripts/'];

/**
 * @param {string} repoRoot
 * @param {string} absolutePath
 * @returns {string}
 */
function toRepoRelative(repoRoot, absolutePath) {
  const rel = relative(repoRoot, absolutePath).replace(/\\/g, '/');
  if (rel.startsWith('../')) {
    throw new Error(`path outside repo root: ${absolutePath}`);
  }
  return rel === '' ? '' : rel;
}

/**
 * @param {string} repoRelative
 */
function assertAllowedReadPrefix(repoRelative) {
  const normalized = repoRelative.replace(/\\/g, '/');
  const allowed = ALLOWED_READ_PREFIXES.some(
    (prefix) => normalized === prefix.replace(/\/$/, '') || normalized.startsWith(prefix),
  );
  if (!allowed) {
    throw new Error(
      `fs read scope violation: ${normalized} (allowed: ${ALLOWED_READ_PREFIXES.join(', ')})`,
    );
  }
}

/**
 * Scoped filesystem reads for repo structure tools.
 * @param {string} repoRoot
 * @param {{ onRead?: (repoRelative: string, op: 'readdir' | 'readFile') => void }} [opts]
 */
export function createRepoFsAccess(repoRoot, opts = {}) {
  const { onRead } = opts;

  const track = (absolutePath, op) => {
    const repoRelative = toRepoRelative(repoRoot, absolutePath);
    assertAllowedReadPrefix(repoRelative);
    if (onRead) {
      onRead(repoRelative, op);
    }
    return repoRelative;
  };

  return {
    async readdir(absolutePath, options) {
      track(absolutePath, 'readdir');
      return readdir(absolutePath, options);
    },
    async readFile(absolutePath, encoding) {
      track(absolutePath, 'readFile');
      return readFile(absolutePath, encoding);
    },
    join: (...segments) => join(...segments),
  };
}
