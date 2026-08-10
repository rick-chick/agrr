/**
 * Verify EN research report HTML under public/research/en/ is translated (not JA stubs).
 */

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { EN_TRANSLATED_CROPS } from './research-en-translated-crops-lib.mjs';
import { parseResearchReportPath } from './patch-research-meta-descriptions-lib.mjs';
import {
  findAwkwardEnTitleIssues,
  findMajorPestsCropAlignmentIssues,
} from './research-major-pests-crop-alignment-lib.mjs';

/** Hiragana, katakana, CJK unified ideographs. */
const JAPANESE_CHAR_RE = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/g;

/** Max ratio of Japanese chars in visible vp-doc text for translated pages. */
export const MAX_JAPANESE_CHAR_RATIO = 0.02;

const REPORT_HEADING_HINTS = {
  temperature_requirements: [['overview', 'summary', 'introduction'], 'temperature'],
  gdd_requirements: [['overview', 'summary', 'introduction'], 'gdd'],
  npk_absorption: [['overview', 'summary', 'introduction'], 'npk'],
  major_pests: [['overview', 'summary', 'introduction'], 'pest'],
};

/**
 * @param {string} html
 * @returns {string}
 */
export function extractVpDocText(html) {
  const match = html.match(/class="vp-doc[^"]*"[^>]*><div>([\s\S]*?)<\/div><\/div><\/main>/);
  if (!match) {
    return '';
  }
  return match[1]
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * @param {string} text
 * @returns {{ japaneseCount: number; totalCount: number; ratio: number }}
 */
export function measureJapaneseCharRatio(text) {
  const japaneseMatches = text.match(JAPANESE_CHAR_RE) ?? [];
  const letters = text.replace(/\s+/g, '');
  const totalCount = letters.length;
  const japaneseCount = japaneseMatches.length;
  const ratio = totalCount === 0 ? 0 : japaneseCount / totalCount;
  return { japaneseCount, totalCount, ratio };
}

/**
 * @param {string} text
 * @param {string} reportType
 * @returns {string[]}
 */
export function missingEnglishHeadingHints(text, reportType) {
  const hints = REPORT_HEADING_HINTS[reportType] ?? [['overview', 'summary']];
  const lower = text.toLowerCase();
  return hints
    .map((hint) => (Array.isArray(hint) ? hint : [hint]))
    .filter((alternatives) => !alternatives.some((hint) => lower.includes(hint)))
    .map((alternatives) => alternatives[0]);
}

/**
 * @param {string} relativePath - Path relative to public/research/en/
 * @param {string} html
 * @returns {{ ok: boolean; issues: string[] }}
 */
export function verifyEnResearchHtml(relativePath, html) {
  const parsed = parseResearchReportPath(`en/${relativePath}`);
  const issues = [];

  if (!parsed) {
    return { ok: true, issues };
  }

  const text = extractVpDocText(html);
  if (!text) {
    issues.push('missing vp-doc body');
    return { ok: false, issues };
  }

  const { ratio, japaneseCount } = measureJapaneseCharRatio(text);
  if (ratio > MAX_JAPANESE_CHAR_RATIO) {
    issues.push(
      `japanese char ratio ${(ratio * 100).toFixed(1)}% (${japaneseCount} chars) exceeds ${MAX_JAPANESE_CHAR_RATIO * 100}%`
    );
  }

  const missingHints = missingEnglishHeadingHints(text, parsed.report);
  if (missingHints.length > 0) {
    issues.push(`missing english heading hints: ${missingHints.join(', ')}`);
  }

  if (parsed.report === 'major_pests') {
    for (const issue of findMajorPestsCropAlignmentIssues(parsed.crop, text)) {
      issues.push(issue);
    }
  }

  const titleMatch = html.match(/<title>([^<]+)<\/title>/);
  if (titleMatch) {
    for (const issue of findAwkwardEnTitleIssues(titleMatch[1])) {
      issues.push(issue);
    }
  }

  return { ok: issues.length === 0, issues };
}

/**
 * @param {string} researchDir - Absolute path to public/research
 * @returns {Array<{ relativePath: string; crop: string; issues: string[]; required: boolean }>}
 */
export function collectEnTranslationIssues(researchDir) {
  const enReportsDir = join(researchDir, 'en', 'research_reports');
  const failures = [];

  function walk(dir, prefix = '') {
    for (const entry of readdirSync(dir)) {
      const fullPath = join(dir, entry);
      const rel = prefix ? `${prefix}/${entry}` : entry;
      if (statSync(fullPath).isDirectory()) {
        walk(fullPath, rel);
        continue;
      }
      if (!entry.endsWith('.html')) {
        continue;
      }

      const html = readFileSync(fullPath, 'utf8');
      const parsed = parseResearchReportPath(`en/research_reports/${rel}`);
      const crop = parsed?.crop ?? 'unknown';
      const required = EN_TRANSLATED_CROPS.has(crop);
      const { ok, issues } = verifyEnResearchHtml(`research_reports/${rel}`, html);

      if (!ok) {
        failures.push({
          relativePath: `en/research_reports/${rel}`,
          crop,
          issues,
          required,
        });
      }
    }
  }

  walk(enReportsDir);
  return failures;
}

/**
 * Expected EN report count per crop (cucumber currently lacks major_pests until created).
 *
 * @param {string} crop
 * @returns {number}
 */
export function expectedEnReportCountForCrop(crop) {
  return crop === 'cucumber' ? 4 : 4;
}

/**
 * @param {string} researchDir
 * @param {Set<string>} translatedCrops
 * @returns {string[]}
 */
export function findAllowlistCoverageGaps(researchDir, translatedCrops) {
  const gaps = [];
  for (const crop of translatedCrops) {
    const cropDir = join(researchDir, 'en', 'research_reports', crop);
    let count = 0;
    try {
      const walk = (dir) => {
        for (const entry of readdirSync(dir)) {
          const full = join(dir, entry);
          if (statSync(full).isDirectory()) {
            walk(full);
          } else if (entry.endsWith('.html')) {
            count += 1;
          }
        }
      };
      walk(cropDir);
    } catch {
      gaps.push(`${crop}: directory missing`);
      continue;
    }
    const expected = expectedEnReportCountForCrop(crop);
    if (count < expected) {
      gaps.push(`${crop}: ${count}/${expected} EN report HTML files`);
    }
  }
  return gaps;
}
