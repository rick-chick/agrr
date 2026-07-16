import assert from 'node:assert/strict';
import test from 'node:test';

import { AgrrClient } from '../src/agrr-client.mjs';
import { tomatoJpSetupProposal } from '../src/fixtures.mjs';

/**
 * Contract: fixed tomato (jp) input must pass dry_run without validation errors.
 * Uses a mock HTTP layer; live API verification is documented in README.
 */
test('tomato jp dry_run contract has no validation errors', async () => {
  const proposal = tomatoJpSetupProposal();
  const client = new AgrrClient({
    baseUrl: 'http://localhost:3000',
    apiKey: 'contract-test-key',
    fetch: async (url, init) => {
      assert.match(url, /setup_proposal\?mode=dry_run$/);
      const body = JSON.parse(init.body);
      assert.equal(body.agricultural_tasks[0].region, 'jp');
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            mode: 'dry_run',
            valid: true,
            normalized: body,
            errors: [],
          };
        },
        async text() {
          return JSON.stringify(await this.json());
        },
      };
    },
  });

  const result = await client.proposeCropSetup(1, proposal);
  assert.equal(result.valid, true);
  assert.equal(result.errors?.length ?? 0, 0);
});
