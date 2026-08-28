# ドキュメント索引

- **アーキテクチャ（規約本体）**: ルート [`ARCHITECTURE.md`](../ARCHITECTURE.md)（L1）・[`architecture/LAYER-RULES.md`](architecture/LAYER-RULES.md)（L2 詳細）
- **ADR（Architecture Decision Records）**: [`adr/`](adr/)
  - [ADR-001: 生成は外・計算は agrr デーモン（内蔵 AI 廃止方針）](adr/ADR-001-external-skill-generation-agrr-daemon-calculation.md) — 親 [#316](https://github.com/rick-chick/agrr/issues/316)
  - [ADR-002: Organization モデル（B2B マルチテナンシー土台）](adr/ADR-002-organization-multi-tenancy.md) — 親 [#604](https://github.com/rick-chick/agrr/issues/604)
- **設計メモ**: [`design/`](design/)
  - [Organization データモデル案](design/organization-data-model.md) — 親 [#604](https://github.com/rick-chick/agrr/issues/604)
- **コア API / 最適化 SLI・SLO・アラート**: [`ops/core-api-optimization-sli-slo.md`](ops/core-api-optimization-sli-slo.md)
- **Litestream RPO / RTO・レプリケーション運用**: [`ops/litestream-rpo-rto-runbook.md`](ops/litestream-rpo-rto-runbook.md)
- **マイグレーション・データ移行**: [`migration/`](migration/)
- **Ruby→Rust ドメイン移行（完了）**: [`migration/lib-domain-rust/`](migration/lib-domain-rust/)（[`TRACKING.yaml`](migration/lib-domain-rust/TRACKING.yaml)）
- **アプリ RUST 化（完了）**: [`migration/app-rust-stack/`](migration/app-rust-stack/)（本番: [`PRODUCTION-CUTOVER-STATUS.md`](migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md)、P8: [`P8-RAILS-SHELL-REMOVAL.md`](migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)）
- **移行履歴（参照のみ）**: [`migration/archive/`](migration/archive/)
- **ローカル Compose 開発**: [`.cursor/skills/dev-docker/SKILL.md`](../.cursor/skills/dev-docker/SKILL.md)
- **Cursor Automation × GitHub Workflows（全体俯瞰）**: [`automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md`](automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md)（運用設定の正本は [`.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md`](../.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md)）
- **テスト運用**: [`testing/`](testing/)
- **SEO**: [`seo/`](seo/)
  - [SEO 改善レビュー観点（一般ベストプラクティス）](seo/seo-review-perspectives.md)
  - [GSC / CrUX / ルーティング運用](seo/gsc-crux-operations-runbook.md)（デプロイ後検証・定期監視）
  - [VitePress research rebuild checklist](seo/vitepress-rebuild-checklist.md)

API・ドメインの振る舞いの正は **`ARCHITECTURE.md`**、**`crates/agrr-server`**、**`crates/agrr-domain`**、**R4**（`run-rust-contract-tests.sh`）。Ruby 契約は P8.6 で削除済み（[`P8-RAILS-SHELL-REMOVAL.md`](migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)）。
