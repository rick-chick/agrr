import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  auditComponentGuideContent,
  auditDarkModeAdrContent,
  auditDesignSystemDocs,
} from './design-system-component-guide-lib.mjs';

test('auditComponentGuideContent rejects incomplete guide', () => {
  const violations = auditComponentGuideContent('# Component guide\n');
  assert.ok(violations.length > 0);
  assert.ok(violations.some((v) => v.rule === 'required-heading'));
});

test('auditComponentGuideContent accepts complete guide', () => {
  const markdown = `
# Component guide
## Button variants
Use btn-primary, btn-secondary, btn-danger for actions.
## Anti-patterns
Do not place two btn-primary buttons side by side.
## Shared components
MasterLoadErrorPanelComponent for errors.
MasterContextHeaderComponent for breadcrumb.
## Design tokens
Use audit:css-tokens and check:btn-base-class.
## Reference implementations
/crops/:id, /work, /plans
## Dark mode policy
See ADR-003.
`;
  assert.deepEqual(auditComponentGuideContent(markdown), []);
});

test('auditDarkModeAdrContent requires future-support decision', () => {
  const violations = auditDarkModeAdrContent('# ADR\n## Context\n');
  assert.ok(violations.length > 0);
});

test('auditDarkModeAdrContent accepts option B policy', () => {
  const markdown = `
# ADR-003
## Decision
将来対応予定。styles.css のトークンを拡張し、prefers-color-scheme で切り替える。
`;
  assert.deepEqual(auditDarkModeAdrContent(markdown), []);
});

test('auditDesignSystemDocs passes on repository docs', async () => {
  const frontendRoot = new URL('..', import.meta.url).pathname;
  const violations = await auditDesignSystemDocs(frontendRoot);
  assert.deepEqual(violations, []);
});
