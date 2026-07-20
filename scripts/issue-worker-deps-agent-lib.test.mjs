import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  AGENT_DEPS_MARKER,
  buildAgentDepsCacheComment,
  createGetAgentDepsContractFromComments,
  hashIssueBody,
  isAgentDepsCacheValid,
  parseAgentDepsFromCommentBody,
  parseAgentDepsFromComments,
} from './issue-worker-deps-agent-lib.mjs';

const body384 = [
  '## 依存',
  '',
  '- なし（既存 open issue #362 epic「作業予定画面」とは独立。着手ブロックしない）',
].join('\n');

const body402 = [
  '## 依存',
  '',
  '- #384（タブラベル整合。open の間は着手不可）',
].join('\n');

test('hashIssueBody is stable for full issue body', () => {
  const hash1 = hashIssueBody(body384);
  const hash2 = hashIssueBody(body384);
  assert.equal(hash1, hash2);
  assert.match(hash1, /^[a-f0-9]{64}$/);
});

test('parseAgentDepsFromCommentBody reads embedded JSON contract', () => {
  const contract = {
    hard_dependencies: [],
    soft_notes: ['#362 は独立'],
    rationale: 'なし行のみ。参照 issue は hard に含めない。',
    body_hash: hashIssueBody(body384),
  };
  const comment = buildAgentDepsCacheComment(contract);
  assert.match(comment, new RegExp(AGENT_DEPS_MARKER));
  const parsed = parseAgentDepsFromCommentBody(comment);
  assert.deepEqual(parsed, contract);
});

test('parseAgentDepsFromComments picks newest valid comment', () => {
  const older = buildAgentDepsCacheComment({
    hard_dependencies: [362],
    soft_notes: [],
    rationale: 'stale',
    body_hash: 'deadbeef',
  });
  const newer = buildAgentDepsCacheComment({
    hard_dependencies: [],
    soft_notes: [],
    rationale: 'current',
    body_hash: hashIssueBody(body384),
  });
  const parsed = parseAgentDepsFromComments([
    { body: older, createdAt: '2026-01-01T00:00:00Z' },
    { body: newer, createdAt: '2026-01-02T00:00:00Z' },
  ]);
  assert.equal(parsed?.rationale, 'current');
  assert.deepEqual(parsed?.hard_dependencies, []);
});

test('isAgentDepsCacheValid compares body_hash', () => {
  const contract = {
    hard_dependencies: [384],
    soft_notes: [],
    rationale: 'blocks on #384',
    body_hash: hashIssueBody(body402),
  };
  assert.equal(isAgentDepsCacheValid(contract, body402), true);
  assert.equal(isAgentDepsCacheValid(contract, body384), false);
});

test('createGetAgentDepsContractFromComments returns null on cache miss or stale hash', async () => {
  const contract = {
    hard_dependencies: [384],
    soft_notes: [],
    rationale: 'blocks on #384',
    body_hash: hashIssueBody(body402),
  };
  const comment = buildAgentDepsCacheComment(contract);
  const getContract = createGetAgentDepsContractFromComments(async () => [
    { body: comment, createdAt: '2026-01-02T00:00:00Z' },
  ]);

  assert.deepEqual(await getContract(402, body402), contract);
  assert.equal(await getContract(402, body384), null);
});

test('createGetAgentDepsContractFromComments ignores invalid contract payloads', async () => {
  const getContract = createGetAgentDepsContractFromComments(async () => [
    {
      body: `<!-- ${AGENT_DEPS_MARKER} {"hard_dependencies":[0],"soft_notes":[],"rationale":"x","body_hash":"abc"} -->`,
      createdAt: '2026-01-02T00:00:00Z',
    },
  ]);

  assert.equal(await getContract(1, body384), null);
});
