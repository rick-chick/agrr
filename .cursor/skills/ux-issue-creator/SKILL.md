---
name: ux-issue-creator
description: >-
  visual-review-results.md・audit:css-tokens の指摘から rick-chick/agrr 向け GitHub Issue を起票する。
  重複確認・ドライラン・gh issue create・agent-ready ラベル付与まで。
  UX Issue 作成、ビジュアルレビューから issue、CSS 監査から issue、
  ux-findings-draft の起票で適用する。
---

# UX/UI Issue Creator（AGRR）

監査成果物を **GitHub Issue** に変換する。実装は **`github-issue-worker`** に委譲する。

## 入力（正とするファイル）

| 入力 | パス |
|------|------|
| ビジュアルレビュー | `frontend/e2e/agent-review/visual-review-results.md` |
| PNG | `frontend/e2e/agent-review/out/*.{ja,en,in}.png` |
| CSS 監査 | `cd frontend && npm run audit:css-tokens` |
| **自動収集の出力** | `frontend/e2e/agent-review/ux-findings-draft.json` |
| **人間可読草案** | `frontend/e2e/agent-review/ux-issue-drafts.md` |

**前提**: `visual-review-results.md` が最新であること。無い・古い場合は先に **`ux-issue-pipeline`** のステップ 1–2 を実行する。

## 1) 指摘の収集

```bash
node .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs
# CI / オフライン時
node .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs --skip-gh
```

- `visual-review-results.md` のサマリ表（`注意` / `要確認`）と「指摘の詳細」の P0–P2 をマージ
- **複合行**（`#8 / #14`、`#17–18, #30–31`）は `mergeGroups` として **1 issue 候補**に統合
- CSS は `audit:css-tokens` の **var 外セクションのみ**を拾い、**リポジトリ全体で 1 issue**（#24 方針）
- 各 finding に `existingIssueCandidates`（`gh issue list` 照合・score ≥ 3）を付与
- 出力: `ux-findings-draft.json` + `ux-issue-drafts.md`

`ux-findings-draft.json` の主要フィールド:

| フィールド | 意味 |
|------------|------|
| `mergeGroups` | 統合起票候補の一覧 |
| `findings[].mergeGroup` | `true` なら複数行を束ねた候補 |
| `findings[].existingIssueCandidates` | 重複の可能性がある既存 issue（`state` / `score` 付き） |
| `counts.likelyDuplicateOpen` | OPEN かつ score ≥ 5 の既存候補がある件数（起票スキップの目安） |
| `sources.githubLookupStatus` | `ok` / `skipped` / `failed`（`failed` 時は起票禁止） |

`--skip-gh` または `gh` 失敗時は `githubLookupStatus` を確認する。**`failed` のまま起票しない。**

`suggestedTitle` は 60 文字で切り詰められる場合がある。起票時は `summary` 全文を本文に写し、タイトルは人手で短縮する。

参照データ由来（`note` / 詳細に「参照データ」）の行は `collect` が自動除外する。それ以外の対象外は §3 の優先度表に従う。

既に CSS ログがある場合:

```bash
cd frontend && npm run audit:css-tokens 2> /tmp/css-audit.log || true
node .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs --css-audit-log /tmp/css-audit.log
```

## 2) 重複・統合（必須）

1. `ux-findings-draft.json` の `sources.githubLookupStatus` を確認（**`failed` なら起票中止**）
2. `existingIssueCandidates` を読む（**open かつ score ≥ 5 なら起票しない**）
3. `mergeGroup: true` の候補は **個別行より優先**して 1 issue に起票
4. 不足時のみ `gh issue list` で手動確認:

```bash
gh issue list --repo rick-chick/agrr --state all --search "in:title <pattern の主要語>" --limit 20
```

