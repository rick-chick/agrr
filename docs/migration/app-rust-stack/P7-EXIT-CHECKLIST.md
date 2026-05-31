# P7 出口チェックリスト（Rails 廃止）

**前提**: [`TRACKING-P6.yaml`](./TRACKING-P6.yaml) の全 BC が `phase: done`。

**ローカルゲート**: [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh)（本番 Rust 単体前に `lib/domain` を削除しない）

| # | 項目 | 確認 |
|---|------|------|
| 1 | URL map から `rails-backend` 削除（[`.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh`](../../../.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh)） | |
| 2 | `lib/domain/` 削除 | |
| 3 | Rails adapter / 未使用 Solid Cable DB 削除 | |
| 4 | refinery ADR 実施（[`P7-REFINERY-ADR.md`](./P7-REFINERY-ADR.md)） | |
| 5 | R4 contract on Rust runtime GREEN | |
| 6 | 本番 Cloud Run Rust 単体 + Litestream（[`Dockerfile.agrr-server`](../../../Dockerfile.agrr-server) / [`start_agrr_server.sh`](../../../scripts/start_agrr_server.sh)） | |

**注意**: 上記は P6 全 BC 切替完了後にのみ実行する。途中で `lib/domain` を削除しない。
