# アプリ RUST 化 — スタック選定

**終着ランタイム**（Axum + `agrr-domain` + Rust adapter）の仮決定と、[`lib-domain-rust`](../lib-domain-rust/) プログラム（P0–P5）および本書（P6–P7）との関係をまとめる。

Rails を移行期の前提として**維持しない**。未移行ルートのみ一時的に Rails が応答し、ストラングラー完了後に廃止する。

| 文書 | 内容 |
|------|------|
| [PROVISIONAL-STACK.md](./PROVISIONAL-STACK.md) | **スタック仮決定**（終着像、本番運用の正、確定事項・OAuth callback 案 A、R4 複製元） |
| [ADR-strangler-lb-url-map.md](./ADR-strangler-lb-url-map.md) | **ストラングラー配線 ADR**（二 Cloud Run + URL map、`/api/*`・`/cable`・`/auth/*`） |
| [BLOCKERS-RESPONSE.md](./BLOCKERS-RESPONSE.md) | **スタック調査ブロッカー回答**（解消済み・P6 ゲート） |
| [TRACKING-P6.yaml](./TRACKING-P6.yaml) | **P6 BC 切替進捗** |
| [P7-REFINERY-ADR.md](./P7-REFINERY-ADR.md) | **P7 スキーマ移管・Rails 廃止 ADR** |
| [P6-BC-CUTOVER-TEMPLATE.md](./P6-BC-CUTOVER-TEMPLATE.md) | BC 切替 PR チェックリスト |
| [P6-COMPLETION-CRITERIA.md](./P6-COMPLETION-CRITERIA.md) | **完了条件**（Rust 起動 ≠ 移行完了、レベル 1〜5） |
| [P7-EXIT-CHECKLIST.md](./P7-EXIT-CHECKLIST.md) | P7 出口（`lib/domain` 削除は全 BC 後） |
| [P7-MIGRATION-RUNBOOK.md](./P7-MIGRATION-RUNBOOK.md) | **schema / data CLI**（本番移行要約・repair は手動 — 冒頭「Rust 本番移行時に必要なこと」） |
| [RUST-OPTIMIZATION-CHAIN-VERIFY.md](./RUST-OPTIMIZATION-CHAIN-VERIFY.md) | **最適化ジョブチェーン**のローカル確認（spike / chain-run） |

**「完了」の定義**は [`P6-COMPLETION-CRITERIA.md`](./P6-COMPLETION-CRITERIA.md) が正。BC 切替 PR の手順は [`P6-BC-CUTOVER-TEMPLATE.md`](./P6-BC-CUTOVER-TEMPLATE.md)。R4 契約テストの実行・CI は [`test/contract/README.md`](../../../test/contract/README.md)。

ドメイン BC の実装順・進捗は [`lib-domain-rust/`](../lib-domain-rust/) を参照。

**着手前提（lib/domain プログラム）**: **満たす**（2026-05-29）— [`TRACKING.yaml`](../lib-domain-rust/TRACKING.yaml) 全 19 BC `phase: done`、[`PROGRAM.md`](../lib-domain-rust/PROGRAM.md) 出口。

**P6 実装（コード）**: [`TRACKING-P6.yaml`](./TRACKING-P6.yaml) 全 BC `phase: done`（2026-05-30）。`agrr-server` + R4 契約 + [`Dockerfile.agrr-server`](../../../Dockerfile.agrr-server) 起動 bootstrap あり。

**本番トラフィック**: 未切替 — URL map は依然 `agrr-rails-backend`（観測 2026-05）。カットオーバーは [`.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh`](../../../.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh) → P7。
