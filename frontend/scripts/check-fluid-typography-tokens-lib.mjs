import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

/** Tokens that must use fluid clamp() per issue #684 (lg tier and above). */
export const FLUID_FONT_SIZE_TOKENS = [
  '--font-size-lg',
  '--font-size-xl',
  '--font-size-2xl',
  '--font-size-3xl',
  '--font-size-5xl',
];

/**
 * @param {string} css
 * @param {string} tokenName
 * @returns {boolean}
 */
export function tokenUsesClamp(css, tokenName) {
  const escaped = tokenName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`${escaped}\\s*:\\s*clamp\\(`, 'm').test(css);
}

/**
 * @param {string} declarationValue
 * @returns {string | null}
 */
export function extractClampMin(declarationValue) {
  const match = declarationValue.match(/clamp\(\s*([^,]+)\s*,/);
  return match ? match[1].trim() : null;
}

/**
 * @param {string} css
 * @param {string} tokenName
 * @returns {string | null}
 */
export function readTokenValue(css, tokenName) {
  const escaped = tokenName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = css.match(new RegExp(`${escaped}\\s*:\\s*([^;]+);`, 'm'));
  return match ? match[1].trim() : null;
}

/**
 * @param {string} minExpr
 * @returns {number | null} minimum size in px when expressed as rem (16px base)
 */
export function minExprToPx(minExpr) {
  const rem = minExpr.match(/^([\d.]+)rem$/);
  if (rem) return parseFloat(rem[1]) * 16;
  const px = minExpr.match(/^([\d.]+)px$/);
  if (px) return parseFloat(px[1]);
  return null;
}

/**
 * @param {string} stylesCss
 * @returns {{ rule: string; token?: string; message: string }[]}
 */
export function auditFluidTypographyTokens(stylesCss) {
  const violations = [];

  for (const token of FLUID_FONT_SIZE_TOKENS) {
    if (!tokenUsesClamp(stylesCss, token)) {
      violations.push({
        rule: 'clamp-required',
        token,
        message: `${token} must use clamp() for fluid typography`,
      });
      continue;
    }

    const value = readTokenValue(stylesCss, token);
    if (!value) continue;

    const minExpr = extractClampMin(value);
    const minPx = minExpr ? minExprToPx(minExpr) : null;
    if (minPx !== null && minPx < 16) {
      violations.push({
        rule: 'min-readable',
        token,
        message: `${token} clamp minimum must be at least 16px (got ${minPx}px)`,
      });
    }
  }

  return violations;
}

/**
 * @param {string} frontendRoot
 */
export async function auditFluidTypographyFromDisk(frontendRoot) {
  const stylesPath = join(frontendRoot, 'src/styles.css');
  const stylesCss = await readFile(stylesPath, 'utf8');
  return auditFluidTypographyTokens(stylesCss);
}
