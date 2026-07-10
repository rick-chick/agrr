/** @typedef {{ file: string, line: number, snippet: string }} BtnVariantViolation */

const VARIANT_PATTERN = /\bbtn-(primary|secondary|danger)\b/;
const CLASS_ATTR_PATTERN = /class="([^"]*)"/g;

/**
 * @param {string} text
 * @param {number} offset
 */
export function lineNumberForOffset(text, offset) {
  let line = 1;
  for (let i = 0; i < offset && i < text.length; i += 1) {
    if (text[i] === '\n') {
      line += 1;
    }
  }
  return line;
}

/**
 * Returns violations where a btn-* variant appears without the base .btn class.
 * @param {string} text
 * @param {string} filePath
 * @returns {BtnVariantViolation[]}
 */
export function findBtnVariantWithoutBase(text, filePath) {
  /** @type {BtnVariantViolation[]} */
  const violations = [];
  for (const match of text.matchAll(CLASS_ATTR_PATTERN)) {
    const classes = match[1];
    if (!VARIANT_PATTERN.test(classes)) {
      continue;
    }
    const tokens = classes.trim().split(/\s+/).filter(Boolean);
    if (tokens.includes('btn')) {
      continue;
    }
    const offset = match.index ?? 0;
    const line = lineNumberForOffset(text, offset);
    const snippet = match[0].length > 80 ? `${match[0].slice(0, 77)}...` : match[0];
    violations.push({ file: filePath, line, snippet });
  }
  return violations;
}
