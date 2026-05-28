# ドキュメント索引

- **アーキテクチャ（規約本体）**: リポジトリ直下 [`ARCHITECTURE.md`](../ARCHITECTURE.md)
- **設計メモ**: [`design/`](design/)
- **マイグレーション・データ移行**: [`migration/`](migration/)
- **lib/domain → Rust 移行プログラム**: [`migration/lib-domain-rust/`](migration/lib-domain-rust/)（進捗: [TRACKING.md](migration/lib-domain-rust/TRACKING.md)）
- **テスト運用**: [`testing/`](testing/)
- **アセットパイプライン（Rails HTML 側）**: [`asset-pipeline.md`](asset-pipeline.md)
- **Gateway 移行（命名・adapter 残存ドメインロジック）**: [`gateway-domain-logic-migration.md`](gateway-domain-logic-migration.md)（正: [`gateway-naming-violations.md`](gateway-naming-violations.md) は命名中心）

API・ドメインの振る舞いの正は **`ARCHITECTURE.md`** と **`lib/domain` のポート/DTO**、および **該当テスト** とする（旧 `docs/contracts/`・`docs/adr/` は廃止）。
