/**
 * DOM 可視テキストの i18n 漏れ検出（`frontend-agent-visual-review` の「言語・i18n」節に準拠）。
 * @typedef {'ja' | 'en' | 'in'} CaptureLocale
 */

/** ngx-translate 未解決キー（3 セグメント以上のドット区切り） */
const RAW_I18N_KEY_RE = /\b[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]+){2,}\b/gi;

/** Rails / 古いカタログの %{param} 残り */
const UNINTERPOLATED_PLACEHOLDER_RE = /%\{[a-zA-Z_][a-zA-Z0-9_]*\}/g;

/** ひらがな・カタカナ・CJK（日本語 UI の検出用） */
const JAPANESE_SCRIPT_RE = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

/** デーヴァナーガリー（ヒンディー UI の検出用） */
const DEVANAGARI_RE = /[\u0900-\u097F]/;

/** セマンバージョン等の誤検知除外 */
const NUMERIC_DOT_SEGMENTS_RE = /^\d+(?:\.\d+)+$/;

/**
 * @param {string} token
 */
function isLikelyRawI18nKey(token) {
  if (NUMERIC_DOT_SEGMENTS_RE.test(token)) return false;
  if (token.includes('://')) return false;
  if (token.includes('@')) return false;
  return true;
}

/**
 * @param {string} text
 * @returns {string[]}
 */
export function findRawTranslationKeys(text) {
  const hits = new Set();
  for (const match of text.matchAll(RAW_I18N_KEY_RE)) {
    const token = match[0];
    if (isLikelyRawI18nKey(token)) {
      hits.add(token);
    }
  }
  return [...hits].sort();
}

/**
 * @param {string} text
 * @returns {string[]}
 */
export function findUninterpolatedPlaceholders(text) {
  const hits = new Set();
  for (const match of text.matchAll(UNINTERPOLATED_PLACEHOLDER_RE)) {
    hits.add(match[0]);
  }
  return [...hits].sort();
}

/**
 * @param {string} text
 * @returns {boolean}
 */
export function containsJapaneseScript(text) {
  return JAPANESE_SCRIPT_RE.test(text);
}

/**
 * @param {string} text
 * @returns {boolean}
 */
export function containsDevanagariScript(text) {
  return DEVANAGARI_RE.test(text);
}

/**
 * @param {string} text
 * @param {CaptureLocale} locale
 * @returns {string[]}
 */
export function findLocaleI18nViolations(text, locale) {
  /** @type {string[]} */
  const violations = [];

  for (const key of findRawTranslationKeys(text)) {
    violations.push(`raw i18n key: ${key}`);
  }
  for (const ph of findUninterpolatedPlaceholders(text)) {
    violations.push(`uninterpolated placeholder: ${ph}`);
  }

  if (locale === 'en' && containsJapaneseScript(text)) {
    violations.push('Japanese script visible in en locale');
  }
  if (locale === 'in') {
    if (containsJapaneseScript(text)) {
      violations.push('Japanese script visible in in locale');
    }
    const trimmed = text.replace(/\s+/g, ' ').trim();
    if (trimmed.length >= 24 && !containsDevanagariScript(trimmed)) {
      violations.push('no Devanagari script in substantial in-locale body text');
    }
  }

  return violations;
}
