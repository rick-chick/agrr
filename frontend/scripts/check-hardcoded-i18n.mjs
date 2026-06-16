import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

import {
  LOCALES,
  SOURCE_EXTENSIONS,
  collectStaticTranslateKeysFromText,
  findMissingLocaleKeys
} from './check-hardcoded-i18n-lib.mjs';

const SOURCE_ROOT = join(process.cwd(), 'src', 'app');
const I18N_ROOT = join(process.cwd(), 'src', 'assets', 'i18n');
const enforce = process.argv.includes('--enforce');

function sourceFiles(dir) {
  const entries = readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...sourceFiles(fullPath));
      continue;
    }
    const dot = entry.name.lastIndexOf('.');
    const extension = dot >= 0 ? entry.name.slice(dot) : '';
    if (SOURCE_EXTENSIONS.has(extension) && !entry.name.endsWith('.spec.ts')) {
      files.push(fullPath);
    }
  }
  return files;
}

function collectStaticTranslateKeys() {
  const keys = [];
  for (const file of sourceFiles(SOURCE_ROOT)) {
    const text = readFileSync(file, 'utf8');
    const filePath = relative(process.cwd(), file);
    for (const match of collectStaticTranslateKeysFromText(text, filePath)) {
      keys.push(match);
    }
  }
  return keys;
}

if (!statSync(SOURCE_ROOT).isDirectory()) {
  throw new Error(`source root not found: ${SOURCE_ROOT}`);
}

const catalogs = Object.fromEntries(
  LOCALES.map((locale) => {
    const file = join(I18N_ROOT, `${locale}.json`);
    if (!existsSync(file)) {
      throw new Error(`locale file not found: ${file}`);
    }
    return [locale, JSON.parse(readFileSync(file, 'utf8'))];
  })
);

const references = collectStaticTranslateKeys();
const missing = findMissingLocaleKeys(references, catalogs);

if (missing.length === 0) {
  console.log(`check-hardcoded-i18n: OK (${references.length} static references checked)`);
  process.exit(0);
}

console.log(
  `check-hardcoded-i18n: missing ${missing.length} locale/key entries from ${references.length} static references`
);
for (const row of missing) {
  console.log(`${row.locale}\t${row.key}\t${row.file}:${row.line}`);
}
process.exit(enforce ? 1 : 0);
