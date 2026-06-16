import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import {
  attachIssueCandidates,
  buildCssFindings,
  buildTitle,
  buildVisualFindings,
  extractVarOutsideSection,
  isLikelyDuplicateFinding,
  isReferenceDataExclusion,
  matchIssueScore,
  parseCssAuditLog,
  parseDetailRowNumbers,
  parseDetailedFindings,
  parseVisualReviewTable,
  titleMatchesSegment,
} from './collect-ux-findings-parsers.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURES = join(__dirname, 'fixtures');

test('parseDetailRowNumbers: 単一行・複合・範囲', () => {
  assert.deepEqual(parseDetailRowNumbers('#3 about'), [3]);
  assert.deepEqual(parseDetailRowNumbers('#8 privacy / #14 terms'), [8, 14]);
  assert.deepEqual(parseDetailRowNumbers('#17–18, #30–31'), [17, 18, 30, 31]);
  assert.deepEqual(parseDetailRowNumbers('#32–35 interaction_rules'), [32, 33, 34, 35]);
});

test('parseDetailedFindings: 複合行を rows 配列で展開', () => {
  const md = `
## 指摘の詳細

### P1 — 補間

4. **#8 privacy / #14 terms** — contact_link 未展開。
7. **#17–18, #30–31** — en で地域ラベルが日本語。
`;
  const items = parseDetailedFindings(md);
  assert.equal(items.length, 2);
  assert.deepEqual(items[0].rows, [8, 14]);
  assert.deepEqual(items[1].rows, [17, 18, 30, 31]);
});

test('parseCssAuditLog: var 外セクションのみ（var 内は除外）', async () => {
  const log = await readFile(join(FIXTURES, 'css-audit-sample.log'), 'utf8');
  const violations = parseCssAuditLog(log);
  assert.equal(violations.length, 2);
  assert.ok(violations.every((v) => v.file.includes('gantt-chart')));
  assert.ok(!violations.some((v) => v.file.includes('login')));
});

test('extractVarOutsideSection: 内側セクションを切り落とす', async () => {
  const log = await readFile(join(FIXTURES, 'css-audit-sample.log'), 'utf8');
  const section = extractVarOutsideSection(log);
  assert.match(section, /gantt-chart/);
  assert.doesNotMatch(section, /login\.component\.css/);
});

test('buildCssFindings: リポジトリ全体で 1 issue', () => {
  const violations = parseCssAuditLog(
    '--- var 外 ---\nsrc/app/components/plans/a.component.css:1  [hex] #fff\n  color: #fff;\nsrc/app/components/plans/b.component.css:2  [hex] #000\n  color: #000;\n--- var( 内のみ ---\nsrc/app/components/auth/login/login.component.css:68  [hex] #2196f3\n',
  );
  const findings = buildCssFindings(violations);
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'css-all');
  assert.equal(findings[0].violations.length, 2);
});

test('buildCssFindings: 最多違反ファイルのコンポーネント名を slug に使う', () => {
  const violations = parseCssAuditLog(
    '--- var 外 ---\nsrc/app/components/plans/a.component.css:1  [hex] #fff\nsrc/app/components/plans/gantt-chart.component.css:1  [hex] #000\nsrc/app/components/plans/gantt-chart.component.css:2  [hex] #111\n',
  );
  const findings = buildCssFindings(violations);
  assert.match(findings[0].suggestedTitle, /gantt-chart/);
  assert.equal(findings[0].pattern, 'gantt-chart');
});

