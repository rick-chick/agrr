import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  htmlHasRobotsNoindex,
  injectNoindexIntoHtml,
  ROBOTS_NOINDEX_META_TAG,
} from './inject-shell-noindex-lib.mjs';

const repoRoot = join(fileURLToPath(new URL('.', import.meta.url)), '../../../..');

describe('injectNoindexIntoHtml', () => {
  it('inserts noindex meta after head', () => {
    const html = '<!DOCTYPE html><html><head><title>Login</title></head><body></body></html>';
    const result = injectNoindexIntoHtml(html);
    assert.ok(htmlHasRobotsNoindex(result));
    assert.match(result, /<head[^>]*>\s*<meta name="robots" content="noindex">/i);
  });

  it('is idempotent when noindex already exists', () => {
    const html = `<html><head>${ROBOTS_NOINDEX_META_TAG}</head></html>`;
    assert.equal(injectNoindexIntoHtml(html), html);
  });
});

describe('login shell deploy contract', () => {
  it('gcp-frontend-deploy.sh injects noindex for login CSR shell', () => {
    const deployScript = readFileSync(
      join(repoRoot, '.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh'),
      'utf8',
    );
    assert.match(deployScript, /inject-shell-noindex-cli\.mjs/);
    assert.match(deployScript, /login.*inject|inject.*login|shell_path.*login/s);
  });
});
