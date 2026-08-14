import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  assertArtifactsIssueCreateRefsPolicy,
  assertAutomationPromptRefsPolicy,
  assertIssuePackTemplateRefsPolicy,
  assertSkillPhase9RefsPolicy,
  auditProductGapIssueRefsDocs,
} from './product-gap-issue-refs-lib.mjs';

test('issue-pack-template Epic 参照節 prohibits tmp/product-gap and allows repo paths + #N', async () => {
  const { issuePackTemplate } = await auditProductGapIssueRefsDocs();
  assert.doesNotThrow(() => assertIssuePackTemplateRefsPolicy(issuePackTemplate));
});

test('SKILL.md フェーズ9 documents not putting tmp/product-gap in issue bodies', async () => {
  const { skill } = await auditProductGapIssueRefsDocs();
  assert.doesNotThrow(() => assertSkillPhase9RefsPolicy(skill));
});

test('artifacts.md documents reference conversion before gh issue create', async () => {
  const { artifacts } = await auditProductGapIssueRefsDocs();
  assert.doesNotThrow(() => assertArtifactsIssueCreateRefsPolicy(artifacts));
});

test('automation-prompt.md is consistent with issue reference constraints', async () => {
  const { automationPrompt } = await auditProductGapIssueRefsDocs();
  assert.doesNotThrow(() => assertAutomationPromptRefsPolicy(automationPrompt));
});

test('audit rejects Epic template with tmp/product-gap in 参照 example', () => {
  const bad = `
## Epic
**参照の制約** — tmp/product-gap/ path は**禁止**
- リポジトリ内のコード path（例: frontend/src/app/...）
- 関連 GitHub issue / PR 番号（#N）
\`\`\`markdown
## 参照
- tmp/product-gap/screen-mocks.md
\`\`\`

---

## 子 issue
`;
  assert.throws(
    () => assertIssuePackTemplateRefsPolicy(bad),
    /must not include tmp\/product-gap/,
  );
});
