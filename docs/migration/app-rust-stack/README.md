# アプリ RUST 化 — 索引

**本番 API**: Rust（`agrr-server`）。詳細は [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md)。

## 現行（運用・開発）

| 文書 | 内容 |
|------|------|
| [PRODUCTION-CUTOVER-STATUS.md](./PRODUCTION-CUTOVER-STATUS.md) | 本番切替・P7 完了 |
| [P8-RAILS-SHELL-REMOVAL.md](./P8-RAILS-SHELL-REMOVAL.md) | リポジトリから Rails 除去（P8 完了） |
| [P7-MIGRATION-RUNBOOK.md](./P7-MIGRATION-RUNBOOK.md) | `agrr-migrate` schema / data CLI |
| [P7-REFINERY-ADR.md](./P7-REFINERY-ADR.md) | refinery スキーマ移管 |
| [WEATHER-DATA-GCS-SMOKE.md](./WEATHER-DATA-GCS-SMOKE.md) | 天気 GCS スモーク |
| [PROVISIONAL-STACK.md](./PROVISIONAL-STACK.md) | 終着スタック・OAuth・運用（R4 節は現行に更新済み） |
| [ADR-strangler-lb-url-map.md](./ADR-strangler-lb-url-map.md) | ストラングラー配線 ADR（履歴含む） |

## 履歴（P6 移行期）

[`../archive/`](../archive/) — P6 完了条件・`TRACKING-P6.yaml`・移行期テスト手順。

## 関連

- ドメイン移行（完了）: [`../lib-domain-rust/`](../lib-domain-rust/)
- テスト: [`../../test/README.md`](../../test/README.md)、[`../lib-domain-rust/TEST-STRATEGY.md`](../lib-domain-rust/TEST-STRATEGY.md)
