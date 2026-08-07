import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const PRIMARY_DEF_RE = /^\s*--color-primary\s*:/;

/**
 * @param {string} css
 * @returns {number}
 */
export function countPrimaryDefinitions(css) {
  return css
    .split('\n')
    .filter((line) => !line.trim().startsWith('/*') && PRIMARY_DEF_RE.test(line)).length;
}

/**
 * @param {string} appCss
 * @returns {boolean}
 */
export function btnPrimaryUsesColorPrimary(appCss) {
  const block = appCss.match(/\.btn-primary\s*\{[^}]*\}/s);
  if (!block) return false;
  return /--color-primary\b/.test(block[0]) && !/--gradient-primary\b/.test(block[0]);
}

/**
 * @param {string} stylesCss
 * @returns {boolean}
 */
export function stylesDefinesBrandTokens(stylesCss) {
  return (
    /--color-brand-primary\s*:/.test(stylesCss) &&
    /--color-brand-primary-light\s*:/.test(stylesCss) &&
    /--color-brand-primary-dark\s*:/.test(stylesCss)
  );
}

/**
 * @param {string} frontendRoot
 */
export async function auditPrimaryColorTokens(frontendRoot) {
  const stylesPath = join(frontendRoot, 'src/styles.css');
  const appPath = join(frontendRoot, 'src/app/app.css');
  const buttonPrimitivesPath = join(
    frontendRoot,
    'src/app/components/shared/_button-primitives.css',
  );
  const [stylesCss, appCss, buttonPrimitivesCss] = await Promise.all([
    readFile(stylesPath, 'utf8'),
    readFile(appPath, 'utf8'),
    readFile(buttonPrimitivesPath, 'utf8'),
  ]);

  const violations = [];

  if (countPrimaryDefinitions(stylesCss) !== 1) {
    violations.push({
      rule: 'single-primary-in-styles',
      message: 'styles.css must define --color-primary exactly once',
      count: countPrimaryDefinitions(stylesCss),
    });
  }

  if (countPrimaryDefinitions(appCss) > 0) {
    violations.push({
      rule: 'no-primary-in-app',
      message: 'app.css must not redefine --color-primary (use styles.css)',
    });
  }

  if (!stylesDefinesBrandTokens(stylesCss)) {
    violations.push({
      rule: 'brand-tokens-in-styles',
      message: 'styles.css must define --color-brand-primary* tokens',
    });
  }

  if (!btnPrimaryUsesColorPrimary(buttonPrimitivesCss)) {
    violations.push({
      rule: 'btn-primary-uses-primary',
      message: '.btn-primary must use --color-primary (not --gradient-primary)',
    });
  }

  return violations;
}