test('buildVisualFindings: merge group は個別行を出さない', () => {
  const tableRows = [
    { num: '8', pattern: 'privacy', ja: 'a.ja.png', en: 'a.en.png', in: 'a.in.png', layout: 'OK', i18n: '注意', note: 'i18n: contact' },
    { num: '14', pattern: 'terms', ja: 'b.ja.png', en: 'b.en.png', in: 'b.in.png', layout: 'OK', i18n: '注意', note: 'i18n: contact' },
    { num: '3', pattern: 'about', ja: 'c.ja.png', en: 'c.en.png', in: 'c.in.png', layout: 'OK', i18n: '要確認', note: 'i18n: key' },
  ];
  const detailed = parseDetailedFindings(`
## 指摘の詳細
### P1 — x
4. **#8 privacy / #14 terms** — contact_link 未展開。
### P0 — y
1. **#3 about** — 生キー。
`);
  const findings = buildVisualFindings(tableRows, detailed);
  assert.equal(findings.length, 2);
  assert.ok(findings.some((f) => f.id === 'merge-8-14' && f.mergeGroup === true));
  assert.ok(findings.some((f) => f.id === 'visual-3'));
  assert.ok(!findings.some((f) => f.id === 'visual-8'));
});

test('buildVisualFindings: 行番号のみの merge はテーブル pattern から slug を導出', () => {
  const tableRows = [
    { num: '17', pattern: 'agricultural_tasks/:id/edit', ja: 'a.ja.png', en: 'a.en.png', in: 'a.in.png', layout: 'OK', i18n: '注意', note: 'i18n: region' },
    { num: '18', pattern: 'agricultural_tasks/new', ja: 'b.ja.png', en: 'b.en.png', in: 'b.in.png', layout: 'OK', i18n: '注意', note: 'i18n: region' },
    { num: '30', pattern: 'fertilizes/:id/edit', ja: 'c.ja.png', en: 'c.en.png', in: 'c.in.png', layout: 'OK', i18n: '注意', note: 'i18n: region' },
    { num: '31', pattern: 'fertilizes/new', ja: 'd.ja.png', en: 'd.en.png', in: 'd.in.png', layout: 'OK', i18n: '注意', note: 'i18n: region' },
  ];
  const detailed = parseDetailedFindings(`
## 指摘の詳細
### P1 — x
7. **#17–18, #30–31** — en で地域ラベルが日本語。
`);
  const merge = buildVisualFindings(tableRows, detailed).find((f) => f.id === 'merge-17-18-30-31');
  assert.ok(merge);
  assert.notEqual(merge.pattern, '/');
  assert.equal(merge.pattern, 'agricultural_tasks/fertilizes');
});

test('matchIssueScore: pattern 不一致の P1 i18n は候補にならない', () => {
  const finding = { priority: 'P1', category: 'i18n', pattern: 'about' };
  const unrelated = { title: '[P1][i18n] public-plans/results: 気候プレースホルダ', state: 'OPEN' };
  assert.ok(matchIssueScore(finding, unrelated) < 3);
});

test('titleMatchesSegment: crop は crops に部分一致しない', () => {
  assert.equal(
    titleMatchesSegment('[P1][i18n] マスタ en: region_select と crops ラベル混在', 'crop'),
    false,
  );
});

test('matchIssueScore: entry-schedule と crops issue は無関係', () => {
  const finding = { priority: 'P0', category: 'i18n', pattern: 'entry-schedule/crop/:cropId' };
  const unrelated = { title: '[P1][i18n] マスタ en: region_select と crops ラベル混在', state: 'OPEN' };
  assert.ok(matchIssueScore(finding, unrelated) < 3);
});

test('matchIssueScore: plans は public-plans のハイフン接尾辞だけでは一致しない', () => {
  const finding = { priority: 'P0', category: 'i18n', pattern: 'plans/:id/task_schedule' };
  const unrelated = { title: '[P1][i18n] public-plans/results: 気候プレースホルダの言語確認', state: 'OPEN' };
  assert.ok(matchIssueScore(finding, unrelated) < 5);
});

test('matchIssueScore: plans.task_schedules は plans セグメントで一致する', () => {
  const finding = { priority: 'P0', category: 'i18n', pattern: 'plans/:id/task_schedule' };
  const related = { title: '[P0][i18n] plans.task_schedules: in.json 追加と i18n catalog', state: 'OPEN' };
  assert.ok(matchIssueScore(finding, related) >= 5);
});

