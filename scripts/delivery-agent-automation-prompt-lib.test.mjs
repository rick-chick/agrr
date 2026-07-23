import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import {
  DELIVERY_AGENT_AUTOMATION_ID,
  DELIVERY_AGENT_AUTOMATION_PROMPT,
  buildDeliveryAgentAutomationApplyUrl,
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

test('delivery agent automation prompt forbids skipping pr_unlinked review for agent-no-merge', () => {
  assert.match(
    DELIVERY_AGENT_AUTOMATION_PROMPT,
    /agent-no-merge.*machine routing/i,
  );
  assert.match(
    DELIVERY_AGENT_AUTOMATION_PROMPT,
    /§0a/,
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

test('buildDeliveryAgentAutomationApplyUrl targets live automation with canonical prefill', () => {
  assert.equal(
    DELIVERY_AGENT_AUTOMATION_ID,
    '6a5cb2d9-8317-11f1-a7d1-d6b4613131ce',
  );
  const url = buildDeliveryAgentAutomationApplyUrl();
  assert.equal(
    url,
    `https://cursor.com/automations/${DELIVERY_AGENT_AUTOMATION_ID}?prefill=${buildDeliveryAgentPrefillToken()}`,
  );
  const token = new URL(url).searchParams.get('prefill');
  assert.ok(token);
  const { prompt } = decodeDeliveryAgentPrefillToken(token);
  assert.equal(prompt, DELIVERY_AGENT_AUTOMATION_PROMPT);
});

test('cursor-automation-schedule embeds one-click apply URL for live Delivery Agent', async () => {
  const schedulePath = join(
    REPO_ROOT,
    '.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md',
  );
  const text = await readFile(schedulePath, 'utf8');
  const applyUrl = buildDeliveryAgentAutomationApplyUrl();
  assert.match(
    text,
    new RegExp(applyUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')),
    'schedule must include live Delivery Agent apply URL',
  );
  assert.doesNotMatch(text, /cursor\.com\/https:\/\//);
});

test('cursor-automation-schedule keeps UX Issue Audit prefill separate from Delivery Agent', async () => {
  const schedulePath = join(
    REPO_ROOT,
    '.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md',
  );
  const text = await readFile(schedulePath, 'utf8');
  const uxMatch = text.match(
    /- \*\*UX Issue Audit（月曜 9:00）\*\*:[^\n]*prefill=([A-Za-z0-9_-]+)/,
  );
  assert.ok(uxMatch, 'schedule must include UX Issue Audit prefill URL');
  const { prompt } = decodeDeliveryAgentPrefillToken(uxMatch[1]);
  assert.match(prompt, /UX Issue Audit/i);
  assert.doesNotMatch(prompt, /delivery-agent\/SKILL\.md/i);
});
