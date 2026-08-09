import fs from 'node:fs/promises';
import path from 'node:path';

/** Allowed top-level directories for filesystem reads (repo-relative). */
export const ALLOWED_READ_PREFIXES = ['crates/', 'frontend/', 'scripts/'];

/**
 * @param {string} repoRoot
 * @param {string} relativePath
 * @returns {string}
 */
export function resolveAllowedPath(repoRoot, relativePath) {
  const normalized = relativePath.replace(/\\/g, '/').replace(/^\/+/, '');
  const allowed = ALLOWED_READ_PREFIXES.some(
    (prefix) => normalized === prefix.slice(0, -1) || normalized.startsWith(prefix),
  );
  if (!allowed) {
    throw new Error(`Path not allowed for repo MCP reads: ${relativePath}`);
  }
  const abs = path.resolve(repoRoot, normalized);
  const rootResolved = path.resolve(repoRoot);
  if (!abs.startsWith(rootResolved + path.sep) && abs !== rootResolved) {
    throw new Error(`Path escapes repo root: ${relativePath}`);
  }
  return abs;
}

/**
 * @param {string} repoRoot
 */
export function createSafeFs(repoRoot) {
  return {
    async readdir(relativePath, options) {
      const abs = resolveAllowedPath(repoRoot, relativePath);
      return fs.readdir(abs, options);
    },
    async readFile(relativePath, encoding) {
      const abs = resolveAllowedPath(repoRoot, relativePath);
      return fs.readFile(abs, encoding);
    },
    async stat(relativePath) {
      const abs = resolveAllowedPath(repoRoot, relativePath);
      return fs.stat(abs);
    },
  };
}
