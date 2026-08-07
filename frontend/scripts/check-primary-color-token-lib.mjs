import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const PRIMARY_DEF_RE = /^\s*--color-primary\s*:/;

/**
 * @param {string} text
 * @returns {{ line: number, value: string }[]}
 */
export function findPrimaryColorDefinitions(text) {
  const lines = text.split('\n');
  /** @type {{ line: number, value: string }[]} */
  const defs = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!PRIMARY_DEF_RE.test(line)) continue;
    const match = line.match(/--color-primary\s*:\s*([^;]+)/);
    defs.push({
      line: i + 1,
      value: (match?.[1] ?? '').trim(),
    });
  }
  return defs;
}

/**
 * @param {string} frontendRoot absolute path to frontend/
 * @returns {Promise<{ file: string, definitions: { line: number, value: string }[] }[]>}
 */
export async function scanPrimaryColorDefinitions(frontendRoot) {
  const targets = [
    join(frontendRoot, 'src/styles.css'),
    join(frontendRoot, 'src/app/app.css'),
  ];
  /** @type {{ file: string, definitions: { line: number, value: string }[] }[]} */
  const results = [];
  for (const file of targets) {
    const text = await readFile(file, 'utf8');
    const definitions = findPrimaryColorDefinitions(text);
    if (definitions.length > 0) {
      results.push({ file, definitions });
    }
  }
  return results;
}

/**
 * @param {{ file: string, definitions: { line: number, value: string }[] }[]} scan
 * @returns {{ ok: boolean, totalDefinitions: number, canonicalFile: string, violations: string[] }}
 */
export function validateSinglePrimaryDefinition(scan) {
  const canonicalFile = 'src/styles.css';
  const totalDefinitions = scan.reduce((n, row) => n + row.definitions.length, 0);
  /** @type {string[]} */
  const violations = [];

  if (totalDefinitions === 0) {
    violations.push('no --color-primary definition found in styles.css');
  }

  for (const row of scan) {
    const rel = row.file.replace(/.*frontend\//, 'frontend/');
    const short = rel.includes('frontend/') ? rel.split('frontend/')[1] : row.file;
    if (short !== canonicalFile) {
      for (const def of row.definitions) {
        violations.push(`${short}:${def.line} redefines --color-primary (${def.value})`);
      }
    }
  }

  const canonical = scan.find((row) => row.file.endsWith(canonicalFile));
  if (!canonical || canonical.definitions.length !== 1) {
    if (canonical && canonical.definitions.length > 1) {
      violations.push(`${canonicalFile} must define --color-primary exactly once`);
    }
  }

  return {
    ok: violations.length === 0 && totalDefinitions === 1,
    totalDefinitions,
    canonicalFile,
    violations,
  };
}
