/**
 * collect-ux-findings の純粋パーサ（テスト可能）
 */

/** @typedef {{ file: string, line: number, kind: string, value: string, snippet: string }} CssViolation */
/** @typedef {{ priority: string, rows: number[], patternLabel: string, text: string }} DetailedItem */

/**
 * @param {string} header 例: "#8 privacy / #14 terms", "#17–18, #30–31", "#3 about"
 * @returns {number[]}
 */
export function parseDetailRowNumbers(header) {
  const rows = [];
  const tokens = header.match(/#\d+(?:[–-]\d+)?/g) || [];
  for (const token of tokens) {
    const range = token.match(/^#(\d+)[–-](\d+)$/);
    if (range) {
      for (let i = Number(range[1]); i <= Number(range[2]); i += 1) {
        rows.push(i);
      }
      continue;
    }
    const single = token.match(/^#(\d+)$/);
    if (single) rows.push(Number(single[1]));
  }
  return [...new Set(rows)].sort((a, b) => a - b);
}

/**
 * @param {string} markdown
 * @returns {DetailedItem[]}
 */
export function parseDetailedFindings(markdown) {
  /** @type {DetailedItem[]} */
  const items = [];
  const section = markdown.match(/## 指摘の詳細([\s\S]*?)(?:\n## |\n$)/);
  if (!section) return items;

  let currentPriority = 'P2';
  for (const line of section[1].split('\n')) {
    const heading = line.match(/^### (P[0-3])/);
    if (heading) {
      currentPriority = heading[1];
      continue;
    }
    const item = line.match(/^\d+\.\s+\*\*(.+)\*\*\s+—\s+(.+)$/);
    if (!item) continue;
    const header = item[1].trim();
    const rows = parseDetailRowNumbers(header);
    if (rows.length === 0) continue;
    const patternLabel = header
      .replace(/#\d+(?:[–-]\d+)?/g, '')
      .replace(/\s*[\/,]\s*/g, '/')
      .replace(/\s+/g, ' ')
      .trim();
    items.push({
      priority: currentPriority,
      rows,
      patternLabel,
      text: item[2].trim(),
    });
  }
  return items;
}

/**
 * @param {string} markdown
 */
export function parseVisualReviewTable(markdown) {
  /** @type {Array<Record<string, string>>} */
  const rows = [];
  for (const line of markdown.split('\n')) {
    if (!line.startsWith('|') || line.includes('|---') || line.includes('| # |')) {
      continue;
    }
    const cols = line
      .split('|')
      .map((c) => c.trim())
      .filter((_, i, arr) => i > 0 && i < arr.length - 1);
    if (cols.length < 8) continue;
    const [num, pattern, ja, en, inp, layout, i18n, note] = cols;
    if (!/^\d+$/.test(num)) continue;

    rows.push({
      num,
      pattern: pattern.replace(/`/g, ''),
      ja: ja.replace(/`/g, ''),
      en: en.replace(/`/g, ''),
      in: inp.replace(/`/g, ''),
      layout,
      i18n,
      note,
    });
  }
  return rows;
}

/**
 * @param {string} text
 */
export function extractVarOutsideSection(text) {
  const start = text.indexOf('--- var 外');
  if (start < 0) return text;
  const end = text.indexOf('--- var(', start + 1);
  if (end < 0) return text.slice(start);
  return text.slice(start, end);
}

/**
 * @param {string} text
 * @returns {CssViolation[]}
 */
export function parseCssAuditLog(text) {
  const section = extractVarOutsideSection(text);
  /** @type {CssViolation[]} */
  const violations = [];
  const lines = section.split('\n');
  for (let i = 0; i < lines.length; i += 1) {
    const match = lines[i].match(/^([\w./-]+\.css):(\d+)\s+\[(\w+)\]\s+(.+)$/);
    if (!match) continue;
    violations.push({
      file: match[1],
      line: Number(match[2]),
      kind: match[3],
      value: match[4].trim(),
      snippet: (lines[i + 1] || '').trim(),
    });
  }
  return violations;
}

/**
 * @param {string | undefined} note
 * @param {string | undefined} summary
 */
export function isReferenceDataExclusion(note, summary) {
  const text = `${note || ''} ${summary || ''}`;
  return /参照データ/.test(text);
}

/**
 * @param {string} note
 * @param {string} layout
 * @param {string} i18n
 */
export function inferCategory(note, layout, i18n) {
  const text = `${note} ${layout} ${i18n}`.toLowerCase();
  if (text.includes('i18n') || text.includes('生キー') || text.includes('翻訳')) {
    return 'i18n';
  }
  if (text.includes('layout') || text.includes('ux') || text.includes('遷移')) {
    return 'UX';
  }
  if (text.includes('css') || text.includes('トークン')) {
    return 'CSS';
  }
  if (text.includes('a11y') || text.includes('accessibility')) {
    return 'a11y';
  }
  if (i18n === '注意' || i18n === '要確認') return 'i18n';
  if (layout === '注意' || layout === '要確認') return 'UX';
  return 'UX';
}

/**
 * @param {string} priority
 * @param {string} category
 * @param {string} pattern
 * @param {string} summary
 */
export function buildTitle(priority, category, pattern, summary) {
  const short = summary.length > 60 ? `${summary.slice(0, 57)}...` : summary;
  return `[${priority}][${category}] ${pattern}: ${short}`;
}

/**
 * issue タイトルに route segment が含まれるか（substring 誤検出を避ける）。
 * @param {string} title
 * @param {string} segment
 */
export function titleMatchesSegment(title, segment) {
  const seg = segment.replace(/[()`]/g, '').trim().toLowerCase();
  if (seg.length < 3) return false;

  const lower = title.toLowerCase();

  if (seg.includes('-')) {
    return lower.includes(seg);
  }

  const escaped = seg.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const boundary = new RegExp(`(?:^|[^a-z0-9-])${escaped}(?:[^a-z0-9-/]|$)`, 'i');
  if (!boundary.test(lower)) return false;

  const hyphenSuffix = new RegExp(`[a-z0-9]-${escaped}(?:[^a-z0-9]|$)`, 'i');
  if (hyphenSuffix.test(lower)) {
    const standalone = new RegExp(
      `(?:^|\\[|\\]|\\s|/)${escaped}(?:[:./\\s\\]|$)`,
      'i',
    );
    if (!standalone.test(lower)) return false;
  }

  return true;
}

/**
 * @param {ReturnType<typeof groupCssViolationsByFile>} fileGroups
 */
function deriveCssPatternSlug(fileGroups) {
  const top = [...fileGroups].sort((a, b) => b.count - a.count || a.file.localeCompare(b.file))[0];
  if (!top) return 'components';
  const match = top.file.match(/\/([^/]+)\.component\.css$/);
  return match?.[1] || 'components';
}

/**
 * @param {CssViolation[]} violations
 */
export function groupCssViolationsByFile(violations) {
  /** @type {Map<string, CssViolation[]>} */
  const byFile = new Map();
  for (const v of violations) {
    if (!byFile.has(v.file)) byFile.set(v.file, []);
    byFile.get(v.file).push(v);
  }
  return [...byFile.entries()].map(([file, items]) => ({
    file,
    count: items.length,
    items,
  }));
}

/**
 * @param {string[]} patterns
 */
export function deriveMergePatternSlug(patterns) {
  const roots = patterns
    .map((p) => p.split('/')[0].replace(/:+$/, '').trim())
    .filter(Boolean);
  const unique = [...new Set(roots)];
  return unique.join('/') || 'merged';
}

/**
 * @param {string | undefined} label
 */
function isUsablePatternLabel(label) {
  const trimmed = String(label || '').trim();
  if (!trimmed) return false;
  if (/^[\/,\s]+$/.test(trimmed)) return false;
  return true;
}

/**
 * @param {ReturnType<typeof parseVisualReviewTable>} tableRows
 * @param {DetailedItem[]} detailedItems
 */
export function buildVisualFindings(tableRows, detailedItems) {
  const rowToDetail = new Map();
  /** @type {DetailedItem[]} */
  const mergeSources = [];

  for (const item of detailedItems) {
    if (item.rows.length === 1) {
      rowToDetail.set(item.rows[0], item);
    } else {
      mergeSources.push(item);
    }
  }

  const rowsInMerge = new Set(mergeSources.flatMap((g) => g.rows));
  const tableByNum = new Map(tableRows.map((r) => [Number(r.num), r]));
  /** @type {Array<Record<string, unknown>>} */
  const findings = [];

  for (const row of tableRows) {
    const rowNum = Number(row.num);
    if (rowsInMerge.has(rowNum)) continue;

    const actionable =
      row.layout === '注意' ||
      row.layout === '要確認' ||
      row.i18n === '注意' ||
      row.i18n === '要確認';
    if (!actionable) continue;

    const detail = rowToDetail.get(rowNum);
    const note = row.note === 'なし' ? '' : row.note;
    const summary = detail?.text || note || `${row.pattern} のビジュアル指摘`;
    if (isReferenceDataExclusion(note, summary)) continue;

    findings.push(buildVisualFinding(row, detail));
  }

  for (const merge of mergeSources) {
    const rows = merge.rows
      .map((n) => tableByNum.get(n))
      .filter((r) => r !== undefined);
    if (rows.length === 0) continue;
    if (isReferenceDataExclusion(rows.map((r) => r.note).join(' '), merge.text)) continue;

    const patterns = rows.map((r) => r.pattern);
    const patternSlug = isUsablePatternLabel(merge.patternLabel)
      ? merge.patternLabel
      : deriveMergePatternSlug(patterns);
    const category = inferCategory(
      rows.map((r) => r.note).join(' '),
      rows.some((r) => r.layout === '注意' || r.layout === '要確認') ? '注意' : 'OK',
      rows.some((r) => r.i18n === '注意' || r.i18n === '要確認') ? '注意' : 'OK',
    );

    findings.push({
      id: `merge-${merge.rows.join('-')}`,
      source: 'visual-review',
      mergeGroup: true,
      priority: merge.priority,
      category,
      pattern: patternSlug,
      patterns,
      visualReviewRows: merge.rows,
      summary: merge.text,
      png: rows.flatMap((r) => [r.ja, r.en, r.in]),
      suggestedTitle: buildTitle(merge.priority, category, patternSlug, merge.text),
    });
  }

  return findings;
}

/**
 * @param {Record<string, string>} row
 * @param {DetailedItem | undefined} detail
 */
function buildVisualFinding(row, detail) {
  const rowNum = Number(row.num);
  const note = row.note === 'なし' ? '' : row.note;
  const summary = detail?.text || note || `${row.pattern} のビジュアル指摘`;
  const category = inferCategory(note, row.layout, row.i18n);
  const priority = detail?.priority || (row.i18n === '要確認' ? 'P0' : 'P1');

  return {
    id: `visual-${rowNum}`,
    source: 'visual-review',
    mergeGroup: false,
    priority,
    category,
    pattern: row.pattern,
    visualReviewRow: rowNum,
    layoutResult: row.layout,
    i18nResult: row.i18n,
    summary,
    note,
    png: [row.ja, row.en, row.in],
    suggestedTitle: buildTitle(priority, category, row.pattern, summary),
  };
}

/**
 * @param {CssViolation[]} violations
 */
export function buildCssFindings(violations) {
  if (violations.length === 0) return [];

  const fileGroups = groupCssViolationsByFile(violations);
  const count = violations.length;
  const summary = `var 外の生色指定 ${count} 件（${fileGroups.length} ファイル）`;
  const patternSlug = deriveCssPatternSlug(fileGroups);

  return [
    {
      id: 'css-all',
      source: 'css-audit',
      mergeGroup: false,
      priority: 'P2',
      category: 'CSS',
      pattern: patternSlug,
      summary,
      fileGroups,
      violations,
      suggestedTitle: `[P2][CSS] ${patternSlug}: トークン直書き色 ${count} 件の置換`,
    },
  ];
}

/**
 * @param {Record<string, unknown>} finding
 * @param {{ number: number, title: string, state: string }} issue
 */
export function matchIssueScore(finding, issue) {
  const title = issue.title.toLowerCase();
  let segmentScore = 0;

  const patterns = finding.patterns || [finding.pattern];
  for (const raw of patterns) {
    const pattern = String(raw).toLowerCase();
    const segments = pattern.split(/[/:]/).map((s) => s.replace(/[()`]/g, '').trim()).filter(Boolean);
    for (const seg of segments) {
      if (titleMatchesSegment(issue.title, seg)) segmentScore += 3;
    }
  }

  let score = segmentScore;
  const isCssFinding = finding.category === 'CSS';

  if (segmentScore > 0 || isCssFinding) {
    const priority = String(finding.priority || '').toLowerCase();
    const category = String(finding.category || '').toLowerCase();
    if (priority && title.includes(`[${priority}]`)) score += 2;
    if (category && title.includes(`[${category}]`)) score += 2;
  }

  if (isCssFinding && (title.includes('css') || title.includes('トークン') || title.includes('gantt'))) {
    score += 2;
  }

  return score;
}

/**
 * @param {Record<string, unknown>} finding
 */
export function isLikelyDuplicateFinding(finding) {
  return (finding.existingIssueCandidates || []).some(
    (c) => c.state === 'OPEN' && c.score >= 5,
  );
}

/**
 * @param {Array<Record<string, unknown>>} findings
 * @param {Array<{ number: number, title: string, state: string }>} issues
 */
export function attachIssueCandidates(findings, issues) {
  return findings.map((finding) => {
    const candidates = issues
      .map((issue) => ({
        number: issue.number,
        title: issue.title,
        state: issue.state,
        score: matchIssueScore(finding, issue),
      }))
      .filter((c) => c.score >= 3)
      .sort((a, b) => b.score - a.score)
      .slice(0, 5)
      .map(({ number, title, state, score }) => ({ number, title, state, score }));

    return { ...finding, existingIssueCandidates: candidates };
  });
}
