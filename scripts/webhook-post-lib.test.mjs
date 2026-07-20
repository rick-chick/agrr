import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  PERMANENT_HTTP_STATUS,
  RETRIABLE_HTTP_STATUS,
  WebhookPostError,
  parseCurlWebhookResponse,
  postWebhookJson,
} from './webhook-post-lib.mjs';

const BASE = {
  url: 'https://example.com/webhook',
  bearerToken: 'secret',
  body: { action: 'test' },
};

test('RETRIABLE_HTTP_STATUS includes 429, 500, 502, 503', () => {
  assert.equal(RETRIABLE_HTTP_STATUS.has(429), true);
  assert.equal(RETRIABLE_HTTP_STATUS.has(500), true);
  assert.equal(RETRIABLE_HTTP_STATUS.has(502), true);
  assert.equal(RETRIABLE_HTTP_STATUS.has(503), true);
});

test('PERMANENT_HTTP_STATUS includes 401, 403, 404', () => {
  assert.equal(PERMANENT_HTTP_STATUS.has(401), true);
  assert.equal(PERMANENT_HTTP_STATUS.has(403), true);
  assert.equal(PERMANENT_HTTP_STATUS.has(404), true);
});

test('parseCurlWebhookResponse splits body and status code', () => {
  assert.deepEqual(parseCurlWebhookResponse('{"ok":true}\n204'), {
    statusCode: 204,
    responseBody: '{"ok":true}',
  });
});

test('postWebhookJson returns on 2xx first attempt', () => {
  let calls = 0;
  const result = postWebhookJson({
    ...BASE,
    execFileSync: () => {
      calls += 1;
      return '\n204';
    },
    sleepSync: () => {},
    log: () => {},
  });
  assert.equal(result.ok, true);
  assert.equal(result.statusCode, 204);
  assert.equal(result.attempt, 1);
  assert.equal(calls, 1);
});

test('postWebhookJson retries 503 then succeeds', () => {
  let calls = 0;
  const sleeps = [];
  const logs = [];
  const result = postWebhookJson({
    ...BASE,
    execFileSync: () => {
      calls += 1;
      return calls < 2 ? '\n503' : '\n200';
    },
    sleepSync: (ms) => sleeps.push(ms),
    log: (message) => logs.push(message),
    backoffMs: () => 10,
  });
  assert.equal(result.ok, true);
  assert.equal(result.statusCode, 200);
  assert.equal(result.attempt, 2);
  assert.equal(calls, 2);
  assert.equal(sleeps.length, 1);
  assert.match(logs.join('\n'), /attempt 1\/3/);
  assert.match(logs.join('\n'), /attempt 2\/3/);
});

test('postWebhookJson retries 429 up to maxAttempts', () => {
  let calls = 0;
  assert.throws(
    () =>
      postWebhookJson({
        ...BASE,
        maxAttempts: 3,
        execFileSync: () => {
          calls += 1;
          return '\n429';
        },
        sleepSync: () => {},
        log: () => {},
        backoffMs: () => 1,
      }),
    (error) => {
      assert.ok(error instanceof WebhookPostError);
      assert.equal(error.statusCode, 429);
      assert.equal(error.attempt, 3);
      return true;
    },
  );
  assert.equal(calls, 3);
});

test('postWebhookJson does not retry permanent 401', () => {
  let calls = 0;
  assert.throws(
    () =>
      postWebhookJson({
        ...BASE,
        execFileSync: () => {
          calls += 1;
          return '\n401';
        },
        sleepSync: () => {
          throw new Error('sleep should not be called');
        },
        log: () => {},
      }),
    (error) => {
      assert.ok(error instanceof WebhookPostError);
      assert.equal(error.statusCode, 401);
      assert.equal(error.retriable, false);
      return true;
    },
  );
  assert.equal(calls, 1);
});

