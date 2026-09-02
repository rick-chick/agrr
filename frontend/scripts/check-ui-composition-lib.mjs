/**
 * UI composition lint (Paved Road). See docs/design/UI-COMPOSITION-RULES.md
 */

/**
 * @param {string} content
 * @returns {{ id: string, message: string }[]}
 */
export function findWizardShellProgressViolations(content) {
  /** @type {{ id: string, message: string }[]} */
  const violations = [];

  const usesWizardShell = /app-funnel-shell[\s\S]*?variant=["']wizard["']/.test(content);
  if (!usesWizardShell) {
    return violations;
  }

  const hasProgressProjection =
    /app-[a-z-]+-wizard-progress|wizardProgress|\[wizardProgress\]/.test(content);
  if (!hasProgressProjection) {
    violations.push({
      id: 'UI-R4-wizard-shell-progress',
      message:
        'FunnelShell variant="wizard" must project wizard progress (wizardProgress slot or shared progress component)',
    });
  }

  return violations;
}

/**
 * @param {string} content
 * @returns {{ id: string, message: string }[]}
 */
export function findUiCompositionViolations(content) {
  /** @type {{ id: string, message: string }[]} */
  const violations = [];

  if (/compact-header-card[\s\S]*?page-intro/.test(content)) {
    violations.push({
      id: 'R1-page-intro-in-compact-header',
      message: 'page-intro must not appear inside compact-header-card (use FunnelShell description slot)',
    });
  }

  violations.push(...findWizardShellProgressViolations(content));

  return violations;
}

/**
 * @param {string[]} templateContents
 * @param {string} globalCss
 * @returns {{ id: string, message: string }[]}
 */
export function findLinkInlineViolations(templateContents, globalCss) {
  /** @type {{ id: string, message: string }[]} */
  const violations = [];

  const used = templateContents.some((content) => /link-inline/.test(content));
  const defined = /\.link-inline\b/.test(globalCss);

  if (used && !defined) {
    violations.push({
      id: 'R2-link-inline-undefined',
      message: 'link-inline is used in templates but not defined in global CSS (_form-primitives.css)',
    });
  }

  if (defined && !used) {
    violations.push({
      id: 'R2-link-inline-unused',
      message: 'link-inline is defined in global CSS but not used in scanned templates',
    });
  }

  return violations;
}

/**
 * @param {Record<string, string>} files path -> content
 * @param {string} globalCss
 */
export function checkUiCompositionFiles(files, globalCss) {
  /** @type {{ file: string, id: string, message: string }[]} */
  const all = [];
  for (const [file, content] of Object.entries(files)) {
    for (const v of findUiCompositionViolations(content)) {
      all.push({ file, ...v });
    }
  }

  for (const v of findLinkInlineViolations(Object.values(files), globalCss)) {
    all.push({ file: '(global)', ...v });
  }

  return all;
}
