# アプリ RUST 化 — スタック選定

**終着ランタイム**（Axum + `agrr-domain` + Rust adapter）の仮決定と、[`lib-domain-rust`](../lib-domain-rust/) プログラム（P0–P5）および本書（P6–P7）との関係をまとめる。

Rails を移行期の前提として**維持しない**。未移行ルートのみ一時的に Rails が応答し、ストラングラー完了後に廃止する。

| 文書 | 内容 |
|------|------|
| [PROVISIONAL-STACK.md](./PROVISIONAL-STACK.md) | **スタック仮決定**（終着像、本番運用の正、確定事項・OAuth callback 案 A、R4 複製元、残 ADR） |
| [BLOCKERS-RESPONSE.md](./BLOCKERS-RESPONSE.md) | **スタック調査ブロッカー回答**（解消済み・未決・P6 ゲート） |

ドメイン BC の実装順・進捗は [`lib-domain-rust/`](../lib-domain-rust/) を参照。

**着手前提（lib/domain プログラム）**: [`PROGRAM.md`](../lib-domain-rust/PROGRAM.md) の「lib/domain プログラム出口」— 全コンテキスト `phase: done` かつ R0・R1・R2 GREEN。adapter §P4 残留は [`gateway-domain-logic-migration.md`](../../gateway-domain-logic-migration.md) で app 移植と並行。
