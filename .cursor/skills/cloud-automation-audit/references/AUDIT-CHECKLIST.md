# Cloud Automation 監査チェックリスト

`cloud-automation-audit` SKILL §1–2 用。各項目は **pass / fail / n/a** を記録する。

## 証拠の優先順位（Cloud Agent）

| 優先 | ソース | 備考 |
|------|--------|------|
| 1 | §1B GitHub 副作用 | 毎回実行 |
| 2 | §1C スモーク | 毎回実行 |
| 3 | 自 Automation Memory | 前回監査・連続失敗カウント |
| 4 | §1A 他 Automation run ログ | **人間のみ**（Cloud では不可） |

## Issue Worker

| # | 確認 | クリティカル条件 |
|---|------|------------------|
| 1 | SKILL.md が存在し Automation プロンプトのパスと一致 | ファイル欠落・パス typo |
| 2 | sequential-cleanup-review-workflow SKILL が存在 | 同上 |
| 3 | 直近 7 日に `cursor` 由来 PR または blocked コメントの異常パターン | 毎週例外終了の間接証拠 |
| 4 | `gh issue list` が Cloud Agent で成功 | 今週 fail → P1 注意。2 週連続 fail → P1 |
| 5 | `agent-in-progress` が 7 日以上滞留 | 同一 issue で run が例外終了し続けている根拠あり |
| 6 | 平日 run で「対象なし」のみ | **正常** — 修正不要 |
| 7 | Webhook dispatch: workflow YAML が valid | payload / jq 構文破損 |
| 8 | Secrets 名が doc と一致 | doc 側 typo のみ repo 修正可。未設定は Dashboard 手順 |

## PR Merge Worker

| # | 確認 | クリティカル条件 |
|---|------|------------------|
| 1 | SKILL.md が存在し Automation プロンプトのパスと一致 | ファイル欠落・パス typo |
| 2 | `pr-merge-worker-dispatch.yml` が valid | payload / jq 構文破損・重複 dispatch（Backend test のみ） |
| 3 | ruleset **master CI required** が active | 無い / context 名不一致 → P0 |
| 4 | Issue Worker PR に `agent-merge` 付与手順が doc にある | 連携断絶 |
| 5 | 直近 7 日に eligible PR のマージまたは blocked コメント | 毎回失敗の間接証拠 |
| 6 | Secrets 名が doc と一致 | 未設定は Dashboard 手順（workflow は exit 0） |

## UX Issue Audit

| # | 確認 | クリティカル条件 |
|---|------|------------------|
| 1 | SKILL.md § Automation が存在 | ファイル欠落 |
| 2 | `test -f frontend/e2e/agent-review/visual-review-results.md` | 欠落 → UX Audit 本番パス不能（P0） |
| 3 | `collect-ux-findings.mjs --skip-gh` が exit 0 | 実行時例外（P0） |
| 4 | `collect-ux-findings.mjs --check` / 単体 test が pass | 構文・パーサ破損 |
| 5 | `githubLookupStatus: failed` | **1 週**: Memory + Dashboard 手順。**2 週連続**: P1 エスカレーション |
| 6 | 起票 0（重複 score ≥ 5） | **正常** |
| 7 | e2e キャプチャ未実行 | **正常**（Cloud では実行しない） |

## 共通 bootstrap

| # | 確認 | クリティカル条件 |
|---|------|------------------|
| 1 | `.cursor/environment.json` の `install` が `cloud-gh-auth.sh` を指す | パス誤り |
| 2 | `cloud-gh-auth.sh` が bash -n で pass | 構文エラー |
| 3 | cron ドキュメントが 5 フィールド | 6 フィールド例が doc に残っている |
| 4 | `gitConfig.branch` が `master` | 空欄で default branch エラー |

## Automation Audit（自己監査）

| # | 確認 | クリティカル条件 |
|---|------|------------------|
| 1 | 前回 Memory の「実施した修正」が P0/P1 に該当 | 改善候補のみの PR → 次回以降禁止を Memory に記録 |
| 2 | クリティカル 0 件で PR を開いていない | 毎週 doc 修正 PR → スキル違反 |

## 改善候補（記載のみ・修正禁止）

- run 時間・トークンコストが高い
- Memory が冗長 / 不足
- プロンプトを短くできる
- 監査頻度の変更
- 新しい Automation の追加
