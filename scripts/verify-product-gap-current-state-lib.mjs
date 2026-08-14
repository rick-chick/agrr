import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const SUBAGENT_PROMPTS_PATH =
  '.cursor/skills/product-gap-to-issues/references/subagent-prompts.md';
const ARTIFACTS_PATH =
  '.cursor/skills/product-gap-to-issues/references/artifacts.md';
const SKILL_PATH = '.cursor/skills/product-gap-to-issues/SKILL.md';

const SUBAGENT_PROMPTS_SNIPPETS = [
  'gh issue list',
  'gh issue view',
  'OPEN / CLOSED',
  'gh pr list',
  'merged',
];

const ARTIFACTS_SNIPPETS = [
  '既存 backlog',
  '実装済み',
  'できること一覧',
  '計画→実行→学習',
];

const SKILL_SNIPPETS = [
  'gh issue',
  'マージ済み PR',
  'current-state.md',
  'フェーズ 2',
  '調査を継続',
];

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyProductGapCurrentState(repoRoot) {
  const errors = [];

  const subagentPath = join(repoRoot, SUBAGENT_PROMPTS_PATH);
  let subagentText = '';
  try {
    subagentText = await readFile(subagentPath, 'utf8');
  } catch {
    errors.push(`missing required path: ${SUBAGENT_PROMPTS_PATH}`);
  }

  if (subagentText) {
    const section1Start = subagentText.indexOf('## §1');
    const section2Start = subagentText.indexOf('## §2');
    const section1 =
      section1Start >= 0 && section2Start > section1Start
        ? subagentText.slice(section1Start, section2Start)
        : subagentText;

    for (const snippet of SUBAGENT_PROMPTS_SNIPPETS) {
      if (!section1.includes(snippet)) {
        errors.push(
          `${SUBAGENT_PROMPTS_PATH} §1 missing required snippet: ${snippet}`,
        );
      }
    }
  }

  const artifactsPath = join(repoRoot, ARTIFACTS_PATH);
  let artifactsText = '';
  try {
    artifactsText = await readFile(artifactsPath, 'utf8');
  } catch {
    errors.push(`missing required path: ${ARTIFACTS_PATH}`);
  }

  if (artifactsText) {
    for (const snippet of ARTIFACTS_SNIPPETS) {
      if (!artifactsText.includes(snippet)) {
        errors.push(`${ARTIFACTS_PATH} missing required snippet: ${snippet}`);
      }
    }
    if (!artifactsText.includes('current-state.md')) {
      errors.push(`${ARTIFACTS_PATH} must define current-state.md sections`);
    }
  }

  const skillPath = join(repoRoot, SKILL_PATH);
  let skillText = '';
  try {
    skillText = await readFile(skillPath, 'utf8');
  } catch {
    errors.push(`missing required path: ${SKILL_PATH}`);
  }

  if (skillText) {
    for (const snippet of SKILL_SNIPPETS) {
      if (!skillText.includes(snippet)) {
        errors.push(`${SKILL_PATH} missing required snippet: ${snippet}`);
      }
    }
  }

  return { ok: errors.length === 0, errors };
}