| 判定 | 動作 |
|------|------|
| `existingIssueCandidates` に **OPEN** あり（score ≥ 5） | **起票しない**（コメントで visual-review 行番号を追記可） |
| score 3–4 のみ | ドライランで人間確認 |
| 部分重複 | **1 issue に統合**（本文に複数 #N を列挙） |
| i18n 系が複数画面で同根因（例: region_select） | **1 issue**（`mergeGroups` 参照。例: #17–18, #30–31） |

Issue 本文の型は [references/issue-body-template.md](references/issue-body-template.md)。

## 3) 優先度・区分の上書き

自動提案をそのまま使わず、次で調整する。

| 条件 | 優先度 |
|------|--------|
| 画面に生キーが全面表示 | P0 |
| 主要フロー（public-plans, plans）の UX 破綻 | P0–P1 |
| en/in のラベル混在 | P1 |
| CSS トークン直書き | P2 |
| 参照データ由来の表示混在 | **起票しない**（`collect` は `参照データ` を含む行を除外。総評のみの記述は詳細に行番号を付けない） |

区分: `i18n` / `UX` / `CSS` / `a11y`（タイトル `[P1][i18n]` 形式）。

## 4) ドライラン（必須）

起票前に該当ルート・PNG で現象を確認する。本文は再現手順と完了条件を主契約とする（修正方針は書かない）。

`gh issue create` の**前**に、チャットまたは `ux-issue-drafts.md` へ次を出力する。

- 起票予定一覧（タイトル・優先度・統合理由）
- スキップ一覧（重複・対象外・理由）
- 付与予定ラベル（`enhancement` / `bug` / `agent-ready`）

**ユーザーが「起票して」と明示するまで `gh issue create` しない。**

**Cursor Automation**（`ux-issue-pipeline` §Automation）経路では、同節の起票条件（P0/P1 新規・score &lt; 5・最大 3 件）が本確認を上書きする。

`counts.likelyDuplicateOpen` が総件数の大半なら、ドライランで「新規起票 0・スキップ一覧のみ」を報告する。

## 5) Issue 起票

```bash
gh issue create --repo rick-chick/agrr \
  --title "[P1][UX] plans/:id/optimizing: 進捗100%時の文言と遷移" \
  --label enhancement \
  --label agent-ready \
  --body-file /tmp/ux-issue-body.md
```

- 本文は `issue-body-template.md` のテンプレートを満たす
- バッチ起票時は **1 finding = 1 issue**（統合した場合は 1 統合 issue）
- 起票後、一覧を issue コメントまたは Memory に記録

### agent-ready

**実装対象の issue には起票時に `agent-ready` を付与する**（`github-issue-worker` へ渡す既定）。

`agent-ready` を**付けない**のは次のみ:

| 条件 | 理由 |
|------|------|
| ユーザーと方針・優先度・設計が**議論中・未確定** | 確定前に Worker が着手しない |
| `documentation` のみ（実装なし） | Worker 対象外 |
| ユーザーが **`agent-ready` 不要**と明示 | バックログとして残す |

起票後に `agent-ready` を外す必要があるとき:

```bash
gh issue edit <N> --remove-label agent-ready
```

## 6) 終了条件

- [ ] `collect-ux-findings.mjs` 実行済み
- [ ] 重複確認済み（スキップ理由を記録）
- [ ] ドライラン提示済み
- [ ] 起票した issue 番号一覧を報告
- [ ] 実装対象 issue に `agent-ready` 付与済み（除外理由を記録）

## 禁止

- `visual-review-results.md` 未更新のまま起票
- 重複確認なしの大量 `gh issue create`
- 完了条件・参照なしの issue
- 修正方針のみ・再現手順なしの issue
- 方針未確定・議論中の issue に `agent-ready` を付与
- 実装（PR）まで踏み込む（それは `github-issue-worker`）

## 関連

- パイプライン全体: **`ux-issue-pipeline`**
- キャプチャ・CSS: **`frontend-css-route-audit`**
- ビジュアルレビュー: **`frontend-agent-visual-review`**
- 実装: **`github-issue-worker`**
