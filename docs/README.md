# ドキュメント索引

- **アーキテクチャ（規約本体）**: リポジトリ直下 [`ARCHITECTURE.md`](../ARCHITECTURE.md)
- **設計メモ**: [`design/`](design/)
- **マイグレーション・データ移行**: [`migration/`](migration/)
- **lib/domain → Rust（完了）**: [`migration/lib-domain-rust/`](migration/lib-domain-rust/)（[`TRACKING.yaml`](migration/lib-domain-rust/TRACKING.yaml)）
- **アプリ RUST 化（P6–P7 完了 / P8 Rails シェル削除）**: [`migration/app-rust-stack/`](migration/app-rust-stack/)（本番: [`PRODUCTION-CUTOVER-STATUS.md`](migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md)、残作業: [`P8-RAILS-SHELL-REMOVAL.md`](migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)）
- **テスト運用**: [`testing/`](testing/)
- **アセットパイプライン（Rails HTML 側）**: [`asset-pipeline.md`](asset-pipeline.md)

API・ドメインの振る舞いの正は **`ARCHITECTURE.md`**、**`crates/agrr-domain`**、**該当テスト**（R4: `test/contract/` + `run-rust-contract-tests.sh`）。
