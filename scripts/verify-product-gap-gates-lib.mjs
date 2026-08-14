import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const GATES_REL = '.cursor/skills/product-gap-to-issues/references/gates.md';
const SUBAGENT_PROMPTS_REL =
  '.cursor/skills/product-gap-to-issues/references/subagent-prompts.md';
const ARTIFACTS_REL =
  '.cursor/skills/product-gap-to-issues/references/artifacts.md';
const SKILL_REL = '.cursor/skills/product-gap-to-issues/SKILL.md';

/**
 * Verify product-gap gates include github-issue-creator §3 backlog duplication fail
 * conditions (issue #907).
 * @param {string} repoRoot
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifyProductGapBacklogDuplicationGates(repoRoot) {
  const errors = [];
  const gatesPath = join(repoRoot, GATES_REL);
  const subagentPath = join(repoRoot, SUBAGENT_PROMPTS_REL);
  const artifactsPath = join(repoRoot, ARTIFACTS_REL);
  const skillPath = join(repoRoot, SKILL_REL);

  let gates;
  let subagent;
  let artifacts;
  let skill;
  try {
    gates = readFileSync(gatesPath, 'utf8');
    subagent = readFileSync(subagentPath, 'utf8');
    artifacts = readFileSync(artifactsPath, 'utf8');
    skill = readFileSync(skillPath, 'utf8');
  } catch (err) {
    return { ok: false, errors: [`read failed: ${err.message}`] };
  }

  const g2Section = extractSection(gates, '## G2:', '## G3:');
  const g3Section = extractSection(gates, '## G3:', '## 集約');

  const backlogGateSection = g2Section.includes('G2-5') &&
    /既存 backlog|backlog 重複/i.test(g2Section)
    ? g2Section
    : g3Section;

  const backlogFailRows = [
    {
      patterns: [/G\d-\d+/, /OPEN.*同一要求|同一要求.*OPEN/s],
      hint: 'fail for OPEN issue with same request (no new Epic/child)',
    },
    {
      patterns: [/G\d-\d+/, /CLOSED.*already_fixed|already_fixed.*CLOSED/s],
      hint: 'fail for CLOSED already_fixed equivalent (record reason)',
    },
    {
      patterns: [/G\d-\d+/, /部分重複/],
      hint: 'fail or blocked for partial overlap with mandatory_corrections',
    },
  ];

  for (const row of backlogFailRows) {
    if (!row.patterns.every((p) => p.test(backlogGateSection))) {
      errors.push(`gates.md missing backlog duplication fail: ${row.hint}`);
    }
  }

  if (!/既存 backlog/.test(gates)) {
    errors.push('gates.md must reference current-state.md 既存 backlog as fail input');
  }

  if (!/github-issue-creator.*§3|§3.*github-issue-creator/.test(gates)) {
    errors.push('gates.md must reference github-issue-creator §3 for backlog duplication');
  }

  const section4 = extractSection(subagent, '## §4', '## §5');
  const section5 = extractSection(subagent, '## §5', '---');
  for (const section of [section4, section5]) {
    if (!/current-state\.md/.test(section)) {
      errors.push('subagent-prompts must list current-state.md as gate input');
    }
    if (!/既存 backlog/.test(section)) {
      errors.push('subagent-prompts must reference 既存 backlog section for gate input');
    }
  }

  if (!/backlog.*重複|重複.*backlog|既存 backlog.*OPEN/s.test(artifacts)) {
    errors.push('artifacts.md missing backlog duplication JSON examples');
  }
  if (!/plan-review\.json/.test(artifacts) || !/overlap-ux-gate\.json/.test(artifacts)) {
    errors.push('artifacts.md must include plan-review.json and overlap-ux-gate.json examples');
  }

  const phase5 = extractSkillPhase(skill, '## フェーズ 5');
  const phase7 = extractSkillPhase(skill, '## フェーズ 7');
  const phase9 = extractSkillPhase(skill, '## フェーズ 9');
  if (!/backlog|§3|github-issue-creator/.test(phase5 + phase7)) {
    errors.push(
      'SKILL.md フェーズ5 or 7 must note backlog duplication is verified in G2/G3',
    );
  }
  if (!/フェーズ\s*[57].*§3|§3.*フェーズ\s*9|二重.*矛盾しない|矛盾しない.*§3/s.test(skill)) {
    errors.push(
      'SKILL.md must note G2/G3 backlog check aligns with phase 9 github-issue-creator §3',
    );
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
