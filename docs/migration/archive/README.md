# 移行プログラム — 履歴ドキュメント（現行運用の正ではない）

P6–P8 完了後、**現行のテスト・開発の正**は次を参照する。

| 用途 | 正 |
|------|-----|
| 本番 API / 切替 | [`../app-rust-stack/PRODUCTION-CUTOVER-STATUS.md`](../app-rust-stack/PRODUCTION-CUTOVER-STATUS.md) |
| Rails シェル削除 | [`../app-rust-stack/P8-RAILS-SHELL-REMOVAL.md`](../app-rust-stack/P8-RAILS-SHELL-REMOVAL.md) |
| ドメイン・adapter テスト | [`../lib-domain-rust/TEST-STRATEGY.md`](../lib-domain-rust/TEST-STRATEGY.md) |
| 実行 | [`.cursor/skills/test-common/SKILL.md`](../../.cursor/skills/test-common/SKILL.md)、[`../../test/README.md`](../../test/README.md) |

## 本ディレクトリのファイル

| ファイル | 内容 |
|----------|------|
| [P6-COMPLETION-CRITERIA.md](./P6-COMPLETION-CRITERIA.md) | P6 完了条件（`test/contract`・Rails デュアル R4 時代） |
| [TRACKING-P6.yaml](./TRACKING-P6.yaml) | P6 BC 切替進捗スナップショット |
| [lib-domain-rust-TEST-STRATEGY-pre-p8.md](./lib-domain-rust-TEST-STRATEGY-pre-p8.md) | R0–R3 Ruby `test/domain` + 移行期 R4 の手順 |
