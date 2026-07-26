import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const URL_MAP_PATH = join(__dirname, 'agrr-frontend-url-map-simple.yaml');

function findRedirect(yamlText, sourcePath) {
  const lines = yamlText.split('\n');
  let inRule = false;
  let paths = [];
  let redirect = null;

  for (const line of lines) {
    if (line.startsWith('  - paths:')) {
      if (inRule && paths.includes(sourcePath) && redirect) {
        return redirect;
      }
      inRule = true;
      paths = [];
      redirect = null;
      continue;
    }
    if (!inRule) {
      continue;
    }
    const pathMatch = line.match(/^\s+- (\/[^\s]+)\s*$/);
    if (pathMatch) {
      paths.push(pathMatch[1]);
      continue;
    }
    const redirectMatch = line.match(/^\s+pathRedirect: (\/[^\s]+)\s*$/);
    if (redirectMatch) {
      redirect = { pathRedirect: redirectMatch[1] };
      continue;
    }
    const codeMatch = line.match(/^\s+redirectResponseCode: (\S+)\s*$/);
    if (codeMatch && redirect) {
      redirect.redirectResponseCode = codeMatch[1];
    }
    if (line.match(/^\s+service:/) || line.match(/^\s+routeAction:/)) {
      inRule = false;
    }
  }

  if (inRule && paths.includes(sourcePath) && redirect) {
    return redirect;
  }
  return null;
}

test('agrr-frontend-url-map redirects legacy /in/privacy and /in/terms', () => {
  const yamlText = readFileSync(URL_MAP_PATH, 'utf8');

  const privacy = findRedirect(yamlText, '/in/privacy');
  assert.ok(privacy, 'expected /in/privacy redirect rule');
  assert.equal(privacy.pathRedirect, '/privacy');
  assert.equal(privacy.redirectResponseCode, 'MOVED_PERMANENTLY_DEFAULT');

  const terms = findRedirect(yamlText, '/in/terms');
  assert.ok(terms, 'expected /in/terms redirect rule');
  assert.equal(terms.pathRedirect, '/terms');
  assert.equal(terms.redirectResponseCode, 'MOVED_PERMANENTLY_DEFAULT');
});
