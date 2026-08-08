import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import {
  COMPONENT_GUIDE_REQUIREMENTS,
  DARK_MODE_POLICY_REQUIREMENTS,
  auditDesignSystemGuide,
  findMissingGuideSections,
} from './check-design-system-guide-lib.mjs';

const SAMPLE_GUIDE = `# Component Guide

## Buttons
Use primary, secondary, and danger variants.

## アンチパターン
Do not place two primary buttons side by side.

## 空状態
See work-hub-empty and plan-list-empty patterns.

## エラーパネル
Use MasterLoadErrorPanel.

## パンくず
Use MasterContextHeaderComponent.

## Tokens
Run npm run audit:css-tokens:enforce.

## Reference implementations
- crops/:id — crop-detail.component.ts
- work-hub — work-hub.component.ts
- plan-list — plan-list.component.ts
`;

const SAMPLE_POLICY = `# Dark Mode Policy

## 方針 (B)
将来 prefers-color-scheme: dark でセマンティックトークンを上書きする。
`;

test('findMissingGuideSections reports absent sections', () => {
  const missing = findMissingGuideSections('primary only', COMPONENT_GUIDE_REQUIREMENTS);
  assert.ok(missing.length > 0);
  assert.ok(missing.includes('anti-patterns'));
});

test('findMissingGuideSections passes complete guide sample', () => {
  assert.deepEqual(findMissingGuideSections(SAMPLE_GUIDE, COMPONENT_GUIDE_REQUIREMENTS), []);
  assert.deepEqual(findMissingGuideSections(SAMPLE_POLICY, DARK_MODE_POLICY_REQUIREMENTS), []);
});

test('auditDesignSystemGuide fails when docs are missing', async () => {
  const root = await mkdtemp(join(tmpdir(), 'ds-guide-'));
  const result = await auditDesignSystemGuide(root);
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((e) => e.includes('COMPONENT-GUIDE.md')));
  assert.ok(result.errors.some((e) => e.includes('DARK-MODE-POLICY.md')));
});

test('auditDesignSystemGuide passes when docs satisfy contract', async () => {
  const root = await mkdtemp(join(tmpdir(), 'ds-guide-'));
  const docsDir = join(root, 'docs/design-system');
  await mkdir(docsDir, { recursive: true });
  await writeFile(join(docsDir, 'COMPONENT-GUIDE.md'), SAMPLE_GUIDE, 'utf8');
  await writeFile(join(docsDir, 'DARK-MODE-POLICY.md'), SAMPLE_POLICY, 'utf8');

  const result = await auditDesignSystemGuide(root);
  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('repository design-system docs satisfy contract', async () => {
  const root = join(import.meta.dirname, '..');
  const result = await auditDesignSystemGuide(root);
  assert.equal(result.ok, true, result.errors.join('\n'));
});