test('postWebhookJson does not retry permanent 404', () => {
  let calls = 0;
  assert.throws(
    () =>
      postWebhookJson({
        ...BASE,
        execFileSync: () => {
          calls += 1;
          return '\n404';
        },
        sleepSync: () => {
          throw new Error('sleep should not be called');
        },
        log: () => {},
      }),
    WebhookPostError,
  );
  assert.equal(calls, 1);
});

test('postWebhookJson retries transient curl error then succeeds', () => {
  let calls = 0;
  const sleeps = [];
  const logs = [];
  const result = postWebhookJson({
    ...BASE,
    execFileSync: () => {
      calls += 1;
      if (calls < 2) {
        const error = new Error('curl timeout');
        error.status = 28;
        throw error;
      }
      return '\n200';
    },
    sleepSync: (ms) => sleeps.push(ms),
    log: (message) => logs.push(message),
    backoffMs: () => 10,
  });
  assert.equal(result.ok, true);
  assert.equal(result.statusCode, 200);
  assert.equal(result.attempt, 2);
  assert.equal(calls, 2);
  assert.equal(sleeps.length, 1);
  assert.match(logs.join('\n'), /curl error/);
});

test('postWebhookJson retries 500 then succeeds', () => {
  let calls = 0;
  const sleeps = [];
  const result = postWebhookJson({
    ...BASE,
    execFileSync: () => {
      calls += 1;
      return calls < 2 ? '\n500' : '\n200';
    },
    sleepSync: (ms) => sleeps.push(ms),
    log: () => {},
    backoffMs: () => 10,
  });
  assert.equal(result.ok, true);
  assert.equal(result.statusCode, 200);
  assert.equal(result.attempt, 2);
  assert.equal(calls, 2);
  assert.equal(sleeps.length, 1);
});

test('postWebhookJson retries 502 then succeeds', () => {
  let calls = 0;
  const sleeps = [];
  const result = postWebhookJson({
    ...BASE,
    execFileSync: () => {
      calls += 1;
      return calls < 2 ? '\n502' : '\n200';
    },
    sleepSync: (ms) => sleeps.push(ms),
    log: () => {},
    backoffMs: () => 10,
  });
  assert.equal(result.ok, true);
  assert.equal(result.statusCode, 200);
  assert.equal(result.attempt, 2);
  assert.equal(calls, 2);
  assert.equal(sleeps.length, 1);
});

test('postWebhookJson throws WebhookPostError on non-integer HTTP status', () => {
  let calls = 0;
  assert.throws(
    () =>
      postWebhookJson({
        ...BASE,
        execFileSync: () => {
          calls += 1;
          return 'not-a-number';
        },
        sleepSync: () => {},
        log: () => {},
      }),
    (error) => {
      assert.ok(error instanceof WebhookPostError);
      assert.match(error.message, /Invalid (HTTP status|curl webhook response)/);
      return true;
    },
  );
  assert.equal(calls, 1);
});

test('postWebhookJson passes curl args with JSON body', () => {
  let capturedArgv;
  postWebhookJson({
    ...BASE,
    body: { hello: 'world' },
    execFileSync: (_cmd, argv) => {
      capturedArgv = argv;
      return '\n200';
    },
    sleepSync: () => {},
    log: () => {},
  });
  assert.ok(capturedArgv.includes('-d'));
  const dataIndex = capturedArgv.indexOf('-d');
  assert.equal(capturedArgv[dataIndex + 1], '{"hello":"world"}');
});

test('postWebhookJson logs response body on HTTP 400', () => {
  const logs = [];
  assert.throws(
    () =>
      postWebhookJson({
        ...BASE,
        execFileSync: () => '{"code":"invalid"}\n400',
        sleepSync: () => {},
        log: (message) => logs.push(message),
        maxAttempts: 1,
      }),
    (error) => {
      assert.ok(error instanceof WebhookPostError);
      assert.equal(error.statusCode, 400);
      assert.equal(error.responseBody, '{"code":"invalid"}');
      return true;
    },
  );
  assert.match(logs.join('\n'), /invalid/);
});
