# アプリ RUST 化 — スタック選定

**終着ランタイム**（Axum + `agrr-domain` + Rust adapter）の仮決定と、[`lib-domain-rust`](../lib-domain-rust/) プログラム（P0–P5）および本書（P6–P7）との関係をまとめる。

Rails を移行期の前提として**維持しない**。未移行ルートのみ一時的に Rails が応答し、ストラングラー完了後に廃止する。

| 文書 | 内容 |
|------|------|
| [PROVISIONAL-STACK.md](./PROVISIONAL-STACK.md) | **スタック仮決定**（終着像、本番運用の正、確定事項・OAuth callback 案 A、R4 複製元） |
| [ADR-strangler-lb-url-map.md](./ADR-strangler-lb-url-map.md) | **ストラングラー配線 ADR**（二 Cloud Run + URL map、`/api/*`・`/cable`・`/auth/*`） |
| [BLOCKERS-RESPONSE.md](./BLOCKERS-RESPONSE.md) | **スタック調査ブロッカー回答**（解消済み・P6 ゲート） |

ドメイン BC の実装順・進捗は [`lib-domain-rust/`](../lib-domain-rust/) を参照。

**着手前提（lib/domain プログラム）**: **満たす**（2026-05-29）— [`TRACKING.yaml`](../lib-domain-rust/TRACKING.yaml) 全 19 BC `phase: done`、[`PROGRAM.md`](../lib-domain-rust/PROGRAM.md) 出口。[`BLOCKERS-RESPONSE.md`](./BLOCKERS-RESPONSE.md) §4。P6 残りは §3 adapter §P4・§5 `agrr-server`・BC 単位 R4。
