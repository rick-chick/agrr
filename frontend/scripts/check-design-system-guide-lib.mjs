import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

/** @typedef {{ section: string; pattern: RegExp }} GuideRequirement */

/** @type {GuideRequirement[]} */
export const COMPONENT_GUIDE_REQUIREMENTS = [
  { section: 'button variants', pattern: /primary.*secondary.*danger/is },
  { section: 'anti-patterns', pattern: /アンチパターン|anti-?pattern/i },
  { section: 'empty state', pattern: /空状態|empty state/i },
  { section: 'error panel', pattern: /MasterLoadErrorPanel|エラーパネル/i },
  { section: 'breadcrumb', pattern: /MasterContextHeader|パンくず|breadcrumb/i },
  { section: 'css token audit', pattern: /audit:css-tokens/i },
  { section: 'reference crop detail', pattern: /crops\/:id|crop-detail/i },
  { section: 'reference work hub', pattern: /work-hub/i },
  { section: 'reference plan list', pattern: /plan-list/i },
];

/** @type {GuideRequirement[]} */
export const DARK_MODE_POLICY_REQUIREMENTS = [
  { section: 'dark mode policy', pattern: /ダークモード|dark mode/i },
  { section: 'future token direction', pattern: /prefers-color-scheme|セマンティックトークン|semantic token/i },
];

/**
 * @param {string} markdown
 * @param {GuideRequirement[]} requirements
 * @returns {string[]}
 */
export function findMissingGuideSections(markdown, requirements) {
  return requirements
    .filter(({ pattern }) => !pattern.test(markdown))
    .map(({ section }) => section);
}

/**
 * @param {string} frontendRoot
 */
export async function auditDesignSystemGuide(frontendRoot) {
  const guidePath = join(frontendRoot, 'docs/design-system/COMPONENT-GUIDE.md');
  const policyPath = join(frontendRoot, 'docs/design-system/DARK-MODE-POLICY.md');

  const errors = [];

  let guideMarkdown = '';
  try {
    guideMarkdown = await readFile(guidePath, 'utf8');
  } catch {
    errors.push(`missing file: ${guidePath}`);
  }

  let policyMarkdown = '';
  try {
    policyMarkdown = await readFile(policyPath, 'utf8');
  } catch {
    errors.push(`missing file: ${policyPath}`);
  }

  if (guideMarkdown) {
    for (const section of findMissingGuideSections(guideMarkdown, COMPONENT_GUIDE_REQUIREMENTS)) {
      errors.push(`COMPONENT-GUIDE.md missing section: ${section}`);
    }
  }

  if (policyMarkdown) {
    for (const section of findMissingGuideSections(policyMarkdown, DARK_MODE_POLICY_REQUIREMENTS)) {
      errors.push(`DARK-MODE-POLICY.md missing section: ${section}`);
    }
  }

  return { ok: errors.length === 0, errors };
}
