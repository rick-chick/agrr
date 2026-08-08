import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

export const COMPONENT_GUIDE_REL = 'docs/design-system/COMPONENT-GUIDE.md';
export const DARK_MODE_ADR_REL = 'docs/adr/ADR-003-dark-mode-policy.md';

/** @typedef {{ rule: string; message: string }} DesignSystemGuideViolation */

/**
 * @param {string} markdown
 * @returns {DesignSystemGuideViolation[]}
 */
export function auditComponentGuideContent(markdown) {
  /** @type {DesignSystemGuideViolation[]} */
  const violations = [];

  const requiredHeadings = [
    '## Button variants',
    '## Anti-patterns',
    '## Shared components',
    '## Design tokens',
    '## Reference implementations',
    '## Dark mode policy',
  ];

  for (const heading of requiredHeadings) {
    if (!markdown.includes(heading)) {
      violations.push({
        rule: 'required-heading',
        message: `missing heading: ${heading}`,
      });
    }
  }

  const requiredSnippets = [
    'btn-primary',
    'btn-secondary',
    'btn-danger',
    'MasterLoadErrorPanelComponent',
    'MasterContextHeaderComponent',
    'audit:css-tokens',
    'check:btn-base-class',
    '/crops/:id',
    '/work',
    '/plans',
  ];

  for (const snippet of requiredSnippets) {
    if (!markdown.includes(snippet)) {
      violations.push({
        rule: 'required-snippet',
        message: `missing snippet: ${snippet}`,
      });
    }
  }

  if (!/primary.*secondary.*danger/s.test(markdown)) {
    violations.push({
      rule: 'variant-order',
      message: 'button variant section must mention primary, secondary, and danger',
    });
  }

  return violations;
}

/**
 * @param {string} markdown
 * @returns {DesignSystemGuideViolation[]}
 */
export function auditDarkModeAdrContent(markdown) {
  /** @type {DesignSystemGuideViolation[]} */
  const violations = [];

  if (!markdown.includes('## Decision')) {
    violations.push({ rule: 'adr-decision', message: 'ADR must include ## Decision' });
  }

  if (!/将来対応|future/i.test(markdown)) {
    violations.push({
      rule: 'dark-mode-future',
      message: 'dark mode ADR must document future-support policy (option B)',
    });
  }

  if (!/prefers-color-scheme|styles\.css/i.test(markdown)) {
    violations.push({
      rule: 'dark-mode-mechanism',
      message: 'dark mode ADR must reference prefers-color-scheme or styles.css tokens',
    });
  }

  return violations;
}

/**
 * @param {string} frontendRoot
 * @returns {Promise<DesignSystemGuideViolation[]>}
 */
export async function auditDesignSystemDocs(frontendRoot) {
  const repoRoot = join(frontendRoot, '..');
  const guidePath = join(frontendRoot, COMPONENT_GUIDE_REL);
  const adrPath = join(repoRoot, DARK_MODE_ADR_REL);

  /** @type {DesignSystemGuideViolation[]} */
  const violations = [];

  let guideMarkdown;
  try {
    guideMarkdown = await readFile(guidePath, 'utf8');
  } catch {
    violations.push({
      rule: 'component-guide-exists',
      message: `missing file: ${COMPONENT_GUIDE_REL}`,
    });
    return violations;
  }

  violations.push(...auditComponentGuideContent(guideMarkdown));

  let adrMarkdown;
  try {
    adrMarkdown = await readFile(adrPath, 'utf8');
  } catch {
    violations.push({
      rule: 'dark-mode-adr-exists',
      message: `missing file: ${DARK_MODE_ADR_REL}`,
    });
    return violations;
  }

  violations.push(...auditDarkModeAdrContent(adrMarkdown));

  return violations;
}
