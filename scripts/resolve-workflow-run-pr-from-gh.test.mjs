import assert from 'node:assert/strict';
import { test } from 'node:test';

import { resolveWorkflowRunPrFromGh } from './resolve-workflow-run-pr-from-gh.mjs';

const REPO = 'rick-chick/agrr';
const HEAD_SHA = 'abc123deadbeef';

test('resolveWorkflowRunPrFromGh returns mapped fields when one open PR is found', () => {
  const result = resolveWorkflowRunPrFromGh({
    repo: REPO,
    headSha: HEAD_SHA,
    workflowRunPullRequests: [],
    execFileSync: (cmd, argv) => {
      assert.equal(cmd, 'gh');
      if (argv[0] === 'api') {
        return JSON.stringify([
          {
            number: 42,
            state: 'open',
            title: 'Fix bug',
            body: 'PR body',
            head: { ref: 'feature/foo' },
            labels: [{ name: 'agent-ready' }],
            html_url: 'https://github.com/rick-chick/agrr/pull/42',
            user: { login: 'alice' },
          },
        ]);
      }
      throw new Error(`unexpected gh argv: ${argv.join(' ')}`);
    },
  });

  assert.equal(result.skip, false);
  assert.equal(result.number, 42);
  assert.equal(result.headRef, 'feature/foo');
  assert.equal(result.title, 'Fix bug');
  assert.equal(result.labels, 'agent-ready');
  assert.equal(result.author, 'alice');
});

test('resolveWorkflowRunPrFromGh returns skip when no open PR is found', () => {
  const result = resolveWorkflowRunPrFromGh({
    repo: REPO,
    headSha: HEAD_SHA,
    workflowRunPullRequests: [],
    execFileSync: (cmd, argv) => {
      assert.equal(cmd, 'gh');
      if (argv[0] === 'api') {
        return '[]';
      }
      if (argv[0] === 'pr' && argv[1] === 'list') {
        return '[]';
      }
      throw new Error(`unexpected gh argv: ${argv.join(' ')}`);
    },
  });

  assert.equal(result.skip, true);
  assert.match(result.skipReason, /No open PR found/);
});

test('resolveWorkflowRunPrFromGh reads HEAD_SHA alias via env-shaped input', () => {
  const result = resolveWorkflowRunPrFromGh({
    repo: REPO,
    headSha: HEAD_SHA,
    workflowRunPullRequests: [{ number: 99 }],
    execFileSync: (cmd, argv) => {
      if (argv[0] === 'api') {
        return '[]';
      }
      if (argv[0] === 'pr' && argv[1] === 'view') {
        return JSON.stringify({
          number: 99,
          state: 'open',
          title: 'From workflow_run',
          body: '',
          headRefName: 'cursor/issue-99',
          labels: [],
          url: 'https://github.com/rick-chick/agrr/pull/99',
          user: { login: 'bot' },
        });
      }
      throw new Error(`unexpected gh argv: ${argv.join(' ')}`);
    },
  });

  assert.equal(result.skip, false);
  assert.equal(result.number, 99);
  assert.equal(result.headRef, 'cursor/issue-99');
});
