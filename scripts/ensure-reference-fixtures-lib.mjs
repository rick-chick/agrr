/**
 * Pure helpers for reference weather fixture lock / ensure logic.
 * Shell wrapper: scripts/ensure-reference-fixtures.sh
 */
import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

/** @typedef {{ path: string, object: string, sha256: string, size_bytes: number }} FixtureEntry */
/** @typedef {{ version: string, bucket: string, prefix: string, files: FixtureEntry[] }} FixtureLock */

/**
 * @param {unknown} raw
 * @returns {FixtureLock}
 */
export function parseLockFile(raw) {
  if (typeof raw !== 'object' || raw === null) {
    throw new Error('lock file must be a JSON object');
  }
  const lock = /** @type {Record<string, unknown>} */ (raw);
  if (typeof lock.version !== 'string' || !lock.version) {
    throw new Error('lock.version is required');
  }
  if (typeof lock.bucket !== 'string' || !lock.bucket) {
    throw new Error('lock.bucket is required');
  }
  if (typeof lock.prefix !== 'string' || !lock.prefix) {
    throw new Error('lock.prefix is required');
  }
  if (!Array.isArray(lock.files) || lock.files.length === 0) {
    throw new Error('lock.files must be a non-empty array');
  }
  const files = lock.files.map((entry, i) => parseFixtureEntry(entry, i));
  return {
    version: lock.version,
    bucket: lock.bucket,
    prefix: lock.prefix.replace(/\/$/, ''),
    files,
  };
}

/**
 * @param {unknown} entry
 * @param {number} index
 * @returns {FixtureEntry}
 */
function parseFixtureEntry(entry, index) {
  if (typeof entry !== 'object' || entry === null) {
    throw new Error(`lock.files[${index}] must be an object`);
  }
  const e = /** @type {Record<string, unknown>} */ (entry);
  for (const key of ['path', 'object', 'sha256']) {
    if (typeof e[key] !== 'string' || !e[key]) {
      throw new Error(`lock.files[${index}].${key} is required`);
    }
  }
  if (typeof e.size_bytes !== 'number' || e.size_bytes <= 0) {
    throw new Error(`lock.files[${index}].size_bytes must be a positive number`);
  }
  if (!/^[a-f0-9]{64}$/.test(/** @type {string} */ (e.sha256))) {
    throw new Error(`lock.files[${index}].sha256 must be 64 hex chars`);
  }
  return {
    path: /** @type {string} */ (e.path),
    object: /** @type {string} */ (e.object),
    sha256: /** @type {string} */ (e.sha256),
    size_bytes: /** @type {number} */ (e.size_bytes),
  };
}

/**
 * @param {FixtureLock} lock
 * @param {FixtureEntry} entry
 * @returns {string}
 */
export function buildGcsUri(lock, entry) {
  return `gs://${lock.bucket}/${lock.prefix}/${entry.object}`;
}

/**
 * @param {string} repoRoot
 * @param {string} relativePath
 * @returns {string}
 */
export function resolveFixturePath(repoRoot, relativePath) {
  return resolve(repoRoot, relativePath);
}

/**
 * @param {string} filePath
 * @returns {string | null}
 */
export function sha256OfFile(filePath) {
  if (!existsSync(filePath)) {
    return null;
  }
  const data = readFileSync(filePath);
  return createHash('sha256').update(data).digest('hex');
}

/**
 * @param {FixtureEntry} entry
 * @param {string} localPath
 * @param {(p: string) => string | null} hashFn
 * @returns {'ok' | 'missing' | 'hash_mismatch'}
 */
export function checkFixtureEntry(entry, localPath, hashFn) {
  const hash = hashFn(localPath);
  if (hash === null) {
    return 'missing';
  }
  if (hash !== entry.sha256) {
    return 'hash_mismatch';
  }
  return 'ok';
}

/**
 * Plan which fixtures need fetching.
 * @param {FixtureLock} lock
 * @param {string} repoRoot
 * @param {(p: string) => string | null} [hashFn]
 * @returns {{ entry: FixtureEntry, localPath: string, status: 'ok' | 'missing' | 'hash_mismatch', gcsUri: string }[]}
 */
export function planFixtureEnsure(lock, repoRoot, hashFn = sha256OfFile) {
  return lock.files.map((entry) => {
    const localPath = resolveFixturePath(repoRoot, entry.path);
    const status = checkFixtureEntry(entry, localPath, hashFn);
    return { entry, localPath, status, gcsUri: buildGcsUri(lock, entry) };
  });
}

/**
 * @param {{ status: string }[]} plans
 * @param {boolean} required
 * @returns {0 | 1}
 */
export function ensureExitCode(plans, required) {
  const hasProblem = plans.some((p) => p.status !== 'ok');
  if (hasProblem && required) {
    return 1;
  }
  return 0;
}

/**
 * @param {FixtureEntry} entry
 * @param {string} filePath
 * @returns {FixtureEntry}
 */
export function buildLockEntryFromFile(entry, filePath) {
  const hash = sha256OfFile(filePath);
  if (hash === null) {
    throw new Error(`file not found: ${filePath}`);
  }
  const size = readFileSync(filePath).length;
  return { ...entry, sha256: hash, size_bytes: size };
}

/**
 * @param {string} lockPath
 * @returns {FixtureLock}
 */
export function readLockFile(lockPath) {
  const raw = JSON.parse(readFileSync(lockPath, 'utf8'));
  return parseLockFile(raw);
}
