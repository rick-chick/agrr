export const LOCALES = ['ja', 'en', 'in'];
export const SOURCE_EXTENSIONS = new Set(['.ts', '.html']);

export function getNested(catalog, dottedKey) {
  return dottedKey.split('.').reduce((current, segment) => {
    if (current == null || typeof current !== 'object') return undefined;
    return current[segment];
  }, catalog);
}

export function lineNumberForOffset(text, offset) {
  let line = 1;
  for (let i = 0; i < offset; i += 1) {
    if (text.charCodeAt(i) === 10) line += 1;
  }
  return line;
}

export function addMatches(results, text, file, pattern) {
  for (const match of text.matchAll(pattern)) {
    const key = match.groups?.key;
    if (!key || key.includes('${')) continue;
    results.push({
      key,
      file,
      line: lineNumberForOffset(text, match.index ?? 0)
    });
  }
}

export function collectStaticTranslateKeysFromText(text, file = 'sample.ts') {
  const keys = [];
  addMatches(keys, text, file, /['"`](?<key>[A-Za-z][A-Za-z0-9_.-]+)['"`]\s*\|\s*translate/g);
  addMatches(keys, text, file, /\.instant\(\s*['"`](?<key>[A-Za-z][A-Za-z0-9_.-]+)['"`]/g);
  return keys;
}

export function uniqueByLocaleAndKey(rows) {
  const seen = new Set();
  return rows.filter((row) => {
    const identity = `${row.locale}\0${row.key}`;
    if (seen.has(identity)) return false;
    seen.add(identity);
    return true;
  });
}

export function findMissingLocaleKeys(references, catalogs, locales = LOCALES) {
  return uniqueByLocaleAndKey(
    references.flatMap((ref) =>
      locales.flatMap((locale) =>
        getNested(catalogs[locale], ref.key) === undefined ? [{ ...ref, locale }] : []
      )
    )
  ).sort((a, b) => a.locale.localeCompare(b.locale) || a.key.localeCompare(b.key));
}
