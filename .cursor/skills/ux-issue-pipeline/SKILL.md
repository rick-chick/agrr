---
name: ux-issue-pipeline
description: >-
  AGRR の UX/UI 改善 Issue 作成パイプラインを end-to-end で実行する。
  全ルートキャプチャ → ビジュアルレビュー → CSS 監査 → 指摘収集 → GitHub Issue 起票。
  UX パイプライン、デザインレビューから issue、UI 改善 issue 一括作成で適用する。
---

# UX/UI Issue パイプライン（AGRR）

監査から GitHub Issue 起票までを **1 ワークフロー**でつなぐ。

```
e2e:capture-for-agent
  → frontend-agent-visual-review（visual-review-results.md）
  → audit:css-tokens
  → collect-ux-findings.mjs
  → ux-issue-creator（重複確認・起票）
  → （任意）agent-ready → github-issue-worker
```

## いつ使うか

- 全画面の UX/UI 改善 backlog を GitHub Issue 化したい
- キャプチャ・レビュー後に「気になる点を issue にして」と依頼された
- `PRODUCT-GROWTH-ISSUES.md` の P0/P1 UX 項目をトラッキング可能にしたい

## フェーズ一覧

| # | フェーズ | スキル / コマンド | 成果物 |
|---|----------|-------------------|--------|
| 1 | キャプチャ | `frontend-css-route-audit` | `out/*.{ja,en,in}.png`（verify 通過） |
| 2 | ビジュアルレビュー | `frontend-agent-visual-review` | `visual-review-results.md` |
| 3 | CSS 監査 | `cd frontend && npm run audit:css-tokens` | コンソールレポート |
| 4 | 指摘収集 | `collect-ux-findings.mjs` | `ux-findings-draft.json`, `ux-issue-drafts.md` |
| 5 | Issue 起票 | `ux-issue-creator` | GitHub issues |
| 6 | 実装（別実行） | `github-issue-worker` | PR |

**フェーズ 1–4 は起票の前提。フェーズ 5 だけ単体実行可**（レビュー成果物が最新のとき）。

---

## フェーズ 1 — キャプチャ

**スキル**: `frontend-css-route-audit`

```bash
# Rails development :3000 + ng :4200 が起動していること
cd frontend && npm run e2e:capture-for-agent
```

- `verify-capture-complete.mjs` 通過必須（ルート数 × 3 言語）
- ユーザーに URL を聞かない（`route-to-png.md` が正）

## フェーズ 2 — ビジュアルレビュー

**スキル**: `frontend-agent-visual-review`

- `route-to-png.md` を **10–15 行ずつ**バッチレビューし、**1 ファイル**にマージ
- 出力: `frontend/e2e/agent-review/visual-review-results.md`
- サマリ表: `| # | pattern | ja | en | in | 結果 | i18n | 指摘 |`
- 「指摘の詳細」に P0/P1/P2 を整理（`ux-issue-creator` が参照）

全件一括レビューをユーザーが明示した場合は `#1–N` まとめて可。

## フェーズ 3 — CSS 監査

```bash
cd frontend && npm run audit:css-tokens
```

- 列挙の正はこのコマンド（PNG レビューで CSS を列挙しない）
- CI 相当: `audit:css-tokens:enforce`

## フェーズ 4 — 指摘収集

```bash
node .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs
```

- フェーズ 2・3 の成果物を機械可読 JSON + Markdown 草案に変換
- **複合指摘は mergeGroups に統合**（例: privacy/terms、region_select 系）
- **CSS は var 外のみ・1 issue 候補**
- `existingIssueCandidates` で既存 #13–#25 等との重複をスコア付き提示
- テスト: `node --test .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.test.mjs`

## フェーズ 5 — Issue 起票

**スキル**: `ux-issue-creator`

1. 重複確認（`gh issue list --search`）
2. ドライラン提示
3. ユーザー確認後 `gh issue create`
4. 必要なら `agent-ready` ラベル

タイトル例（既存 issue と統一）:

- `[P0][i18n] about: 運営者情報の生キー表示`
- `[P2][UX] plans/:id/optimizing: 進捗100%時の文言と遷移`
- `[P2][CSS] gantt-chart: トークン直書き色 7 件の置換`

