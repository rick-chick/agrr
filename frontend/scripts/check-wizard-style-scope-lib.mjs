/**
 * Wizard progress markup must live in shared pattern / wizard-progress components only.
 * Page templates must not inline `.compact-progress`.
 */

const WIZARD_PROGRESS_ALLOWLIST = [
  'src/app/components/shared/patterns/wizard-progress.pattern.ts',
  'src/app/components/entry-schedule/entry-schedule-wizard-progress.component.ts',
  'src/app/components/public-plans/public-plan-wizard-progress.component.ts',
];

/**
 * @param {Record<string, string>} files path -> content
 */
export function findWizardStyleScopeViolations(files) {
  /** @type {{ file: string, message: string }[]} */
  const violations = [];

  for (const [file, content] of Object.entries(files)) {
    if (WIZARD_PROGRESS_ALLOWLIST.includes(file)) {
      continue;
    }
    if (/<div\s+class="compact-progress"/.test(content)) {
      violations.push({
        file,
        message:
          'inline compact-progress markup is forbidden in page templates; use wizard-progress pattern/component',
      });
    }
  }

  return violations;
}
