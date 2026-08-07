import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

/** @type {readonly string[]} */
const FLUID_FONT_SIZE_TOKENS = [
  '--font-size-lg',
  '--font-size-xl',
  '--font-size-2xl',
  '--font-size-3xl',
  '--font-size-5xl',
];

const CLAMP_RE = /clamp\s*\(/;

/**
 * @param {string} css
 * @param {string} tokenName e.g. --font-size-lg
 * @returns {string | null}
 */
export function findTokenDefinition(css, tokenName) {
  const re = new RegExp(`^\\s*${tokenName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*:\\s*(.+?);`);
  for (const line of css.split('\n')) {
    const trimmed = line.replace(/\/\*.*?\*\//g, '').trim();
    if (trimmed.startsWith('/*') || !trimmed) continue;
    const match = trimmed.match(re);
    if (match) return match[1].trim();
  }
  return null;
}

/**
 * @param {string} value
 * @returns {boolean}
 */
export function isFluidClampValue(value) {
  return CLAMP_RE.test(value);
}

/**
 * @param {string} stylesCss
 * @returns {{ token: string; value: string | null }[]}
 */
export function findNonFluidTokens(stylesCss) {
  return FLUID_FONT_SIZE_TOKENS.map((token) => {
    const value = findTokenDefinition(stylesCss, token);
    return { token, value };
  }).filter(({ value }) => value === null || !isFluidClampValue(value));
}

/**
 * @param {string} frontendRoot
 */
export async function auditFluidTypographyTokens(frontendRoot) {
  const stylesPath = join(frontendRoot, 'src/styles.css');
  const stylesCss = await readFile(stylesPath, 'utf8');
  const violations = [];

  for (const { token, value } of findNonFluidTokens(stylesCss)) {
    if (value === null) {
      violations.push({
        rule: 'fluid-token-missing',
        token,
        message: `${token} must be defined in styles.css`,
      });
    } else {
      violations.push({
        rule: 'fluid-token-not-clamp',
        token,
        value,
        message: `${token} must use clamp(min, preferred, max)`,
      });
    }
  }

  return violations;
}
