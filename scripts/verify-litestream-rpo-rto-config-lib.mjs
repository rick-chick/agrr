import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const LITESTREAM_CONFIG = 'config/litestream.yml';
const MAX_PRIMARY_SYNC_SECONDS = 10;

/**
 * Parse sync-interval like "10s", "30s", "1m".
 * @param {string} value
 * @returns {number | null}
 */
export function parseSyncIntervalSeconds(value) {
  const match = /^(\d+)(s|m|h)$/.exec(value.trim());
  if (!match) {
    return null;
  }
  const amount = Number(match[1]);
  switch (match[2]) {
    case 's':
      return amount;
    case 'm':
      return amount * 60;
    case 'h':
      return amount * 3600;
    default:
      return null;
  }
}

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean; errors: string[]; primarySyncSeconds: number | null }}
 */
export function verifyLitestreamRpoRtoConfig(repoRoot) {
  const errors = [];
  const configPath = join(repoRoot, LITESTREAM_CONFIG);

  if (!existsSync(configPath)) {
    errors.push(`missing ${LITESTREAM_CONFIG}`);
    return { ok: false, errors, primarySyncSeconds: null };
  }

  const content = readFileSync(configPath, 'utf8');
  const primaryBlock = content.match(
    /- path: \/tmp\/production\.sqlite3[\s\S]*?sync-interval:\s*(\S+)/,
  );
  if (!primaryBlock) {
    errors.push(`${LITESTREAM_CONFIG} must define primary DB sync-interval`);
    return { ok: false, errors, primarySyncSeconds: null };
  }

  const primarySyncSeconds = parseSyncIntervalSeconds(primaryBlock[1]);
  if (primarySyncSeconds === null) {
    errors.push(`${LITESTREAM_CONFIG} primary sync-interval must be parseable`);
  } else if (primarySyncSeconds > MAX_PRIMARY_SYNC_SECONDS) {
    errors.push(
      `${LITESTREAM_CONFIG} primary sync-interval must be <= ${MAX_PRIMARY_SYNC_SECONDS}s (got ${primaryBlock[1]})`,
    );
  }

  return { ok: errors.length === 0, errors, primarySyncSeconds };
}
