import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  SPA_PRERENDER_CANONICAL_PATHS,
  verifySpaPrerenderCanonicalContract,
} from './verify-seo-routing-lib.mjs';

const repoRoot = join(fileURLToPath(new URL('.', import.meta.url)), '../../../..');

describe('SPA_PRERENDER_CANONICAL_PATHS', () => {
  it('includes required SPA prerender routes', () => {
    assert.deepEqual(SPA_PRERENDER_CANONICAL_PATHS, [
      '/about',
      '/contact',
      '/privacy',
      '/terms',
      '/public-plans/new',
    ]);
  });
});

describe('verifySpaPrerenderCanonicalContract', () => {
  it('passes when verify-seo-routing.sh checks SPA prerender canonicals', () => {
    const result = verifySpaPrerenderCanonicalContract(repoRoot);
    assert.equal(result.ok, true, result.errors.join('\n'));
  });
});
