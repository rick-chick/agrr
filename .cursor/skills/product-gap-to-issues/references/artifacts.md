# 成果物チェーン

すべて `tmp/product-gap/` 配下。リポジトリに commit しない。Issue 本文には `tmp/` を参照しない（内容を埋め込む）。

## 終了地点語彙（正本）

依頼文から終了地点（最終フェーズ）を確定するときの語彙。**他ファイルは本節を再定義せずリンクする。**

| コード | 依頼に含まれる語彙（例） | 最終フェーズ |
|--------|--------------------------|--------------|
| **F2** | 候補洗い出し、バックログ洗い出し、ギャップ列挙、足りない機能の列挙 | フェーズ 2 |
| **F4** | テーマ深掘り、1 テーマの調査 | フェーズ 4 |
| **F7** | 方針、方針レビュー、計画まで | フェーズ 7（G3 `pass`） |
| **F8** | モック、画面モックまで | フェーズ 8 |
| **F9** | GitHub issue 起票、Epic 起票、バックログ起票、issue 化、issue 作成、「起票」「起票まで」 | フェーズ 9 |

**判定不能**: 「調査」「整理」「比較」等だけでは F2〜F9 を確定できない。着手前に focused question で終了地点を確認する。

**F9 と明示依頼**: 終了地点が **F9** と確定した時点で **issue 起票の明示依頼**とみなす（[`github-issue-creator`](../../github-issue-creator/SKILL.md) §4 例外と同一文言）。`issue-pack.md` を一括ドライランとし、§2・§3 を満たしていれば同一実行で §5 へ進める。F9 以外で着手し、後から起票へ進む依頼は **新しい明示承認**とみなし、通常の §4 パスに従う。

## 終了地点別の必須成果物

| 終了地点 | 最終フェーズ | 必須ファイル |
|----------|--------------|--------------|
| F2 ギャップ洗い出し | フェーズ 2 | `current-state.md`, `gap-backlog.md` |
| F4 テーマ深掘り | フェーズ 4 | 上記 + `theme-selection.md`, `theme-deep-dive.md` |
| F7 方針 | フェーズ 7 | 上記 + `overlap-ux-gate.json`（`pass`）, `enhancement-plan.md`, `plan-review.json`（`pass`） |
| F8 モック | フェーズ 8 | 上記 + `screen-mocks.md` |
| F9 issue 起票 | フェーズ 9 | 上記 + `issue-pack.md`, GitHub #N |

## ファイル一覧

| ファイル | フェーズ | 備考 |
|----------|----------|------|
| `current-state.md` | 1 | 常に必須 |
| `gap-backlog.md` | 2 | 常に必須 |
| `theme-selection.md` | 3 | フェーズ 3 以降 |
| `theme-deep-dive.md` | 4 | フェーズ 4 以降 |
| `overlap-ux-gate.json` | 5 G2 | フェーズ 5 以降（`pass`） |
| `enhancement-plan.md` | 6 | フェーズ 6 以降 |
| `plan-review.json` | 7 G3 | フェーズ 7 以降（`pass`） |
| `screen-mocks.md` | 8 | モック・起票 |
| `issue-pack.md` | 9 | 起票のみ |

## ゲート JSON の例

**G2 pass（既存強化）:**

```json
{
  "gate": "overlap-ux-guard",
  "verdict": "pass",
  "summary": "既存 /work と /plans/:id/work で役割分担。新画面なし",
  "findings": [],
  "mandatory_corrections": []
}
```

**G2 pass（新ルートあり・justification 済み）:**

```json
{
  "gate": "overlap-ux-guard",
  "verdict": "pass",
  "summary": "新ルート /reports/compliance は既存画面では帳票導線を賄えないため採用",
  "findings": [],
  "mandatory_corrections": []
}
```

**G3 fail:**

```json
{
  "gate": "plan-review",
  "verdict": "fail",
  "summary": "v1 と v2 の境界が未記載",
  "findings": ["天候注意と GDD 補足が v1 issue に混在"],
  "mandatory_corrections": ["enhancement-plan に v1/v2 を分離", "v2 を Epic の後続に移動"]
}
```

## 完了報告（正本）

完了報告の内容は **本節のみ**が正本。各フェーズ手順は [`phases.md`](phases.md) で本節へリンクする。

| 終了地点 | 報告に含めるもの |
|----------|------------------|
| F2 ギャップ洗い出し | `gap-backlog.md` 要約 |
| F4 テーマ深掘り | `theme-deep-dive.md` 要約 + `theme-selection.md` の選定理由 |
| F7 方針 | `enhancement-plan.md` 要約 + G2/G3 verdict |
| F8 モック | `screen-mocks.md` 要約 |
| F9 issue 起票 | [`github-issue-creator`](../../github-issue-creator/SKILL.md) §7 終了チェックを満たしたうえで、Epic / 子 issue の URL 一覧 + `agent-ready` の有無と理由 |
