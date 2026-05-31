# P7 出口チェックリスト（Rails 廃止）

**前提**: [`TRACKING-P6.yaml`](./TRACKING-P6.yaml) の全 BC が `phase: done`。

**ローカルゲート**: [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh)（`lib/domain` 削除後も契約・schema・Cable 除去を検証）

| # | 項目 | 確認 |
|---|------|------|
| 1 | URL map **命名整理** — `rust-backend`（[`scripts/agrr-frontend-url-map-simple.yaml`](../../../scripts/agrr-frontend-url-map-simple.yaml)） | 2026-05-31 |
| 2 | `lib/domain/` 削除 | 2026-05-31 |
| 3 | Rails adapter / 未使用 Solid Cable DB 削除 | 2026-05-31 |
| 4 | refinery ADR 実施（[`P7-REFINERY-ADR.md`](./P7-REFINERY-ADR.md)） | 2026-05-31 |
| 5 | R4 contract on Rust runtime GREEN | 2026-06-01（`p7-code-removal-gate.sh` — 109 runs, 0 failures） |
| 6 | 本番 Cloud Run Rust 単体 + Litestream（[`Dockerfile.agrr-server`](../../../Dockerfile.agrr-server) / [`start_agrr_server.sh`](../../../scripts/start_agrr_server.sh)） | 2026-05-31 — `Dockerfile.production` 削除 |
| 7 | 参照データ: デプロイ後 **手動** `agrr-migrate data apply`（`20260531120000`/`20260531130100` repair は起動時に走らない）— [`P7-MIGRATION-RUNBOOK.md`](./P7-MIGRATION-RUNBOOK.md)「Rust 本番移行時に必要なこと」 | |

**注意**: 上記は P6 全 BC 切替完了後にのみ実行する。途中で `lib/domain` を削除しない。本番 primary への `data apply` は運用合意後にのみ。
