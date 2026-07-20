import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import {
  DELIVERY_AGENT_AUTOMATION_PROMPT,
  buildDeliveryAgentPrefillToken,
  buildDeliveryAgentPrefillUrl,
  decodeDeliveryAgentPrefillToken,
} from './delivery-agent-automation-prompt-lib.mjs';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

test('delivery agent automation prompt documents pr_unlinked webhook field', () => {
  assert.match(
    DELIVERY_AGENT_AUTOMATION_PROMPT,
    /pr_unlinked \(optional\)/,
  );
  assert.match(
    DELIVERY_AGENT_AUTOMATION_PROMPT,
    /ux-campaign-loop/,
  );
});

test('prefill token round-trips canonical prompt', () => {
  const { prompt } = decodeDeliveryAgentPrefillToken(buildDeliveryAgentPrefillToken());
  assert.equal(prompt, DELIVERY_AGENT_AUTOMATION_PROMPT);
});

test('cursor-automation-schedule embeds pr_unlinked in Delivery Agent prefill', async () => {
  const schedulePath = join(
    REPO_ROOT,
    '.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md',
  );
  const text = await readFile(schedulePath, 'utf8');
  const match = text.match(/automations\/new\?prefill=([A-Za-z0-9_-]+)/);
  assert.ok(match, 'schedule must include Delivery Agent prefill URL');
  const { prompt } = decodeDeliveryAgentPrefillToken(match[1]);
  assert.match(prompt, /pr_unlinked \(optional\)/);
});

test('delivery-agent SKILL automation block matches canonical prompt', async () => {
  const skillPath = join(REPO_ROOT, '.cursor/skills/delivery-agent/SKILL.md');
  const text = await readFile(skillPath, 'utf8');
  const block = text.match(/## Automation[\s\S]*?```\n([\s\S]*?)\n```/);
  assert.ok(block, 'SKILL must include automation prompt block');
  assert.equal(block[1].trim(), DELIVERY_AGENT_AUTOMATION_PROMPT.trim());
});

test('buildDeliveryAgentPrefillUrl is stable', () => {
  assert.equal(
    buildDeliveryAgentPrefillUrl(),
    `https://cursor.com/automations/new?prefill=${buildDeliveryAgentPrefillToken()}`,
  );
});
