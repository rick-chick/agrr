/**
 * Shared logic for audit-component-css-tokens (unit-testable).
 */

export const HEX_RE = /#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b/g;
export const RGB_RE = /\brgba?\([^)]*\)/g;

/** @returns {[number, number][]} inclusive start, exclusive end */
export function findVarSpans(line) {
  const spans = [];
  const lower = line.toLowerCase();
  let i = 0;
  while (i < line.length) {
    const idx = lower.indexOf('var(', i);
    if (idx === -1) break;
    let j = idx + 4;
    let depth = 1;
    while (j < line.length && depth > 0) {
      const c = line[j];
      if (c === '(') depth++;
      else if (c === ')') depth--;
      j++;
    }
    spans.push([idx, j]);
    i = j;
  }
  return spans;
}

export function isInsideVarSpans(index, spans) {
  return spans.some(([a, b]) => index >= a && index < b);
}

export function stripBlockComments(text) {
  return text.replace(/\/\*[\s\S]*?\*\//g, '\n');
}

export function stripLineComments(line) {
  const idx = line.indexOf('//');
  if (idx === -1) return line;
  const before = line.slice(0, idx);
  const qSingle = (before.match(/'/g) || []).length;
  const qDouble = (before.match(/"/g) || []).length;
  if (qSingle % 2 === 1 || qDouble % 2 === 1) return line;
  return before;
}

export function maskUrls(fragment) {
  return fragment.replace(/url\([^)]*\)/gi, 'url()');
}

/**
 * @param {string} line
 * @param {number} lineNumber 1-based
 * @returns {{ outside: object[], insideVar: object[] }}
 */
export function findViolationsInLine(line, lineNumber) {
  const spans = findVarSpans(line);
  const outside = [];
  const insideVar = [];

  const pushMatch = (kind, value, index, snippetSource) => {
    const row = {
      line: lineNumber,
      kind,
      value,
      snippet: snippetSource.trim().slice(0, 120),
    };
    if (isInsideVarSpans(index, spans)) insideVar.push(row);
    else outside.push(row);
  };

  let m;
  const seenHex = new Set();
  HEX_RE.lastIndex = 0;
  while ((m = HEX_RE.exec(line)) !== null) {
    const key = `hex:${lineNumber}:${m.index}`;
    if (seenHex.has(key)) continue;
    seenHex.add(key);
    pushMatch('hex', m[0], m.index, line);
  }

  const seenRgb = new Set();
  RGB_RE.lastIndex = 0;
  while ((m = RGB_RE.exec(line)) !== null) {
    const key = `rgb:${lineNumber}:${m.index}`;
    if (seenRgb.has(key)) continue;
    seenRgb.add(key);
    pushMatch('rgb', m[0].trim(), m.index, line);
  }

  return { outside, insideVar };
}

export function findViolations(raw) {
  const stripped = stripBlockComments(raw);
  const lines = stripped.split(/\n/);
  const outside = [];
  const insideVar = [];

  for (let i = 0; i < lines.length; i++) {
    let line = stripLineComments(lines[i]);
    line = maskUrls(line);
    if (!line.includes('#') && !line.toLowerCase().includes('rgb')) continue;

    const { outside: o, insideVar: iv } = findViolationsInLine(line, i + 1);
    outside.push(...o);
    insideVar.push(...iv);
  }
  return { outside, insideVar };
}

/** @returns {number} index of top-level comma in var() inner, or -1 */
function findTopLevelComma(inner) {
  let depth = 0;
  for (let i = 0; i < inner.length; i++) {
    const c = inner[i];
    if (c === '(') depth++;
    else if (c === ')') depth--;
    else if (c === ',' && depth === 0) return i;
  }
  return -1;
}

/** Remove fallback values from var(--token, fallback) → var(--token). */
export function stripVarFallbacks(text) {
  let result = '';
  let i = 0;
  while (i < text.length) {
    const idx = text.indexOf('var(', i);
    if (idx === -1) {
      result += text.slice(i);
      break;
    }
    result += text.slice(i, idx);
    let j = idx + 4;
    let depth = 1;
    while (j < text.length && depth > 0) {
      const c = text[j];
      if (c === '(') depth++;
      else if (c === ')') depth--;
      j++;
    }
    const inner = text.slice(idx + 4, j - 1);
    const commaIdx = findTopLevelComma(inner);
    if (commaIdx !== -1) {
      const tokenName = inner.slice(0, commaIdx).trim();
      result += `var(${tokenName})`;
    } else {
      result += text.slice(idx, j);
    }
    i = j;
  }
  return result;
}

export function shouldEnforceFail(outsideCount, insideVarCount, enforce) {
  if (!enforce) return false;
  return outsideCount > 0 || insideVarCount > 0;
}
