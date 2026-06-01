# アプリ RUST 化 — スタック選定

**終着ランタイム**（Axum + `agrr-domain` + Rust adapter）と P6–P7（本番切替・Rails 廃止）の索引。

| 文書 | 内容 |
|------|------|
| [PROVISIONAL-STACK.md](./PROVISIONAL-STACK.md) | **スタック仮決定**（終着像、本番運用、OAuth、R4） |
| [ADR-strangler-lb-url-map.md](./ADR-strangler-lb-url-map.md) | ストラングラー配線 ADR |
| [TRACKING-P6.yaml](./TRACKING-P6.yaml) | P6 BC 切替進捗（全 `done`） |
| [P6-COMPLETION-CRITERIA.md](./P6-COMPLETION-CRITERIA.md) | **完了条件**（レベル 1〜5） |
| [P7-REFINERY-ADR.md](./P7-REFINERY-ADR.md) | refinery スキーマ移管 |
| [P7-MIGRATION-RUNBOOK.md](./P7-MIGRATION-RUNBOOK.md) | `agrr-migrate` schema / data CLI |
| [WEATHER-DATA-GCS-SMOKE.md](./WEATHER-DATA-GCS-SMOKE.md) | 天気 GCS スモーク |
| [PRODUCTION-CUTOVER-STATUS.md](./PRODUCTION-CUTOVER-STATUS.md) | **本番切替・P7 完了の正** |
| [P8-RAILS-SHELL-REMOVAL.md](./P8-RAILS-SHELL-REMOVAL.md) | **リポジトリから Rails を外す**（P7 後の残作業） |

**完了の定義**: [`P6-COMPLETION-CRITERIA.md`](./P6-COMPLETION-CRITERIA.md)。R4 契約: [`test/contract/README.md`](../../../test/contract/README.md)、`./scripts/run-rust-contract-tests.sh`。

**lib/domain プログラム**: 完了（[`TRACKING.yaml`](../lib-domain-rust/TRACKING.yaml) 19/19 `done`）。

**P6 コード**: 完了（[`TRACKING-P6.yaml`](./TRACKING-P6.yaml) 全 BC `done`）。

**本番 API**: Rust（`agrr-server` on `agrr-production`）。詳細・手動スモーク・P7 削除順は [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md)。チェック: [`.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh`](../../../.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh)。
