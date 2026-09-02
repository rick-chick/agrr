/**
 * Wizard style scope lint. See docs/design/UI-COMPOSITION-RULES.md
 *
 * Detects inline wizard progress markup in page templates.
 * UI composition rules (R1/R4) live in check-ui-composition-lib.mjs.
 */

/** @type {readonly string[]} */
export const WIZARD_PROGRESS_COMPONENT_SUFFIXES = [
  'entry-schedule-wizard-progress.component.ts',
];

/**
 * @param {string} filePath
 * @returns {boolean}
 */
export function isDedicatedWizardProgressComponent(filePath) {
  return WIZARD_PROGRESS_COMPONENT_SUFFIXES.some((suffix) => filePath.endsWith(suffix));
}

/**
 * @param {string} content
 * @param {string} filePath
 * @returns {{ id: string, message: string }[]}
 */
export function findWizardInlineProgressViolations(content, filePath) {
  if (isDedicatedWizardProgressComponent(filePath)) {
    return [];
  }

  /** @type {{ id: string, message: string }[]} */
  const violations = [];

  if (/class=["']compact-progress["']/.test(content)) {
    violations.push({
      id: 'UI-R3-wizard-inline-progress',
      message:
        'Inline compact-progress in page templates is forbidden (use shared wizard progress via FunnelShell wizardProgress slot)',
    });
  }

  return violations;
}

/**
 * @param {Record<string, string>} files path -> content
 * @returns {{ file: string, id: string, message: string }[]}
 */
export function checkWizardStyleScopeFiles(files) {
  /** @type {{ file: string, id: string, message: string }[]} */
  const all = [];
  for (const [file, content] of Object.entries(files)) {
    for (const v of findWizardInlineProgressViolations(content, file)) {
      all.push({ file, ...v });
    }
  }
  return all;
}
