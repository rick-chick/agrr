import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const SKILL_PATH = '.cursor/skills/product-gap-to-issues/SKILL.md';
const ARTIFACTS_PATH = '.cursor/skills/product-gap-to-issues/references/artifacts.md';
const PROMPTS_PATH = '.cursor/skills/product-gap-to-issues/references/subagent-prompts.md';

const REQUIRED_PROMPT_SNIPPETS = [
  'gh issue list',
  'gh issue view',
  'OPEN',
  'CLOSED',
  'gh pr list',
  'merged',
];

const REQUIRED_CURRENT_STATE_SECTIONS = [
  '既存 backlog',
  '実装済み',
  'できること一覧',
  '計画→実行→学習',
];

const REQUIRED_SKILL_SNIPPETS = [
  'current-state.md',
  '既存 backlog',
  'マージ済み PR',
  'フェーズ 2',
  '調査を継続',
];

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean; errors: string[] }}
 */
export function verifyProductGapPhase1CurrentState(repoRoot) {
  const errors = [];

  const skillPath = join(repoRoot, SKILL_PATH);
  const artifactsPath = join(repoRoot, ARTIFACTS_PATH);
  const promptsPath = join(repoRoot, PROMPTS_PATH);

  for (const [label, path] of [
    ['SKILL', skillPath],
    ['artifacts', artifactsPath],
    ['subagent-prompts', promptsPath],
  ]) {
    if (!existsSync(path)) {
      errors.push(`missing ${label}: ${path}`);
    }
  }

  if (errors.length > 0) {
    return { ok: false, errors };
  }

  const skillText = readFileSync(skillPath, 'utf8');
  const artifactsText = readFileSync(artifactsPath, 'utf8');
  const promptsText = readFileSync(promptsPath, 'utf8');

  const section1 = promptsText.split('## §2')[0] ?? '';
  if (!section1.includes('## §1')) {
    errors.push(`${PROMPTS_PATH} must define ## §1`);
  }

  for (const snippet of REQUIRED_PROMPT_SNIPPETS) {
    if (!section1.includes(snippet)) {
      errors.push(`${PROMPTS_PATH} §1 must mention: ${snippet}`);
    }
  }

  for (const section of REQUIRED_CURRENT_STATE_SECTIONS) {
    const inPrompts = section1.includes(section);
    const inArtifacts = artifactsText.includes(section);
    if (!inPrompts && !inArtifacts) {
      errors.push(
        `current-state required section "${section}" must appear in ${PROMPTS_PATH} §1 or ${ARTIFACTS_PATH}`,
      );
    }
  }

  if (!artifactsText.includes('current-state.md')) {
    errors.push(`${ARTIFACTS_PATH} must define current-state.md required sections`);
  }

  for (const snippet of REQUIRED_SKILL_SNIPPETS) {
    if (!skillText.includes(snippet)) {
      errors.push(`${SKILL_PATH} must mention: ${snippet}`);
    }
  }

  const phase1Section = skillText.split('## フェーズ 2')[0] ?? '';
  if (!phase1Section.includes('必須セクション') || !phase1Section.includes('空')) {
    errors.push(`${SKILL_PATH} phase 1 must require non-empty current-state sections before phase 2`);
  }

  return { ok: errors.length === 0, errors };
}
