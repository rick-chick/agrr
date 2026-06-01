# ドキュメント索引

- **アーキテクチャ（規約本体）**: リポジトリ直下 [`ARCHITECTURE.md`](../ARCHITECTURE.md)
- **設計メモ**: [`design/`](design/)
- **マイグレーション・データ移行**: [`migration/`](migration/)
- **lib/domain → Rust（完了）**: [`migration/lib-domain-rust/`](migration/lib-domain-rust/)（[`TRACKING.yaml`](migration/lib-domain-rust/TRACKING.yaml)）
- **アプリ RUST 化（完了）**: [`migration/app-rust-stack/`](migration/app-rust-stack/)（本番: [`PRODUCTION-CUTOVER-STATUS.md`](migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md)、P8: [`P8-RAILS-SHELL-REMOVAL.md`](migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)）
- **移行履歴（参照のみ）**: [`migration/archive/`](migration/archive/)
- **ローカル Compose 開発**: [`.cursor/skills/dev-docker/SKILL.md`](../.cursor/skills/dev-docker/SKILL.md)
- **テスト運用**: [`testing/`](testing/)

API・ドメインの振る舞いの正は **`ARCHITECTURE.md`**、**`crates/agrr-server`**、**`crates/agrr-domain`**、**R4**（`run-rust-contract-tests.sh`）。Ruby 契約は P8.6 で削除済み（[`P8-RAILS-SHELL-REMOVAL.md`](migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)）。
