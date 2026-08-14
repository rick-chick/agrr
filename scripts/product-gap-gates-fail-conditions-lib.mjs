import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const GATES_REL = '.cursor/skills/product-gap-to-issues/references/gates.md';
const SUBAGENT_PROMPTS_REL =
  '.cursor/skills/product-gap-to-issues/references/subagent-prompts.md';
const SKILL_REL = '.cursor/skills/product-gap-to-issues/SKILL.md';

/** @typedef {{ ok: boolean; errors: string[] }} CheckResult */

/**
 * Verify product-gap gates.md fail conditions for breadth-depth-scale stop
 * and theme-selection 見送り (issue #908).
 * @param {string} rootDir
 * @returns {CheckResult}
 */
export function checkProductGapGatesFailConditions(rootDir) {
  const errors = [];

  const gatesPath = join(rootDir, GATES_REL);
  if (!existsSync(gatesPath)) {
    return { ok: false, errors: [`${GATES_REL}: missing`] };
  }
  const gates = readFileSync(gatesPath, 'utf8');

  const subagentPath = join(rootDir, SUBAGENT_PROMPTS_REL);
  if (!existsSync(subagentPath)) {
    errors.push(`${SUBAGENT_PROMPTS_REL}: missing`);
  }
  const subagent = existsSync(subagentPath) ? readFileSync(subagentPath, 'utf8') : '';

  const skillPath = join(rootDir, SKILL_REL);
  if (!existsSync(skillPath)) {
    errors.push(`${SKILL_REL}: missing`);
  }
  const skill = existsSync(skillPath) ? readFileSync(skillPath, 'utf8') : '';

  // G2 fail rows for deep-dive stop conditions (breadth-depth-scale.md §深掘り打ち止め)
  const g2StopPatterns = [
    { id: 'G2-5', pattern: /G2-5/ },
    { id: 'G2-5 G2-3', pattern: /G2-3.*抵触|抵触.*G2-3/i },
    { id: 'G2-6', pattern: /G2-6/ },
    { id: 'G2-6 depth', pattern: /深さ寄り.*2\s*未満|2\s*未満.*深さ寄り/ },
    { id: 'G2-7', pattern: /G2-7/ },
    { id: 'G2-7 existing', pattern: /既存強化で足りる/ },
  ];
  for (const { id, pattern } of g2StopPatterns) {
    if (!pattern.test(gates)) {
      errors.push(`${GATES_REL}: missing deep-dive stop fail condition (${id})`);
    }
  }

  // theme-selection 見送り fail
  if (!/G2-8/.test(gates)) {
    errors.push(`${GATES_REL}: missing theme-selection 見送り fail row (G2-8)`);
  }
  if (!/見送り（反対側）/.test(gates)) {
    errors.push(`${GATES_REL}: missing 見送り（反対側） fail condition text`);
  }

  // mandatory_corrections aligned with breadth-depth-scale
  const correctionPatterns = [
    /打ち止め/,
    /見送り/,
    /幅候補|幅に回す|テーマ差し替え/,
  ];
  for (const pattern of correctionPatterns) {
    if (!pattern.test(gates)) {
      errors.push(`${GATES_REL}: mandatory_corrections missing breadth-depth-scale alignment (${pattern})`);
    }
  }

  // G2 inputs include theme-selection.md
  const g2Section = gates.split('## G3')[0] ?? gates;
  if (!/theme-selection\.md/.test(g2Section)) {
    errors.push(`${GATES_REL}: G2 inputs missing theme-selection.md`);
  }

  // subagent-prompts §4 and §5 list theme-selection.md + theme-deep-dive.md as inputs
  const section4 = extractSection(subagent, '## §4');
  const section5 = extractSection(subagent, '## §5');
  if (!section4.includes('theme-selection.md') || !section4.includes('theme-deep-dive.md')) {
    errors.push(`${SUBAGENT_PROMPTS_REL}: §4 must list theme-selection.md and theme-deep-dive.md as G2 inputs`);
  }
  if (!section5.includes('theme-selection.md')) {
    errors.push(`${SUBAGENT_PROMPTS_REL}: §5 must list theme-selection.md as G3 input`);
  }

  // SKILL.md phases 3 and 4 reference gates
  const phase3 = extractSkillPhase(skill, '## フェーズ 3');
  const phase4 = extractSkillPhase(skill, '## フェーズ 4');
  if (!/gates\.md|G2-/.test(phase3)) {
    errors.push(`${SKILL_REL}: phase 3 must reference gates.md or G2 fail conditions`);
  }
  if (!/gates\.md|G2-/.test(phase4)) {
    errors.push(`${SKILL_REL}: phase 4 must reference gates.md or G2 fail conditions`);
  }

  return { ok: errors.length === 0, errors };
}

/**
 * @param {string} text
 * @param {string} heading
 */
function extractSection(text, heading) {
  const start = text.indexOf(heading);
  if (start < 0) return '';
  const rest = text.slice(start + heading.length);
  const next = rest.search(/\n## §/);
  return next < 0 ? rest : rest.slice(0, next);
}

/**
 * @param {string} text
 * @param {string} heading
 */
function extractSkillPhase(text, heading) {
  const start = text.indexOf(heading);
  if (start < 0) return '';
  const rest = text.slice(start);
  const next = rest.search(/\n## フェーズ \d/);
  if (next > 0) return rest.slice(0, next);
  const nextSection = rest.search(/\n## [^フェ]/);
  return nextSection > 0 ? rest.slice(0, nextSection) : rest;
}
