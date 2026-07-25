import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, chmodSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';

/**
 * @param {string} repoRoot
 */
export function verifyDbBootstrapRestoreContract(repoRoot) {
  const errors = [];
  const startScript = readFileSync(
    join(repoRoot, 'scripts/start_agrr_server.sh'),
    'utf8',
  );
  const bootstrapScript = readFileSync(
    join(repoRoot, 'scripts/db_bootstrap_common.sh'),
    'utf8',
  );

  if (!/run_db_restore_phase/.test(startScript)) {
    errors.push('start_agrr_server.sh must synchronously run_db_restore_phase before exec agrr-server');
  }
  if (!/run_db_bootstrap_post_restore\s*&/.test(startScript)) {
    errors.push('start_agrr_server.sh must background run_db_bootstrap_post_restore (not full bootstrap)');
  }
  if (/run_db_bootstrap\s*&/.test(startScript) || /^\s*run_db_bootstrap\s*$/m.test(startScript)) {
    errors.push('start_agrr_server.sh must not run full run_db_bootstrap (blocks HTTP until migrate/replicate)');
  }
  if (!/exec agrr-server/.test(startScript)) {
    errors.push('start_agrr_server.sh must exec agrr-server after restore phase');
  }
  if (!/Removing stale .* database file before restore/.test(bootstrapScript)) {
    errors.push('restore_db must remove stale db file before litestream restore');
  }
  if (!/litestream-restore\.tmp/.test(bootstrapScript)) {
    errors.push('restore_db must restore to a temp file then rename (avoids parallel boot race)');
  }
  if (!/AGRR_ENV.*production/.test(bootstrapScript)) {
    errors.push('restore_db must treat production restore failure as fatal');
  }
  if (/starting fresh/.test(bootstrapScript)) {
    const strictBlock = bootstrapScript.includes('ERROR:') &&
      bootstrapScript.includes('return 1');
    if (!strictBlock) {
      errors.push('restore_db must not silently fresh-start on production restore failure');
    }
  }

  return { ok: errors.length === 0, errors };
}

/**
 * Run restore_db in an isolated bash subprocess with a fake litestream on PATH.
 *
 * @param {{ strict?: boolean, litestreamExit?: number, precreateDb?: boolean }} opts
 */
export function runRestoreDbHarness(opts = {}) {
  const {
    strict = false,
    litestreamExit = 0,
    precreateDb = false,
  } = opts;
  const dir = mkdtempSync(join(tmpdir(), 'agrr-restore-db-'));
  const binDir = join(dir, 'bin');
  mkdirSync(binDir);
  const dbPath = join(dir, 'primary.sqlite3');
  const litestreamPath = join(binDir, 'litestream');
  const litestreamLog = join(dir, 'litestream.log');

  writeFileSync(
    litestreamPath,
    `#!/bin/bash
echo "litestream $*" >> "${litestreamLog}"
out=""
args=("$@")
for ((i=0; i<\${#args[@]}; i++)); do
  if [[ "\${args[$i]}" == "-o" && $((i+1)) -lt \${#args[@]} ]]; then
    out="\${args[$((i+1))]}"
    break
  fi
done
if [[ ${litestreamExit} -eq 0 && -n "$out" ]]; then
  echo "restored" > "$out"
fi
exit ${litestreamExit}
`,
  );
  chmodSync(litestreamPath, 0o755);

  if (precreateDb) {
    writeFileSync(dbPath, 'stale');
  }

  const env = {
    ...process.env,
    PATH: `${binDir}:${process.env.PATH ?? ''}`,
    AGRR_ENV: strict ? 'production' : 'development',
    GCS_BUCKET: strict ? 'agrr-production-db' : '',
    AGRR_SCRIPTS_DIR: join(process.cwd(), 'scripts'),
  };

  const bash = `
set -euo pipefail
source "${join(process.cwd(), 'scripts/db_bootstrap_common.sh')}"
restore_db "${dbPath}" "primary"
`;

  let status = 0;
  let stdout = '';
  let stderr = '';
  try {
    stdout = execFileSync('bash', ['-c', bash], {
      env,
      encoding: 'utf8',
    });
  } catch (err) {
    status = err.status ?? 1;
    stdout = err.stdout?.toString?.() ?? '';
    stderr = err.stderr?.toString?.() ?? '';
  }

  return { status, stdout, stderr, dbPath, litestreamLog, dir };
}