test('buildTitle: pattern の / と : を保持する', () => {
  const title = buildTitle('P0', 'i18n', 'plans/:id/task_schedule', 'summary text');
  assert.match(title, /\[P0\]\[i18n\] plans\/:id\/task_schedule: summary text/);
});

test('matchIssueScore: CSS は segment なしでもトークン系タイトルと一致', () => {
  const finding = { priority: 'P2', category: 'CSS', pattern: 'src/app/components' };
  const cssIssue = { title: '[P2][CSS] gantt-chart: トークン直書き色 7 件の置換', state: 'OPEN' };
  assert.ok(matchIssueScore(finding, cssIssue) >= 5);
});

test('isLikelyDuplicateFinding: OPEN かつ score >= 5 のみ', () => {
  assert.equal(
    isLikelyDuplicateFinding({
      existingIssueCandidates: [
        { state: 'OPEN', score: 4 },
        { state: 'OPEN', score: 5 },
      ],
    }),
    true,
  );
  assert.equal(
    isLikelyDuplicateFinding({
      existingIssueCandidates: [{ state: 'OPEN', score: 4 }],
    }),
    false,
  );
  assert.equal(
    isLikelyDuplicateFinding({
      existingIssueCandidates: [{ state: 'CLOSED', score: 10 }],
    }),
    false,
  );
});

test('parseVisualReviewTable: サマリ表の列をパース', () => {
  const md = `
| # | pattern | ja | en | in | 結果 | i18n | 指摘 |
|---|---------|----|----|----|----|------|------|
| 3 | \`about\` | \`about.ja.png\` | \`about.en.png\` | \`about.in.png\` | OK | 要確認 | i18n: key |
`;
  const rows = parseVisualReviewTable(md);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].num, '3');
  assert.equal(rows[0].pattern, 'about');
  assert.equal(rows[0].ja, 'about.ja.png');
  assert.equal(rows[0].i18n, '要確認');
});

test('isReferenceDataExclusion: 参照データ由来は起票対象外', () => {
  assert.equal(
    isReferenceDataExclusion('参照データ由来の表示混在', ''),
    true,
  );
  assert.equal(
    isReferenceDataExclusion('', '作物名・作業名等の多言語混在は参照データ由来で UI 破綻ではない'),
    true,
  );
  assert.equal(isReferenceDataExclusion('i18n: region_select 混在', ''), false);
});

test('buildVisualFindings: 参照データ由来の行は除外', () => {
  const tableRows = [
    {
      num: '5',
      pattern: 'crops',
      ja: 'crops.ja.png',
      en: 'crops.en.png',
      in: 'crops.in.png',
      layout: 'OK',
      i18n: '注意',
      note: '参照データ由来: 作物名の多言語混在',
    },
  ];
  const findings = buildVisualFindings(tableRows, []);
  assert.equal(findings.length, 0);
});

test('attachIssueCandidates: 既存 issue をスコア付きで提案', () => {
  const findings = [
    {
      id: 'visual-3',
      priority: 'P0',
      category: 'i18n',
      pattern: 'about',
      suggestedTitle: '[P0][i18n] about: 生キー',
    },
  ];
  const issues = [
    { number: 16, title: '[P0][i18n] about 運営者情報: 再キャプチャ確認と contact_html 修正', state: 'OPEN' },
    { number: 99, title: '[P2][UX] unrelated', state: 'OPEN' },
  ];
  const [withCandidates] = attachIssueCandidates(findings, issues);
  assert.equal(withCandidates.existingIssueCandidates.length, 1);
  assert.equal(withCandidates.existingIssueCandidates[0].number, 16);
  assert.ok(matchIssueScore(findings[0], issues[0]) >= 3);
});
