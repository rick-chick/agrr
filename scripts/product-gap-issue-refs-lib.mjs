import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '..');

const SKILL_DIR = join(REPO_ROOT, '.cursor/skills/product-gap-to-issues');

export const PATHS = {
  issuePackTemplate: join(SKILL_DIR, 'references/issue-pack-template.md'),
  skill: join(SKILL_DIR, 'SKILL.md'),
  artifacts: join(SKILL_DIR, 'references/artifacts.md'),
  automationPrompt: join(SKILL_DIR, 'references/automation-prompt.md'),
};

/** @param {string} text */
export function assertIssuePackTemplateRefsPolicy(text) {
  const epicSection = text.match(/## Epic[\s\S]*?(?=\n---\n\n## 子 issue)/);
  if (!epicSection) {
    throw new Error('issue-pack-template.md must include Epic section with 参照');
  }
  const epic = epicSection[0];
  if (!/tmp\/product-gap\/.*禁止|禁止[\s\S]*?tmp\/product-gap\//.test(epic)) {
    throw new Error('Epic 参照節 must prohibit tmp/product-gap/ paths');
  }
  if (!/リポジトリ内のコード path|コード path（`frontend\/|crates\//.test(epic)) {
    throw new Error('Epic 参照節 must allow repository code paths');
  }
  if (!/#N|GitHub issue/.test(epic)) {
    throw new Error('Epic 参照節 must allow GitHub issue / PR numbers');
  }
  const epicRefsExample = epic.match(/## 参照[\s\S]*?```/);
  if (epicRefsExample && /tmp\/product-gap\//.test(epicRefsExample[0])) {
    throw new Error('Epic 参照節 example must not include tmp/product-gap/ path');
  }
}

/** @param {string} text */
export function assertSkillPhase9RefsPolicy(text) {
  const phase9 = text.match(/## フェーズ 9[\s\S]*?(?=## |$)/);
  if (!phase9) {
    throw new Error('SKILL.md must include フェーズ 9 section');
  }
  if (!/tmp\/product-gap\//.test(phase9[0]) || !/起票|gh issue create/.test(phase9[0])) {
    throw new Error('フェーズ 9 must mention not putting tmp/product-gap/ in issue bodies');
  }
}

/** @param {string} text */
export function assertArtifactsIssueCreateRefsPolicy(text) {
  if (!/起票時|gh issue create/.test(text)) {
    throw new Error('artifacts.md must document issue create reference conversion');
  }
  if (!/リポジトリ.*path|コード path/.test(text)) {
    throw new Error('artifacts.md must mention repository code paths in conversion');
  }
  if (!/#N|GitHub issue/.test(text)) {
    throw new Error('artifacts.md must mention GitHub issue numbers in conversion');
  }
  if (!/tmp\/product-gap\//.test(text) || !/変換|置換|載せない/.test(text)) {
    throw new Error('artifacts.md must describe converting away tmp/product-gap/ refs');
  }
}

/** @param {string} text */
export function assertAutomationPromptRefsPolicy(text) {
  if (!/tmp\/product-gap\//.test(text)) {
    throw new Error('automation-prompt.md must mention tmp/product-gap/ artifact location');
  }
  if (!/issue.*参照|参照.*issue|gh issue create/.test(text)) {
    throw new Error('automation-prompt.md must constrain issue body references');
  }
  if (!/リポジトリ|コード path|#N/.test(text)) {
    throw new Error('automation-prompt.md must allow only repo paths and #N in issue refs');
  }
}

export async function loadProductGapIssueRefsDocs() {
  const [issuePackTemplate, skill, artifacts, automationPrompt] = await Promise.all([
    readFile(PATHS.issuePackTemplate, 'utf8'),
    readFile(PATHS.skill, 'utf8'),
    readFile(PATHS.artifacts, 'utf8'),
    readFile(PATHS.automationPrompt, 'utf8'),
  ]);
  return { issuePackTemplate, skill, artifacts, automationPrompt };
}

export async function auditProductGapIssueRefsDocs() {
  const docs = await loadProductGapIssueRefsDocs();
  assertIssuePackTemplateRefsPolicy(docs.issuePackTemplate);
  assertSkillPhase9RefsPolicy(docs.skill);
  assertArtifactsIssueCreateRefsPolicy(docs.artifacts);
  assertAutomationPromptRefsPolicy(docs.automationPrompt);
  return docs;
}
