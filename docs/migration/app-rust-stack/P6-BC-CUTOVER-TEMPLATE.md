# P6 BC 切替 PR テンプレート

> **索引**: [`README.md`](./README.md)  
> **「完了」の定義**（Rust 起動 ≠ P6 / P7 完了）: [`P6-COMPLETION-CRITERIA.md`](./P6-COMPLETION-CRITERIA.md)  
> **進捗**: [`TRACKING-P6.yaml`](./TRACKING-P6.yaml)  
> **R4 手順・CI**: [`test/contract/README.md`](../../../test/contract/README.md)  
> **URL map**: [`ADR-strangler-lb-url-map.md`](./ADR-strangler-lb-url-map.md) · **R4 複製元**: [`PROVISIONAL-STACK.md`](./PROVISIONAL-STACK.md)

1. Ruby §P4 確認（[`gateway-domain-logic-migration.md`](../../gateway-domain-logic-migration.md)）
2. `agrr-adapters-sqlite` / `gcs` / `agrr` trait 実装
3. `agrr-server` `build_*` + presenter + ルート
4. [`test/contract/**`](../../../test/contract/) R4 GREEN（[`test/contract/README.md`](../../../test/contract/README.md) — Rails 全件 + [`scripts/run-rust-contract-tests.sh`](../../../scripts/run-rust-contract-tests.sh) で `CONTRACT_RUNTIME=rust`）
5. 単一ライター（当該テーブル write は Rust のみ）
6. URL map pathRule + `.cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh` デプロイ
7. [`TRACKING-P6.yaml`](./TRACKING-P6.yaml) 更新
