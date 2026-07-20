import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  AGENT_DEPS_READY_LABEL,
  AGENT_DEPS_WAIT_LABEL_PREFIX,
  agentDepsWaitLabel,
  hasAgentDepsReadyLabel,
  isAgentDepsLabelCacheHit,
  normalizeLabelNames,
  parseAgentDepsWaitIssueNumbers,
} from './issue-worker-deps-agent-lib.mjs';

test('normalizeLabelNames accepts csv and objects', () => {
  assert.deepEqual(normalizeLabelNames('agent-ready, epic'), ['agent-ready', 'epic']);
  assert.deepEqual(normalizeLabelNames([{ name: 'agent-ready' }, 'epic']), [
    'agent-ready',
    'epic',
  ]);
});

test('parseAgentDepsWaitIssueNumbers reads agent-deps-wait-N labels only', () => {
  const labels = [
    AGENT_DEPS_READY_LABEL,
    agentDepsWaitLabel(317),
    agentDepsWaitLabel(384),
    'agent-ready',
    `${AGENT_DEPS_WAIT_LABEL_PREFIX}0`,
    `${AGENT_DEPS_WAIT_LABEL_PREFIX}abc`,
  ];
  assert.deepEqual(parseAgentDepsWaitIssueNumbers(labels), [317, 384]);
});

test('hasAgentDepsReadyLabel and isAgentDepsLabelCacheHit', () => {
  assert.equal(hasAgentDepsReadyLabel(['agent-ready']), false);
  assert.equal(hasAgentDepsReadyLabel([AGENT_DEPS_READY_LABEL]), true);
  assert.equal(isAgentDepsLabelCacheHit([AGENT_DEPS_READY_LABEL]), true);
  assert.equal(isAgentDepsLabelCacheHit([agentDepsWaitLabel(317)]), false);
});
