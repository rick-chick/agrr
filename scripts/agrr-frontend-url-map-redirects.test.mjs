import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const URL_MAP = join(__dirname, 'agrr-frontend-url-map-simple.yaml');

function findRedirectTarget(yaml, legacyPath) {
  const lines = yaml.split('\n');
  for (let i = 0; i < lines.length; i += 1) {
    if (lines[i].trim() !== `- ${legacyPath}`) {
      continue;
    }
    const block = lines.slice(i, i + 8).join('\n');
    const match = block.match(/pathRedirect: (\S+)/);
    return match?.[1] ?? null;
  }
  return null;
}

describe('agrr-frontend-url-map-simple legacy /in redirects', () => {
  const yaml = readFileSync(URL_MAP, 'utf8');

  it('redirects /in/privacy to /privacy', () => {
    assert.equal(findRedirectTarget(yaml, '/in/privacy'), '/privacy');
  });

  it('redirects /in/terms to /terms', () => {
    assert.equal(findRedirectTarget(yaml, '/in/terms'), '/terms');
  });
});
