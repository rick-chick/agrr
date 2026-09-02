/**
 * Wizard progress markup must live in the shared L1 pattern, not page templates.
 */

const INLINE_COMPACT_PROGRESS = /<div\s+class="compact-progress"/;

/** @type {readonly string[]} */
export const WIZARD_STYLE_SCOPE_SCAN_PREFIXES = [
  'src/app/components/public-plans/',
  'src/app/components/entry-schedule/',
];

/**
 * @param {string} relativePath
 * @returns {boolean}
 */
export function shouldScanWizardStyleScope(relativePath) {
  if (!relativePath.endsWith('.ts') || relativePath.endsWith('.spec.ts')) {
    return false;
  }
  if (relativePath.includes('/patterns/')) {
    return false;
  }
  if (relativePath.includes('wizard-progress')) {
    return false;
  }
  return WIZARD_STYLE_SCOPE_SCAN_PREFIXES.some((prefix) => relativePath.startsWith(prefix));
}

/**
 * @param {string} content
 * @param {string} relativePath
 * @returns {{ file: string, message: string }[]}
 */
export function findWizardStyleScopeViolations(content, relativePath) {
  if (!shouldScanWizardStyleScope(relativePath)) {
    return [];
  }

  if (INLINE_COMPACT_PROGRESS.test(content)) {
    return [
      {
        file: relativePath,
        message:
          'inline compact-progress markup is forbidden — use app-wizard-progress (WizardProgressPattern) via funnel shell',
      },
    ];
  }

  return [];
}
