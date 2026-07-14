# スクリプト一覧

**スキル用スクリプトは本スキル配下の [`scripts/`](../scripts/) に置く。** リポジトリ直下 `scripts/` にはスキル専用を追加しない（[`REFERENCES_GUIDE`](../../_common/REFERENCES_GUIDE.md)）。

プレフィックス `SKILL=.cursor/skills/sequential-cleanup-review-workflow/scripts`

## ワークフロー入口・ループ

| 用途 | パス |
|------|------|
| **workflow 入口（tick）** | `$SKILL/cleanup-workflow-tick.sh --parent-slug SLUG` |
| **inner Step 進行** | `$SKILL/cleanup-inner-advance.sh --parent-slug SLUG --completed-step A1` |
| **inner 現在 Step** | `$SKILL/cleanup-inner-next.sh --parent-slug SLUG` |
| **inner 初期化（pop 後）** | `$SKILL/cleanup-inner-init.sh --parent-slug SLUG` |
| **D 後 post / handoff** | `$SKILL/cleanup-post-d.sh` · `$SKILL/cleanup-agent-handoff.sh` |
| **外側ループ gate** | `$SKILL/run-outer-loop.sh --parent-slug SLUG gate` |
| **次 item prompt** | `$SKILL/run-outer-loop.sh --parent-slug SLUG prepare` |

## backlog

| 用途 | パス |
|------|------|
| **backlog 初期化** | `$SKILL/backlog-init.sh --parent-slug SLUG --unit-name NAME` |
| **item 完了** | `$SKILL/backlog-mark-done.sh --parent-slug SLUG --id ID` |
| **status / pop** | `$SKILL/backlog-status.sh` · `$SKILL/backlog-pop.sh` |
| **D1 TSV ingest** | `$SKILL/backlog-push.sh` · `$SKILL/backlog-import-md.sh` |

## スコープ・レビュー

| 用途 | パス |
|------|------|
| **Step 0 スコープ・マニフェスト** | `$SKILL/collect-modification-scope.sh` |
| **D レビュー検証** | `$SKILL/d-review-validate.sh` |

## 他スキル（共有）

| 用途 | パス |
|------|------|
| R4 契約テスト（全体） | `scripts/run-rust-contract-tests.sh` |
| agrr-domain | `.cursor/skills/test-common/scripts/run-test-rust-domain.sh` |
| Frontend | `.cursor/skills/test-common/scripts/run-test-frontend.sh` |
| メソッド単位デッド候補 | `.cursor/skills/find-method-dead-code/scripts/find-method-dead-code.py` |

実行手順の正は各スキルの SKILL.md（[`test-common`](../../test-common/SKILL.md) 等）。
