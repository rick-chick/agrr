import assert from 'node:assert/strict';
import test from 'node:test';

import { AgrrClient } from '../src/agrr-client.mjs';
import { tomatoJpSetupProposal } from '../src/fixtures.mjs';

function mockFetch(handler) {
  return async (url, init = {}) => {
    const response = await handler(url, init);
    return {
      ok: response.status >= 200 && response.status < 300,
      status: response.status,
      async json() {
        return response.body;
      },
      async text() {
        return JSON.stringify(response.body);
      },
    };
  };
}

test('AgrrClient requires AGRR_API_KEY', () => {
  assert.throws(
    () => new AgrrClient({ baseUrl: 'http://localhost:3000', apiKey: '' }),
    /AGRR_API_KEY/,
  );
});

test('listReferenceCrops filters is_reference and optional region', async () => {
  const seen = { url: null, headers: null };
  const client = new AgrrClient({
    baseUrl: 'http://localhost:3000',
    apiKey: 'test-key',
    fetch: mockFetch((url, init) => {
      seen.url = url;
      seen.headers = init.headers;
      return {
        status: 200,
        body: [
          { id: 1, name: 'トマト', region: 'jp', is_reference: true },
          { id: 2, name: '私のトマト', region: 'jp', is_reference: false },
          { id: 3, name: 'Tomato', region: 'us', is_reference: true },
        ],
      };
    }),
  });

  const crops = await client.listReferenceCrops({ region: 'jp' });
  assert.equal(seen.url, 'http://localhost:3000/api/v1/masters/crops');
  assert.equal(seen.headers.Authorization, 'Bearer test-key');
  assert.deepEqual(crops, [{ id: 1, name: 'トマト', region: 'jp', is_reference: true }]);
});

test('getCropDetail fetches crop by id', async () => {
  const client = new AgrrClient({
    baseUrl: 'http://localhost:3000',
    apiKey: 'test-key',
    fetch: mockFetch((url) => {
      assert.equal(url, 'http://localhost:3000/api/v1/masters/crops/42');
      return { status: 200, body: { id: 42, name: 'トマト', region: 'jp' } };
    }),
  });

  const crop = await client.getCropDetail(42);
  assert.equal(crop.id, 42);
  assert.equal(crop.name, 'トマト');
});

test('proposeCropSetup posts dry_run mode', async () => {
  const proposal = tomatoJpSetupProposal();
  const client = new AgrrClient({
    baseUrl: 'http://localhost:3000',
    apiKey: 'test-key',
    fetch: mockFetch((url, init) => {
      assert.equal(
        url,
        'http://localhost:3000/api/v1/masters/crops/7/setup_proposal?mode=dry_run',
      );
      assert.equal(init.method, 'POST');
      assert.deepEqual(JSON.parse(init.body), proposal);
      return {
        status: 200,
        body: { mode: 'dry_run', valid: true, normalized: proposal },
      };
    }),
  });

  const result = await client.proposeCropSetup(7, proposal);
  assert.equal(result.valid, true);
});

test('applyCropSetup posts apply mode', async () => {
  const proposal = tomatoJpSetupProposal();
  const client = new AgrrClient({
    baseUrl: 'http://localhost:3000',
    apiKey: 'test-key',
    fetch: mockFetch((url, init) => {
      assert.equal(
        url,
        'http://localhost:3000/api/v1/masters/crops/7/setup_proposal?mode=apply',
      );
      assert.equal(init.method, 'POST');
      return {
        status: 201,
        body: {
          mode: 'apply',
          valid: true,
          result: { stage_ids: [1], blueprint_ids: [2] },
        },
      };
    }),
  });

  const result = await client.applyCropSetup(7, proposal);
  assert.equal(result.valid, true);
  assert.equal(result.result.stage_ids.length, 1);
});

test('request surfaces API errors', async () => {
  const client = new AgrrClient({
    baseUrl: 'http://localhost:3000',
    apiKey: 'test-key',
    fetch: mockFetch(() => ({ status: 401, body: { error: 'unauthorized' } })),
  });

  await assert.rejects(
    () => client.listReferenceCrops(),
    (err) => err.status === 401,
  );
});
