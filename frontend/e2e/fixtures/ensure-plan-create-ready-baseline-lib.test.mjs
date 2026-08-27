import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  createFetchTransport,
  parseRows,
  pollFarmWeatherCompleted,
} from './ensure-plan-create-ready-baseline-lib.mjs';

test('parseRows accepts array payloads', () => {
  assert.deepEqual(parseRows([{ id: 1 }]), [{ id: 1 }]);
  assert.deepEqual(parseRows({}), []);
});

test('pollFarmWeatherCompleted returns when weather_data_status is completed', async () => {
  let attempts = 0;
  const transport = {
    async get(path) {
      attempts += 1;
      const status = attempts >= 2 ? 'completed' : 'fetching';
      return {
        ok: true,
        status: 200,
        json: async () => ({ weather_data_status: status, weather_data_progress: 100 }),
        text: async () => '',
      };
    },
    async post() {
      throw new Error('unexpected post');
    },
  };

  await pollFarmWeatherCompleted(transport, 42, { maxAttempts: 5, sleepMs: 0 });
  assert.equal(attempts, 2);
});

test('createFetchTransport prefixes api origin', async () => {
  let requestedUrl = '';
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    requestedUrl = String(url);
    return new Response(JSON.stringify([]), { status: 200 });
  };
  try {
    const transport = createFetchTransport('http://127.0.0.1:4200', { Cookie: 'session_id=test' });
    await transport.get('/api/v1/plans');
    assert.equal(requestedUrl, 'http://127.0.0.1:4200/api/v1/plans');
  } finally {
    globalThis.fetch = originalFetch;
  }
});
