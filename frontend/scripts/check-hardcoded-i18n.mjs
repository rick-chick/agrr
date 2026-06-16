import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const LOCALES = ['ja', 'en', 'in'];
const SOURCE_EXTENSIONS = new Set(['.ts', '.html']);
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

function getNested(catalog, dottedKey) {
  return dottedKey.split('.').reduce((current, segment) => {
    if (current == null || typeof current !== 'object') return undefined;
    return current[segment];
  }, catalog);
}

function lineNumberForOffset(text, offset) {
  let line = 1;
  for (let i = 0; i < offset; i += 1) {
    if (text.charCodeAt(i) === 10) line += 1;
  }
  return line;
}

function addMatches(results, text, file, pattern) {
  for (const match of text.matchAll(pattern)) {
    const key = match.groups?.key;
    if (!key || key.includes('${')) continue;
    results.push({
      key,
      file: relative(process.cwd(), file),
      line: lineNumberForOffset(text, match.index ?? 0)
    });
  }
}

function collectStaticTranslateKeys() {
  const keys = [];
  for (const file of sourceFiles(SOURCE_ROOT)) {
    const text = readFileSync(file, 'utf8');
    addMatches(keys, text, file, /['"`](?<key>[A-Za-z][A-Za-z0-9_.-]+)['"`]\s*\|\s*translate/g);
    addMatches(keys, text, file, /\.instant\(\s*['"`](?<key>[A-Za-z][A-Za-z0-9_.-]+)['"`]/g);
  }
  return keys;
}

function uniqueByLocaleAndKey(rows) {
  const seen = new Set();
  return rows.filter((row) => {
    const identity = `${row.locale}\0${row.key}`;
    if (seen.has(identity)) return false;
    seen.add(identity);
    return true;
  });
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
const missing = uniqueByLocaleAndKey(
  references.flatMap((ref) =>
    LOCALES.flatMap((locale) =>
      getNested(catalogs[locale], ref.key) === undefined ? [{ ...ref, locale }] : []
    )
  )
).sort((a, b) => a.locale.localeCompare(b.locale) || a.key.localeCompare(b.key));

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
