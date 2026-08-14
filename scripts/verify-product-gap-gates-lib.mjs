import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const GATES_REL = '.cursor/skills/product-gap-to-issues/references/gates.md';
const SUBAGENT_PROMPTS_REL =
  '.cursor/skills/product-gap-to-issues/references/subagent-prompts.md';
const SKILL_REL = '.cursor/skills/product-gap-to-issues/SKILL.md';

/**
 * Verify product-gap gates.md includes breadth-depth-scale fail conditions (issue #908).
 * @param {string} repoRoot
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifyProductGapBreadthDepthGates(repoRoot) {
  const errors = [];
  const gatesPath = join(repoRoot, GATES_REL);
  const subagentPath = join(repoRoot, SUBAGENT_PROMPTS_REL);
  const skillPath = join(repoRoot, SKILL_REL);

  let gates;
  let subagent;
  let skill;
  try {
    gates = readFileSync(gatesPath, 'utf8');
    subagent = readFileSync(subagentPath, 'utf8');
    skill = readFileSync(skillPath, 'utf8');
  } catch (err) {
    return { ok: false, errors: [`read failed: ${err.message}`] };
  }

  const g2Section = extractSection(gates, '## G2:', '## G3:');
  const g3Section = extractSection(gates, '## G3:', '## 集約');

  // G2: each 深掘り打ち止め condition → fail row
  const g2StopConditions = [
    {
      patterns: [/G2-5/, /深掘り打ち止め/],
      hint: 'G2 fail for 深掘り打ち止め (breadth-depth-scale.md §深掘り打ち止め)',
    },
    {
      patterns: [/G2-3.*打ち止め|打ち止め.*G2-3/i, /根拠なしのチャート/],
      hint: 'G2 fail linking G2-3 excess to 打ち止め',
    },
    {
      patterns: [/深さ寄り.*2\s*未満|2\s*未満.*深さ寄り/],
      hint: 'G2 fail for core-5 depth-oriented < 2 with breadth candidates',
    },
    {
      patterns: [/既存強化で足りる/],
      hint: 'G2 fail for 既存強化で足りる 打ち止め condition',
    },
  ];

  for (const cond of g2StopConditions) {
    if (!cond.patterns.every((p) => p.test(g2Section))) {
      errors.push(`gates.md §G2 missing: ${cond.hint}`);
    }
  }

  // G3: theme-selection 見送り（反対側） missing → fail
  if (!/G3-\d+.*見送り（反対側）|見送り（反対側）.*G3-\d+/s.test(g3Section)) {
    errors.push(
      'gates.md §G3 missing fail condition for theme-selection.md 見送り（反対側） row',
    );
  }

  // mandatory_corrections guidance
  const correctionPatterns = [/打ち止め/, /見送り/, /幅.*候補|幅候補/];
  for (const p of correctionPatterns) {
    if (!p.test(gates)) {
      errors.push(`gates.md missing mandatory_corrections guidance matching ${p}`);
    }
  }

  // subagent-prompts §5: theme-selection.md as G3 input
  const section5 = extractSection(subagent, '## §5', '---');
  if (!/theme-selection\.md/.test(section5)) {
    errors.push('subagent-prompts.md §5 must list theme-selection.md as G3 input');
  }
  if (!/theme-deep-dive\.md/.test(section5)) {
    errors.push('subagent-prompts.md §5 must list theme-deep-dive.md as G3 input');
  }

  // subagent-prompts §4: theme-selection.md as G2 input (breadth-depth context)
  const section4 = extractSection(subagent, '## §4', '## §5');
  if (!/theme-selection\.md/.test(section4)) {
    errors.push('subagent-prompts.md §4 must list theme-selection.md as G2 input');
  }

  // SKILL.md phase 3 & 4 gate references
  const phase3 = extractSkillPhase(skill, '## フェーズ 3');
  const phase4 = extractSkillPhase(skill, '## フェーズ 4');
  if (!/gates\.md|G3-\d+|見送り/.test(phase3)) {
    errors.push('SKILL.md フェーズ3 must reference gates.md / 見送り fail correspondence');
  }
  if (!/gates\.md|G2-\d+|打ち止め/.test(phase4)) {
    errors.push('SKILL.md フェーズ4 must reference gates.md / 打ち止め fail correspondence');
  }

  return { ok: errors.length === 0, errors };
}

/**
 * @param {string} text
 * @param {string} startMarker
 * @param {string} endMarker
 */
function extractSection(text, startMarker, endMarker) {
  const start = text.indexOf(startMarker);
  if (start < 0) return '';
  const end = text.indexOf(endMarker, start + startMarker.length);
  return end < 0 ? text.slice(start) : text.slice(start, end);
}

/**
 * @param {string} skill
 * @param {string} phaseMarker
 */
function extractSkillPhase(skill, phaseMarker) {
  const start = skill.indexOf(phaseMarker);
  if (start < 0) return '';
  const nextPhase = skill.indexOf('## フェーズ', start + phaseMarker.length);
  return nextPhase < 0 ? skill.slice(start) : skill.slice(start, nextPhase);
}