## フェーズ 6 — 実装（オプション・別トリガー）

起票だけが本パイプラインのスコープ。実装は:

- 手動: 「issue ワーカー実行」
- ラベル: `agent-ready` → `.github/workflows/issue-worker-dispatch.yml`
- **スキル**: `github-issue-worker`

デザイン系 issue の実装後は、完了条件に **キャプチャ再実行 + visual-review 更新** が含まれる場合のみフェーズ 1–2 を繰り返す。

---

## 部分実行の早見

| 依頼 | 実行するフェーズ |
|------|------------------|
| 「キャプチャしてレビューだけ」 | 1 → 2 |
| 「レビュー結果から issue 起票」 | 4 → 5（2 が最新であること） |
| 「UX パイプライン全部」 | 1 → 2 → 3 → 4 → 5 |
| 「#N を実装」 | 6 のみ（`github-issue-worker`） |

## 禁止

- キャプチャ verify 未通過で「レビュー完了」
- フェーズ 2 省略で visual-review なし起票
- パイプライン内で PR まで実装（フェーズ 6 と混同しない）
- `npm test` 直叩き（実装フェーズでは `test-common`）

## 関連ドキュメント

- `frontend/e2e/agent-review/README.txt`
- `docs/product/PRODUCT-GROWTH-ISSUES.md`（製品優先度の参考。Issue 起票時に矛盾する場合は製品 doc を優先度調整の入力とする）
- **Cursor Automation 設定**: [references/cursor-automation-schedule.md](references/cursor-automation-schedule.md)

---

## Automation（スケジュール）

Cloud Agent 向け。**フェーズ 1–2（キャプチャ・PNG レビュー）は実行しない**（ローカル Rails :3000 + ng :4200 が必要なため）。リポジトリに commit 済みの `visual-review-results.md` を正とする。

### トリガー例

| cron | 意味 |
|------|------|
| `0 9 * * 1` | 毎週月曜 9:00 JST |
| `0 9 1 * *` | 毎月 1 日 9:00 JST |

設定手順・prefill URL: [references/cursor-automation-schedule.md](references/cursor-automation-schedule.md)

### 実行フロー（Automation 専用）

1. `cd frontend && npm run audit:css-tokens`（フェーズ 3）
2. `node .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs`（フェーズ 4）
3. **`ux-issue-creator` のドライランのみ**（チャット出力 or Memory に要約）
4. 起票判定:
   - `sources.githubLookupStatus` が **`failed`** → **`gh issue create` 禁止**（Memory に失敗理由を記録し終了）
   - `existingIssueCandidates` に **OPEN かつ score ≥ 5** がある finding → **起票しない**（スキップ一覧に記録）
   - 上記以外で **P0/P1** の新規 finding のみ → `gh issue create` 可（1 実行あたり **最大 3 件**）
   - `counts.likelyDuplicateOpen === counts.total` → **起票 0 件**で終了し Memory に記録
5. **PR を開かない**（実装は `github-issue-worker`）
6. `visual-review-results.md` を変更した場合のみ、docs 用 PR を検討（通常は変更しない）

### Automation 用プロンプト（コピペ）

```
You are the AGRR UX Issue Audit automation for rick-chick/agrr.

Read `.cursor/skills/ux-issue-pipeline/SKILL.md` section **Automation（スケジュール）** and follow it exactly.
Read `.cursor/skills/ux-issue-creator/SKILL.md` for dry-run and gh issue create rules.

Do NOT run e2e:capture-for-agent or PNG visual review batches.
Do NOT implement issues or open implementation PRs.
If ux-findings-draft.json has sources.githubLookupStatus === "failed", do NOT gh issue create; record failure and exit.
```

### ローカルとの役割分担

| 作業 | 担当 |
|------|------|
| キャプチャ + 全画面ビジュアルレビュー | ローカル（開発者 or IDE Agent + Docker） |
| CSS 監査 + 草案 + 条件付き起票 | Cursor Automation（本節） |
| issue 実装 | `github-issue-worker` Automation |
